# Scripts

A script is prepared JavaScript that belongs to a playbook. It is a `.js` file beside `playbook.json`, or a short inline `source`. A `script:` step runs it in the tab's page. Its result is validated against a declared `returns` shape. Only scripts from a loaded playbook directory are handed to the page's JavaScript engine by a run.

`eval` is a different thing: the agent's own one-off function body. A model never writes a script. A model may choose a script the playbook already has, or an argument value. The argument value travels as JSON, never inside the function text. A discovery proposal cannot carry scripts.

A script is the body of an async function of `args`, an object of strings. It may `await fetch` the site's own endpoints with the page's cookies. It should read. It should not click, scroll, fetch other pages, or change the page. Throw when the page is the wrong one; an empty list is a valid result (an empty cart).

## pages

`pages` says where JEV may choose the script.

- Absent: offered on every page of the site.
- A list of page-kind names: offered only when the current page is one of those kinds. If the page matches no kind, it is not offered.
- `[]`: never offered. Use this for a control script, such as a `repeat.until` check. It is not a tool for JEV.

## returns

The result must be a record, or a list of records. A shape is a type name (`string`, `number`, `boolean`, `url` — absolute http or https), an object of field to shape (a field whose name ends in `?` is optional), or a one-element array for a list. Nesting is at most eight deep.

Declare returns in exactly one place:

- a leading `/** returns: ... */` comment in the source
- `scripts/<name>.returns.json` beside the playbook
- `"returns": "<shape>"` naming a shape in `shapes`

An inline shape object on the declaration is refused. A missing returns, or two of them, is refused. `max_bytes` bounds the serialized result: default 8 MiB, at most 16 MiB. A file script is at most 1 MiB. Inline source is at most 4096 bytes.

## args

Every `args.NAME` the source reads must be declared. A name is a lowercase slug. A declaration is an object, not a list of names:

- `{"from":"mission"}` — the text helper reads the mission sentence. Missing and required: the run is `blocked` and names the argument.
- `{"from":"mission","optional":true}` — the same, and absence is fine.
- `{"const":60}` — always this value. `const` does not take `optional`.

A value found once is reused by later procedures and scripts. Name arguments as the user would say them (`category`, `query`), so the helper finds them.

## How JEV chooses one

On a playbook lane, Leash offers the scripts whose `pages` match the current page. Each is a choice `run_script:<name>`, labeled with the script's `description` (one sentence: when to choose it). JEV picks it the same way it picks `click` or `scroll_down`. The operation list stays under 255 choices, including `DONE` and `BLOCKED`. Scripts that would pass that ceiling are not offered.

A procedure can also pin a script with `{"script":"list-page"}` so JEV is not asked. `leash playbook test NAME/SCRIPT --tab TAB` runs one installed script on the tab's current page and validates the result. That is not a dry run.
