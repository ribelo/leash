# Leash fresh-user transcript

## $ leash
```

[stderr]
bash: line 1: leash: command not found

```
[exit code: 127]

## $ leash --help
```

[stderr]
bash: line 1: leash: command not found

```
[exit code: 127]

## $ leash help
```

[stderr]
bash: line 1: leash: command not found

```
[exit code: 127]

Note: env is empty in my harness; I export HOME=/home/ribelo and PATH incl /etc/profiles/per-user/ribelo/bin before each command.

## $ leash
```
Leash is a local browser service: one managed Chrome that agents share with the human, driven by the leash command. leash new returns a handle you must keep; it is the only way to act on that tab, and leash list never shows one. agent tabs close after 30 idle minutes; human tabs are never closed unless an agent takes one. Models are OpenRouter and need an API key, OPENROUTER_API_KEY in the service's environment or models.api_key in the config; the key is the operator's, not the agent's. Start with leash status, leash new https://example.com, and leash snap TAB.

```
[exit code: 0]

## $ leash --help
```
NAME
       leash - A local managed Chrome for agents.

SYNOPSIS
       leash [COMMAND] …

DESCRIPTION
       One local service owns the managed Chrome. Commands send one JSON
       request over its private Unix socket. Only skill install may ask for
       local installation consent; use --force or --no-input in automation.

       Handles are secret capabilities; save the handle from leash new or
       leash take. leash list never reveals handles.

       agent tabs close after 30 idle minutes; human tabs are never closed
       unless an agent takes one

       leash status

       leash list --table

       leash new https://example.com --label research

       leash snap TAB --limit 20

SERVICE
       serve
           Start the service in the foreground; normally systemctl --user
           start leash owns it.

       config init / config check
           Write the default configuration, then report all setup problems
           before starting.

       status [--config=FILE] [--pretty] [--socket=PATH] [OPTION]…
           Report version, Chrome, the model key and the installed skill.

SKILL
       leash skill show prints the bundled entrypoint. leash skill install
       --dry-run previews configured skill.roots (or discovered skills roots
       when unset); --force authorizes installation or replacement. PATH
       means a skills root, with the bundle at PATH/leash/.

       skill COMMAND …
           Show or install the bundled agent skill.

ACT
       check [OPTION]… [TAB] [SNAPSHOT] [INDEX]
           Check the control at INDEX and verify it became checked.

       click [OPTION]… [TAB] [SNAPSHOT] [INDEX]
           Click the row at INDEX of SNAPSHOT. A covering label of that
           control is clicked and reported as via label.

       dialog [OPTION]… [TAB] [ACCEPT|DISMISS]
           Answer the page's dialog (never automatic).

       fill [OPTION]… [TAB] [SNAPSHOT] [INDEX] [TEXT]
           Fill the row at INDEX of SNAPSHOT with TEXT, or with
           --argument-file or --stdin.

       hover [OPTION]… [TAB] [SNAPSHOT] [INDEX]
           Move the mouse to the row at INDEX of SNAPSHOT.

       nav [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB] [URL]
           Navigate a tab to a URL (http, https or about:blank).

       press [OPTION]… [TAB] [SNAPSHOT] [KEY]
           Press KEY; with --index the row is focused first. Accepted names:
           Enter, Escape, Esc, Tab, Backspace, Delete, ArrowUp, ArrowDown,
           ArrowLeft, ArrowRight, Home, End, PageUp, PageDown, Space,
           lowercase a-z, digits 0-9, and single punctuation characters - = [
           ] ; , . / '.

       scroll [OPTION]… [TAB] [UP|DOWN]
           Scroll the page, or the row --index names, one viewport.

       select [OPTION]… [TAB] [SNAPSHOT] [INDEX] [OPTION]
           Choose OPTION, the row's observed option index.

       uncheck [OPTION]… [TAB] [SNAPSHOT] [INDEX]
           Uncheck the control at INDEX and verify it became unchecked.

       upload [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
       [SNAPSHOT] [INDEX] [PATH]…
           Set PATH... on the file input at INDEX of SNAPSHOT. At most 10
           files, 10 GiB together.

       wait [OPTION]… [TAB]
           Wait for the ANDed page conditions.

MISSIONS
       discover [OPTION]… [SITE-OR-URL]
           Explore SITE with the planner; write a proposed playbook without
           applying it.

       drive [OPTION]… [MISSION]
           Drive MISSION on the fly, or through a fitting playbook when JEV
           chooses one.

NETWORK AND DEBUG
       cookies [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
           Read the cookies of the tab's URL, httpOnly included (read-only).

       debug [OPTION]… [TAB]
           Show the console, exception and failed-request ring.

       eval [OPTION]… [TAB] [EXPRESSION]
           Evaluate EXPRESSION as a function body in the page.

       net [OPTION]… [TAB] [body|request] [ID]
           List the tab's recent requests; `net TAB body ID` and `net TAB
           request ID` read one.

       storage [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
       [local|session]
           Read the tab's local or session storage (read-only).

OBSERVE
       downloads [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
           List downloads started by this tab.

       shot [OPTION]… [TAB] [PATH]
           Write a screenshot as a PNG to PATH.

       snap [OPTION]… [TAB]
           Observe an indexed snapshot of a tab.

       text [OPTION]… [TAB]
           Extract the page's visible text.

PLAYBOOKS
       playbook COMMAND …
           Inspect, validate and grow site playbooks.

TABS
       close [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
           Close a tab using its handle.

       handoff [OPTION]… [TAB] [REASON]
           Hand the tab to the human and block until resume or timeout. The
           human gets a notification that stays until they click Done; run
           this as a background job and keep working. Actions on the tab
           answer with-human until then.

       list [OPTION]…
           List all tabs without handles; agent tabs close after 30 idle
           minutes; human tabs are never closed unless an agent takes one

       new [OPTION]… [URL]
           Open an agent tab. agent tabs close after 30 idle minutes; human
           tabs are never closed unless an agent takes one

       resume [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]
           Resume a tab a handoff is waiting on.

       take [OPTION]…
           Take exactly one human tab matching one selector and return its
           handle. Take only a tab the human told you to take; Leash does not
           ask or notify them. From then on it is an agent tab: it closes
           after 30 idle minutes like any other.

COMMANDS
       config COMMAND …
           Inspect configuration.

       help [OPTION]… [TOPIC]
           Print a help topic, or list topics. Does not contact the service.

       serve [--config=FILE] [OPTION]…
           Start the program.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash click --help; leash help errors

       leash config init; leash config check; leash serve

ERRORS
       Run leash help errors for every code, exit class, meaning and recovery
       hint. --socket PATH overrides the configured control socket.


```
[exit code: 0]

## $ leash help
```
handles
playbooks
authoring
expectations
drive
scripts
errors

```
[exit code: 0]

## $ leash help handles
```
Handles
=======

A handle is the only way to act on a tab. It is 128 bits from the system's randomness. Whoever holds it acts. Whoever lacks it cannot. There is no owner string, no claim, no release, and the CLI reads no session identity from the environment. Agents do not interfere because they do not hold each other's handles. Sharing a tab is handing over the handle. The service has no opinion about that.

`leash new` and `leash take` return a handle. Keep it. Losing it loses the tab: an agent tab closes when it has been idle, and a new one is opened. `leash list` shows every tab and never a handle. A label is a free string for finding a tab. It is not a capability.

Origin
------

Every tab has an origin. `human` means the tab was opened in the Chrome UI or by a page. `agent` means it was opened through the protocol, or a human tab an agent has taken. Taking flips the origin to `agent` and does not flip it back.

agent tabs close after 30 idle minutes; human tabs are never closed unless an agent takes one

The idle duration is `expiry.idle_s` in the configuration, 1800 seconds by default. Any command on the handle resets the clock. `list` shows `closes_in_s`; it is null for a human tab and for a tab handed to the human. There is no force-close escape hatch.

Take
----

`leash take` mints a handle for exactly one tab matching one selector: `--url PREFIX` (case-insensitive URL prefix), `--title TEXT` (case-insensitive title substring), or `--label TEXT` (case-insensitive exact label). Several matches are `ambiguous`. None is `no-match`. A tab that already has a live handle is `taken`: ask the holder for the handle. A tab with the human is not take-able.

Take only a tab the human told you to take. Leash does not ask or notify them. A taken tab is an agent tab from then on and closes after 30 idle minutes. Tell the human when you leave one open for them. Human tabs often have no label, so match on URL or title. `list` reads each tab's current title first, so a tab the human navigated shows its page title.

A popup opened by a page is human and does not inherit its opener's handle. After a browser restart, restored tabs are human and handles from the previous generation are gone with reason `browser_lost`.

With the human
--------------

`handoff` asks the human to do something on the agent's tab: a login, a CAPTCHA, a choice only they can make. It is keyed on the handle. While the tab is with the human, commands on the handle are refused and idleness is paused. `resume` (the notification's Done action, or `leash resume HANDLE`) clears that flag and restarts the idle clock. Anyone with the handle may resume; an agent should do so only after the human says they are finished.

When a handle is gone
---------------------

A later request reports why, from a tombstone:

- `closed_by_handle` — `leash close` on this handle
- `closed_by_idle` — the idle duration elapsed
- `closed_externally` — the page or the window closed it
- `browser_lost` — the managed Chrome was replaced; the handle was from an older generation

The hint is to open a new tab with `leash new`. Do not replay a submission because its tab vanished.

```
[exit code: 0]

## $ leash help playbooks
```
Playbooks
=========

A playbook describes one site. It is a directory, `$XDG_CONFIG_HOME/leash/playbooks/<name>/`, holding `playbook.json` and the files beside it (usually `~/.config/leash/playbooks/<name>/` when that variable is unset). The operator or an agent writes it. A model never does. Nothing but `playbook.json` and the script files may sit in that directory: another `.json` file beside `playbook.json` is refused. A `.json` file left in the playbooks root is not a playbook.

Install by copying the directory. `leash playbook list` lists validated installed books. `leash playbook show NAME` prints one, including script text. `leash playbook check ./DIR` validates a directory and skips JavaScript compilation. `leash playbook check NAME` does the same for an installed name and compiles each script in a blank tab. `leash playbook accept FILE` merges a reviewed proposal. The format below is what `check` accepts.

Format, field by field
----------------------

`site` is the site name. It must not be empty, `.`, `..`, or contain `/` or a NUL. It is not required to equal the directory name, but `show` and `check NAME` look the book up by the installed directory name.

`entry` is the URL a blank tab opens. It must be `http://` or `https://`, with no credentials (`@` is refused).

`description` is one non-empty string. JEV reads it when choosing a book.

`pages` is the list of page kinds. Each has `name` (a unique lowercase slug: `a-z`, `0-9`, `-`, `_`), `description`, and at least one of `url_pattern` or `text_marker`. `url_pattern` matches the whole URL; `*` matches any characters, including `?` and `#`; without `*` it is exact. `text_marker` is a case-insensitive substring of the page text. `null` means that recogniser is absent.

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

A script step is `{"script":"name"}` with optional `args` (an object of strings). `navigate` is `{"navigate":{"script":"name"}}` and the script must return exactly `{url}`.

A procedure with no goal step is allowed only when another procedure `use:`s it, or it is a `repeat.next` helper. A playbook whose every procedure is only scripts is refused.

Worked example
--------------

This is `examples/playbooks/books.toscrape.com/playbook.json`, complete.

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

The directory also holds `scripts/list-page.js` and `scripts/last-page.js`. Those files are not inside the JSON. `list-page.js` starts with `/** returns: "book" */` and returns one record per card. `last-page.js` returns `{done: true}` when the listing has no next link.

A sentence for each field
-------------------------

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

Loader refusals
---------------

`FILE` is the `playbook.json` path, or the path you passed when the path is not a directory. `SLUG` is the procedure slug. `NAME` is a script, shape, or argument name. Messages are exact, including the spaces the loader writes.

A JSON value of the wrong type is `FILE: ` plus the decoder's reason. That reason is not listed here; the messages below are the ones the loader writes itself. Shape messages are included because the loader returns them on `returns` and on `shapes`.

step must have exactly one of goal, use or script
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

The two lines with long runs of spaces are exact. A symlink that resolves outside the playbook directory is the "resolves outside" message. A unix error on a script file is `file PATH: ` plus the system message.

```
[exit code: 0]

## $ leash help authoring
```
Authoring a playbook
====================

Write one when a site will be driven again, or when a mission needs validated records rather than the operator's bounded page state. `leash discover` can propose a playbook; that is propose-and-accept, not this procedure. A model never writes the playbook. You do.

The format, the worked example, and every loader refusal are in `leash help playbooks`. Checker sentences are in `leash help expectations`. Scripts are in `leash help scripts`.

The procedure, in order
-----------------------

1. Study the site on the pages the task touches: `leash new URL`, `leash snap TAB --limit 60`, `leash text TAB`, `leash net TAB`. Note the URLs, which page each control lives on, where lists and pagers are, and what loads late. `snap` lists only rows in the viewport, and `--match` does too: `leash scroll TAB down` and snap again. `text` is the rendered text (CSS text-transform applies), and `wait --text` is case-sensitive against it. A control with an empty name can be inspected with `eval --index N --snapshot S`. In a goal, name it by what is next to it.
2. Name the page kinds. One kind per page type the procedures start on or land on (`home`, `category`, `product`, `cart`). Prefer a `url_pattern` with `*`. Use `text_marker` only when the URL does not tell (a modal, a single-page app).
3. Write each procedure's goal steps as a person would say them. One intention per goal. Put the site's words in the goal when they are the control's label. A goal runs on whatever page the tab is on, so if its control lives elsewhere, put a navigation goal first, with `until`.
4. Add a script only where bulk reading or a file is needed. Navigation, search, forms, and pagination are goals. Declare `description`, `pages`, and `returns`.
5. Declare every argument with its source. See `leash help scripts`.
6. Write `expect` sentences from the checker vocabulary. Every procedure's `expect` names the page kind it lands on.
7. `leash playbook check ./DIR` until clean. Install by copying the directory into `$XDG_CONFIG_HOME/leash/playbooks/` (usually `~/.config/leash/playbooks/` when that variable is unset). Then `leash playbook check SITE`, which also compiles the scripts.
8. `leash playbook test SITE/SCRIPT --tab TAB` on a real page of each kind the script is for. Compare the count with what you see.
9. A `--dry-run` mission shows which book and first procedure are chosen, with their probabilities. It spends model calls, acts on nothing, does not open `--url`, and always reads `status: blocked`. It cannot catch a control that is on another page.
10. A live mission with `--out`. Then read the trace: `procedures[].slug` and `outcome`, each drive's `steps[].operation` and `probabilities.op`, `data.scripts`, `collected`, `mission_expectations`. Scrolls alternating with BLOCKED near 0.5, ending "no available action toward the goal", means the control is not on this page or the goal does not name it. Fix the playbook before blaming the model.

