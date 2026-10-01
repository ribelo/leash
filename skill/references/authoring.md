# Authoring a playbook

Write one when a site will be driven again, or when a mission needs validated records rather than the operator's bounded page state. `leash discover` can propose a playbook; that is propose-and-accept, not this procedure. A model never writes the playbook. You do.

The format, the worked example, and every loader refusal are in `leash help playbooks`. Checker sentences are in `leash help expectations`. Scripts are in `leash help scripts`.

## The procedure, in order

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

## Rules the loader does not keep for you

`playbook check` refuses a playbook that breaks the format. These two are yours:

- A procedure's `expect` names the page kind it lands on.
- Payment, messaging, deletion, and other non-idempotent submissions never sit inside a `repeat` or a procedure whose failure could replay it. A failed procedure is replayed once. A milder repeatable action (add to cart bumps the quantity) sits in its own procedure whose `expect` sees it succeed, so a replay happens only when it did not take.

## Composing a task

One procedure per stage (`search-product`, `open-product`, `add-to-cart`), each starting with a goal. The run chooses one procedure at a time, verifies it, and asks again until JEV answers DONE. Every procedure except a `repeat.next` helper stays a choice. JEV chooses on `description`, so say when it applies: "From a product page: add it to the cart." A whole-task procedure (a goal, then `use:` each stage) works too, and wins the choice only if its description says it is the whole task.

## Goals that are relative

"Open the next page" lands on a page that looks like the old one. Give that goal an `until` list of code sentences. The step ends done after the first action that makes them all hold. `until` is checked only after an action:

```json
{"goal": "Open the next page of this category.", "until": ["the address changed", "the page is category"]}
```

## Test it

```sh
leash playbook check ./books.toscrape.com
leash playbook check books.toscrape.com
leash playbook test books.toscrape.com/list-page --tab TAB
leash drive 'collect every book title and price in the Mystery category' --dry-run
leash drive 'collect every book title and price in the Mystery category' --out /tmp/mystery.jsonl
```

Then check `collected` against the site, `status` is `done`, and each procedure is `verified`.
