# Scripts

A script is prepared JavaScript that belongs to a playbook. It is a `.js` file beside `playbook.json`, or a short inline `source`. A `script:` step runs it in the tab's page. Its result is validated against a declared `returns` shape. Only scripts from a loaded playbook directory are handed to the page's JavaScript engine by a run.

`eval` is a different thing: the agent's own one-off function body. A model never writes a script. A model may choose a script the playbook already has, or an argument value. The argument value travels as JSON, never inside the function text. A discovery proposal cannot carry scripts.

A script is the body of an async function of `args`, an object of strings. It may `await fetch` the site's own endpoints with the page's cookies. Collection scripts should read, not click, scroll, or change the page. A navigate control script may read same-site pages or endpoints to find a destination, but should return the URL rather than mutate the current page. Leash performs the navigation after validation. Throw when the page is the wrong one; an empty list is a valid result (an empty cart).

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

Every `args.NAME` the source reads must be declared. Lowercase slugs allow `a-z`, `0-9`, `-`, and `_`; use `args["product-name"]` for a hyphenated name. A declaration is an object, not a list of names:

- `{"from":"mission"}` — the text helper reads the mission sentence. Missing and required: the run is `blocked` and names the argument.
- `{"from":"mission","optional":true}` — the same, and absence is fine.
- `{"const":60}` — always this value. `const` does not take `optional`.

A small text-helper model extracts named values from the mission sentence, with one formatting correction if needed. It does not inspect the site to discover an omitted product or promise to infer missing details. Required values still missing block the run. A value found once is reused by later procedures and model-chosen scripts; extraction is not shown as a separate trace event. Name arguments as the user would say them (`category`, `query`), and put their values clearly in the mission.

There are three argument locations:

1. Procedure `args` declares the values the text helper or constants fill. A goal substitutes `{product}`; a `use` can pass an object of strings to its child.
2. Script declaration `args` declares every value its source reads. When JEV chooses `run_script:name`, these sources fill its inputs.
3. Pinned step `args` supplies the actual values. This is inside `{"script":"name","args":{...}}` or `{"navigate":{"script":"name","args":{...}}}`. Values are strings, and `{product}` substitutes a previously filled procedure argument. These steps do not run the text helper or apply declaration constants: missing required declared inputs are refused at load, instead of silently ignored. Optional inputs may be omitted.

For example, declare `product` with `{"from":"mission"}` on both the procedure and script, then use `{"navigate":{"script":"product-url","args":{"product":"{product}"}}}`. The script can read `args.product` and return `{url: resolvedUrl}`.

## How JEV chooses one

On a playbook lane, Leash offers the scripts whose `pages` match the current page. Each is a choice `run_script:<name>`, labeled with the script's `description` (one sentence: when to choose it). JEV picks it the same way it picks `click` or `scroll_down`. The operation list stays under 255 choices, including `DONE` and `BLOCKED`. Scripts that would pass that ceiling are not offered.

A procedure can also pin a script with `{"script":"list-page"}` so JEV is not asked. `leash playbook test NAME/SCRIPT --tab TAB` runs one installed script on the tab's current page and validates the result. That is not a dry run. Pass declared inputs explicitly with `--args '{"product":"Blue Top"}'`; a standalone test has no mission to extract them from.

## One-off eval

`leash eval TAB 'return document.title'` takes a normal function body, not an expression-only script. A returned promise is awaited: `leash eval TAB 'return (async () => { await Promise.resolve(); return document.title; })()'`. Top-level `await` is invalid here; `return Promise.resolve(document.title)` also works. Syntax errors, thrown exceptions, and rejected promises report `script-failed` with the engine message.