Rules the loader does not keep for you
--------------------------------------

`playbook check` refuses a playbook that breaks the format. These two are yours:

- A procedure's `expect` names the page kind it lands on.
- Payment, messaging, deletion, and other non-idempotent submissions never sit inside a `repeat` or a procedure whose failure could replay it. A failed procedure is replayed once. A milder repeatable action (add to cart bumps the quantity) sits in its own procedure whose `expect` sees it succeed, so a replay happens only when it did not take.

Composing a task
----------------

One procedure per stage (`search-product`, `open-product`, `add-to-cart`), each starting with a goal. The run chooses one procedure at a time, verifies it, and asks again until JEV answers DONE. Every procedure except a `repeat.next` helper stays a choice. JEV chooses on `description`, so say when it applies: "From a product page: add it to the cart." A whole-task procedure (a goal, then `use:` each stage) works too, and wins the choice only if its description says it is the whole task.

Goals that are relative
-----------------------

"Open the next page" lands on a page that looks like the old one. Give that goal an `until` list of code sentences. The step ends done after the first action that makes them all hold. `until` is checked only after an action:

{"goal": "Open the next page of this category.", "until": ["the address changed", "the page is category"]}

Test it
-------

leash playbook check ./books.toscrape.com
leash playbook check books.toscrape.com
leash playbook test books.toscrape.com/list-page --tab TAB
leash drive 'collect every book title and price in the Mystery category' --dry-run
leash drive 'collect every book title and price in the Mystery category' --out /tmp/mystery.jsonl

Then check `collected` against the site, `status` is `done`, and each procedure is `verified`.

```
[exit code: 0]

## $ leash help expectations
```
Expectations
============

An expectation is a sentence. After a procedure, and before a mission is accepted as done, Leash checks the sentence. Some sentences are checked by code. Any other sentence is a judgment: JEV scores it against the page, which is slower and can be wrong. `{name}` placeholders are substituted from the run's arguments first (`the page shows {product}`).

A trailing period is ignored. Matching of the sentence shape is case-insensitive. A page-kind name that is not declared is refused at load (`unknown page kind KIND`), not scored.

Code checkers
-------------

`the page is category`

The current URL or page text matches the page kind named `category`. A `url_pattern` matches the whole URL. `*` matches any characters, including `?` and `#`. Without `*` the pattern is exact. A `text_marker` matches as a case-insensitive substring of the page text. Either match is enough.

`the page is not cart`

The current page is not the kind named `cart`.

`the page shows Your cart is empty`

The page text contains that string, case-insensitive. `the page contains In stock` is the same checker. An empty phrase (`the page shows` with nothing after it) is not this checker; it is a judgment.

`a file was downloaded`

A download started by this tab has completed.

`a pdf was downloaded`

A completed download whose MIME type is `application/pdf`. `a pdf file was downloaded` is the same checker.

`no dialog is open`

No JavaScript `alert`, `confirm`, `prompt`, or `beforeunload` is open. An HTML modal is page text and rows, not this checker.

`a button named Checkout is present`

A snapshot row has that role and that name. The shape is `a ROLE named NAME is present`. An empty name is not this checker; it is a judgment.

Only in a goal's until
----------------------

`the address changed`

The URL differs from the URL at the start of this goal step. Checked only after an action, never before the first one. `the url changed` is the same checker. It is not a procedure expectation: in `expect` it is a judgment.

Judgment
--------

`the cheapest book is selected`

JEV scores the sentence against the page. Use a code checker when one exists. A mission `--expect` with no playbook must be a concrete text, row, download, or dialog sentence: a page-kind name needs a playbook.

```
[exit code: 0]

## $ leash help drive
```
Drive
=====

`leash drive MISSION` is the one mission command. It runs on one tab toward one goal until `done`, `blocked`, a cap, a deadline, or an error, and returns the trace and a final snapshot. Leash never asserts that the goal is achieved. There is no `run` command, and the call is not `drive TAB GOAL`. Include the concrete result and any needed values in the mission. Do not delegate a broader action than the user authorized.

leash drive 'Open Travel and return the visible titles and prices' --url https://books.toscrape.com/ --out /tmp/travel-state.jsonl
leash drive 'Complete this page search and open the matching result' --tab TAB --max-steps 60 --deadline-s 300

The connection stays open until the mission returns. A long mission can run in the background while you work on other tabs. Do not start another action or read on that tab while it is working.

Models are OpenRouter. The service needs `OPENROUTER_API_KEY` in its own environment, or `models.api_key` in the configuration. The key is the operator's. Setting a variable in the client shell does not update an already running service. A missing key or a provider failure is `model-unavailable`; read `detail.code` and the partial trace before any retry.

Options
-------

Option                Meaning                                                                                                                                                                                                                               
`--url URL`           Explicit http or https start, no userinfo. Opens a drive-owned tab. Does not replace an already populated `--tab`. A bad URL is `usage` and names a correct example.                                                                  
`--tab TAB`           Reuse this tab and leave it open. Without it, Leash opens a temporary tab and closes it when the mission ends, including errors. A human handoff keeps it open. `final` is the last snapshot, not a promise that its tab still exists.
`--max-steps N`       On-the-fly executed-action cap, default 60. Must be a positive integer. The prediction cap is twice N. Not the playbook procedure cap.                                                                                                
`--max-procedures N`  Playbook-lane procedure cap, default 40. Not the operator action cap.                                                                                                                                                                 
`--deadline-s S`      Whole mission budget, default 900 seconds. Must be positive when present.                                                                                                                                                             
`--expect SENTENCE`   Repeatable mission expectation the DONE guard verifies, with or without a playbook.                                                                                                                                                   
`--out FILE`          Append tagged JSONL. Use a deliberate writable path, not an existing valuable file.                                                                                                                                                   
`--dry-run`           Observe and decide once. No navigation, input, text helper, or `--out` write. Still makes billable model calls and may allocate a blank tab.                                                                                          

Always pass `--expect` with a concrete sentence the result must satisfy. Without one, `done` is only JEV's opinion. Code-checked sentences are in `leash help expectations`. The operator never types a password: fill that row yourself (`snap` marks it `password`) with `leash fill`, then drive the rest.

A drive reply is large. Write it to a file and read the fields below. Do not paste the whole reply into the chat.

Lanes
-----

Playbooks are optional. A missing book never blocks a usable browser task and never requires you to author one first.

Installed books  What happens                                                                                                                                                                   
no-playbooks     No playbook question and no planner. The operator runs the whole mission.                                                                                                      
one-book         JEV is offered that book and `NONE`. A lone book is never forced.                                                                                                              
many-books       JEV chooses one book identity (`book:<file>`) or `NONE`. Books are not merged.                                                                                                 
none-matching    `NONE` enters the operator on the current page. It is not `BLOCKED`, not discovery, and not a planner review. A procedure-level `NONE` or `BLOCKED` falls through the same way.

On a blank tab without a URL, installed playbooks are offered first. A chosen book opens its own `entry`. Otherwise pass `--url`, or include exactly one explicit http or https URL in the mission. With `--tab`, Leash works from the current page and does not replace an already populated page with `--url`. No URL and no chosen book, on a blank tab, returns `blocked` with the missing-start reason. That is not a missing playbook and it makes no model call. Do not invent a search engine or ask JEV to navigate from `about:blank`.

Reading a trace
---------------

Exit 0 means the service answered. It does not mean the mission succeeded. Read:

- `status` — `done`, `blocked`, `failed`, `handoff`, `limit`, `deadline`, or `error`. An operator action cap is `limit`.
- `reason` — why it stopped, when present.
- `playbook_choices` — decision order, including a JEV `NONE`.
- `procedures[].slug`, `outcome` (`verified`, `failed`, `skipped`, `planned`), and `expectations`.
- `steps[].operation`, `index`, and `probabilities.op` — what JEV picked and how sure it was.
- `collected` — how many validated script records were streamed.
- `mission_expectations` — the DONE guard, each sentence, checker, and whether it passed.
- `operator_state.page.text` — on the fly, the answer is the page, at most 6000 characters of viewport text. `page.coverage` is a `+`-joined string starting with `viewport`.
- `output_kinds` — `script-record`, `operator-state`, or both.
- `model_cost` — null when any call is unpriced. `data.reported_cost` is the known subtotal.
- `final` — the last snapshot.

`--out` lines are tagged. `{"kind":"script-record","source":"playbook",...}` has the record under `.record`. `{"kind":"operator-state","source":"operator","state":...}` is one terminal bounded observation, not a record list. A dry run writes neither.

An unmet expectation in the operator lane returns `blocked`. It does not call the planner. In a playbook mission the planner may ask for the human when a selected procedure fails twice or an argument cannot be filled. A procedure's failed expectations or a rejected script can cause the whole procedure to replay once. Keep payment, messaging, deletion, and other non-idempotent submissions out of a retryable procedure unless repeating them is explicitly safe and authorized.

Repeating a form-submit mission is not idempotent. Keep the executed-input evidence and do not automatically rerun an uncertain mutation.

```
[exit code: 0]

## $ leash help scripts
```
Scripts
=======

A script is prepared JavaScript that belongs to a playbook. It is a `.js` file beside `playbook.json`, or a short inline `source`. A `script:` step runs it in the tab's page. Its result is validated against a declared `returns` shape. Only scripts from a loaded playbook directory are handed to the page's JavaScript engine by a run.

`eval` is a different thing: the agent's own one-off function body. A model never writes a script. A model may choose a script the playbook already has, or an argument value. The argument value travels as JSON, never inside the function text. A discovery proposal cannot carry scripts.

A script is the body of an async function of `args`, an object of strings. It may `await fetch` the site's own endpoints with the page's cookies. It should read. It should not click, scroll, fetch other pages, or change the page. Throw when the page is the wrong one; an empty list is a valid result (an empty cart).

pages
-----

`pages` says where JEV may choose the script.

- Absent: offered on every page of the site.
- A list of page-kind names: offered only when the current page is one of those kinds. If the page matches no kind, it is not offered.
- `[]`: never offered. Use this for a control script, such as a `repeat.until` check. It is not a tool for JEV.

returns
-------

The result must be a record, or a list of records. A shape is a type name (`string`, `number`, `boolean`, `url` — absolute http or https), an object of field to shape (a field whose name ends in `?` is optional), or a one-element array for a list. Nesting is at most eight deep.

Declare returns in exactly one place:

- a leading `/** returns: ... */` comment in the source
- `scripts/<name>.returns.json` beside the playbook
- `"returns": "<shape>"` naming a shape in `shapes`

An inline shape object on the declaration is refused. A missing returns, or two of them, is refused. `max_bytes` bounds the serialized result: default 8 MiB, at most 16 MiB. A file script is at most 1 MiB. Inline source is at most 4096 bytes.

args
----

Every `args.NAME` the source reads must be declared. A name is a lowercase slug. A declaration is an object, not a list of names:

- `{"from":"mission"}` — the text helper reads the mission sentence. Missing and required: the run is `blocked` and names the argument.
- `{"from":"mission","optional":true}` — the same, and absence is fine.
- `{"const":60}` — always this value. `const` does not take `optional`.

A value found once is reused by later procedures and scripts. Name arguments as the user would say them (`category`, `query`), so the helper finds them.

How JEV chooses one
-------------------

On a playbook lane, Leash offers the scripts whose `pages` match the current page. Each is a choice `run_script:<name>`, labeled with the script's `description` (one sentence: when to choose it). JEV picks it the same way it picks `click` or `scroll_down`. The operation list stays under 255 choices, including `DONE` and `BLOCKED`. Scripts that would pass that ceiling are not offered.

A procedure can also pin a script with `{"script":"list-page"}` so JEV is not asked. `leash playbook test NAME/SCRIPT --tab TAB` runs one installed script on the tab's current page and validates the result. That is not a dry run.

```
[exit code: 0]

## $ leash help errors
```
Errors
======

Each row is one code the service or the CLI can return. The wire object is
`{code,message,hint,detail?}`. Exit status is the class, not 1. Field meaning
is in the other topics; this table is the code, when it is used, and the next
action.

