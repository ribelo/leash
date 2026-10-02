# Playbooks

A playbook describes one site. It is a directory, `$XDG_CONFIG_HOME/leash/playbooks/<name>/`, holding `playbook.json` and the files beside it (usually `~/.config/leash/playbooks/<name>/` when that variable is unset). The operator or an agent writes it. Learning can also compile and install validated procedures from completed mission traces; it never creates script code. Nothing but `playbook.json` and the script files may sit in that directory: another `.json` file beside `playbook.json` is refused. A `.json` file left in the playbooks root is not a playbook.

Install by copying the directory. `leash playbook list` lists validated installed books. `leash playbook show NAME` prints one, including script text. `leash playbook check ./DIR` validates a directory and skips JavaScript compilation. `leash playbook check NAME` does the same for an installed name and compiles each script in a blank tab. `leash playbook accept FILE` merges a reviewed proposal. The format below is what `check` accepts.

## Format, field by field

`site` is the site name. It must not be empty, `.`, `..`, or contain `/` or a NUL. It is not required to equal the directory name, but `show` and `check NAME` look the book up by the installed directory name.

`entry` is the URL a blank tab opens. It must be `http://` or `https://`, with no credentials (`@` is refused).

`description` is one non-empty string. JEV reads it when choosing a book.

`pages` is the list of page kinds. Each has `name` (a unique lowercase slug: `a-z`, `0-9`, `-`, `_`), `description`, and at least one of `url_pattern` or `text_marker`. `url_pattern` matches the whole URL; `*` matches any characters, including `?` and `#`; without `*` it is exact. `text_marker` is a case-insensitive substring of the page text. `null` means that recogniser is absent. `repeatable` defaults to `true`; set it to `false` for irreversible pages such as checkout or upload, overriding inferred safety.

`shapes` is an object of shape name (a lowercase slug) to a shape. A shape is `string`, `number`, `boolean`, `url`, an object of field to shape, or a one-element array for a list. A field name ending in `?` is optional. Nesting is at most eight deep. See `leash help scripts`.

`scripts` is an object of script name (a lowercase slug) to a declaration: exactly one of `file` or `source`, a one-sentence `description`, optional `pages`, optional `args`, optional `returns` naming a shape, optional `max_bytes`. `file` is relative to the playbook directory, ends in `.js`, has no `..`, and is not absolute. See `leash help scripts`.

`procedures` is the list of procedures, at most 200. Each has:

- `slug` — a unique lowercase slug.
- `description` — non-empty. JEV chooses on this.
- `args` — optional object of argument name to a source. Not a list of names.
- `steps` — a non-empty list. Each step is exactly one of `goal`, `use`, `script`, or `navigate`.
- `expect` — a non-empty list of sentences. See `leash help expectations`.
- `expect_timeout_s` — optional, 1 to 30. Default 5.
- `max_steps` — optional, 1 to 30. The operator cap for one goal step.
- `deadline_s` — optional, 1 to 600.
- `repeat` — optional. `next` names another procedure that does not itself repeat. `max` is 1 to 1000. `until` is an expectation sentence or `{"script":"name"}`. `delay_ms` is optional, 0 to 60000, default 500. `key` is a non-empty string used to drop a record seen twice.

A goal step is `{"goal":"..."}` with optional `until` (a non-empty list of code checkers, or `the address changed`) and optional `hint`. The goal text must not be empty.

A use step is `{"use":"slug"}` with optional `args` (an object of strings) and optional `optional`. It must not form a cycle.

A script step is `{"script":"name"}` with optional `args` (an object of strings). A navigation step is `{"navigate":{"script":"name","args":{"product":"{product}"}}}`: run the declared script, validate exactly `{url}`, then navigate the tab to that URL. It does not collect a record. For pinned script and navigate steps, pass each required script argument here; declaration sources do not fill these steps. See `leash help scripts` for the three argument locations.

A procedure with no goal step is allowed only when another procedure `use:`s it, or it is a `repeat.next` helper. A playbook whose every procedure is only scripts is refused.

