# Authoring a playbook

Write one when a site will be driven again, or when a mission needs validated records rather than the operator's bounded page state. Discovery (`leash discover`, Leash proposing a playbook) exists too; it is propose-and-accept, not covered here.

## What a playbook is

- **Site and entry:** one site (`books.toscrape.com`) and the URL a blank tab opens.
- **Page kinds:** names for the pages the task touches, each recognised by a URL pattern or a text marker.
- **Procedures:** named, ordered steps. At least one step is a **goal** in plain language that JEV (the small operator model) drives by clicking, typing and scrolling.
- **Scripts:** JavaScript files JEV can choose as tools (`run_script:<name>`) or a procedure pins, for what clicking cannot do: read every card on a page, save a file. Their results are validated against a declared shape.
- **Expectations:** sentences checked by code after each procedure (`the page is category`), so "done" is evidence, not an opinion.

A playbook is a directory `~/.config/leash/playbooks/<site>/` holding `playbook.json` and `scripts/`. Nothing else may sit beside `playbook.json`.

## The procedure, in order

1. **Study the site** on the pages the task touches: `leash new URL`, `leash snap TAB --limit 60`, `leash text TAB`, `leash net TAB`. Note the URLs, **which page each control lives on**, where lists and pagers are, what loads late. `snap` lists only rows in the viewport (`--match` too): `leash scroll TAB down` and snap again. `text` is the rendered text (CSS `text-transform` applies: "SEARCHED PRODUCTS"), and `wait --text` is case-sensitive against it. A control with an empty name (an icon link) can be inspected with `eval --index N --snapshot S`; in goals, name it by what is next to it.
2. **Name the page kinds.** One kind per page type the procedures start on or land on (`home`, `category`, `product`, `cart`). Prefer a `url_pattern` with `*`; use `text_marker` only when the URL does not tell (a modal, a single-page app).
3. **Write each procedure's goal steps** as a person would say them: "Open the {category} category.", "Add this product to the cart.". One intention per goal. Put the site's words in the goal when they are the control's label. A goal runs on whatever page the tab is on — the entry, or where the last procedure left it — so if its control lives elsewhere, put a navigation goal first ("Open the Products page.", with `until`).
4. **Add a script only where bulk reading or a file is needed.** Navigation, search, forms and pagination are goals. A script reads; it does not click, scroll, fetch other pages or change the page. Declare `description` (one sentence: when JEV should choose it), `pages` and `returns` beside it.
5. **Declare every argument with its source** (table below).
6. **Write `expect` sentences** from the checker vocabulary (below). Every procedure's `expect` names the page kind it lands on.
7. `leash playbook check ./DIR` until clean; install by copying the directory; `leash playbook check <site>` (adds JS syntax).
8. `leash playbook test <site>/<script> --tab TAB` on a real page of each kind the script is for. Compare the count with what you see. An empty list is a valid result (an empty cart); throw when the page is the wrong one.
9. A `--dry-run` mission: shows which book and first procedure are chosen, with their probabilities. It spends model calls, acts on nothing, does not open `--url`, and always reads `status: blocked`. It cannot catch a control that is on another page.
10. A live mission with `--out`; then read the trace: `procedures[].slug` and `outcome`, each drive's `steps[].operation` and `probabilities.op`, `data.scripts`, `collected`, `mission_expectations`. Scrolls alternating with BLOCKED near 0.5, ending "no available action toward the goal", means the control is not on this page or the goal does not name it. Fix the playbook before blaming the model.

## Rules

`playbook check` refuses the first five; the last two are yours to keep.

- Every procedure has a goal step of its own, unless another procedure `use:`s it. A procedure made only of `use:` or `script` steps is refused when nothing uses it; start it with a goal.
- A script declares `description`, `returns` (in a leading `/** returns: ... */` comment, `scripts/<name>.returns.json`, or a name from `shapes`), and every `args.<x>` it reads.
- `pages`: absent = offered on every page of the site; a list = offered on those kinds; `[]` = never offered (a control script for `repeat.until`).
- Every procedure has a nonempty `expect`; page kinds named anywhere must exist.
- Old forms are refused, not converted: top-level `returns`, inline `returns` on a declaration, `args` as a list of names.
- A procedure's `expect` names the page kind it lands on.
- Payment, messaging, deletion and other non-idempotent submissions never sit inside a `repeat` or a procedure whose failure could replay it (a failed procedure is replayed once). A milder repeatable action (add to cart bumps the quantity) sits in its own procedure whose `expect` sees it succeed ("the page shows Added"), so a replay happens only when it did not take.

## Composing a task

One procedure per stage (`search-product`, `open-product`, `add-to-cart`, `view-cart`), each starting with a goal. The run chooses one procedure at a time, verifies it, and asks again until JEV answers DONE; every procedure except a `repeat.next` helper stays a choice. JEV chooses on `description`, so say when it applies: "From a product page: add it to the cart." A whole-task procedure (a goal, then `use:` each stage) works too, and wins the choice only if its description says it is the whole task.

## Arguments and the mission sentence

| Declaration | Filled from |
| --- | --- |
| `{"from":"mission"}` | The text helper reads the mission sentence: "collect every book in Mystery" fills `{category}` with `Mystery`. Missing → the run is `blocked` naming the argument. |
| `{"from":"mission","optional":true}` | The same, and absence is fine. |
| `{"const": 60}` | Always this value. |

Name arguments as the user would say them (`category`, `product`, `query`), so the helper finds them. A value found once is reused by later procedures and scripts.

## Checker vocabulary

