(* extr-zdst: the shape language is data, decoded into a variant; validation is a pure
   function over the decoded JSON, so it is table-tested with no browser. *)
type scalar = String | Number | Boolean | Url

type t = Scalar of scalar | Record of field list | List of t
and field = { name : string; optional : bool; shape : t }

let max_depth = 8

let scalar_name = function
  | String -> "string"
  | Number -> "number"
  | Boolean -> "boolean"
  | Url -> "url"

let ( let* ) = Result.bind

let rec t_of_yojson_at path depth json =
  if depth > max_depth then
    Error (Printf.sprintf "%s: shape nested more than %d deep" path max_depth)
  else
    match json with
    | `String "string" -> Ok (Scalar String)
    | `String "number" -> Ok (Scalar Number)
    | `String "boolean" -> Ok (Scalar Boolean)
    | `String "url" -> Ok (Scalar Url)
    | `String s when String.ends_with ~suffix:"?" s ->
        Error
          (Printf.sprintf
             "%s: a field is optional by a ? on its name, not on its type (%s)" path s)
    | `String s ->
        Error
          (Printf.sprintf "%s: unknown type %S (string, number, boolean or url)" path s)
    | `List [ one ] ->
        let* shape = t_of_yojson_at (path ^ "[]") (depth + 1) one in
        Ok (List shape)
    | `List _ -> Error (path ^ ": a list shape has exactly one element shape")
    | `Assoc [] -> Error (path ^ ": a record shape declares at least one field")
    | `Assoc fields ->
        let rec go seen acc = function
          | [] -> Ok (Record (List.rev acc))
          | (key, value) :: rest ->
              let optional = String.ends_with ~suffix:"?" key in
              let name =
                if optional then String.sub key 0 (String.length key - 1) else key
              in
              if name = "" then Error (path ^ ": a field needs a name")
              else if List.mem name seen then
                Error (Printf.sprintf "%s: field %S is declared twice" path name)
              else
                let* shape = t_of_yojson_at (path ^ "." ^ name) (depth + 1) value in
                go (name :: seen) ({ name; optional; shape } :: acc) rest
        in
        go [] [] fields
    | _ -> Error (path ^ ": a shape is a type name, a record object or a one-element list")

let t_of_yojson json = t_of_yojson_at "returns" 0 json

let rec yojson_of_t = function
  | Scalar scalar -> `String (scalar_name scalar)
  | List shape -> `List [ yojson_of_t shape ]
  | Record fields ->
      `Assoc
        (List.map
           (fun field ->
             ( (if field.optional then field.name ^ "?" else field.name),
               yojson_of_t field.shape ))
           fields)

let check_returns = function
  | Record _ | List (Record _) -> Ok ()
  | _ -> Error "returns must be a record or a list of records"

let kind = function
  | `Null -> "null"
  | `Bool _ -> "boolean"
  | `Int _ | `Intlit _ | `Float _ -> "number"
  | `String _ -> "string"
  | `List _ -> "array"
  | `Assoc _ -> "object"
  | `Tuple _ | `Variant _ -> "value"

let is_url s =
  let after prefix =
    if String.starts_with ~prefix s then Some (String.length prefix) else None
  in
  match match after "https://" with Some n -> Some n | None -> after "http://" with
  | None -> false
  | Some n ->
      n < String.length s
      && s.[n] <> '/'
      && String.for_all (fun c -> Char.code c > 0x20 && Char.code c <> 0x7f) s

let rec validate_at path shape json =
  let mismatch what = Error (Printf.sprintf "%s: %s" path what) in
  match (shape, json) with
  | Scalar String, `String _ -> Ok ()
  | Scalar Number, (`Int _ | `Intlit _) -> Ok ()
  | Scalar Number, `Float f ->
      if Float.is_finite f then Ok () else mismatch "expected a finite number"
  | Scalar Boolean, `Bool _ -> Ok ()
  | Scalar Url, `String s ->
      if is_url s then Ok ()
      else mismatch (Printf.sprintf "expected an http(s) url, got %S" s)
  | Scalar scalar, other ->
      mismatch (Printf.sprintf "expected %s, got %s" (scalar_name scalar) (kind other))
  | List element, `List items ->
      let rec go i = function
        | [] -> Ok ()
        | item :: rest ->
            let* () = validate_at (Printf.sprintf "%s[%d]" path i) element item in
            go (i + 1) rest
      in
      go 0 items
  | List _, other -> mismatch (Printf.sprintf "expected an array, got %s" (kind other))
  | Record fields, `Assoc members -> (
      let* () =
        List.fold_left
          (fun acc field ->
            let* () = acc in
            let here = path ^ "." ^ field.name in
            match List.assoc_opt field.name members with
            | None | Some `Null ->
                if field.optional then Ok ()
                else
                  Error
                    (Printf.sprintf "%s: missing field %S%s" path field.name
                       (if List.mem_assoc field.name members then " (it is null)" else ""))
            | Some value -> validate_at here field.shape value)
          (Ok ()) fields
      in
      match
        List.find_opt
          (fun (key, _) -> not (List.exists (fun f -> f.name = key) fields))
          members
      with
      | Some (key, _) -> Error (Printf.sprintf "%s.%s: unexpected field" path key)
      | None -> Ok ())
  | Record _, other -> mismatch (Printf.sprintf "expected an object, got %s" (kind other))

let validate shape json = validate_at "$" shape json
let records = function `List items -> List.length items | _ -> 1
