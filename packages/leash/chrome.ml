type spawn_error = Eta_process.Child.error
type reason = [ `Spawn of spawn_error | `Schedule_exhausted of Eta_process.Child.exit ]
type event = Started of int | Lost of int | Gave_up of reason Eta.Cause.t | Stopped
type phase = [ `Running | `Restarting | `Gave_up | `Stopped ]
type status = { generation : int; phase : phase; failure : string option }

type backoff = {
  initial : Eta.Duration.t;
  cap : Eta.Duration.t;
  factor : float;
  attempts : int;
}

let default_backoff =
  {
    initial = Eta.Duration.seconds 1;
    cap = Eta.Duration.seconds 30;
    factor = 2.0;
    attempts = 10;
  }

type config = {
  binary : string;
  profile_dir : string;
  workspace : string;
  grace : Eta.Duration.t;
  backoff : backoff;
  headless : bool;
  window_size : string;
}

let make ~binary ~profile_dir ~workspace ?(grace = Eta.Duration.seconds 5)
    ?(backoff = default_backoff) ?(headless = false) ?(window_size = "1366,900") () =
  { binary; profile_dir; workspace; grace; backoff; headless; window_size }

let argv config =
  [
    config.binary;
    "--user-data-dir=" ^ config.profile_dir;
    "--no-first-run";
    "--no-default-browser-check";
    "--hide-crash-restore-bubble";
    "--remote-debugging-pipe";
    "--class=leash";
  ]
  @
  if config.headless then [ "--headless=new"; "--window-size=" ^ config.window_size ]
  else []

type 'clock deps = {
  clock : 'clock Eio.Time.clock;
  mgr : Eio_unix.Process.mgr_ty Eio.Resource.t;
  logger : Eta_observability.Logger.t;
}

type 'clock launch =
  sw:Eio.Switch.t ->
  clock:'clock Eio.Time.clock ->
  mgr:Eio_unix.Process.mgr_ty Eio.Resource.t ->
  config ->
  (Eta_process.Child.t * Cdp.transport, spawn_error) result

let fd flow =
  match Eio_unix.Resource.fd_opt flow with
  | Some fd -> fd
  | None -> invalid_arg "Chrome: pipe flow without a unix descriptor"

let launch_pipe ~sw ~clock ~mgr config =
  let child_read, parent_write = Eio_unix.pipe sw in
  let parent_read, child_write = Eio_unix.pipe sw in
  match
    Eta_process.Child.spawn ~sw ~clock ~mgr ~argv:(argv config) ~grace:config.grace
      ~stderr:Pipe
      ~fds:[ (3, fd child_read); (4, fd child_write) ]
      ()
  with
  | Error error -> Error error
  | Ok child ->
      Eio.Resource.close child_read;
      Eio.Resource.close child_write;
      Ok (child, { Cdp.read = parent_read; write = parent_write })

let schedule backoff =
  Eta.Schedule.both
    (Eta.Schedule.exponential ~factor:backoff.factor backoff.initial)
    (Eta.Schedule.recurs backoff.attempts)
  |> Eta.Schedule.max_interval backoff.cap

let pp_reason ppf = function
  | `Spawn (`Invalid_fd fd) -> Format.fprintf ppf "invalid fd %d" fd
  | `Spawn (`Duplicate_fd fd) -> Format.fprintf ppf "duplicate fd %d" fd
  | `Schedule_exhausted (Eta_process.Child.Exited status) ->
      Format.fprintf ppf "chrome exited with status %d" status
  | `Schedule_exhausted (Eta_process.Child.Signaled signal) ->
      Format.fprintf ppf "chrome was killed by signal %d" signal

let render cause = Format.asprintf "%a" (Eta.Cause.pp_compact pp_reason) cause

module Log = struct
  let lifecycle logger level ~msg fields =
    Eta_observability.Logger.log logger level ~msg ~fields ()

  let int name value = (name, Eta_observability.Logger.Int value)
  let string name value = (name, Eta_observability.Logger.String value)
end

type state = {
  signals :
    [ `Supervised of spawn_error Eta_process.Supervised.event | `Transport_closed of int ]
    Eio.Stream.t;
  events : event Eio.Stream.t;
  logger : Eta_observability.Logger.t;
  mutable phase : phase;
  mutable generation : int;
  mutable current : (int * Cdp.t) option;
  mutable failure : string option;
  mutable pending : Cdp.t option;
  mutable stderr_tails : (int * Chrome_stderr.t * unit Eio.Promise.t) list;
  mutable closed_before_start : int option;
}

type t = { state : state; supervised : spawn_error Eta_process.Supervised.t }

let publish state event =
  if Eio.Stream.length state.events >= 32 then
    ignore (Eio.Stream.take_nonblocking state.events);
  Eio.Stream.add state.events event