code                     exit  meaning                                                                                                                                                                                                             hint                                                                                                                                                                                       
`invalid-request`        64    malformed JSON, unknown command, or bad arguments                                                                                                                                                                   fix the request; `leash <command> --help` names the arguments and one example                                                                                                              
`ambiguous`              66    take matches several tabs; detail.matches lists them without handles                                                                                                                                                narrow the URL, title or label selector                                                                                                                                                    
`no-match`               66    take matches no tab                                                                                                                                                                                                 read `leash list` and use a matching URL prefix, title or label                                                                                                                            
`taken`                  77    the tab already has a live handle                                                                                                                                                                                   ask the holder for the handle                                                                                                                                                              
`with-human`             77    the tab is handed to the human; commands are refused until resume                                                                                                                                                   the human holds this tab; wait, or return it with `leash resume TAB`                                                                                                                       
`tab-gone`               66    the handle names a closed tab; detail.disposition is closed_by_handle, closed_by_idle, closed_externally, or browser_lost                                                                                           open a new tab with `leash new`                                                                                                                                                            
`unknown-tab`            66    no tab and no tombstone for the handle                                                                                                                                                                              that handle is not a tab; open a new tab with `leash new`, or ask the holder for the handle                                                                                                
`stale-snapshot`         65    the snapshot id or target row no longer matches the current page                                                                                                                                                    read detail.snapshot; re-snap with `leash snap TAB` and use its id and row; if the row is gone, navigate back or re-find it before acting                                                  
`no-such-row`            66    the index is not in the snapshot                                                                                                                                                                                    that index is not in the snapshot; `leash snap TAB` and use a listed index                                                                                                                 
`body-unavailable`       66    net body or request has no body to read, or Chrome has evicted it                                                                                                                                                   that body is gone; `leash net TAB` and read a request that still has one                                                                                                                   
`unknown-request`        66    the tab's ring holds no request with that id                                                                                                                                                                        that id is not in the tab's ring; `leash net TAB` and use a listed id                                                                                                                      
`row-not-actionable`     65    the row is not visible, is disabled, is covered, or is the wrong kind of control                                                                                                                                    pick another row, or `leash snap TAB` if the page moved; a file input takes `leash upload`                                                                                                 
`state-unchanged`        65    a check or uncheck did not change the control's checked state                                                                                                                                                       snap and read the row's state; the control did not toggle, so pick another row or click its label                                                                                          
`dialog-open`            65    a dialog blocks page reads and actions; answer it first                                                                                                                                                             answer it with `leash dialog TAB accept` or `leash dialog TAB dismiss`, then retry                                                                                                         
`no-dialog`              64    dialog was asked with nothing to answer                                                                                                                                                                             nothing is open; `leash snap TAB` and call dialog only when a dialog is shown                                                                                                              
`no-handoff`             64    resume on a tab nobody is waiting on                                                                                                                                                                                nobody is waiting; `leash handoff TAB REASON` starts one, and only then does `leash resume TAB` finish it                                                                                  
`url-refused`            64    scheme is not http, https, or about:blank, or the URL has userinfo                                                                                                                                                  use an http or https URL with no userinfo, or about:blank                                                                                                                                  
`tab-cap`                75    no capacity for a new tab                                                                                                                                                                                           close a tab with `leash close TAB`, then retry `leash new`                                                                                                                                 
`timeout`                75    wait, handoff, or a bounded operation ran out of time; a handoff's detail.warnings lists the steps that failed                                                                                                      retry; for a wait raise `--timeout-ms`, for a handoff raise the timeout or `leash resume TAB`                                                                                              
`renderer-unresponsive`  75    a tab session CDP call exceeded its deadline; detail.entries carries its last debug entries                                                                                                                         the page's renderer is not answering; a bot-detection challenge or a hung script is likely; shot may still work; close the tab or hand off                                                 
`browser-unavailable`    69    Chrome is restarting                                                                                                                                                                                                Chrome is restarting; retry `leash status` in a few seconds                                                                                                                                
`model-unavailable`      69    System One or the text helper failed, or no API key is configured; detail.code is missing-key, unavailable, timeout, authentication, invalid-response, input-too-large, model-mismatch, or text-helper-unavailable  read detail.code; set OPENROUTER_API_KEY or fix the model config, then retry                                                                                                               
`model-timeout`          75    a model call exceeded its per-call deadline                                                                                                                                                                         the model provider timed out; retry, or raise models.<kind>_timeout                                                                                                                        
`too-large`              65    expression, argument, result, fill text, or a script result is over its bound                                                                                                                                       shrink the text, expression, argument, or files under the bound and retry                                                                                                                  
`script-failed`          65    a playbook script threw, rejected, or could not be compiled; message carries what it threw                                                                                                                          read message; fix the script or the page, then `leash playbook test`                                                                                                                       
`script-invalid`         65    a playbook script's result does not fit its returns; message is the first mismatch                                                                                                                                  the result missed its returns shape; message is the first bad path, so fix the script or the returns                                                                                       
`playbook-invalid`       65    a playbook failed validation (load, check or accept); message names the rule                                                                                                                                        fix the playbook as the message says, then `leash playbook check ./DIR`; the skill's authoring reference lists the rules                                                                   
`internal`               70    a defect; the message carries no page content                                                                                                                                                                       a defect, not a page failure; retry once, then report the message                                                                                                                          
`service-unreachable`    69    the CLI could not connect to the control socket                                                                                                                                                                     `systemctl --user start leash`, or pass --socket                                                                                                                                           
`not-installed`          69    no leash.service unit is installed                                                                                                                                                                                  Leash is not installed; rebuild NixOS so leash.service exists, then `systemctl --user start leash`                                                                                         
`service-stopped`        69    the leash unit is installed but inactive                                                                                                                                                                            `systemctl --user start leash`, then `leash status`; a brief service-restarting (75) right after start is normal - retry; tabs and snapshots from before the stop are gone, so re-open them
`service-restarting`     75    the leash unit is activating or auto-restarting, or Chrome's generation is being relaunched                                                                                                                         Leash is restarting; retry `leash status` in a few seconds                                                                                                                                 
`socket-permission`      77    the CLI was denied access to the control socket                                                                                                                                                                     the control socket is not readable; check its permissions, or pass --socket                                                                                                                
`permission-denied`      77    the CLI was denied access to a filesystem path                                                                                                                                                                      check the path's permissions, or pass another path                                                                                                                                         
`config-invalid`         65    the configuration file is missing, unreadable, or invalid                                                                                                                                                           fix the reported problems; `leash config check` lists every one with the config path                                                                                                       
`usage`                  64    the command was invoked wrongly; the arguments do not match its synopsis                                                                                                                                            `leash <command> --help` shows the arguments and an example                                                                                                                                
`cli-parse`              124   Cmdliner rejected the command line; the command did not run                                                                                                                                                         the command line did not parse; `leash <command> --help` shows the accepted form                                                                                                           
`invalid-response`       70    the service reply was not a protocol object the CLI could decode                                                                                                                                                    the service reply was not a protocol object; check `leash status` and retry                                                                                                                


```
[exit code: 0]

## $ leash status
```

[stderr]
{"code":"config-invalid","message":"invalid configuration in /home/ribelo/.config/leash/config.toml: the environment variable in this path is unset (/control/socket)","hint":"fix the reported problems; `leash config check` lists every one with the config path"}

```
[exit code: 65]

## $ leash playbook --help
```
NAME
       leash-playbook - Inspect, validate and grow site playbooks.

SYNOPSIS
       leash playbook COMMAND …

EXAMPLES
       leash playbook list

       leash playbook check ./my-playbook

SEE ALSO
       leash(1)

DESCRIPTION
       A playbook is a directory that describes one site: pages, procedures, and scripts.
       The operator writes it. A model never does. JEV follows it when a mission fits.
       Format, example, and every loader refusal: leash help playbooks

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