## Worked example

Here is a complete `playbook.json` for the bookshop catalogue. Save it in your own playbook directory; no source checkout is needed.

```json
{
  "site": "books.toscrape.com",
  "entry": "https://books.toscrape.com/",
  "description": "A bookshop catalogue with categories, book titles, prices, ratings, and availability.",
  "pages": [
    {
      "name": "home",
      "description": "The shop front page with the category list",
      "url_pattern": "https://books.toscrape.com/",
      "text_marker": null
    },
    {
      "name": "category",
      "description": "A category listing",
      "url_pattern": "https://books.toscrape.com/catalogue/category/*",
      "text_marker": null
    }
  ],
  "shapes": {
    "book": [
      {
        "title": "string",
        "price": "number",
        "url": "url",
        "category": "string",
        "rating": "number",
        "availability": "string"
      }
    ],
    "pager": {
      "done": "boolean"
    }
  },
  "scripts": {
    "list-page": {
      "file": "scripts/list-page.js",
      "description": "Collect every book card on this category page as records.",
      "pages": ["category"]
    },
    "last-page": {
      "file": "scripts/last-page.js",
      "description": "Report whether this category listing has no next page.",
      "pages": []
    }
  },
  "procedures": [
    {
      "slug": "open-category",
      "description": "Open a category listing and collect its books.",
      "args": {
        "category": { "from": "mission" }
      },
      "steps": [
        { "goal": "Open the {category} category." },
        { "use": "collect-page" }
      ],
      "expect": ["the page is category"],
      "repeat": {
        "next": "next-page",
        "max": 60,
        "until": { "script": "last-page" },
        "delay_ms": 200,
        "key": "url"
      }
    },
    {
      "slug": "collect-page",
      "description": "Collect the books listed on this category page.",
      "steps": [{ "script": "list-page" }],
      "expect": ["the page is category"]
    },
    {
      "slug": "next-page",
      "description": "Open the next page of this category and collect its books.",
      "steps": [
        { "goal": "Open the next page of this category.", "until": ["the address changed", "the page is category"] },
        { "use": "collect-page" }
      ],
      "expect": ["the page is category"]
    },
    {
      "slug": "read-page",
      "description": "Collect the books shown on the current category page.",
      "steps": [{ "goal": "Collect the books on this category page." }],
      "expect": ["the page is category"]
    }
  ]
}
```

The directory also holds `scripts/list-page.js` and `scripts/last-page.js`. Those files are not inside the JSON. `list-page.js` starts with `/** returns: "book" */` and returns one record per card. `last-page.js` returns `{done: true}` when the listing has no next link.

### A sentence for each field

