module P = Protocol

let capacity = 500

(* One request. The record is mutable because a request is told in pieces: what was asked,
   what answered, and how it ended. *)
type entry = {
  seq : int;
  mutable id : string;
  chrome_id : string;
  method_ : string;
  url : string;
  resource : string;
  mutable headers : (string * string) list;
  has_post_data : bool;
  started : float option;
  mutable status : int option;
  mutable mime : string option;
  mutable size : int option;
  mutable duration : int option;
  mutable from_cache : bool;
  mutable error : string option;
  mutable responded : bool;
  mutable redirected : bool;
}

type t = {
  entries : (string, entry) Hashtbl.t;
  order : (int * string) Queue.t;
  mutable next : int;
}

let create () = { entries = Hashtbl.create 64; order = Queue.create (); next = 0 }
let member key = function `Assoc fields -> List.assoc_opt key fields | _ -> None
let text key json = match member key json with Some (`String s) -> Some s | _ -> None

let number key json =
  match member key json with
  | Some (`Int n) -> Some (float_of_int n)
  | Some (`Float x) -> Some x
  | _ -> None

let flag key json = match member key json with Some (`Bool b) -> b | _ -> false

(* UTF-8 safe: a cut never lands inside a multi-byte character. *)
let clip limit s =
  if String.length s <= limit then (s, false)
  else
    let cut = ref limit in
    while !cut > 0 && Char.code s.[!cut] land 0xc0 = 0x80 do
      decr cut
    done;
    (String.sub s 0 !cut, true)

let max_url = 8192
let max_header_value = 8192
let max_headers = 200

let headers_of json =
  match json with
  | Some (`Assoc fields) ->
      List.filteri (fun i _ -> i < max_headers) fields
      |> List.filter_map (fun (name, value) ->
          match value with
          | `String v -> Some (name, fst (clip max_header_value v))
          | _ -> None)
  | _ -> []

let millis seconds = int_of_float (Float.round (seconds *. 1000.))

let evict t =
  while Hashtbl.length t.entries > capacity && not (Queue.is_empty t.order) do
    let seq, id = Queue.pop t.order in
    match Hashtbl.find_opt t.entries id with
    | Some entry when entry.seq = seq -> Hashtbl.remove t.entries id
    | _ -> ()
  done

let add t entry =
  Hashtbl.replace t.entries entry.id entry;
  Queue.push (entry.seq, entry.id) t.order;
  evict t

let redirect_hop t (old : entry) (response : Yojson.Safe.t option) =
  (* The hop that redirected keeps its history under a name of its own, so the request
     that follows can carry Chrome's id. *)
  Hashtbl.remove t.entries old.id;
  old.id <- Printf.sprintf "%s~%d" old.chrome_id old.seq;
  old.redirected <- true;
  Option.iter
    (fun response ->
      (match number "status" response with
      | Some status -> old.status <- Some (int_of_float status)
      | None -> ());
      Option.iter (fun mime -> old.mime <- Some mime) (text "mimeType" response))
    response;
  Queue.push (old.seq, old.id) t.order;
  Hashtbl.replace t.entries old.id old

let observe t json =
  match (text "method" json, member "params" json) with
  | Some "Network.requestWillBeSent", Some params -> (
      match (text "requestId" params, member "request" params) with
      | Some chrome_id, Some request ->
          (match Hashtbl.find_opt t.entries chrome_id with
          | Some previous -> redirect_hop t previous (member "redirectResponse" params)
          | None -> ());
          let seq = t.next in
          t.next <- seq + 1;
          add t
            {
              seq;
              id = chrome_id;
              chrome_id;
              method_ = Option.value ~default:"GET" (text "method" request);
              url = fst (clip max_url (Option.value ~default:"" (text "url" request)));
              resource =
                String.lowercase_ascii
                  (Option.value ~default:"other" (text "type" params));
              headers = headers_of (member "headers" request);
              has_post_data =
                flag "hasPostData" request || Option.is_some (text "postData" request);
              started = number "timestamp" params;
              status = None;
              mime = None;
              size = None;
              duration = None;
              from_cache = false;
              error = None;
              responded = false;
              redirected = false;
            }
      | _ -> ())
  | Some "Network.requestWillBeSentExtraInfo", Some params -> (
      (* The headers Chrome really sent, cookies and authorization included, arrive here
         and not in requestWillBeSent. *)
      match text "requestId" params with
      | Some id -> (
          match Hashtbl.find_opt t.entries id with
          | Some entry ->
              let extra = headers_of (member "headers" params) in
              let fresh =
                List.filter
                  (fun (name, _) -> not (List.mem_assoc name extra))
                  entry.headers
              in
              entry.headers <- extra @ fresh
          | None -> ())
      | None -> ())
  | Some "Network.responseReceived", Some params -> (
      match Option.bind (text "requestId" params) (Hashtbl.find_opt t.entries) with
      | Some entry ->
          entry.responded <- true;
          Option.iter
            (fun response ->
              Option.iter
                (fun status -> entry.status <- Some (int_of_float status))
                (number "status" response);
              entry.mime <- text "mimeType" response;
              if flag "fromDiskCache" response || flag "fromPrefetchCache" response then
                entry.from_cache <- true)
            (member "response" params)
      | None -> ())
  | Some "Network.requestServedFromCache", Some params -> (
      match Option.bind (text "requestId" params) (Hashtbl.find_opt t.entries) with
      | Some entry -> entry.from_cache <- true
      | None -> ())
  | Some "Network.loadingFinished", Some params -> (
      match Option.bind (text "requestId" params) (Hashtbl.find_opt t.entries) with
      | Some entry -> (
          Option.iter
            (fun bytes -> entry.size <- Some (int_of_float bytes))
            (number "encodedDataLength" params);
          match (entry.started, number "timestamp" params) with
          | Some started, Some finished when finished >= started ->
              entry.duration <- Some (millis (finished -. started))
          | _ -> ())
      | None -> ())
  | Some "Network.loadingFailed", Some params -> (
      match Option.bind (text "requestId" params) (Hashtbl.find_opt t.entries) with
      | Some entry -> (
          entry.error <-
            Some (Option.value ~default:"request failed" (text "errorText" params));
          match (entry.started, number "timestamp" params) with
          | Some started, Some finished when finished >= started ->
              entry.duration <- Some (millis (finished -. started))
          | _ -> ())
      | None -> ())
  | _ -> ()

let contains_ci haystack needle =
  let haystack = String.lowercase_ascii haystack
  and needle = String.lowercase_ascii needle in
  let n = String.length needle in
  let rec scan at =
    at + n <= String.length haystack
    && (String.sub haystack at n = needle || scan (at + 1))
  in
  scan 0

let sorted t =
  Hashtbl.fold (fun _ entry acc -> entry :: acc) t.entries []
  |> List.sort (fun a b -> compare a.seq b.seq)

let listed (entry : entry) : P.net_entry =
  {
    id = entry.id;
    method_ = entry.method_;
    url = entry.url;
    status = entry.status;
    type_ = entry.resource;
    mime = entry.mime;
    size = entry.size;
    duration_ms = entry.duration;
    from_cache = entry.from_cache;
    error = entry.error;
  }

let list t (args : P.net_args) =
  let limit = Option.value ~default:100 args.limit in
  if limit < 0 || limit > capacity then
    Error
      (P.make_error
         (match P.Error_code.of_string "invalid-request" with
         | Ok c -> c
         | Error _ -> assert false)
         ~message:(Printf.sprintf "net limit must be 0..%d" capacity))
  else
    let wanted_type = Option.map String.lowercase_ascii args.type_ in
    let matching =
      sorted t
      |> List.filter (fun (entry : entry) ->
          Option.fold ~none:true
            ~some:(fun needle -> contains_ci entry.url needle)
            args.match_
          && Option.fold ~none:true ~some:(fun kind -> entry.resource = kind) wanted_type)
    in
    let skip = max 0 (List.length matching - limit) in
    Ok P.{ requests = List.filteri (fun i _ -> i >= skip) matching |> List.map listed }

type request = {
  id : string;
  chrome_id : string;
  method_ : string;
  url : string;
  headers : (string * string) list;
  has_post_data : bool;
  has_body : bool;
}

let find t id =
  Option.map
    (fun (entry : entry) ->
      {
        id = entry.id;
        chrome_id = entry.chrome_id;
        method_ = entry.method_;
        url = entry.url;
        headers = entry.headers;
        has_post_data = entry.has_post_data;
        has_body = entry.responded && entry.error = None && not entry.redirected;
      })
    (Hashtbl.find_opt t.entries id)