| Sentence | Checked by code against |
| --- | --- |
| `the page is category` / `the page is not cart` | the page kind of the current URL and text |
| `the page shows Your cart is empty` | the page text (case-insensitive substring) |
| `a file was downloaded` / `a pdf was downloaded` | a completed download |
| `no dialog is open` | a JS `alert`/`confirm`/`prompt` only; an HTML modal is page text and rows |
| `a button named Checkout is present` | a snapshot row with that role and name |
| `the address changed` | only in a goal's `until`: the URL differs from the step's start |

A `url_pattern` matches the whole URL; `*` matches any characters, including `?` and `#` (`https://site/products*` covers `/products?search=x`). Without `*` it is an exact match. Any other sentence is a judgment: JEV scores it against the page, which is slower and can be wrong. `{name}` placeholders are substituted first (`the page shows {product}`).

## Goals that are relative: `until`

"Open the next page", "open another result": once reached, the new page looks like the old one and JEV cannot tell whether it is done. Give such a goal an `until` list of code sentences; the step ends `done` after the first action that makes them all hold. `until` is checked only after an action, never before the first one:

```json
{"goal": "Open the next page of this category.", "until": ["the address changed", "the page is category"]}
```

## Worked example: books.toscrape.com

Mission: "collect every book title and price in the Mystery category". The complete playbook follows; the two scripts are below it.

```json
{
  "site": "books.toscrape.com",
  "entry": "https://books.toscrape.com/",
  "description": "A bookshop catalogue with categories, book titles, prices, ratings, and availability.",
  "pages": [
    {"name": "home", "description": "The shop front page with the category list", "url_pattern": "https://books.toscrape.com/", "text_marker": null},
    {"name": "category", "description": "A category listing", "url_pattern": "https://books.toscrape.com/catalogue/category/*", "text_marker": null}
  ],
  "shapes": {
    "book": [{"title": "string", "price": "number", "url": "url", "category": "string", "rating": "number", "availability": "string"}],
    "pager": {"done": "boolean"}
  },
  "scripts": {
    "list-page": {"file": "scripts/list-page.js", "description": "Collect every book card on this category page as records.", "pages": ["category"]},
    "last-page": {"file": "scripts/last-page.js", "description": "Report whether this category listing has no next page.", "pages": []}
  },
  "procedures": [
    {"slug": "open-category", "description": "Open a category listing and collect its books.",
     "args": {"category": {"from": "mission"}},
     "steps": [{"goal": "Open the {category} category."}, {"use": "collect-page"}],
     "expect": ["the page is category"],
     "repeat": {"next": "next-page", "max": 60, "until": {"script": "last-page"}, "delay_ms": 200, "key": "url"}},
    {"slug": "collect-page", "description": "Collect the books listed on this category page.",
     "steps": [{"script": "list-page"}], "expect": ["the page is category"]},
    {"slug": "next-page", "description": "Open the next page of this category and collect its books.",
     "steps": [{"goal": "Open the next page of this category.", "until": ["the address changed", "the page is category"]}, {"use": "collect-page"}],
     "expect": ["the page is category"]},
    {"slug": "read-page", "description": "Collect the books shown on the current category page.",
     "steps": [{"goal": "Collect the books on this category page."}], "expect": ["the page is category"]}
  ]
}
```

`scripts/list-page.js` (`last-page.js` is the same pattern returning `{done: document.querySelector(".pager .next a") === null}`):

```js
/** returns: "book" */
const words = {One: 1, Two: 2, Three: 3, Four: 4, Five: 5};
const category = document.querySelector('.page-header h1')?.textContent.trim();
const cards = [...document.querySelectorAll('article.product_pod')];
if (!category || cards.length === 0) throw new Error('not a category listing page: ' + location.href);
return cards.map(card => ({
  title: card.querySelector('h3 a').getAttribute('title'),
  price: Number(card.querySelector('.price_color').textContent.replace(/[^0-9.]/g, '')),
  url: card.querySelector('h3 a').href,
  category,
  rating: words[[...card.querySelector('.star-rating').classList].find(c => c in words)],
  availability: card.querySelector('.availability').textContent.trim(),
}));
```

Why each choice:

- Two page kinds, by URL: the procedures start on `home` and land on `category`; nothing else matters.
- `open-category` is a goal: finding "Mystery" in a sidebar is what JEV does well. Its argument comes from the mission.
- `collect-page` is the one script: reading 20 cards by clicking is impossible; reading them in code is exact. It throws on the wrong page rather than returning nothing.
- `next-page` is a goal with `until`, not a URL computed by a script: JEV clicks "next" like a person, and code decides when it got there.
- `repeat` loops `next-page` until `last-page` says done; `key: "url"` drops a book seen twice. `last-page` has `pages: []`: it is a control, not a tool for JEV.
- `read-page` has no pinned script: on "collect the books on this page" JEV chooses `run_script:list-page` itself.
- Measured (2026-09-30): Mystery 32/32 in 11 model calls, $0.0016; Default (8 pages) 152/152 in 35 calls, $0.007.

## Test it

```sh
leash playbook check ./books.toscrape.com
cp -r ./books.toscrape.com ~/.config/leash/playbooks/
leash playbook check books.toscrape.com
TAB=$(leash new https://books.toscrape.com/catalogue/category/books/mystery_3/index.html | jq -er .tab)
leash playbook test books.toscrape.com/list-page --tab "$TAB"    # expect 20 records
leash drive 'collect every book title and price in the Mystery category' --dry-run
leash drive 'collect every book title and price in the Mystery category' --out /tmp/mystery.jsonl
```

Then check `collected` against the site, `status` = `done`, and each procedure `verified`.