- `site` is `books.toscrape.com`, the catalogue this book knows.
- `entry` is `https://books.toscrape.com/`, the shop front a blank tab opens.
- `description` tells JEV this is a bookshop catalogue with categories, titles, prices, ratings, and availability.
- `pages[0].name` is `home`, the slug later expectations use.
- `pages[0].description` says the home page is the shop front with the category list.
- `pages[0].url_pattern` is the exact shop-front URL, no wildcard, so only that URL is home.
- `pages[0].text_marker` is null: home is recognised by URL alone.
- `pages[1].name` is `category`, a category listing.
- `pages[1].description` says this kind is a category listing.
- `pages[1].url_pattern` uses `*` so every category URL matches, including query strings.
- `pages[1].text_marker` is null: category is recognised by URL alone.
- `shapes.book` is a list of records, one per book card, with title, price, url, category, rating, and availability.
- `shapes.book[].title` is a string, the card's title attribute.
- `shapes.book[].price` is a number, the price with the currency symbol stripped.
- `shapes.book[].url` is an absolute http(s) URL of the book.
- `shapes.book[].category` is a string, the listing heading.
- `shapes.book[].rating` is a number, the star class mapped to 1..5.
- `shapes.book[].availability` is a string, the stock line.
- `shapes.pager` is one record, not a list.
- `shapes.pager.done` is a boolean: true when this listing has no next page.
- `scripts.list-page.file` is `scripts/list-page.js`, relative to the playbook directory.
- `scripts.list-page.description` tells JEV to choose it when it should collect every book card on this category page.
- `scripts.list-page.pages` is `["category"]`, so JEV is offered the script only on a category page.
- `scripts.last-page.file` is `scripts/last-page.js`.
- `scripts.last-page.description` says it reports whether the listing has no next page.
- `scripts.last-page.pages` is `[]`, so JEV is never offered it; only `repeat.until` runs it.
- `procedures[0].slug` is `open-category`, the procedure a mission starts with.
- `procedures[0].description` says it opens a category listing and collects its books.
- `procedures[0].args.category` is `{"from":"mission"}`: "collect every book in Mystery" fills `{category}` with Mystery.
- `procedures[0].steps[0].goal` is "Open the {category} category.", a click JEV can do.
- `procedures[0].steps[1].use` is `collect-page`, run inline after the category is open.
- `procedures[0].expect` is "the page is category", so done means the listing was reached.
- `procedures[0].repeat.next` is `next-page`, the procedure that advances one page.
- `procedures[0].repeat.max` is 60, the page cap.
- `procedures[0].repeat.until` is `{"script":"last-page"}`, stop when that script says done.
- `procedures[0].repeat.delay_ms` is 200, the pause between pages.
- `procedures[0].repeat.key` is `url`, so a book seen twice is streamed once.
- `procedures[1].slug` is `collect-page`, the helper that reads one page.
- `procedures[1].description` says it collects the books listed on this category page.
- `procedures[1].steps[0].script` is `list-page`, pinned, so JEV is not asked to click the cards.
- `procedures[1].expect` is "the page is category".
- `procedures[2].slug` is `next-page`.
- `procedures[2].description` says it opens the next page and collects its books.
- `procedures[2].steps[0].goal` is "Open the next page of this category."
- `procedures[2].steps[0].until` is "the address changed" and "the page is category", so the step ends when the click actually moved.
- `procedures[2].steps[1].use` is `collect-page`.
- `procedures[2].expect` is "the page is category".
- `procedures[3].slug` is `read-page`.
- `procedures[3].description` says it collects the books shown on the current category page.
- `procedures[3].steps[0].goal` is "Collect the books on this category page.", with no pinned script, so JEV may choose `run_script:list-page` itself.
- `procedures[3].expect` is "the page is category".

## Loader refusals

`FILE` is the `playbook.json` path, or the path you passed when the path is not a directory. `SLUG` is the procedure slug. `NAME` is a script, shape, or argument name. Messages are exact, including the spaces the loader writes.

A JSON value of the wrong type is `FILE: ` plus the decoder's reason. That reason is not listed here; the messages below are the ones the loader writes itself. Shape messages are included because the loader returns them on `returns` and on `shapes`.