let lost state generation ~origin =
  state.current <- None;
  state.phase <- `Restarting;
  let stderr =
    match List.find_opt (fun (n, _, _) -> n = generation) state.stderr_tails with
    | Some (_, tail, drained) ->
        Eio.Promise.await drained;
        state.stderr_tails <-
          List.filter (fun (n, _, _) -> n <> generation) state.stderr_tails;
        Chrome_stderr.lines tail
    | None -> []
  in
  publish state (Lost generation);
  Log.lifecycle state.logger Eta_observability.Logger.Warn ~msg:"chrome generation lost"
    [
      Log.int "generation" generation;
      Log.string "origin" origin;
      ( "stderr",
        Eta_observability.Logger.Json (`List (List.map (fun line -> `String line) stderr))
      );
    ]

let on_started state generation =
  let cdp = state.pending in
  state.pending <- None;
  state.generation <- generation;
  state.phase <- `Running;
  state.failure <- None;
  state.current <- Option.map (fun cdp -> (generation, cdp)) cdp;
  publish state (Started generation);
  Log.lifecycle state.logger Eta_observability.Logger.Info ~msg:"chrome started"
    [ Log.int "generation" generation ];
  match state.closed_before_start with
  | Some closed when closed = generation ->
      state.closed_before_start <- None;
      lost state generation ~origin:"transport before start"
  | _ -> ()

let on_exited state generation exit =
  if generation = state.generation && state.phase = `Running then
    let origin =
      match exit with
      | Eta_process.Child.Exited status -> "exit " ^ string_of_int status
      | Signaled signal -> "signal " ^ string_of_int signal
    in
    lost state generation ~origin

let on_transport_closed state generation =
  if generation = state.generation then
    begin if state.phase = `Running then lost state generation ~origin:"transport"
    end
  else if generation > state.generation then state.closed_before_start <- Some generation

let on_gave_up state cause =
  if state.phase = `Running then lost state state.generation ~origin:"gave up";
  let failure = render cause in
  state.phase <- `Gave_up;
  state.current <- None;
  state.failure <- Some failure;
  publish state (Gave_up cause);
  Log.lifecycle state.logger Eta_observability.Logger.Error ~msg:"chrome gave up"
    [ Log.string "cause" failure ]

let on_stopped state =
  state.phase <- `Stopped;
  state.current <- None;
  publish state Stopped;
  Log.lifecycle state.logger Eta_observability.Logger.Info ~msg:"chrome stopped" []

let rec observe state : [ `Stop_daemon ] =
  (match Eio.Stream.take state.signals with
  | `Supervised (Eta_process.Supervised.Started generation) -> on_started state generation
  | `Supervised (Exited (generation, exit)) -> on_exited state generation exit
  | `Supervised (Gave_up cause) -> on_gave_up state cause
  | `Supervised Stopped -> on_stopped state
  | `Transport_closed generation -> on_transport_closed state generation);
  observe state

let create ~sw ?(launch : 'clock launch = launch_pipe) config (deps : 'clock deps) =
  let state =
    {
      signals = Eio.Stream.create max_int;
      events = Eio.Stream.create 32;
      logger = deps.logger;
      phase = `Restarting;
      generation = 0;
      current = None;
      failure = None;
      pending = None;
      stderr_tails = [];
      closed_before_start = None;
    }
  in
  let spawns = ref 0 in
  let spawn ~sw:child_sw =
    match launch ~sw:child_sw ~clock:deps.clock ~mgr:deps.mgr config with
    | Error error -> Error error
    | Ok (child, transport) ->
        incr spawns;
        let generation = !spawns in
        let cdp = Cdp.create ~sw:child_sw ~clock:deps.clock transport in
        let tail = Chrome_stderr.create () in
        let drained, resolve = Eio.Promise.create () in
        state.stderr_tails <- (generation, tail, drained) :: state.stderr_tails;
        (match Eta_process.Child.stderr child with
        | None -> Eio.Promise.resolve resolve ()
        | Some source ->
            Eio.Fiber.fork ~sw:child_sw (fun () ->
                Fun.protect
                  ~finally:(fun () -> Eio.Promise.resolve resolve ())
                  (fun () -> Chrome_stderr.read tail source)));
        state.pending <- Some cdp;
        Eio.Fiber.fork_daemon ~sw:child_sw (fun () ->
            let _reason = Eio.Promise.await (Cdp.closed cdp) in
            Eio.Stream.add state.signals (`Transport_closed generation);
            (* The generation is over either way: a browser we cannot talk to still holds
               the profile lock, so the process is retired before the restart. *)
            ignore (Eta_process.Child.stop child);
            `Stop_daemon);
        Ok child
  in
  let supervised =
    Eta_process.Supervised.start ~sw ~clock:deps.clock ~schedule:(schedule config.backoff)
      ~spawn
  in
  Eio.Fiber.fork_daemon ~sw (fun () ->
      let rec forward () : [ `Stop_daemon ] =
        Eio.Stream.add state.signals
          (`Supervised (Eio.Stream.take (Eta_process.Supervised.events supervised)));
        forward ()
      in
      forward ());
  Eio.Fiber.fork_daemon ~sw (fun () -> observe state);
  { state; supervised }

let generation t = Eta_process.Supervised.generation t.supervised

let status t =
  {
    generation = Eta_process.Supervised.generation t.supervised;
    phase = t.state.phase;
    failure = t.state.failure;
  }

let connection t =
  match (t.state.phase, t.state.current) with
  | `Running, Some (_, cdp) -> Ok cdp
  | _ -> Error `Browser_unavailable

let events t = t.state.events
let stop t = Eta_process.Supervised.stop t.supervised