ACT
       check [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… NAME|DIR
           Check local playbook data and, for an installed NAME, compile its
           scripts.

SERVICE
       test [OPTION]… [PLAYBOOK/SCRIPT]
           Run one playbook script on a tab and print its validated output.

COMMANDS
       accept [OPTION]… FILE
           Merge a proposed procedure into its site's playbook.

       list [OPTION]…
           List validated installed site playbooks.

       show [OPTION]… NAME
           Show a named installed playbook: scripts, their text and resolved
           checkers.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash playbook exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.


```
[exit code: 0]

## $ leash playbook list
```
books.toscrape.com	A bookshop catalogue with categories, book titles, prices, ratings, and availability.

```
[exit code: 0]

## $ leash list --table
```

[stderr]
{"code":"config-invalid","message":"invalid configuration in /home/ribelo/.config/leash/config.toml: the environment variable in this path is unset (/control/socket)","hint":"fix the reported problems; `leash config check` lists every one with the config path"}

```
[exit code: 65]

## $ leash config --help
```
NAME
       leash-config - Inspect configuration.

SYNOPSIS
       leash config COMMAND …

DESCRIPTION
       One local service owns the managed Chrome. Commands send one JSON
       request over its private Unix socket. Only skill install may ask for
       local installation consent; use --force or --no-input in automation.

       Handles are secret capabilities; save the handle from leash new or
       leash take. leash list never reveals handles.

       agent tabs close after 30 idle minutes; human tabs are never closed
       unless an agent takes one

       leash status

       leash list --table

       leash new https://example.com --label research

       leash snap TAB --limit 20

SERVICE
       serve
           Start the service in the foreground; normally systemctl --user
           start leash owns it.

       config init / config check
           Write the default configuration, then report all setup problems
           before starting.

SKILL
       leash skill show prints the bundled entrypoint. leash skill install
       --dry-run previews configured skill.roots (or discovered skills roots
       when unset); --force authorizes installation or replacement. PATH
       means a skills root, with the bundle at PATH/leash/.

COMMANDS
       check [--config=FILE] [OPTION]…
           Validate and print redacted effective configuration.

       init [--config=FILE] [--force] [OPTION]…
           Write a commented default configuration file.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash config exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash click --help; leash help errors

       leash config init; leash config check; leash serve

ERRORS
       Run leash help errors for every code, exit class, meaning and recovery
       hint. --socket PATH overrides the configured control socket.

SEE ALSO
       leash(1)


```
[exit code: 0]

## $ leash config check
```

[stderr]
{"code":"config-invalid","message":"/home/ribelo/.config/leash/config.toml: invalid configuration; fix the reported problems","hint":"fix the reported problems; `leash config check` lists every one with the config path","detail":{"config":"/home/ribelo/.config/leash/config.toml","problems":[{"pointer":"/control/socket","message":"the environment variable in this path is unset"}]}}

```
[exit code: 65]

## $ id -u; ls /run/user
```
1000
1000

```
[exit code: 0]

Note: config.toml needs an env var in control.socket (error never names it); I guessed XDG_RUNTIME_DIR=/run/user/1000 and put env in /tmp/l50-env.sh sourced before each command.

## $ leash status
```
{"key_present":true,"commit":"bed8f66e39042d7a8697fb4ec923c9af995a08d5","skill":{"state":"current","version":"0.0.0","commit":"bed8f66e39042d7a8697fb4ec923c9af995a08d5","installs":[{"path":"/home/ribelo/.dotfiles/skills/engineering/debugging/leash","state":"current","version":"0.0.0","commit":"bed8f66e39042d7a8697fb4ec923c9af995a08d5"}]},"generation":1,"tabs":{"open":3,"cap":32},"chrome":"running","uptime_s":337.69600009918213,"models":{"configured":true,"jev_model":"typesafe/jev-1.13-20260917","text_model":"inception/mercury-2.5","systemone_endpoint":"https://openrouter.ai/api/v1/systemone","chat_base_url":"https://openrouter.ai/api/v1"},"version":"0.0.0","pid":2886434,"headed":true}

```
[exit code: 0]

## $ leash list --table
```
LABEL	URL	TITLE	ORIGIN	AGE_S	IDLE_S	CLOSES_IN_S	WITH_HUMAN
-	chrome://newtab/	New Tab	human	336	336	-	false
pilot-read	https://x.com/JamesLucasIT/status/2105689860753215815	James Lucas on X: "This is not a photograph. It’s called A Stream and a Deer, and it was painted by the Danish artist Peder Mørk Mønsted. Look closely at the way the stream leads your eye into the forest, reflecting the trees and patches of light along the way. Mønsted had an extraordinary https://t.co/J4AWMeRZEL" / X	agent	167	163	1637	false
pilot-read	https://x.com/dwarkesh_sp/status/2105689480539557938	Dwarkesh Patel on X: "New episode with military historian Si Sheppard. The conquests of the Aztec and Inca empires might be the most shocking events in human history. Hernan Cortés and some hundreds of Conquistadors landed on a new continent they knew basically nothing about, and within 2 and a half https://t.co/aULW8DXWJc" / X	agent	136	132	1668	false

```
[exit code: 0]

## $ leash playbook list; leash playbook show books.toscrape.com | head -80
```
books.toscrape.com	A bookshop catalogue with categories, book titles, prices, ratings, and availability.
{
  "file": "/home/ribelo/.config/leash/playbooks/books.toscrape.com/playbook.json",
  "playbook": {
    "site": "books.toscrape.com",
    "entry": "https://books.toscrape.com/",
    "description": "A bookshop catalogue with categories, book titles, prices, ratings, and availability.",
    "pages": [
      {
        "name": "home",
        "description": "The shop front page with the category list",
        "url_pattern": "https://books.toscrape.com/"
      },
      {
        "name": "category",
        "description": "A category listing",
        "url_pattern": "https://books.toscrape.com/catalogue/category/*"
      }
    ],
    "procedures": [
      {
        "slug": "open-category",
        "description": "Open a category listing and collect its books.",
        "args": { "category": { "from": "mission" } },
        "steps": [
          { "goal": "Open the {category} category." },
          { "use": "collect-page" }
        ],
        "expect": [ "the page is category" ],
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
        "steps": [ { "script": "list-page" } ],
        "expect": [ "the page is category" ]
      },
      {
        "slug": "next-page",
        "description": "Open the next page of this category and collect its books.",
        "steps": [
          {
            "goal": "Open the next page of this category.",
            "until": [ "the address changed", "the page is category" ]
          },
          { "use": "collect-page" }
        ],
        "expect": [ "the page is category" ]
      },
      {
        "slug": "read-page",
        "description": "Collect the books shown on the current category page.",
        "steps": [ { "goal": "Collect the books on this category page." } ],
        "expect": [ "the page is category" ]
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
      "pager": { "done": "boolean" }
    },
    "scripts": {
      "list-page": {
        "file": "scripts/list-page.js",
        "description": "Collect every book card on this category page as records.",
        "pages": [ "category" ]
      },

```
[exit code: 0]

## $ leash playbook show books.toscrape.com | sed -n 80,400p
```
      },
      "last-page": {
        "file": "scripts/last-page.js",
        "description": "Report whether this category listing has no next page.",
        "pages": []
      }
    }
  },
  "scripts": [
    {
      "script": "list-page",
      "origin": "file scripts/list-page.js",
      "bytes": 730,
      "max_bytes": 8388608,
      "returns": [
        {
          "title": "string",
          "price": "number",
          "url": "url",
          "category": "string",
          "rating": "number",
          "availability": "string"
        }
      ],
      "code": "/** returns: \"book\" */\nconst words = {One: 1, Two: 2, Three: 3, Four: 4, Five: 5};\nconst category = document.querySelector('.page-header h1')?.textContent.trim();\nconst cards = [...document.querySelectorAll('article.product_pod')];\nif (!category || cards.length === 0) throw new Error('not a category listing page: ' + location.href);\nreturn cards.map(card => ({\n  title: card.querySelector('h3 a').getAttribute('title'),\n  price: Number(card.querySelector('.price_color').textContent.replace(/[^0-9.]/g, '')),\n  url: card.querySelector('h3 a').href,\n  category,\n  rating: words[[...card.querySelector('.star-rating').classList].find(c => c in words)],\n  availability: card.querySelector('.availability').textContent.trim(),\n}));\n"
    },
    {
      "script": "last-page",
      "origin": "file scripts/last-page.js",
      "bytes": 248,
      "max_bytes": 8388608,
      "returns": { "done": "boolean" },
      "code": "/** returns: \"pager\" */\nif (!location.pathname.startsWith(\"/catalogue/category/books/\") || !document.querySelector(\"article.product_pod\")) throw new Error(\"not a category listing\");\nreturn {done: document.querySelector(\".pager .next a\") === null};\n"
    }
  ],
  "resolved": [
    {
      "procedure": "open-category",
      "checkers": [ { "checker": "page_kind", "kind": "category" } ]
    },
    {
      "procedure": "collect-page",
      "checkers": [ { "checker": "page_kind", "kind": "category" } ]
    },
    {
      "procedure": "next-page",
      "checkers": [ { "checker": "page_kind", "kind": "category" } ]
    },
    {
      "procedure": "read-page",
      "checkers": [ { "checker": "page_kind", "kind": "category" } ]
    }
  ]
}

```
[exit code: 0]

## $ leash new --help | sed -n "1,60p"
```
NAME
       leash-new - Open an agent tab. agent tabs close after 30 idle minutes;
       human tabs are never closed unless an agent takes one

SYNOPSIS
       leash new [OPTION]… [URL]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --label=TEXT
           Free label shown by list. It is not a capability.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash new exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash new https://example.com

       leash new https://example.com --label research

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
[exit code: 0]

## $ leash snap --help | sed -n "1,60p"
```
NAME
       leash-snap - Observe an indexed snapshot of a tab.

SYNOPSIS
       leash snap [OPTION]… [TAB]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --limit=N
           At most N rows, default 120, max 1000.

       --match=TEXT
           Keep rows whose role, name or value contains TEXT.

       --offset=N
           Skip the first N rows, default 0. A negative offset is refused.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

       --table
           Render list and snap rows as a table.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash snap exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash snap t_9xk --match Save --limit 10

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for

```
[exit code: 0]

## $ leash text --help | sed -n "1,60p"
```
NAME
       leash-text - Extract the page's visible text.

SYNOPSIS
       leash text [OPTION]… [TAB]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --index=N
           Read only the row at index N.

       --max-chars=N
           At most N characters (default and maximum 65536).

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash text exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash text t_9xk --max-chars 300

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
[exit code: 0]

## $ leash eval --help | sed -n "1,60p"
```
NAME
       leash-eval - Evaluate EXPRESSION as a function body in the page.

SYNOPSIS
       leash eval [OPTION]… [TAB] [EXPRESSION]

OPTIONS
       --argument=JSON
           JSON value bound to argument in the expression.

       --config=FILE
           TOML configuration file the control socket is read from.

       --index=N
           Call the expression as (argument, element), element being the row
           at index N.

       --pretty
           Indent JSON output.

       --snapshot=SNAPSHOT
           The snapshot --index names (required with it).

       --socket=PATH
           Control socket path; overrides control.socket.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash eval exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash eval t_9xk 'return document.title'

       leash eval t_9xk 'return element.getBoundingClientRect().width'
       --snapshot s_3 --index 7

ERRORS

```
[exit code: 0]

## $ leash wait --help | sed -n "1,60p"
```
NAME
       leash-wait - Wait for the ANDed page conditions.

SYNOPSIS
       leash wait [OPTION]… [TAB]

OPTIONS
       --changed-since=SNAPSHOT
           Until the page's loader or mutation counter differs from
           SNAPSHOT's.

       --config=FILE
           TOML configuration file the control socket is read from.

       --dialog
           Until a dialog is open.

       --index-gone=N
           Until row N is gone.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

       --text=TEXT
           Until the page text contains TEXT.

       --timeout=MS
           Alias of --timeout-ms.

       --timeout-ms=MS
           Bound the wait in milliseconds (default 30000, max 3600000: one
           hour).

       --until=JSON
           JSON object of the conditions below.

       --url-prefix=PREFIX
           Until the url starts with PREFIX.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash wait exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

```
[exit code: 0]

## $ leash playbook test --help | sed -n "1,60p"
```
NAME
       leash-playbook-test - Run one playbook script on a tab and print its
       validated output.

SYNOPSIS
       leash playbook test [OPTION]… [PLAYBOOK/SCRIPT]

OPTIONS
       --arg=K=V
           A string argument for the script (repeatable).

       --config=FILE
           TOML configuration file the control socket is read from.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

       --tab=TAB
           The tab whose page runs the script (required).

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash playbook test exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash playbook test books.toscrape.com/list_books --tab t_9xk

       leash playbook test shop/search --tab t_9xk --arg q=gpu --arg max=2000

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO

```
[exit code: 0]

## $ leash drive --help | sed -n "1,60p"
```
NAME
       leash-drive - Drive MISSION on the fly, or through a fitting playbook
       when JEV chooses one.

SYNOPSIS
       leash drive [OPTION]… [MISSION]

EXAMPLES
       leash drive 'Open Travel and return the visible titles and prices'
       --url https://books.toscrape.com/ --out travel-state.jsonl

       leash drive 'Complete this page search and open the matching result'
       --tab TAB --max-steps 60 --deadline-s 300

       no-playbooks: leash drive 'Open Travel and return the visible titles
       and prices' --url https://books.toscrape.com/ --max-steps 60

       one-book: leash drive 'Collect the supported category' --url
       https://books.toscrape.com/ --out books.jsonl

       many-books: leash drive 'Collect the supported category' --tab TAB
       --max-steps 60

       none-matching: leash drive 'Search one-way and stop at the visible
       options' --url https://www.google.com/travel/flights --max-steps 60
       --deadline-s 300

SEE ALSO
       leash(1)

DESCRIPTION
       Drive runs one mission on one tab until done, blocked, a cap, a deadline, or an error.
       It may follow an installed playbook or act on the page. Leash never asserts the goal.
       Lanes, options, and how to read a trace: leash help drive

ROUTING
       max-steps default 60.

       Playbooks are optional. no-playbooks: no playbook question and no
       planner; the operator runs the whole mission. one-book: that book is
       offered with NONE and is never forced. many-books: JEV chooses one
       book identity or NONE; books are not merged. none-matching: NONE
       enters the operator on the current page. NONE is not BLOCKED and is
       not a planner review. A procedure NONE or BLOCKED also falls through
       to the operator.

       --out JSONL is tagged. script-record, source playbook, is a validated
       script record. operator-state, source operator, is one terminal
       bounded page observation, not a record list. The Travel example writes
       operator-state. output_kinds names the kinds in the reply. A
       successful reply is not proof the mission succeeded. model_cost is
       null when any call is unpriced; data.reported_cost is the known
       subtotal.

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

OPTIONS
       --config=FILE

```
[exit code: 0]

## $ leash close --help | sed -n "1,60p"
```
NAME
       leash-close - Close a tab using its handle.

SYNOPSIS
       leash close [--config=FILE] [--pretty] [--socket=PATH] [OPTION]… [TAB]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash close exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash close t_9xk

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
[exit code: 0]

## $ leash net --help | sed -n "1,60p"
```
NAME
       leash-net - List the tab's recent requests; `net TAB body ID` and `net
       TAB request ID` read one.

SYNOPSIS
       leash net [OPTION]… [TAB] [body|request] [ID]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --limit=N
           The most recent N requests (default 100, at most 500).

       --match=TEXT
           Keep requests whose URL contains TEXT.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

       --type=TYPE
           Keep one resource type: xhr, fetch, document, script, ...

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash net exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash net t_9xk --type fetch --match /api/

       leash net t_9xk body 1000.5

       leash net t_9xk request 1000.5


```
[exit code: 0]

## $ leash playbook check --help | sed -n "1,60p"
```
NAME
       leash-playbook-check - Check local playbook data and, for an installed
       NAME, compile its scripts.

SYNOPSIS
       leash playbook check [--config=FILE] [--pretty] [--socket=PATH]
       [OPTION]… NAME|DIR

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash playbook check exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash playbook check books.toscrape.com

       leash playbook check ./my-playbook

ERRORS
       Failures are one JSON record on stderr. Run leash help errors for
       codes and recovery hints.

SEE ALSO
       leash(1)


```
[exit code: 0]

## $ leash playbook show --help | sed -n "1,60p"
```
NAME
       leash-playbook-show - Show a named installed playbook: scripts, their
       text and resolved checkers.

SYNOPSIS
       leash playbook show [OPTION]… NAME

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash playbook show exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       70  Internal failure or invalid service response.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.

EXAMPLES
       leash playbook show books.toscrape.com

SEE ALSO
       leash(1)


```
[exit code: 0]

## $ leash drive --help | sed -n "60,200p"
```
       --config=FILE
           TOML configuration file the control socket is read from.

       --deadline-s=S
           Seconds for the whole mission (default 900).

       --dry-run
           Observe and decide once; never navigate, act, type, or write
           --out.

       --expect=SENTENCE
           Mission expectation the DONE guard verifies (repeatable).

       --max-procedures=N
           Playbook-lane procedure cap (default 40), not the operator action
           cap.

       --max-steps=N
           On-the-fly executed-action cap (default 60). Must be positive.
           Prediction cap is twice N.

       --out=FILE
           Append tagged JSONL: script-record from a playbook, operator-state
           from the operator.

       --pretty
           Indent JSON output.

       --socket=PATH
           Control socket path; overrides control.socket.

       --tab=TAB
           Reuse TAB instead of opening one. Does not replace a populated
           page.

       --url=URL
           Explicit http(s) start (start_url). Not a model navigation target.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash drive exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

       66  Unknown or gone tab, row, or network request.

       69  Service, browser, or model unavailable.

       70  Internal failure or invalid service response.

       75  Retryable timeout or tab capacity limit.

       77  Filesystem or socket permission, or tab capability refused.

       124 Command-line parsing failed; the command did not run.


```
[exit code: 0]

## $ leash new https://automationexercise.com --label l50-study
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/","title":"Automation Exercise","origin":"agent","age_s":2,"idle_s":2,"closes_in_s":1798,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 60 --table
```
INDEX	ROLE	NAME	VALUE	STATE
1	link	Website for automation practice	-	
2	link	 Home	-	
3	link	 Products	-	
4	link	 Cart	-	
5	link	 Signup / Login	-	
6	link	 Test Cases	-	
7	link	 API Testing	-	
8	link	 Video Tutorials	-	
9	link	 Contact us	-	
10	heading	AutomationExercise	-	
11	heading	Full-Fledged practice website for Automation Engineers	-	
12	paragraph	All QA engineers can use this website for automation practice and API testing either they are at beginner or advance level. This is for everybody to help them brush up their automation skills.	-	
13	link	Test Cases	-	
14	button	Test Cases	-	
15	link	APIs list for practice	-	
16	button	APIs list for practice	-	
17	link		-	
18	link		-	
19	heading	CATEGORY	-	
20	heading	 WOMEN	-	
21	link	 WOMEN	-	
22	heading	 MEN	-	
23	link	 MEN	-	
24	heading	 KIDS	-	
25	link	 KIDS	-	
26	heading	BRANDS	-	
27	link	(6) POLO	-	
28	link	(5) H&M	-	
29	heading	FEATURES ITEMS	-	
30	heading	Rs. 500	-	
31	paragraph	Blue Top	-	
32	heading	Rs. 500	-	
33	paragraph	Blue Top	-	
34	link	 Add to cart	-	
35	heading	Rs. 400	-	
36	paragraph	Men Tshirt	-	
37	heading	Rs. 400	-	
38	paragraph	Men Tshirt	-	
39	link	 Add to cart	-	
40	paragraph	Welcome	-	
41	heading	This site asks for consent to use your data	-	
42	button	Learn more	-	
43	paragraph	Your personal data will be processed and information from your device (cookies, unique identifiers, and other device data) may be stored by, accessed by and shared with 210 partners, or used specifically by this site. We and our partners may use precise geolocation data. 	-	
44	button	List of partners.	-	
45	paragraph	Some vendors may process your personal data on the basis of legitimate interest, which you can object to by managing your options below. Look for a link at the bottom of this page or in the site menu to manage or withdraw consent in privacy and cookie settings.	-	
46	button	Consent	-	
47	paragraph	Consent	-	
48	button	Manage options	-	
49	paragraph	Manage options	-	

```
[exit code: 0]

## $ leash text t_c9edfdf33da436fdf4df7c91277f9f1d --max-chars 800
```
{"url":"https://automationexercise.com/","title":"Automation Exercise","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\n  \nAutomationExercise\nFull-Fledged practice website for Automation Engineers\n\nAll QA engineers can use this website for automation practice and API testing either they are at beginner or advance level. This is for everybody to help them brush up their automation skills.\n\nTest Cases APIs list for practice\nCATEGORY\nWOMEN\nMEN\nKIDS\nBRANDS\n(6)\nPOLO\n(5)\nH&M\n(5)\nMADAME\n(3)\nMAST & HARBOUR\n(4)\nBABYHUG\n(3)\nALLEN SOLLY JUNIOR\n(3)\nKOOKIE KIDS\n(5)\nBIBA\nFEATURES ITEMS\nRs. 500\n\nBlue Top\n\nAdd to cart\nRs. 500\n\nBlue Top\n\nAdd to cart\nView Product\nRs. 400\n\nMen Tshirt\n\nAdd to cart\nRs. 400\n\nMen Tshirt\n\nAdd to cart\nView Product\nRs. 1000\n\nSleeveless Dress\n\nAdd to cart\nRs. 1000\n\nSleeveless Dress\n\nAdd to cart\nView Product\nR","truncated":true}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/products
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","origin":"agent","age_s":18,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 40 --table
```
INDEX	ROLE	NAME	VALUE	STATE
1	link	Website for automation practice	-	
2	link	 Home	-	
3	link	 Products	-	
4	link	 Cart	-	
5	link	 Signup / Login	-	
6	link	 Test Cases	-	
7	link	 API Testing	-	
8	link	 Video Tutorials	-	
9	link	 Contact us	-	
10	textbox	Search Product	-	
11	button		-	
12	heading	CATEGORY	-	
13	heading	 WOMEN	-	
14	link	 WOMEN	-	
15	heading	 MEN	-	
16	link	 MEN	-	
17	heading	 KIDS	-	
18	link	 KIDS	-	
19	heading	BRANDS	-	
20	link	(6) POLO	-	
21	link	(5) H&M	-	
22	link	(5) MADAME	-	
23	link	(3) MAST & HARBOUR	-	
24	link	(4) BABYHUG	-	
25	heading	ALL PRODUCTS	-	
26	heading	Rs. 500	-	
27	paragraph	Blue Top	-	
28	link	 Add to cart	-	
29	heading	Rs. 500	-	
30	paragraph	Blue Top	-	
31	link	 Add to cart	-	
32	link	 View Product	-	
33	heading	Rs. 400	-	
34	paragraph	Men Tshirt	-	
35	link	 Add to cart	-	
36	heading	Rs. 400	-	
37	paragraph	Men Tshirt	-	
38	link	 Add to cart	-	
39	link	 View Product	-	
40	heading	Rs. 1000	-	

```
[exit code: 0]

## $ leash fill --help | sed -n 1,40p; leash click --help | sed -n 1,40p
```
NAME
       leash-fill - Fill the row at INDEX of SNAPSHOT with TEXT, or with
       --argument-file or --stdin.

SYNOPSIS
       leash fill [OPTION]… [TAB] [SNAPSHOT] [INDEX] [TEXT]

OPTIONS
       --argument-file=PATH
           Read TEXT from PATH instead of the argument (at most 64 KiB).

       --config=FILE
           TOML configuration file the control socket is read from.

       --limit=N
           With --snap, at most N rows, default 120, max 1000.

       --match=TEXT
           With --snap, keep rows whose role, name or value contains TEXT.

       --pretty
           Indent JSON output.

       --snap
           After settling, include a fresh snapshot in the reply.

       --socket=PATH
           Control socket path; overrides control.socket.

       --stdin
           Read TEXT from stdin instead of the argument (at most 64 KiB).

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash fill exits with:
NAME
       leash-click - Click the row at INDEX of SNAPSHOT. A covering label of
       that control is clicked and reported as via label.

SYNOPSIS
       leash click [OPTION]… [TAB] [SNAPSHOT] [INDEX]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --limit=N
           With --snap, at most N rows, default 120, max 1000.

       --match=TEXT
           With --snap, keep rows whose role, name or value contains TEXT.

       --pretty
           Indent JSON output.

       --snap
           After settling, include a fresh snapshot in the reply.

       --socket=PATH
           Control socket path; overrides control.socket.

COMMON OPTIONS
       --help[=FMT] (default=auto)
           Show this help in format FMT. The value FMT must be one of auto,
           pager, groff or plain. With auto, the format is pager or plain
           whenever the TERM env var is dumb or undefined.

EXIT STATUS
       leash click exits with:

       0   Success.

       64  Invalid request or invocation; fix the input.

       65  Invalid configuration, playbook, or stale page data.

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 5
```
{"snapshot":"s_t_7afd6d57174ece0d5900414fc0835617","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","rows":[{"index":1,"role":"link","name":"Website for automation practice"},{"index":2,"role":"link","name":" Home"},{"index":3,"role":"link","name":" Products"},{"index":4,"role":"link","name":" Cart"},{"index":5,"role":"link","name":" Signup / Login"}],"total":53,"offset":0,"truncated":true,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash fill t_c9edfdf33da436fdf4df7c91277f9f1d s_t_7afd6d57174ece0d5900414fc0835617 10 'Blue Top'
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","snapshot":null,"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 14
```
{"snapshot":"s_t_de935030e23fd8b58486e1e5dc800ccd","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","rows":[{"index":1,"role":"link","name":"Website for automation practice"},{"index":2,"role":"link","name":" Home"},{"index":3,"role":"link","name":" Products"},{"index":4,"role":"link","name":" Cart"},{"index":5,"role":"link","name":" Signup / Login"},{"index":6,"role":"link","name":" Test Cases"},{"index":7,"role":"link","name":" API Testing"},{"index":8,"role":"link","name":" Video Tutorials"},{"index":9,"role":"link","name":" Contact us"},{"index":10,"role":"textbox","name":"Search Product"},{"index":11,"role":"button","name":""},{"index":12,"role":"heading","name":"CATEGORY"},{"index":13,"role":"heading","name":" WOMEN"},{"index":14,"role":"link","name":" WOMEN"}],"total":53,"offset":0,"truncated":true,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return document.querySelector("#search_product").value'
```
{"value":""}

```
[exit code: 0]

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_de935030e23fd8b58486e1e5dc800ccd 11 --snap --limit 40
```

[stderr]
{"code":"row-not-actionable","message":"the row is covered at its click point","hint":"pick another row, or `leash snap TAB` if the page moved; a file input takes `leash upload`"}

```
[exit code: 65]

## $ leash shot t_c9edfdf33da436fdf4df7c91277f9f1d /tmp/l50-shot1.png
```

[stderr]
{"code":"renderer-unresponsive","message":"browser operation timed out","hint":"the page's renderer is not answering; a bot-detection challenge or a hung script is likely; shot may still work; close the tab or hand off","detail":{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","entries":[{"at":"2026-10-01T16:14:10Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:14:10Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:14:10Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:13:54Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:13:54Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:13:54Z","kind":"request-failed","text":""}]}}

```
[exit code: 75]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return [...document.querySelectorAll("input")].map(i=>[i.id,i.name,i.value])'
```
{"value":[["search_product","search",""],["","csrfmiddlewaretoken","dlCbt8RzKyElO2GO80jYal6DFw5sJTLtIqlmFdK5NwUw9qGOVO7eD6YY6SlNbbSW"],["susbscribe_email","",""],["","","on"],["","","on"],["fc-preference-slider-purpose-2","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-purpose-7","","on"],["","","on"],["fc-preference-slider-purpose-8","","on"],["","","on"],["fc-preference-slider-purpose-9","","on"],["","","on"],["fc-preference-slider-purpose-10","","on"],["","","on"],["fc-preference-slider-purpose-11","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-11","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-15","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-21","","on"],["","","on"],["fc-preference-slider-gvl-vendor-23","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-28","","on"],["","","on"],["fc-preference-slider-gvl-vendor-30","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-32","","on"],["","","on"],["fc-preference-slider-gvl-vendor-36","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-50","","on"],["","","on"],["fc-preference-slider-gvl-vendor-52","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-69","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-76","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-85","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-93","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-98","","on"],["","","on"],["fc-preference-slider-gvl-vendor-104","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-124","","on"],["fc-preference-slider-gvl-vendor-126","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-132","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-142","","on"],["","","on"],["fc-preference-slider-gvl-vendor-156","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-163","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-173","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-209","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-231","","on"],["","","on"],["fc-preference-slider-gvl-vendor-232","","on"],["","","on"],["fc-preference-slider-gvl-vendor-238","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-246","","on"],["","","on"],["fc-preference-slider-gvl-vendor-253","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-263","","on"],["","","on"],["fc-preference-slider-gvl-vendor-264","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-278","","on"],["","","on"],["fc-preference-slider-gvl-vendor-284","","on"],["","","on"],["fc-preference-slider-gvl-vendor-290","","on"],["","","on"],["fc-preference-slider-gvl-vendor-294","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-297","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-319","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-394","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-431","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-452","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-527","","on"],["","","on"],["fc-preference-slider-gvl-vendor-528","","on"],["","","on"],["fc-preference-slider-gvl-vendor-541","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-559","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-612","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-655","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-667","","on"],["","","on"],["fc-preference-slider-gvl-vendor-671","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-690","","on"],["","","on"],["fc-preference-slider-gvl-vendor-699","","on"],["","","on"],["fc-preference-slider-gvl-vendor-728","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-740","","on"],["","","on"],["fc-preference-slider-gvl-vendor-755","","on"],["","","on"],["fc-preference-slider-gvl-vendor-762","","on"],["","","on"],["fc-preference-slider-gvl-vendor-767","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-804","","on"],["","","on"],["fc-preference-slider-gvl-vendor-806","","on"],["","","on"],["fc-preference-slider-gvl-vendor-807","","on"],["","","on"],["fc-preference-slider-gvl-vendor-812","","on"],["","","on"],["fc-preference-slider-gvl-vendor-867","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-986","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1005","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1019","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1043","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1067","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1135","","on"],["fc-preference-slider-gvl-vendor-1142","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1230","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1237","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1391","","on"],["fc-preference-slider-gvl-vendor-1412","","on"],["","","on"],["fc-preference-slider-gvl-vendor-1549","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"],["","","on"]]}

```
[exit code: 0]

## $ leash shot t_c9edfdf33da436fdf4df7c91277f9f1d /tmp/l50-shot1.png
```
{"path":"/tmp/l50-shot1.png","bytes":119358}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --match Manage
```
{"snapshot":"s_t_cbe320577fc5525491e8800960f10507","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","rows":[{"index":49,"role":"paragraph","name":"Some vendors may process your personal data on the basis of legitimate interest, which you can object to by managing your options below. Look for a link at the bottom of this page or in the site menu to manage or withdraw consent in privacy and cookie settings."},{"index":52,"role":"button","name":"Manage options"},{"index":53,"role":"paragraph","name":"Manage options"}],"total":3,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_cbe320577fc5525491e8800960f10507 52
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","snapshot":null,"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash text t_c9edfdf33da436fdf4df7c91277f9f1d --max-chars 1500
```
{"url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\n\n\nCATEGORY\nWOMEN\nMEN\nKIDS\nBRANDS\n(6)\nPOLO\n(5)\nH&M\n(5)\nMADAME\n(3)\nMAST & HARBOUR\n(4)\nBABYHUG\n(3)\nALLEN SOLLY JUNIOR\n(3)\nKOOKIE KIDS\n(5)\nBIBA\nALL PRODUCTS\nRs. 500\n\nBlue Top\n\nAdd to cart\nRs. 500\n\nBlue Top\n\nAdd to cart\nView Product\nRs. 400\n\nMen Tshirt\n\nAdd to cart\nRs. 400\n\nMen Tshirt\n\nAdd to cart\nView Product\nRs. 1000\n\nSleeveless Dress\n\nAdd to cart\nRs. 1000\n\nSleeveless Dress\n\nAdd to cart\nView Product\nRs. 1500\n\nStylish Dress\n\nAdd to cart\nRs. 1500\n\nStylish Dress\n\nAdd to cart\nView Product\nRs. 600\n\nWinter Top\n\nAdd to cart\nRs. 600\n\nWinter Top\n\nAdd to cart\nView Product\nRs. 400\n\nSummer White Top\n\nAdd to cart\nRs. 400\n\nSummer White Top\n\nAdd to cart\nView Product\nRs. 1000\n\nMadame Top For Women\n\nAdd to cart\nRs. 1000\n\nMadame Top For Women\n\nAdd to cart\nView Product\nRs. 700\n\nFancy Green Top\n\nAdd to cart\nRs. 700\n\nFancy Green Top\n\nAdd to cart\nView Product\nRs. 499\n\nSleeves Printed Top - White\n\nAdd to cart\nRs. 499\n\nSleeves Printed Top - White\n\nAdd to cart\nView Product\nRs. 359\n\nHalf Sleeves Top Schiffli Detailing - Pink\n\nAdd to cart\nRs. 359\n\nHalf Sleeves Top Schiffli Detailing - Pink\n\nAdd to cart\nView Product\nRs. 278\n\nFrozen Tops For Kids\n\nAdd to cart\nRs. 278\n\nFrozen Tops For Kids\n\nAdd to cart\nView Product\nRs. 679\n\nFull Sleeves Top Cherry - Pink\n\nAdd to cart\nRs. 679\n\nFull Sleeves Top Cherry - Pink\n\nAdd to cart\nView Product\nRs. 315\n\nPrinted Off Shoulder Top - White\n\nAdd to cart\nRs. 315\n\nPrinted Off Shoulder T","truncated":true}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --match button
```
{"snapshot":"s_t_ecfc183ed6376423abf2c385f8097006","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","rows":[{"index":11,"role":"button","name":""},{"index":44,"role":"button","name":"Back"},{"index":51,"role":"button","name":"View details, Store and/or access information on a device"},{"index":54,"role":"button","name":"View details, Use limited data to select advertising"},{"index":57,"role":"button","name":"View details, Create profiles for personalised advertising"},{"index":58,"role":"button","name":"Accept all"},{"index":60,"role":"button","name":"Confirm choices"}],"total":7,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'const c=[...document.querySelectorAll(".fc-dialog input[type=checkbox]")]; return {n:c.length, checked:c.filter(x=>x.checked).length, text:document.querySelector(".fc-dialog")?.innerText.slice(0,600)}'
```
{"value":{"n":290,"checked":78,"text":"WelcomeThis site asks for consent to use your dataPersonalised advertising and content, advertising and content measurement, audience research and services developmentStore and/or access information on a deviceLearn moreHow can I change my choice?What if I don't consent?How does legitimate interest work?Do I have to consent to everything?Your personal data will be processed and information from your device (cookies, unique identifiers, and other device data) may be stored by, accessed by and shared with 210 partners, or used specifically by this site. We and our partners may use precise geoloc"}}

```
[exit code: 0]

Decision: a cookie-consent modal blocks the page. Chose "Confirm choices" (not "Accept all") as the least-invasive dismissal.

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_ecfc183ed6376423abf2c385f8097006 60
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","snapshot":null,"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 14 --match Search
```
{"snapshot":"s_t_ad241bc805a9bdfc3631d61b0c462271","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","rows":[{"index":10,"role":"textbox","name":"Search Product"}],"total":1,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash fill t_c9edfdf33da436fdf4df7c91277f9f1d s_t_ad241bc805a9bdfc3631d61b0c462271 10 'Blue Top'
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","snapshot":null,"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return document.querySelector("#search_product").value'
```
{"value":"Blue Top"}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 14
```
{"snapshot":"s_t_c58b5aa7702eea7d34cddadc85937805","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","rows":[{"index":1,"role":"link","name":"Website for automation practice"},{"index":2,"role":"link","name":" Home"},{"index":3,"role":"link","name":" Products"},{"index":4,"role":"link","name":" Cart"},{"index":5,"role":"link","name":" Signup / Login"},{"index":6,"role":"link","name":" Test Cases"},{"index":7,"role":"link","name":" API Testing"},{"index":8,"role":"link","name":" Video Tutorials"},{"index":9,"role":"link","name":" Contact us"},{"index":10,"role":"textbox","name":"Search Product","value":"Blue Top"},{"index":11,"role":"button","name":""},{"index":12,"role":"heading","name":"CATEGORY"},{"index":13,"role":"heading","name":" WOMEN"},{"index":14,"role":"link","name":" WOMEN"}],"total":44,"offset":0,"truncated":true,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_c58b5aa7702eea7d34cddadc85937805 11
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","snapshot":null,"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash text t_c9edfdf33da436fdf4df7c91277f9f1d --max-chars 600
```
{"url":"https://automationexercise.com/products?search=Blue%20Top","title":"automationexercise.com/products?search=Blue Top","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\n\n\nCATEGORY\nWOMEN\nMEN\nKIDS\nBRANDS\n(6)\nPOLO\n(5)\nH&M\n(5)\nMADAME\n(3)\nMAST & HARBOUR\n(4)\nBABYHUG\n(3)\nALLEN SOLLY JUNIOR\n(3)\nKOOKIE KIDS\n(5)\nBIBA\nSEARCHED PRODUCTS\nRs. 500\n\nBlue Top\n\nAdd to cart\nRs. 500\n\nBlue Top\n\nAdd to cart\nView Product\nSUBSCRIPTION\n \n\nGet the most recent updates from\nour site and be updated your self...\n\nCopyright © 2021 All rights reserved","truncated":false}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --match View
```
{"snapshot":"s_t_322689ed395a33270860b2c5bdd2f4c2","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products?search=Blue%20Top","title":"automationexercise.com/products?search=Blue Top","rows":[{"index":32,"role":"link","name":" View Product"}],"total":1,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_322689ed395a33270860b2c5bdd2f4c2 32
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products?search=Blue%20Top","title":"Automation Exercise - All Products","snapshot":null,"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash wait t_c9edfdf33da436fdf4df7c91277f9f1d --url-prefix https://automationexercise.com/product_details
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1","title":"automationexercise.com/product_details/1","snapshot":null,"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash text t_c9edfdf33da436fdf4df7c91277f9f1d --max-chars 700
```
{"url":"https://automationexercise.com/product_details/1","title":"automationexercise.com/product_details/1","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\nCATEGORY\nWOMEN\nMEN\nKIDS\nBRANDS\n(6)\nPOLO\n(5)\nH&M\n(5)\nMADAME\n(3)\nMAST & HARBOUR\n(4)\nBABYHUG\n(3)\nALLEN SOLLY JUNIOR\n(3)\nKOOKIE KIDS\n(5)\nBIBA\nBlue Top\n\nCategory: Women > Tops\n\n \nRs. 500\nQuantity:   Add to cart\n\nAvailability: In Stock\n\nCondition: New\n\nBrand: Polo\n\nWRITE YOUR REVIEW\n \nSubmit\nSUBSCRIPTION\n \n\nGet the most recent updates from\nour site and be updated your self...\n\nCopyright © 2021 All rights reserved","truncated":false}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 80 --table
```
INDEX	ROLE	NAME	VALUE	STATE
1	link	Website for automation practice	-	
2	link	 Home	-	
3	link	 Products	-	
4	link	 Cart	-	
5	link	 Signup / Login	-	
6	link	 Test Cases	-	
7	link	 API Testing	-	
8	link	 Video Tutorials	-	
9	link	 Contact us	-	
10	heading	CATEGORY	-	
11	heading	 WOMEN	-	
12	link	 WOMEN	-	
13	heading	 MEN	-	
14	link	 MEN	-	
15	heading	 KIDS	-	
16	link	 KIDS	-	
17	heading	BRANDS	-	
18	link	(6) POLO	-	
19	link	(5) H&M	-	
20	link	(5) MADAME	-	
21	link	(3) MAST & HARBOUR	-	
22	link	(4) BABYHUG	-	
23	link	(3) ALLEN SOLLY JUNIOR	-	
24	link	(3) KOOKIE KIDS	-	
25	link	(5) BIBA	-	
26	heading	Blue Top	-	
27	paragraph	Category: Women > Tops	-	
28	spinbutton		1	
29	button	 Add to cart	-	
30	paragraph	Availability: In Stock	-	
31	paragraph	Condition: New	-	
32	paragraph	Brand: Polo	-	
33	link	WRITE YOUR REVIEW	-	
34	textbox	Your Name	-	required
35	textbox	Email Address	-	required
36	textbox	Add Review Here!	-	required

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --match "Add to cart"
```
{"snapshot":"s_t_c41a6c9151b3fa4327b1dac862689ac0","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1#google_vignette","title":"Automation Exercise - Product Details","rows":[{"index":29,"role":"button","name":" Add to cart"}],"total":1,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_c41a6c9151b3fa4327b1dac862689ac0 29 --snap --match Cart
```

[stderr]
{"code":"row-not-actionable","message":"the row is covered at its click point","hint":"pick another row, or `leash snap TAB` if the page moved; a file input takes `leash upload`"}

```
[exit code: 65]

## $ leash text t_c9edfdf33da436fdf4df7c91277f9f1d --max-chars 300
```
{"url":"https://automationexercise.com/product_details/1#google_vignette","title":"Automation Exercise - Product Details","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\nCATEGORY\nWOMEN\nMEN\nKIDS\nBRANDS\n(6)\nPOLO\n(5)\nH&M\n(5)\nMADAME\n(3)\nMAST & HARBOUR\n(4)\nBABYHUG\n(3)\nALLEN SOLLY JUNIOR\n(3)\nKOOKIE KIDS\n(5)\nBIBA\nBlue Top\n\nCategory: Women > Tops\n\n \nRs. 500\nQuantity:   Add to cart\n\n","truncated":true}

```
[exit code: 0]

## $ leash shot t_c9edfdf33da436fdf4df7c91277f9f1d /tmp/l50-shot2.png
```

[stderr]
{"code":"renderer-unresponsive","message":"browser operation timed out","hint":"the page's renderer is not answering; a bot-detection challenge or a hung script is likely; shot may still work; close the tab or hand off","detail":{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1#google_vignette","title":"Automation Exercise - Product Details","entries":[{"at":"2026-10-01T16:16:21Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:16:17Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:16:16Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:16:16Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:16:16Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:16:12Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:16:11Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:16:11Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:16:11Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:16:10Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:16:10Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:16:06Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:14:10Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:14:10Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:14:10Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:13:54Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:13:54Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:13:54Z","kind":"request-failed","text":""}]}}

```
[exit code: 75]

## $ leash shot t_c9edfdf33da436fdf4df7c91277f9f1d /tmp/l50-shot2.png
```
{"path":"/tmp/l50-shot2.png","bytes":237215}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --match Close
```
{"snapshot":"s_t_255ec26a141967c7ebee140089954230","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1#google_vignette","title":"Automation Exercise - Product Details","rows":[],"total":0,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --match dismiss
```
{"snapshot":"s_t_754a7184f0dcbda0f56751eaca18bcbc","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1#google_vignette","title":"Automation Exercise - Product Details","rows":[],"total":0,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash press --help | sed -n 1,30p
```
NAME
       leash-press - Press KEY; with --index the row is focused first.
       Accepted names: Enter, Escape, Esc, Tab, Backspace, Delete, ArrowUp,
       ArrowDown, ArrowLeft, ArrowRight, Home, End, PageUp, PageDown, Space,
       lowercase a-z, digits 0-9, and single punctuation characters - = [ ] ;
       , . / '.

SYNOPSIS
       leash press [OPTION]… [TAB] [SNAPSHOT] [KEY]

OPTIONS
       --config=FILE
           TOML configuration file the control socket is read from.

       --index=N
           Focus the row at index N before the key.

       --limit=N
           With --snap, at most N rows, default 120, max 1000.

       --match=TEXT
           With --snap, keep rows whose role, name or value contains TEXT.

       --pretty
           Indent JSON output.

       --snap
           After settling, include a fresh snapshot in the reply.

       --socket=PATH

```
[exit code: 0]

## $ leash press t_c9edfdf33da436fdf4df7c91277f9f1d Escape
```

[stderr]
{"code":"usage","message":"press: KEY is missing; usage: press TAB SNAPSHOT KEY","hint":"`leash <command> --help` shows the arguments and an example"}

```
[exit code: 64]

## $ leash press t_c9edfdf33da436fdf4df7c91277f9f1d s_t_754a7184f0dcbda0f56751eaca18bcbc Escape
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1#google_vignette","title":"Automation Exercise - Product Details","snapshot":null,"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return {u:location.href, f:[...document.querySelectorAll("iframe")].filter(f=>f.offsetWidth>100).map(f=>f.id+"|"+f.src.slice(0,60))}'
```
{"value":{"u":"https://automationexercise.com/product_details/1#google_vignette","f":["aswift_1|https://pagead2.googlesyndication.com/pagead/html/r20260929/"]}}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/product_details/1
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/product_details/1","title":"Automation Exercise - Product Details","origin":"agent","age_s":208,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return {u:location.href}'
```
{"value":{"u":"https://automationexercise.com/product_details/1"}}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --match "Add to cart"
```
{"snapshot":"s_t_1663b9076cce74e5d0bf0c6cd4e15d5a","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1","title":"Automation Exercise - Product Details","rows":[{"index":29,"role":"button","name":" Add to cart"}],"total":1,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_1663b9076cce74e5d0bf0c6cd4e15d5a 29 --snap --match Cart
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1","title":"Automation Exercise - Product Details","snapshot":{"snapshot":"s_t_75a2b6ff2eb401c4d5641f3335f8ff00","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1","title":"Automation Exercise - Product Details","rows":[{"index":4,"role":"link","name":" Cart"},{"index":29,"role":"button","name":" Add to cart"}],"total":2,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null},"dialog":null,"popups":[]}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --match View
```
{"snapshot":"s_t_4271090206f9dd514ca2e30ef409f93f","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/product_details/1","title":"Automation Exercise - Product Details","rows":[{"index":28,"role":"link","name":"View Cart"},{"index":37,"role":"link","name":"WRITE YOUR REVIEW"},{"index":40,"role":"textbox","name":"Add Review Here!","state":["required"]}],"total":3,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return document.querySelector("#cartModal")?.innerText'
```
{"value":"\nAdded!\n\nYour product has been added to cart.\n\nView Cart\n\nContinue Shopping"}

```
[exit code: 0]

## $ leash net t_c9edfdf33da436fdf4df7c91277f9f1d --match add_to_cart
```
{"requests":[{"id":"2901471.1270","method":"GET","url":"https://automationexercise.com/add_to_cart/1?quantity=1","status":200,"type":"xhr","mime":"text/html","size":601,"duration_ms":229,"from_cache":false}]}

```
[exit code: 0]

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_4271090206f9dd514ca2e30ef409f93f 28
```

[stderr]
{"code":"row-not-actionable","message":"the row is covered at its click point","hint":"pick another row, or `leash snap TAB` if the page moved; a file input takes `leash upload`"}

```
[exit code: 65]

## $ leash wait t_c9edfdf33da436fdf4df7c91277f9f1d --url-prefix https://automationexercise.com/view_cart
```

[stderr]
{"code":"timeout","message":"wait conditions did not hold before timeout","hint":"retry; for a wait raise `--timeout-ms`, for a handoff raise the timeout or `leash resume TAB`"}

```
[exit code: 75]

## $ leash text t_c9edfdf33da436fdf4df7c91277f9f1d
```
{"url":"https://automationexercise.com/product_details/1#google_vignette","title":"Automation Exercise - Product Details","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\nCATEGORY\nWOMEN\nMEN\nKIDS\nBRANDS\n(6)\nPOLO\n(5)\nH&M\n(5)\nMADAME\n(3)\nMAST & HARBOUR\n(4)\nBABYHUG\n(3)\nALLEN SOLLY JUNIOR\n(3)\nKOOKIE KIDS\n(5)\nBIBA\n\nAdded!\n\nYour product has been added to cart.\n\nView Cart\n\nContinue Shopping\nBlue Top\n\nCategory: Women > Tops\n\n \nRs. 500\nQuantity:   Add to cart\n\nAvailability: In Stock\n\nCondition: New\n\nBrand: Polo\n\nWRITE YOUR REVIEW\n \nSubmit\nDiscover more\nDevelopment Tools\nProgramming\nSoftware\nSUBSCRIPTION\n \n\nGet the most recent updates from\nour site and be updated your self...\n\nCopyright © 2021 All rights reserved","truncated":false}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 80 --table
```
INDEX	ROLE	NAME	VALUE	STATE
1	link	Website for automation practice	-	
2	link	 Home	-	
3	link	 Products	-	
4	link	 Cart	-	
5	link	 Signup / Login	-	
6	link	 Test Cases	-	
7	link	 API Testing	-	
8	link	 Video Tutorials	-	
9	link	 Contact us	-	
10	heading	CATEGORY	-	
11	heading	 WOMEN	-	
12	link	 WOMEN	-	
13	heading	 MEN	-	
14	link	 MEN	-	
15	heading	 KIDS	-	
16	link	 KIDS	-	
17	heading	BRANDS	-	
18	link	(6) POLO	-	
19	link	(5) H&M	-	
20	link	(5) MADAME	-	
21	link	(3) MAST & HARBOUR	-	
22	link	(4) BABYHUG	-	
23	link	(3) ALLEN SOLLY JUNIOR	-	
24	link	(3) KOOKIE KIDS	-	
25	link	(5) BIBA	-	
26	heading	Added!	-	
27	paragraph	Your product has been added to cart.	-	
28	link	View Cart	-	
29	button	Continue Shopping	-	
30	heading	Blue Top	-	
31	paragraph	Category: Women > Tops	-	
32	spinbutton		1	
33	button	 Add to cart	-	
34	paragraph	Availability: In Stock	-	
35	paragraph	Condition: New	-	
36	paragraph	Brand: Polo	-	
37	link	WRITE YOUR REVIEW	-	
38	textbox	Your Name	-	required
39	textbox	Email Address	-	required
40	textbox	Add Review Here!	-	required
41	frame	https://pagead2.googlesyndication.com	-	cross-origin

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return {rows:[...document.querySelectorAll("#cart_info_table tbody tr")].map(r=>r.innerText.replace(/\s+/g," ").trim()), html:document.querySelector("#cart_info_table tbody tr")?.outerHTML.slice(0,1500)}'
```
{"value":{"rows":[]}}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/view_cart
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/view_cart","title":"Automation Exercise - Checkout","origin":"agent","age_s":256,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash text t_c9edfdf33da436fdf4df7c91277f9f1d
```
{"url":"https://automationexercise.com/view_cart","title":"Automation Exercise - Checkout","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\nHome Shopping Cart\nProceed To Checkout\nItem\tDescription\tPrice\tQuantity\tTotal\t\n\nBlue Top\n\nWomen > Tops\n\n\t\n\nRs. 500\n\n\t2\t\n\nRs. 1000\n\n\t\nSUBSCRIPTION\n \n\nGet the most recent updates from\nour site and be updated your self...\n\nCopyright © 2021 All rights reserved","truncated":false}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return {u:location.href, t:document.title, tableRows:[...document.querySelectorAll("table tbody tr")].map(r=>[r.id,r.innerText.replace(/\s+/g," ").trim()]), first:document.querySelector("table tbody tr")?.outerHTML.slice(0,1800)}'
```
{"value":{"u":"https://automationexercise.com/view_cart","t":"Automation Exercise - Checkout","tableRows":[["product-1","Blue Top Women > Tops Rs. 500 2 Rs. 1000"]],"first":"<tr id=\"product-1\">\n\t\t\t\t\t\t\t<td class=\"cart_product\">\n\t\t\t\t\t\t\t\t<a href=\"\"><img src=\"get_product_picture/1\" style=\"width:80px; height: 80px;\" class=\"product_image\" alt=\"Product Image\"></a>\n\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t\t<td class=\"cart_description\">\n\t\t\t\t\t\t\t\t<h4><a href=\"/product_details/1\">Blue Top</a></h4>\n\t\t\t\t\t\t\t\t<p>Women &gt; Tops</p>\n\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t\t<td class=\"cart_price\">\n\t\t\t\t\t\t\t\t<p>Rs. 500</p>\n\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t\t<td class=\"cart_quantity\">\n\t\t\t\t\t\t\t\t<button class=\"disabled\">2</button>\n\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t\t<td class=\"cart_total\">\n\t\t\t\t\t\t\t\t<p class=\"cart_total_price\">Rs. 1000</p>\n\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t\t<td class=\"cart_delete\">\n\t\t\t\t\t\t\t\t<a class=\"cart_quantity_delete\" style=\"cursor: pointer;\" data-product-id=\"1\"><i class=\"fa fa-times\"></i></a>\n\t\t\t\t\t\t\t</td>\n\t\t\t\t\t\t</tr>"}}

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 60 --table
```
INDEX	ROLE	NAME	VALUE	STATE
1	link	Website for automation practice	-	
2	link	 Home	-	
3	link	 Products	-	
4	link	 Cart	-	
5	link	 Signup / Login	-	
6	link	 Test Cases	-	
7	link	 API Testing	-	
8	link	 Video Tutorials	-	
9	link	 Contact us	-	
10	link	Home	-	
11	link	Proceed To Checkout	-	
12	link	Product Image	-	
13	heading	Blue Top	-	
14	link	Blue Top	-	
15	paragraph	Women > Tops	-	
16	paragraph	Rs. 500	-	
17	button	2	-	
18	paragraph	Rs. 1000	-	
19	link		-	
20	heading	SUBSCRIPTION	-	
21	textbox	Your email address	-	required
22	button		-	
23	paragraph	Get the most recent updates from
our site and be updated your self...	-	
24	paragraph	Copyright © 2021 All rights reserved	-	
25	button	Privacy and cookie settings	-	
26	link	Go to shopping options for Software testing courses	-	
27	button	Close shopping anchor	-	

```
[exit code: 0]

## $ leash snap t_c9edfdf33da436fdf4df7c91277f9f1d --limit 30
```
{"snapshot":"s_t_15325dc9a0b69d52c51602b8d2fbd134","tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/view_cart#google_vignette","title":"Automation Exercise - Checkout","rows":[{"index":1,"role":"link","name":" Video Tutorials"},{"index":2,"role":"link","name":" Contact us"},{"index":3,"role":"link","name":"Home"},{"index":4,"role":"link","name":"Proceed To Checkout"},{"index":5,"role":"link","name":"Product Image"},{"index":6,"role":"heading","name":"Blue Top"},{"index":7,"role":"link","name":"Blue Top"},{"index":8,"role":"paragraph","name":"Women > Tops"},{"index":9,"role":"paragraph","name":"Rs. 500"},{"index":10,"role":"button","name":"2"},{"index":11,"role":"paragraph","name":"Rs. 1000"},{"index":12,"role":"link","name":""},{"index":13,"role":"heading","name":"SUBSCRIPTION"},{"index":14,"role":"textbox","name":"Your email address","state":["required"]},{"index":15,"role":"button","name":""},{"index":16,"role":"paragraph","name":"Get the most recent updates from\nour site and be updated your self..."},{"index":17,"role":"paragraph","name":"Copyright © 2021 All rights reserved"},{"index":18,"role":"button","name":"Privacy and cookie settings"},{"index":19,"role":"link","name":"Go to shopping options for Software testing courses"},{"index":20,"role":"button","name":"Close shopping anchor"},{"index":21,"role":"frame","name":"https://pagead2.googlesyndication.com","state":["cross-origin"]},{"index":22,"role":"frame","name":"https://pagead2.googlesyndication.com","state":["cross-origin"]}],"total":22,"offset":0,"truncated":false,"settled":true,"source":"ax","dialog":null}

```
[exit code: 0]

Cleaning my own test cart (Blue Top qty 2 left from study) by clicking the row delete link; no checkout.

## $ leash click t_c9edfdf33da436fdf4df7c91277f9f1d s_t_15325dc9a0b69d52c51602b8d2fbd134 19
```

[stderr]
{"code":"row-not-actionable","message":"the row is covered at its click point","hint":"pick another row, or `leash snap TAB` if the page moved; a file input takes `leash upload`"}

```
[exit code: 65]

## $ leash text t_c9edfdf33da436fdf4df7c91277f9f1d --max-chars 400
```
{"url":"https://automationexercise.com/view_cart#google_vignette","title":"Automation Exercise - Checkout","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\nHome Shopping Cart\nProceed To Checkout\nItem\tDescription\tPrice\tQuantity\tTotal\t\n\nBlue Top\n\nWomen > Tops\n\n\t\n\nRs. 500\n\n\t2\t\n\nRs. 1000\n\n\t\nSUBSCRIPTION\n \n\nGet the most recent updates from\nour site and be updated your self...\n\nCopyright © 2021 All rights reserved","truncated":false}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'const r=await fetch("/delete_cart/1"); const h=await (await fetch("/view_cart")).text(); return {status:r.status, empty:/Cart is empty/i.test(h), rows:(h.match(/<tr id="product-\d+"/g)||[])}'
```

[stderr]
{"code":"internal","message":"page evaluation threw an exception","hint":"a defect, not a page failure; retry once, then report the message"}

```
[exit code: 70]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return 1+1'
```
{"value":2}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/view_cart").then(r=>r.text()).then(h=>({rows:(h.match(/<tr id="product-[0-9]+"/g)||[]).length}))'
```
{"value":{"rows":1}}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return await Promise.resolve(5)'
```

[stderr]
{"code":"internal","message":"page evaluation threw an exception","hint":"a defect, not a page failure; retry once, then report the message"}

```
[exit code: 70]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/delete_cart/1").then(r=>r.status)'
```
{"value":200}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/view_cart").then(r=>r.text()).then(h=>({rows:(h.match(/<tr id="product-[0-9]+"/g)||[]).length, empty:/Cart is empty/i.test(h)}))'
```
{"value":{"rows":0,"empty":true}}

```
[exit code: 0]

## $ cd /tmp/l50-pb && leash playbook check ./automationexercise.com
```
{
  "file": "./automationexercise.com/playbook.json",
  "playbook": {
    "site": "automationexercise.com",
    "entry": "https://automationexercise.com/",
    "description": "A public demo online shop (Automation Exercise): search products, open a product page, add it to the cart and view the cart. Never checkout, login or register.",
    "pages": [
      {
        "name": "home",
        "description": "Shop front page",
        "url_pattern": "https://automationexercise.com/"
      },
      {
        "name": "products",
        "description": "All products or search results list with a Search Product box",
        "url_pattern": "https://automationexercise.com/products*"
      },
      {
        "name": "product",
        "description": "One product's detail page with the Add to cart button",
        "url_pattern": "https://automationexercise.com/product_details/*"
      },
      {
        "name": "cart",
        "description": "The shopping cart page",
        "url_pattern": "https://automationexercise.com/view_cart*"
      }
    ],
    "procedures": [
      {
        "slug": "search-product",
        "description": "From anywhere on the shop: search the catalogue for a product by name and show the search results.",
        "args": { "query": { "from": "mission" } },
        "steps": [
          {
            "goal": "Open the Products page from the Products link in the top menu.",
            "until": [ "the page is products" ]
          },
          {
            "goal": "Type {query} into the Search Product box and click the unnamed search button beside it.",
            "hint": "If a cookie or ad overlay covers the page, close it first. Never choose Accept all.",
            "until": [ "the address changed", "the page is products" ]
          }
        ],
        "expect": [
          "the page is products", "the page shows Searched Products"
        ]
      },
      {
        "slug": "open-product",
        "description": "From the products list or search results: open the detail page of one product with its View Product link.",
        "args": { "product": { "from": "mission" } },
        "steps": [
          {
            "goal": "Click the View Product link of the {product} product.",
            "until": [ "the address changed", "the page is product" ]
          }
        ],
        "expect": [ "the page is product", "the page shows {product}" ]
      },
      {
        "slug": "add-to-cart",
        "description": "From a product page: add this product to the cart once with the Add to cart button.",
        "steps": [
          {
            "goal": "Click the Add to cart button next to the Quantity box on this product page, once."
          }
        ],
        "expect": [ "the page shows Your product has been added to cart" ]
      },
      {
        "slug": "view-cart",
        "description": "Show the shopping cart and read its lines. Never press Proceed To Checkout.",
        "steps": [
          {
            "goal": "Open the shopping cart with the Cart link in the top menu. Do not press Proceed To Checkout.",
            "until": [ "the page is cart" ]
          },
          { "use": "cart-lines" }
        ],
        "expect": [ "the page is cart" ]
      },
      {
        "slug": "cart-lines",
        "description": "Read the lines of the cart page.",
        "steps": [ { "script": "read-cart" } ],
        "expect": [ "the page is cart" ]
      }
    ],
    "shapes": {
      "cart-line": [
        {
          "name": "string",
          "price": "number",
          "quantity": "number",
          "total": "number",
          "url": "url"
        }
      ]
    },
    "scripts": {
      "read-cart": {
        "file": "scripts/read-cart.js",
        "description": "Read every line of the shopping cart as records (empty list when the cart is empty).",
        "pages": [ "cart" ]
      }
    }
  },
  "scripts": [
    {
      "script": "read-cart",
      "origin": "file scripts/read-cart.js",
      "bytes": 5
```
[exit code: 0]

## $ cp -r /tmp/l50-pb/automationexercise.com ~/.config/leash/playbooks/ && ls -R ~/.config/leash/playbooks/automationexercise.com
```
/home/ribelo/.config/leash/playbooks/automationexercise.com:
playbook.json
scripts

/home/ribelo/.config/leash/playbooks/automationexercise.com/scripts:
read-cart.js

```
[exit code: 0]

## $ leash playbook list
```
automationexercise.com	A public demo online shop (Automation Exercise): search products, open a product page, add it to the cart and view the cart. Never checkout, login or register.
books.toscrape.com	A bookshop catalogue with categories, book titles, prices, ratings, and availability.

```
[exit code: 0]

## $ leash playbook check automationexercise.com | tail -8
```
    },
    {
      "procedure": "cart-lines",
      "checkers": [ { "checker": "page_kind", "kind": "cart" } ]
    }
  ],
  "syntax": [ { "script": "read-cart", "ok": true } ]
}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/products
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/products","title":"Automation Exercise - All Products","origin":"agent","age_s":335,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash playbook test automationexercise.com/read-cart --tab t_c9edfdf33da436fdf4df7c91277f9f1d
```

[stderr]
{"code":"script-failed","message":"Error: not the cart page: https://automationexercise.com/products\n    at <anonymous>:3:56","hint":"read message; fix the script or the page, then `leash playbook test`"}

```
[exit code: 65]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/view_cart
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/view_cart","title":"Automation Exercise - Checkout","origin":"agent","age_s":336,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash playbook test automationexercise.com/read-cart --tab t_c9edfdf33da436fdf4df7c91277f9f1d
```
{"script":"automationexercise.com/read-cart","value":[],"records":0,"bytes":2,"elapsed_ms":1,"truncated":false}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/add_to_cart/1").then(r=>r.status)'
```
{"value":200}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/view_cart
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/view_cart","title":"Automation Exercise - Checkout","origin":"agent","age_s":336,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash playbook test automationexercise.com/read-cart --tab t_c9edfdf33da436fdf4df7c91277f9f1d
```
{"script":"automationexercise.com/read-cart","value":[{"name":"Blue Top","price":0.5,"quantity":1,"total":0.5,"url":"https://automationexercise.com/product_details/1"}],"records":1,"bytes":115,"elapsed_ms":2,"truncated":false}

```
[exit code: 0]

## $ cp /tmp/l50-pb/automationexercise.com/scripts/read-cart.js ~/.config/leash/playbooks/automationexercise.com/scripts/read-cart.js && leash playbook check automationexercise.com | tail -3
```
  ],
  "syntax": [ { "script": "read-cart", "ok": true } ]
}

```
[exit code: 0]

## $ leash playbook test automationexercise.com/read-cart --tab t_c9edfdf33da436fdf4df7c91277f9f1d
```
{"script":"automationexercise.com/read-cart","value":[{"name":"Blue Top","price":500,"quantity":1,"total":500,"url":"https://automationexercise.com/product_details/1"}],"records":1,"bytes":115,"elapsed_ms":4,"truncated":false}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/delete_cart/1").then(r=>r.status)'
```
{"value":200}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/view_cart").then(r=>r.text()).then(h=>(h.match(/<tr id="product-[0-9]+"/g)||[]).length)'
```
{"value":0}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/","title":"Automation Exercise","origin":"agent","age_s":352,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top, open it, add it to the cart and show the cart. Do not check out.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --dry-run --pretty > /tmp/l50-dry.json; echo; wc -c /tmp/l50-dry.json
```

5935 /tmp/l50-dry.json

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top, open it, add it to the cart once and show the cart. Do not check out, log in or register.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --expect 'the page is cart' --expect 'the page shows Blue Top' --max-procedures 12 --deadline-s 300 --out /tmp/l50-live1.jsonl --pretty > /tmp/l50-live1.json; echo done
```
done

```
[exit code: 0]

## $ leash shot t_c9edfdf33da436fdf4df7c91277f9f1d /tmp/l50-shot3.png
```

[stderr]
{"code":"renderer-unresponsive","message":"browser operation timed out","hint":"the page's renderer is not answering; a bot-detection challenge or a hung script is likely; shot may still work; close the tab or hand off","detail":{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","url":"https://automationexercise.com/products#google_vignette","title":"Automation Exercise - All Products","entries":[{"at":"2026-10-01T16:20:03Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:20:00Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:20:00Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:19:59Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:59Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:59Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:54Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:19:53Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:19:46Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:19:44Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:44Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:44Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:29Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:19:28Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:28Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:28Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:28Z","kind":"request-failed","text":"net::ERR_ABORTED"},{"at":"2026-10-01T16:19:28Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:28Z","kind":"request-failed","text":""},{"at":"2026-10-01T16:19:28Z","kind":"request-failed","text":""}]}}

```
[exit code: 75]

## $ leash shot t_c9edfdf33da436fdf4df7c91277f9f1d /tmp/l50-shot3.png
```
{"path":"/tmp/l50-shot3.png","bytes":281351}

```
[exit code: 0]

## $ cd /tmp/l50-pb && leash playbook check ./automationexercise.com | tail -5
```
      "checkers": [ { "checker": "page_kind", "kind": "cart" } ]
    }
  ],
  "syntax": "skipped: only an installed playbook (its name, not a path) is compiled"
}

```
[exit code: 0]

## $ rm -rf ~/.config/leash/playbooks/automationexercise.com && cp -r /tmp/l50-pb/automationexercise.com ~/.config/leash/playbooks/ && leash playbook check automationexercise.com | tail -9
```
    }
  ],
  "syntax": [
    { "script": "read-cart", "ok": true },
    { "script": "search-url", "ok": true },
    { "script": "product-url", "ok": true },
    { "script": "cart-url", "ok": true }
  ]
}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d 'https://automationexercise.com/products?search=Blue%20Top'
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/products?search=Blue%20Top","title":"Automation Exercise - All Products","origin":"agent","age_s":455,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash playbook test automationexercise.com/search-url --tab t_c9edfdf33da436fdf4df7c91277f9f1d --arg 'query=Blue Top'
```
{"script":"automationexercise.com/search-url","value":{"url":"https://automationexercise.com/products?search=Blue%20Top"},"records":1,"bytes":67,"elapsed_ms":7,"truncated":false}

```
[exit code: 0]

## $ leash playbook test automationexercise.com/product-url --tab t_c9edfdf33da436fdf4df7c91277f9f1d --arg 'product=Blue Top'
```
{"script":"automationexercise.com/product-url","value":{"url":"https://automationexercise.com/product_details/1"},"records":1,"bytes":58,"elapsed_ms":2,"truncated":false}

```
[exit code: 0]

## $ leash playbook test automationexercise.com/product-url --tab t_c9edfdf33da436fdf4df7c91277f9f1d --arg 'product=Nonexistent'
```

[stderr]
{"code":"script-failed","message":"Error: product not listed: nonexistent\n    at <anonymous>:11:17","hint":"read message; fix the script or the page, then `leash playbook test`"}

```
[exit code: 65]

## $ leash playbook test automationexercise.com/cart-url --tab t_c9edfdf33da436fdf4df7c91277f9f1d
```
{"script":"automationexercise.com/cart-url","value":{"url":"https://automationexercise.com/view_cart"},"records":1,"bytes":50,"elapsed_ms":4,"truncated":false}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/","title":"Automation Exercise","origin":"agent","age_s":465,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top, open it, add it to the cart once and show the cart. Do not check out, log in or register.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --dry-run --pretty > /tmp/l50-dry2.json
```

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top, open it, add it to the cart once and show the cart. Do not check out, log in or register.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --expect 'the page is cart' --expect 'the page shows Blue Top' --max-procedures 12 --deadline-s 300 --out /tmp/l50-live2.jsonl --pretty > /tmp/l50-live2.json
```

```
[exit code: 0]

## $ ls -la ~/.config/leash/playbooks ~/.config/leash/playbooks/automationexercise.com; leash playbook list | cut -c1-60
```
/home/ribelo/.config/leash/playbooks:
total 16
drwxr-xr-x 4 ribelo users 4096 Oct  1 18:21 .
drwxr-xr-x 3 ribelo users 4096 Oct  1 18:07 ..
drwxr-xr-x 3 ribelo users 4096 Oct  1 18:21 automationexercise.com
drwxr-xr-x 3 ribelo users 4096 Sep 30 23:55 books.toscrape.com

/home/ribelo/.config/leash/playbooks/automationexercise.com:
total 20
drwxr-xr-x 3 ribelo users 4096 Oct  1 18:21 .
drwxr-xr-x 4 ribelo users 4096 Oct  1 18:21 ..
-rw-r--r-- 1 ribelo users 4724 Oct  1 18:21 playbook.json
drwxr-xr-x 2 ribelo users 4096 Oct  1 18:21 scripts
automationexercise.com	A public demo online shop (Automation
books.toscrape.com	A bookshop catalogue with categories, boo

```
[exit code: 0]

## $ rm -rf ~/.config/leash/playbooks/automationexercise.com && cp -r /tmp/l50-pb/automationexercise.com ~/.config/leash/playbooks/ && leash playbook check automationexercise.com | tail -8
```
  ],
  "syntax": [
    { "script": "read-cart", "ok": true },
    { "script": "search-url", "ok": true },
    { "script": "product-url", "ok": true },
    { "script": "cart-url", "ok": true }
  ]
}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/view_cart").then(r=>r.text()).then(h=>(h.match(/<tr id="product-[0-9]+"/g)||[]).length)'
```
{"value":0}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/","title":"Automation Exercise","origin":"agent","age_s":515,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top, open it, add it to the cart once and show the cart. Do not check out, log in or register.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --expect 'the page is cart' --expect 'the page shows Blue Top' --max-procedures 12 --deadline-s 300 --out /tmp/l50-live3.jsonl --pretty > /tmp/l50-live3.json
```

```
[exit code: 0]

## $ rm -rf /tmp/l50-exp && cp -r /tmp/l50-pb /tmp/l50-exp
```

```
[exit code: 0]

## $ cd /tmp/l50-exp && leash playbook check ./automationexercise.com | head -5
```
{
  "file": "./automationexercise.com/playbook.json",
  "playbook": {
    "site": "automationexercise.com",
    "entry": "https://automationexercise.com/",

```
[exit code: 0]

## $ cd /tmp/l50-exp && leash playbook check ./automationexercise.com | head -3
```
{
  "file": "./automationexercise.com/playbook.json",
  "playbook": {

```
[exit code: 0]

## $ rm -rf ~/.config/leash/playbooks/automationexercise.com && cp -r /tmp/l50-exp/automationexercise.com ~/.config/leash/playbooks/ && leash playbook check automationexercise.com | tail -2
```
  ]
}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/","title":"Automation Exercise","origin":"agent","age_s":595,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top and show the results. Do not click anything else.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --max-procedures 1 --deadline-s 120 --pretty > /tmp/l50-exp1.json
```

```
[exit code: 0]

## $ rm -rf ~/.config/leash/playbooks/automationexercise.com && cp -r /tmp/l50-pb/automationexercise.com ~/.config/leash/playbooks/ && leash playbook check automationexercise.com | tail -8
```
  ],
  "syntax": [
    { "script": "read-cart", "ok": true },
    { "script": "search-url", "ok": true },
    { "script": "product-url", "ok": true },
    { "script": "cart-url", "ok": true }
  ]
}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/view_cart").then(r=>r.text()).then(h=>(h.match(/<tr id="product-[0-9]+"/g)||[]).length)'
```
{"value":0}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/","title":"Automation Exercise","origin":"agent","age_s":613,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top, open it, add it to the cart once and show the cart. Do not check out, log in or register.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --expect 'the page is cart' --expect 'the page shows Blue Top' --max-procedures 12 --deadline-s 300 --out /tmp/l50-live4.jsonl --pretty > /tmp/l50-live4.json
```

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return {u:location.href, rows:[...document.querySelectorAll("#cart_info_table tbody tr")].map(r=>r.innerText.replace(/\s+/g," ").trim())}'
```
{"value":{"u":"https://automationexercise.com/view_cart#google_vignette","rows":["Blue Top Women > Tops Rs. 500 2 Rs. 1000"]}}

```
[exit code: 0]