```
step must have exactly one of goal, use, script or navigate
step must be an object
repeat until must be an expectation or {script: name}
unknown arg field EXTRA; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
an arg is from the mission or a const, not both; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
an arg needs a source; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
optional must be a boolean
unknown arg source "OTHER"; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
from must be "mission"; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
const does not take optional; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
an arg source is an object; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
args must declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}, not a list of names
arg NAME must be a lowercase slug
arg NAME is declared twice
arg NAME: WHY
args must be an object; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
KEY must be a string
description must be a string
pages must be a list of page-kind names
max_bytes must be an integer
a script declaration must be an object
script NAME: WHY
scripts must be an object of script name to declaration
shape NAME must be a lowercase slug
shape NAME: WHY
shapes must be an object of shape name to shape
unknown page kind KIND
FILE: procedure SLUG: slug must be a lowercase slug
FILE: procedure SLUG: description must not be empty
FILE: procedure SLUG: expect must be a non-empty list of sentences
FILE: procedure SLUG: steps must not be empty
FILE: procedure SLUG: expect_timeout_s must be 1..30
FILE: procedure SLUG: max_steps must be 1..30
FILE: procedure SLUG: deadline_s must be 1..600
FILE: procedure SLUG: args must be unique lowercase names
FILE: procedure SLUG: repeat max must be 1..1000
FILE: procedure SLUG: repeat next must name another procedure
FILE: procedure SLUG: repeat next must not itself repeat
FILE: procedure SLUG: repeat until must not be empty
FILE: procedure SLUG: repeat until script must be declared
FILE: procedure SLUG: repeat key must not be empty
FILE: procedure SLUG: repeat delay_ms must be 0..60000
FILE: procedure SLUG: goal must not be empty
FILE: procedure SLUG: goal until must not be empty
FILE: procedure SLUG: goal until: MESSAGE
FILE: procedure SLUG: goal until must be a code checker or "the address changed": SENTENCE
FILE: procedure SLUG: cycle of use: SLUG -> SLUG
FILE: procedure SLUG: use of unknown slug SLUG
FILE: procedure SLUG: use args must be an object of strings
FILE: procedure SLUG: script step names unknown script NAME
FILE: procedure SLUG: script args must be an object of strings
FILE: procedure SLUG: script step NAME must pass declared argument ARG in step args; declarations do not fill pinned steps
a file script needs a playbook directory
file must not be empty
file must not contain NUL
file PATH must be relative to the playbook directory
file PATH must not contain ..
file PATH must be a .js file
file PATH: SYSTEM-MESSAGE
file PATH resolves outside the playbook directory
file PATH is over 1048576 bytes
file PATH is not a regular file
returns block is missing */
returns block: JSON-ERROR
RELATIVE: SYSTEM-MESSAGE
RELATIVE resolves outside the playbook directory
RELATIVE: JSON-ERROR
unknown shape "NAME"
FILE: script NAME: name must be a lowercase slug
FILE: script NAME: declared twice
FILE: script NAME: max_bytes must be 1..16777216
FILE: script NAME: inline source is over 4096 bytes: put it in a file
FILE: script NAME: declare exactly one of file or source
FILE: script NAME: the script is empty
FILE: script NAME: the script contains NUL
FILE: script NAME: description must be one sentence
FILE: script NAME: pages names unknown page kind PAGE
FILE: script NAME: args.IDENT is read but not declared; declare each source as {"from":"mission"},    {"from":"mission","optional":true}, or {"const":<value>}
FILE: script NAME: returns belongs beside the script (a leading /** returns: ... */ block, scripts/<name>.returns.json, or "returns":    "<shape>" naming a shape in shapes), not an inline shape on the declaration
FILE: script NAME: returns belongs beside the script (a leading /** returns: ... */ block, scripts/<name>.returns.json, or "returns":    "<shape>" naming a shape in shapes)
FILE: script NAME: returns is declared more than once; a leading /** returns: ... */ block, scripts/<name>.returns.json, or "returns":    "<shape>" naming a shape in shapes
FILE: procedure <playbook>: invalid site
FILE: procedure <playbook>: entry must be an HTTP(S) URL
FILE: procedure <playbook>: entry URL must not contain credentials
FILE: procedure <playbook>: description must not be empty
FILE: procedure <playbook>: page kind names must be unique lowercase slugs
FILE: procedure <playbook>: page kind NAME needs url_pattern or text_marker
FILE: procedure <playbook>: more than 200 procedures (255-option JEV ceiling)
FILE: procedure <playbook>: procedure slugs must be unique lowercase slugs
FILE: procedure SLUG: cycle of use: A -> B
FILE: procedure SLUG has no goal step; a script-only procedure is allowed                   only as a use: sub-procedure
FILE: every procedure is a script; use `leash eval` or `playbook test`, or add the goal steps JEV drives
FILE: more than 246 scripts (255-option JEV ceiling)
FILE: returns belongs beside the script (a leading /** returns: ... */ block, scripts/<name>.returns.json, or "returns":    "<shape>" naming a shape in shapes), not at the playbook top level
DIR: a playbook is a directory holding playbook.json, not a single file
FILE: playbooks use JSON (<name>/playbook.json); YAML is not supported
FILE: No such file or directory
DIR: stray JSON beside playbook.json (NAMES); a playbook directory holds one             playbook.json
FILE: invalid JSON: REASON
PATH: playbooks are directories; move it to <name>/playbook.json
NAME: invalid playbook name
no installed playbook for site SITE
PATH: a proposed playbook cannot carry scripts
returns: shape nested more than 8 deep
returns: a field is optional by a ? on its name, not on its type (TYPE?)
returns: unknown type "TYPE" (string, number, boolean or url)
returns: a list shape has exactly one element shape
returns: a record shape declares at least one field
returns: a field needs a name
returns: field "NAME" is declared twice
returns: a shape is a type name, a record object or a one-element list
returns must be a record or a list of records
```

