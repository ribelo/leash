(* field-jkx6: the fallback owns element objects, never selectors used later by an action. *)
module P = Protocol

let get key = function
  | `Assoc fields -> Option.value ~default:`Null (List.assoc_opt key fields)
  | _ -> `Null

let list = function `List values -> values | _ -> []
let text = function `String value -> value | _ -> ""
let integer = function `Int value -> value | _ -> -1
let ( let* ) = Result.bind

let expression ~selector =
  Printf.sprintf
    {|(() => {
  const rows = [], elements = [];
  for (const el of document.querySelectorAll(%s + ',iframe')) {
    if (rows.length === 250) break;
    const rect = el.getBoundingClientRect(), css = getComputedStyle(el);
    if (rect.width <= 0 || rect.height <= 0 || rect.bottom <= 0 || rect.right <= 0 ||
        rect.top >= innerHeight || rect.left >= innerWidth ||
        css.display === 'none' || css.visibility === 'hidden') continue;
    const tag = el.tagName, type = (el.getAttribute('type') || '').toLowerCase();
    let role = (el.getAttribute('role') || '').split(/\s+/)[0];
    if (!role) role = tag === 'A' ? 'link' : tag === 'SELECT' ? (el.multiple ? 'listbox' : 'combobox') :
      tag === 'TEXTAREA' || el.isContentEditable ? 'textbox' :
      tag === 'INPUT' ? ({checkbox:'checkbox',radio:'radio',range:'slider',number:'spinbutton',
        file:'file-input',search:'searchbox',button:'button',submit:'button',reset:'button',image:'button'}[type] || 'textbox') : 'button';
    let name = el.getAttribute('aria-label') ||
      (el.getAttribute('aria-labelledby') || '').split(/\s+/).map(id =>
        document.getElementById(id)?.textContent || '').join(' ').trim() ||
      Array.from(el.labels || []).map(label => label.textContent).join(' ').trim() ||
      el.getAttribute('title') || el.getAttribute('placeholder') ||
      (['INPUT','TEXTAREA','SELECT'].includes(tag) ? '' : (el.innerText || el.textContent || '').trim());
    const state = [];
    if (type === 'password') state.push('password');
    if (el.matches(':disabled') || el.getAttribute('aria-disabled') === 'true') state.push('disabled');
    if (el.required || el.getAttribute('aria-required') === 'true') state.push('required');
    if (el.readOnly || el.getAttribute('aria-readonly') === 'true') state.push('readonly');
    if (role === 'checkbox' || role === 'radio' || role === 'switch')
      state.push(el.indeterminate || el.getAttribute('aria-checked') === 'mixed' ? 'mixed' :
        el.checked || el.getAttribute('aria-checked') === 'true' ? 'checked' : 'unchecked');
    if (el.getAttribute('aria-selected') === 'true') state.push('selected');
    if (el.hasAttribute('aria-expanded')) state.push(el.getAttribute('aria-expanded') === 'true' ? 'expanded' : 'collapsed');
    if (tag === 'IFRAME') {
      let origin; try { origin = new URL(el.getAttribute('src') || '', location.href).origin; } catch { continue; }
      if (origin === location.origin || origin === 'null') continue;
      role = 'frame'; name = origin; state.length = 0; state.push('cross-origin');
    }
    const row = {index:rows.length + 1, role, name:name.slice(0, 2000)};
    if (state.length) row.state = state;
    if (type !== 'password' && type !== 'file' && tag !== 'IFRAME') {
      if ('value' in el && !['button','checkbox','radio'].includes(role)) row.value = String(el.value);
      else if (el.isContentEditable) row.value = el.textContent || '';
    }
    if (tag === 'SELECT') row.options = Array.from(el.options).map((o,index) =>
      ({index,label:o.label,value:o.value,selected:o.selected,
        disabled:o.disabled || (o.parentElement.tagName === 'OPTGROUP' && o.parentElement.disabled)}));
    rows.push(row); elements.push(el);
  }
  return {rows, elements};
})()|}
    (Yojson.Safe.to_string (`String selector))

let rows ~call ~context ~selector =
  let internal message =
    let code =
      match P.Error_code.of_string "internal" with
      | Ok code -> code
      | Error _ -> assert false
    in
    Error (P.make_error code ~message)
  in
  Fun.protect
    ~finally:(fun () ->
      (* Releasing temporaries must not replace the snapshot failure. *)
      let _released_snapshot_group =
        call "Runtime.releaseObjectGroup"
          (`Assoc [ ("objectGroup", `String "leash-dom-snapshot") ])
      in
      ())
    (fun () ->
      let* reply =
        call "Runtime.evaluate"
          (`Assoc
             [
               ("expression", `String (expression ~selector));
               ("contextId", `Int context);
               ("objectGroup", `String "leash-dom-snapshot");
               ("returnByValue", `Bool false);
             ])
      in
      match get "objectId" (get "result" reply) with
      | `String object_id ->
          let invoke function_ return_by_value =
            call "Runtime.callFunctionOn"
              (`Assoc
                 [
                   ("objectId", `String object_id);
                   ("functionDeclaration", `String function_);
                   ("returnByValue", `Bool return_by_value);
                 ])
          in
          let* metadata = invoke "function(){return this.rows}" true in
          let* metadata =
            match get "value" (get "result" metadata) with
            | `List rows -> Ok rows
            | _ -> internal "DOM snapshot row metadata unavailable"
          in
          let* elements = invoke "function(){return this.elements}" false in
          let* elements =
            match get "objectId" (get "result" elements) with
            | `String id -> Ok id
            | _ -> internal "DOM snapshot element array unavailable"
          in
          let* properties =
            call "Runtime.getProperties"
              (`Assoc [ ("objectId", `String elements); ("ownProperties", `Bool true) ])
          in
          let properties = list (get "result" properties) in
          let rec resolve index acc = function
            | [] -> Ok (List.rev acc)
            | _ when index >= 250 -> Ok (List.rev acc)
            | json :: rest -> (
                match P.row_of_yojson json with
                | Error message -> internal ("invalid DOM snapshot row: " ^ message)
                | Ok row -> (
                    let element =
                      List.find_opt
                        (fun p -> text (get "name" p) = string_of_int index)
                        properties
                    in
                    match
                      Option.map (fun p -> get "objectId" (get "value" p)) element
                    with
                    | Some (`String id) ->
                        let* node =
                          call "DOM.describeNode" (`Assoc [ ("objectId", `String id) ])
                        in
                        let backend = integer (get "backendNodeId" (get "node" node)) in
                        if backend < 0 then
                          internal "DOM snapshot element identity unavailable"
                        else
                          resolve (index + 1)
                            (({ row with P.index = index + 1 }, backend) :: acc)
                            rest
                    | _ -> internal "DOM snapshot element unavailable"))
          in
          resolve 0 [] metadata
      | _ -> internal "DOM snapshot unavailable")