## $ leash new https://automationexercise.com/view_cart --label l50-verify
```
{"tab":"t_16f7f764eecec46e3d31c78a0859acba","label":"l50-verify","url":"https://automationexercise.com/view_cart","title":"Automation Exercise - Checkout","origin":"agent","age_s":0,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash text t_16f7f764eecec46e3d31c78a0859acba --max-chars 500
```
{"url":"https://automationexercise.com/view_cart","title":"Automation Exercise - Checkout","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\nHome Shopping Cart\nProceed To Checkout\nItem\tDescription\tPrice\tQuantity\tTotal\t\n\nBlue Top\n\nWomen > Tops\n\n\t\n\nRs. 500\n\n\t2\t\n\nRs. 1000\n\n\t\nSUBSCRIPTION\n \n\nGet the most recent updates from\nour site and be updated your self...\n\nCopyright © 2021 All rights reserved","truncated":false}

```
[exit code: 0]

## $ rm -rf ~/.config/leash/playbooks/automationexercise.com && cp -r /tmp/l50-pb/automationexercise.com ~/.config/leash/playbooks/ && leash playbook check automationexercise.com | tail -3
```
    { "script": "cart-url", "ok": true }
  ]
}

```
[exit code: 0]

Resetting my own test cart (qty 2 from double click) via /delete_cart/1, then rerun.

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/delete_cart/1").then(r=>r.status)'
```
{"value":200}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/view_cart").then(r=>r.text()).then(h=>(h.match(/<tr id="product-[0-9]+"/g)||[]).length)'
```
{"value":0}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/","title":"Automation Exercise","origin":"agent","age_s":669,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top, open it, add it to the cart once and show the cart. Do not check out, log in or register.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --expect 'the page is cart' --expect 'the page shows Blue Top' --max-procedures 12 --deadline-s 300 --out /tmp/l50-live5.jsonl --pretty > /tmp/l50-live5.json
```

