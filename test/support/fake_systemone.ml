(* The local System One server the L19 tests drive (drive-e7oi drive-yqxg drive-kh2u).

   Copied in shape from eta-next's test/ai/fake_server.ml, which is proven against
   {!Eta_http.Client}: plaintext over a loopback listener on the test's switch, one
   complete request read and recorded per connection, the scripted reply written after it,
   then the send side shut down. The accept loop is a daemon, because a plain fork parked
   in [accept] is never woken by the switch's release. *)

type request = {
  method_ : string;
  target : string;
  headers : (string * string) list;
  body : string;
}

type reply = { status : int; reason : string; body : string }
type t = { port : int; requests : request list ref; connections : int ref }

let ok body = { status = 200; reason = "OK"; body }
let failure ?(reason = "Error") status body = { status; reason; body }

let http_response (reply : reply) =
  let headers =
    [
      ("Content-Length", string_of_int (String.length reply.body));
      ("Connection", "close");
      ("Content-Type", "application/json");
    ]
  in
  Printf.sprintf "HTTP/1.1 %d %s\r\n%s\r\n\r\n%s" reply.status reply.reason
    (String.concat "\r\n" (List.map (fun (name, value) -> name ^ ": " ^ value) headers))
    reply.body

let read_request flow =
  let input = Eio.Buf_read.of_flow ~max_size:(8 * 1024 * 1024) flow in
  let line = Eio.Buf_read.line input in
  let method_, target =
    match String.split_on_char ' ' line with
    | method_ :: target :: _ -> (method_, target)
    | _ -> ("", "")
  in
  let rec headers acc =
    let line = Eio.Buf_read.line input in
    if String.equal line "" then List.rev acc
    else
      match String.index_opt line ':' with
      | Some at ->
          headers
            (( String.lowercase_ascii (String.trim (String.sub line 0 at)),
               String.trim (String.sub line (at + 1) (String.length line - at - 1)) )
            :: acc)
      | None -> headers acc
  in
  let headers = headers [] in
  let body =
    match List.assoc_opt "content-length" headers with
    | Some length -> Eio.Buf_read.take (int_of_string length) input
    | None -> ""
  in
  { method_; target; headers; body }

let start ~sw listener answer =
  let port =
    match Eio.Net.listening_addr listener with
    | `Tcp (_, port) -> port
    | _ -> assert false
  in
  let requests = ref [] and connections = ref 0 in
  ignore
    (Eio.Fiber.fork_daemon ~sw (fun () ->
         let rec accept () : [ `Stop_daemon ] =
           let flow, _ = Eio.Net.accept ~sw listener in
           connections := !connections + 1;
           let request = read_request flow in
           requests := !requests @ [ request ];
           (* A client that stops reading closes its side first, so a write can fail;
              that is the client's verdict to make, not the server's. *)
           (try
              Eio.Flow.copy_string (http_response (answer request)) flow;
              Eio.Flow.shutdown flow `Send
            with Eio.Io _ | End_of_file -> ());
           accept ()
         in
         accept ()));
  { port; requests; connections }

let serve ~net ~sw answer =
  let listener =
    Eio.Net.listen ~sw ~backlog:8 net (`Tcp (Eio.Net.Ipaddr.V4.loopback, 0))
  in
  start ~sw listener answer

let requests t = !(t.requests)
let connections t = !(t.connections)
let port t = t.port
let url t path = Printf.sprintf "http://127.0.0.1:%d%s" t.port path
let request t = match requests t with [] -> None | request :: _ -> Some request
let body t = match request t with Some request -> request.body | None -> ""

let header name (request : request) =
  List.assoc_opt (String.lowercase_ascii name) request.headers
