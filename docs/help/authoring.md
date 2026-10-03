# Authoring a playbook

Write one when a site will be driven again, or when a mission needs validated records rather than the operator's bounded page state. Prefer `leash drive` for goals: successful traces can produce learning drafts. The learning compiler may generate read-only collection scripts from observed final-page tag/class structure for repeatable drafts; declared returns and successful replay are required. This topic covers explicit manual authoring, not that learning path.

The format, the worked example, and every loader refusal are in `leash help playbooks`. Checker sentences are in `leash help expectations`. Scripts are in `leash help scripts`.

## The procedure, in order

1. Study the site on the pages the task touches: `leash new URL`, `leash snap TAB --limit 60`, `leash text TAB`, `leash net TAB`. Note the URLs, which page each control lives on, where lists and pagers are, and what loads late. `snap` lists only rows in the viewport, and `--match` does too: `leash scroll TAB down` and snap again. `text` is the rendered text (CSS text-transform applies), and `wait --text` is case-sensitive against it. A control with an empty name can be inspected with `eval --index N --snapshot S`. In a goal, name it by what is next to it.
2. Name the page kinds. One kind per page type the procedures start on or land on (`home`, `category`, `product`, `cart`). Prefer a `url_pattern` with `*`. Use `text_marker` only when the URL does not tell (a modal, a single-page app).
3. Write each procedure's goal steps as a person would say them. One intention per goal. Put the site's words in the goal when they are the control's label. A goal runs on whatever page the tab is on, so if its control lives elsewhere, put a navigation goal first. The procedure expect verifies the landing page; a step does not carry until.
4. Add a script only where bulk reading or a file is needed. Usually navigation, search, forms, and pagination are goals. Do not write a navigate step. Do not use a script to bypass a consent decision, login, or access control. Declare `description`, `pages`, and `returns`.
5. Declare every argument with its source. See `leash help scripts`.
6. Write `expect` sentences from the checker vocabulary. Every procedure's `expect` names the page kind it lands on.
7. `leash playbook check ./DIR` until clean. Install by copying the directory into `$XDG_CONFIG_HOME/leash/playbooks/` (usually `~/.config/leash/playbooks/` when that variable is unset). Then `leash playbook check SITE`, which also compiles the scripts.
8. `leash playbook test SITE/SCRIPT --tab TAB` on a real page of each kind the script is for. Compare the count and representative field values with what you see: product identity, price, currency, quantity, and resolved URLs. A type-correct record can still describe the wrong item.
9. A `--dry-run` mission shows which book and first procedure are chosen, with their probabilities. It spends model calls, acts on nothing, does not open `--url`, and always reads `status: blocked`. It cannot catch a control that is on another page.
10. A live mission with `--out`. Then read the trace: `procedures[].slug` and `outcome`, each drive's `steps[].operation` and `probabilities.op`, `data.scripts`, `collected`, `mission_expectations`. Scrolls alternating with BLOCKED near 0.5, ending "no available action toward the goal", means the control is not on this page or the goal does not name it. Fix the playbook before blaming the model.

## Rules the loader does not keep for you

`playbook check` refuses a playbook that breaks the format. These two are yours:

- A procedure's `expect` names the page kind it lands on.
- Payment, messaging, deletion, and other non-idempotent submissions never sit inside a `repeat` or a procedure whose failure could replay it. A failed procedure is replayed once. A milder repeatable action (add to cart bumps the quantity) also needs within-goal protection: say "Add this product exactly once, then stop; do not click again while waiting" in both goal and hint, and put the visible success in the procedure expect. Keep it in its own verified procedure. Neither these words nor a checker is a transaction guarantee: inspect the resulting quantity, and never replay an ambiguous submission without checking whether it took.

## Composing a task

One procedure per stage (`search-product`, `open-product`, `add-to-cart`), each containing a goal. The run chooses one procedure at a time, verifies it, and asks again until JEV answers DONE. A standalone, unreferenced procedure must contain at least one goal even if it has navigate steps; a goal-free helper is allowed only when another procedure names it in `use` or `repeat.next`. The minimal playbook below navigates directly, then has a goal that observes the cart without submitting anything. `until` still runs only after an action: this confirmation goal is not a skip-if-already-true guard. Every procedure except a `repeat.next` helper stays a choice. JEV chooses on `description`, so say when it applies: "From a product page: add it to the cart." A whole-task procedure (a goal, then `use:` each stage) works too, and wins the choice only if its description says it is the whole task.

## Minimal navigation

Here is a minimal complete `playbook.json`. Replace the illustrative origin and recogniser with ones you observed. Navigation is a goal. The procedure `expect` verifies the landing page.

```json
{
  "site": "shop.example",
  "entry": "https://shop.example/",
  "description": "Open and observe the cart.",
  "pages": [{"name": "cart", "url_pattern": "https://shop.example/cart*"}],
  "procedures": [{
    "slug": "view-cart", "description": "Open the cart and confirm its contents are visible.",
    "steps": [
      {"goal": "Open the cart page.", "hint": "Cart"},
      {"goal": "Confirm the cart is open; do not submit anything.", "hint": "Observe and stop; no add or checkout action."}
    ],
    "expect": ["the page is cart"]
  }]
}
```

## Goals that are relative

"Open the next page" lands on a page that looks like the old one. Say that in the goal, and put the landing check in the procedure `expect`. A step does not carry `until`. `hint` adds guidance to the goal JEV sees; it is not a deterministic command.

```json
{"goal": "Open the next page of this category.", "hint": "Next"}
```

## Test it

```sh
leash playbook check ./books.toscrape.com
leash playbook check books.toscrape.com
leash playbook test books.toscrape.com/list-page --tab TAB
leash drive 'collect every book title and price in the Mystery category' --dry-run
leash drive 'collect every book title and price in the Mystery category' --out /tmp/mystery.jsonl
```

Then check `collected` against the site, sampled field values against their items, `status` is `done`, and each completed procedure is `verified`. Check non-idempotent effects such as cart quantities separately.
