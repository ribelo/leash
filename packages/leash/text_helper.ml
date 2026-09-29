(* L19 — the text helper's Leash-side seam; L22 — its chat client
   (docs/issues/drive/01-drive.md, milestone 5; drive-ls3c drive-fh1h).

   The request is jev-ultrafast's field_text at the pinned commit, copied and not
   adapted: one OpenAI-compatible chat completion whose system message is questions.py's
   TEXT_VALUE and whose user message is json.dumps of field_context — the goal verbatim,
   the field's label, role and value, the page's title and its text bounded at 6000
   bytes on a character boundary, and the last six actions with only their action and text
   (model.py:154-159).
   The reply must parse as exactly {"text": string | null}: null is the model saying the
   value is missing, and the drive ends blocked naming the field; a string is the value
   that goes to the browser, refused over 4 KiB. An answer is remembered and reused when
   the identical context comes back, which is what a stale-page retry is
   (agent.py:105-115). *)

module P = Protocol
module J = Jev_request

type field = { label : string; role : string; value : string }

type context = {
  goal : string;
  field : field;
  page_title : string;
  page_text : string;
  recent : J.recent_action list;
}

type t = {
  complete : ?deadline:Ox.Duration.t -> context -> (string option, P.error) result;
}

let default_deadline = Ox.Duration.seconds 30

(* model.py:157-158 and the drive spec's bound. *)
let page_bytes = 6000
let window = 6
let text_bound = 4096

(* The reference slices Python strings; this truncates bytes and backs off to the last
   whole character, so what is written as a JSON string is always valid UTF-8. *)
let bounded limit text =
  if String.length text <= limit then text
  else begin
    let at = ref limit in
    while !at > 0 && Char.code text.[!at] land 0xc0 = 0x80 do
      decr at
    done;
    String.sub text 0 !at
  end

let last n list =
  let rec drop count list =
    if count <= 0 then list
    else match list with [] -> [] | _ :: rest -> drop (count - 1) rest
  in
  drop (max 0 (List.length list - n)) list

(* model.py:154-159, key for key and bound for bound: the goal as the drive stated it,
   the field the model chose, the page's title and bounded text, and the recent window
   with the two members the reference keeps. *)
let field_context (context : context) =
  let recent =
    List.map
      (fun (action : J.recent_action) ->
        `Assoc
          [
            ("action", `String action.action);
            ("text", match action.text with Some text -> `String text | None -> `Null);
          ])
      (last window context.recent)
  in
  `Assoc
    [
      ("goal", `String context.goal);
      ( "field",
        `Assoc
          [
            ("label", `String context.field.label);
            ("role", `String context.field.role);
            ("value", `String context.field.value);
          ] );
      ( "page",
        `Assoc
          [
            ("title", `String context.page_title);
            ("text", `String (bounded page_bytes context.page_text));
          ] );
      ("recent_actions", `List recent);
    ]

let nothing_typed =
  "the text helper did not answer {\"text\": string|null}; nothing typed"

let refused why = Error (Model_error.unavailable ~code:"invalid-response" why)

(* Exactly one member, text, a string within the bound or null: anything else is a
   refusal, and nothing is typed. *)
let value content =
  match Yojson.Safe.from_string content with
  | `Assoc [ ("text", `String text) ] when String.length text <= text_bound ->
      Ok (Some text)
  | `Assoc [ ("text", `String _) ] ->
      refused
        (Printf.sprintf "the text helper answered a text over %d bytes; nothing typed"
           text_bound)
  | `Assoc [ ("text", `Null) ] -> Ok None
  | _ -> refused nothing_typed
  | exception Yojson.Json_error _ -> refused nothing_typed

(* drive-7tvn: the helper call's accounting, at info so the operator sees it at the
   default level — ox's chat client logs the same call at debug. Written for every
   answered call, before the content is parsed, because the tokens were spent either
   way; a memo reuse makes no call and logs nothing. *)
let log_usage logger (completion : Ox_ai_chat.Codecs.completion) =
  let Ox_ai_chat.Types.{ prompt_tokens; completion_tokens; total_tokens; cost } =
    completion.Ox_ai_chat.Codecs.usage
  in
  Ox_observability.Logger.info logger
    ~fields:
      [
        ("model", Ox_observability.Logger.String completion.Ox_ai_chat.Codecs.model);
        ("prompt_tokens", Ox_observability.Logger.Int prompt_tokens);
        ("completion_tokens", Ox_observability.Logger.Int completion_tokens);
        ("total_tokens", Ox_observability.Logger.Int total_tokens);
        ("cost", Ox_observability.Logger.Float (Option.value ~default:0. cost));
      ]
    "text helper usage"

let ask client ~model ~logger ?(deadline = default_deadline) json =
  let open Ox_ai_chat.Types in
  let messages =
    [ { role = System; content = Questions.text_value }; { role = User; content = json } ]
  in
  Model_usage.start "text_helper";
  match
    Ox_ai_chat.complete client ~deadline ~model ~messages ~max_tokens:1024
      ~json_object:true ~reasoning:`Disabled ()
  with
  | Error error -> Error (Model_error.of_eta error)
  | Ok first -> (
      log_usage logger first;
      Model_usage.report "text_helper" first.Ox_ai_chat.Codecs.usage.cost;
      let content = first.Ox_ai_chat.Codecs.content in
      match value content with
      | Ok answer -> Ok answer
      | Error error -> (
          (* drive-ls3c, L34: malformed model formatting gets one bounded correction,
             never a permissive extraction. Overlong typed values are terminal. *)
          let overlong =
            match Yojson.Safe.from_string content with
            | `Assoc [ ("text", `String text) ] -> String.length text > text_bound
            | _ -> false
            | exception Yojson.Json_error _ -> false
          in
          if overlong then Error error
          else
            let retry =
              messages
              @ [
                  { role = Assistant; content };
                  {
                    role = User;
                    content =
                      "Your previous answer was not exactly one JSON object with only a \
                       text member. Reply with only {\"text\": string|null}; do not add \
                       Markdown fences, other members, or prose.";
                  };
                ]
            in
            Model_usage.start "text_helper";
            match
              Ox_ai_chat.complete client
                ~deadline:(Ox.Duration.min deadline default_deadline)
                ~model ~messages:retry ~max_tokens:1024 ~json_object:true
                ~reasoning:`Disabled ()
            with
            | Error error -> Error (Model_error.of_eta error)
            | Ok second ->
                log_usage logger second;
                Model_usage.report "text_helper" second.Ox_ai_chat.Codecs.usage.cost;
                value second.Ox_ai_chat.Codecs.content))

let create ~client ~model ~logger () =
  (* The one-entry memo of agent.py:110-114, keyed by what the reference compares: the
     field context as it is written to the wire, so a reuse needs the whole helper input
     to be unchanged. A refusal is not remembered. *)
  let last = ref None in
  {
    complete =
      (fun ?deadline context ->
        let json = Yojson.Safe.to_string (field_context context) in
        match !last with
        | Some (previous, answer) when previous = json -> answer
        | _ ->
            let answer = ask client ~model ~logger ?deadline json in
            (match answer with Ok (Some _) -> last := Some (json, answer) | _ -> ());
            answer);
  }

let refusing code message : t =
  let complete ?(deadline = default_deadline) (_ : context) =
    ignore deadline;
    Error (Model_error.unavailable ~code message)
  in
  { complete }

let unavailable = refusing "text-helper-unavailable" "text helper unavailable"

let missing_key =
  refusing "missing-key" "no OpenRouter API key: set OPENROUTER_API_KEY or models.api_key"