```
[exit code: 0]

## $ rm -rf ~/.config/leash/playbooks/automationexercise.com && cp -r /tmp/l50-pb/automationexercise.com ~/.config/leash/playbooks/ && leash playbook check automationexercise.com | tail -3
```
    { "script": "cart-url", "ok": true }
  ]
}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/delete_cart/1").then(r=>r.status)'
```
{"value":200}

```
[exit code: 0]

## $ leash eval t_c9edfdf33da436fdf4df7c91277f9f1d 'return fetch("/view_cart").then(r=>r.text()).then(h=>(h.match(/<tr id="product-[0-9]+"/g)||[]).length)'
```
{"value":0}

```
[exit code: 0]

## $ leash nav t_c9edfdf33da436fdf4df7c91277f9f1d https://automationexercise.com/
```
{"tab":"t_c9edfdf33da436fdf4df7c91277f9f1d","label":"l50-study","url":"https://automationexercise.com/","title":"Automation Exercise","origin":"agent","age_s":715,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash drive 'Search automationexercise.com for the product Blue Top, open it, add it to the cart once and show the cart. Do not check out, log in or register.' --tab t_c9edfdf33da436fdf4df7c91277f9f1d --expect 'the page is cart' --expect 'the page shows Blue Top' --max-procedures 12 --deadline-s 300 --out /tmp/l50-live6.jsonl --pretty > /tmp/l50-live6.json
```

