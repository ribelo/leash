(* svc-qrmc: bound both the number of lines and the size of one unterminated line. *)
let capacity = 20
let line_limit = 1024

type t = { lines : string array; mutable next : int; mutable count : int }

let create () = { lines = Array.make capacity ""; next = 0; count = 0 }

let push t line =
  t.lines.(t.next) <- line;
  t.next <- (t.next + 1) mod capacity;
  t.count <- min capacity (t.count + 1)

let lines t =
  List.init t.count (fun i -> t.lines.((t.next - t.count + i + capacity) mod capacity))

let read t source =
  let chunk = Cstruct.create 4096 in
  let line = Bytes.create line_limit in
  let length = ref 0 in
  let flush () =
    let n =
      if !length > 0 && Bytes.get line (!length - 1) = '\r' then !length - 1 else !length
    in
    push t (Bytes.sub_string line 0 n);
    length := 0
  in
  let rec loop () =
    match Eio.Flow.single_read source chunk with
    | n ->
        for i = 0 to n - 1 do
          let c = Cstruct.get_char chunk i in
          if c = '\n' then flush ()
          else if !length < line_limit then (
            Bytes.set line !length c;
            incr length)
        done;
        loop ()
    | exception End_of_file -> if !length > 0 then flush ()
  in
  loop ()