The two lines with long runs of spaces are exact. A symlink that resolves outside the playbook directory is the "resolves outside" message. A unix error on a script file is `file PATH: ` plus the system message.

## Learning from completed missions

`[learning]` in the service configuration sets `mode = "off" | "draft" | "auto"` (default `draft`), `successes = 2`, `planner_model = "openai/gpt-6-luna"`, `planner_reasoning = "max"`, `max_tries = 3`, `retire_after = 5`, and `planner_actions = 5`, and `timeout_s = 900` (60..3600; the compile, confirmation and repair deadline, not `models.planner_timeout`). `off` does not compile or try drafts. `draft` writes proposals below `$XDG_STATE_HOME/leash/proposed/` without installing them. `auto` offers repeatable proposals as visibly marked `draft:` procedure choices on the next matching page kind. Compile, confirmation, repair and install run after the drive reply. A verified trial is not listed in that reply's `installed`; `status` and `playbook show` report it, and the proposal provenance carries that learning work's calls and cost.

Compilation groups operations, not complete mission paths. An operation is a maximal sequence entered from one page kind; its last action may leave that kind. Its exit is the next kind or the final mission observation. Operations entered off the final host or on a named consent page are excluded. Each independent stored successful trace contributes at most one vote toward `successes`, including traces already marked compiled. Matching operations have the same entry kind and ordered action/role/label signature; typed values and later paths may differ. Learned installed and pending procedures cover only that operation signature.

The compiler receives retained typed values, action sources, feeding mission argument names, and observed titles and accessible labels. It parameterizes differing values, proposes meaningful kind names from those observations rather than URL slugs, and preserves generalized URL patterns and existing names. A new site uses the first observed URL after consent or off-host interstitials as its entry. Learned top-level procedures need at least two goal steps, an exit-kind expectation, and a meaningful result check; only directly `use:`-referenced sub-procedures are exempt from the minimum. The shared loader validates the whole book, including its other pending procedures. An invalid output gets one correction turn, then is dropped with the validation reason.

Repeatable procedures use `gate: "replay"`. A submit, Enter, or click on a path whose kind or observed text marks payment, checkout confirmation, upload, posting, sending, or deletion is non-repeatable. Authored `repeatable: false` pages override inference. Their drafts are never offered for a trial: independent completed traces must agree in entry kind and ordered operations/role/label, and the compiler must confirm the generalization before `auto` installs with `gate: "agreement"`. Non-repeatable repairs use `gate: "agreement-repair"` only when the existing kinds and action targets occur in the failing snapshot; no replay is allowed.

A failed draft keeps its failure and try count for bounded refinement and is archived after `max_tries`. An installed procedure that fails expectations twice receives a same-slug repair. A repeatable repair must pass its own trial before replacement; the prior version is archived. After `retire_after` consecutive failed missions without successful repair, the procedure is retired and excluded from selection.

`leash status` reports the mode, waiting drafts, last compile per site, and installed replay/agreement counts. `leash playbook show NAME` includes each learned procedure's provenance: source traces, model, time, tries, last failure, operation path, raw entry and exit kinds, action/role/label signature, raw-to-meaningful kind mapping, repeatability reason, and gate. Archived versions and retirement reasons live below `proposed/retired/`.