```
[exit code: 0]

## $ leash nav t_16f7f764eecec46e3d31c78a0859acba https://automationexercise.com/view_cart
```
{"tab":"t_16f7f764eecec46e3d31c78a0859acba","label":"l50-verify","url":"https://automationexercise.com/view_cart","title":"Automation Exercise - Checkout","origin":"agent","age_s":102,"idle_s":0,"closes_in_s":1800,"with_human":false,"generation":1,"dialog":null,"loaded":true}

```
[exit code: 0]

## $ leash text t_16f7f764eecec46e3d31c78a0859acba --max-chars 400
```
{"url":"https://automationexercise.com/view_cart","title":"Automation Exercise - Checkout","text":" Home\n Products\n Cart\n Signup / Login\n Test Cases\n API Testing\n Video Tutorials\n Contact us\nHome Shopping Cart\nProceed To Checkout\nItem\tDescription\tPrice\tQuantity\tTotal\t\n\nBlue Top\n\nWomen > Tops\n\n\t\n\nRs. 500\n\n\t1\t\n\nRs. 500\n\n\t\nSUBSCRIPTION\n \n\nGet the most recent updates from\nour site and be updated your self...\n\nCopyright © 2021 All rights reserved","truncated":false}

```
[exit code: 0]

## $ leash eval t_16f7f764eecec46e3d31c78a0859acba 'return [...document.querySelectorAll("#cart_info_table tbody tr")].map(r=>r.innerText.replace(/\s+/g," ").trim())'
```
{"value":["Blue Top Women > Tops Rs. 500 1 Rs. 500"]}

```
[exit code: 0]

## $ leash playbook test automationexercise.com/read-cart --tab t_16f7f764eecec46e3d31c78a0859acba
```
{"script":"automationexercise.com/read-cart","value":[{"name":"Blue Top","price":500,"quantity":1,"total":500,"url":"https://automationexercise.com/product_details/1"}],"records":1,"bytes":115,"elapsed_ms":0,"truncated":false}

```
[exit code: 0]

## $ leash close t_c9edfdf33da436fdf4df7c91277f9f1d
```
{"closed":true}

```
[exit code: 0]

## $ leash close t_16f7f764eecec46e3d31c78a0859acba
```
{"closed":true}

```
[exit code: 0]

## $ leash list --table | cut -c1-90
```
LABEL	URL	TITLE	ORIGIN	AGE_S	IDLE_S	CLOSES_IN_S	WITH_HUMAN
-	chrome://newtab/	New Tab	human	1107	1107	-	false
pilot-read	https://x.com/JamesLucasIT/status/2105689860753215815	James Lucas on X: "This i
pilot-read	https://x.com/dwarkesh_sp/status/2105689480539557938	Dwarkesh Patel on X: "New 

```
[exit code: 0]


## Final: live mission 6 status done, cart verified qty 1, tabs closed.
