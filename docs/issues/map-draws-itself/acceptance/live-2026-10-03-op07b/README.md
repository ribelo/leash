# map-op07 live acceptance, 2026-10-03 (op07b)

Clean master `8e5e92d379c6a785788c030e5a82a92d1e2cd674`. One capped build. Binary sha256 `e5c23867dcf38e8225e3a7b08e14fdb16ab1f3be395db302245dd76f5e8f40eb`. Parked harness reused unchanged. No product edits, no commit.

Criterion, all three sites: **fail**. A fresh agent with only an installed playbook did not complete a fifth changed-argument mission, verified from the page, at lower inclusive cost than mission 1.

| Site | Installed | M5 verified | M5 cheaper than M1 | Result |
|---|---|---|---|---|
| Books | yes, navigation only | no, 5/17 Horror titles | no, $0.001573 > $0.000936 | fail |
| Flights | no | no | no, $0.040956 > $0.005254 | fail |
| Maps | no | page supports the answer; harness verifier does not | yes, $0.018041 < $0.035875 | fail |

Costs are inclusive USD (browser plus learning that finished before the next mission). Per-site files are under this directory. `result.json` `passed: true` is the old harness failure list, which this adaptation does not fill. Use `summary.json`.

## Books

Missions: Travel, Mystery, Poetry, Historical Fiction, then fresh Horror with learning off.

Inclusive cost: 0.000936, 0.014605, 0.025544, 0.033172, 0.001573.

Statuses: done, limit, done, done, done. None independently complete. Travel matched 7/11, Mystery 4/32, Poetry 8/19, Historical Fiction 6/26, Horror 5/17. Every done collection trace has `structural_outline` absent. No script was compiled or installed.

What did install, by the replay gate, is only `open-book-category`. Mission 4 selected `draft:open-book-category`, both expectations passed, and the procedure was installed after the reply. The collection draft was selected on the same mission, failed the judgment "all book titles and prices in the category are collected" (score 0.19), and was not installed. A later compile was dropped: `name page kind page-<id> from its observed title and labels in kinds, not its URL shape`.

Mission 5 used the installed procedure, opened Horror, then the operator said done on the first viewport. The screenshot shows It, 'Salem's Lot, The Stand, The Girl with All ..., and House of Leaves. The independent category read has 17 records.

Final installed playbook, no scripts: [books/installed-playbooks.json](books/installed-playbooks.json).

## Flights

Missions: Warsaw→Lisbon, Kraków→Barcelona, Gdańsk→Rome, Wrocław→Paris, then fresh Poznań→Amsterdam.

Inclusive cost: 0.005254, 0.043410, 0.028847, 0.001432, 0.040956.

M1–M3 ended done on real November search pages (Warsaw–Lisbon 25–29 Nov from PLN 804; Kraków–Barcelona 24–25 Nov from PLN 248; Gdańsk–Rome 25–30 Nov from PLN 284). The drive reply has no answer string. A results page with a Cheapest tab does not prove the cheapest fare for the whole month. The harness verifier is a stub that always returns unverified; this review is from the saved page text.

Two compiles ran and both were dropped, so nothing was installed:

- `name page kind flights from its observed title and labels in kinds, not its URL shape`
- `procedure find-cheapest-flight: goal until must not be empty`

M4 is the same covered date field as the previous run: `type_text` on Departure, row-not-actionable, outcome uncertain, not replayed. The screenshot shows the October/November date picker open over the form. No hit-test node was recorded, so the covering element is not identified. Consent was Reject all on M1 and M5, not Accept all.

M5 reached Poznań to Amsterdam for 1–4 November 2026. The page says the cheapest price shown is 751 PLN on Sun, Nov 1. No answer was returned. Cost was about eight times mission 1, with no playbook.

## Maps

Missions: Eiffel Tower, Colosseum, Brandenburg Gate, Sagrada Família, then fresh Tower of London.

Inclusive cost: 0.035875, 0.022699, unreported, 0.032612, 0.018041. Mission 3's text-helper error did not carry a top-level cost.

No training mission ended done, so nothing was compiled or installed. M5 was another on-the-fly run.

- M1 error: invalid TypeSafe response after 42 Rating clicks, 29 of them on an unchanged URL. The no-progress mask did not keep that action out.
- M2 limit: 60 actions, still on a cafe search.
- M3 error: text helper returned null content while the page was ama Café, Dorotheenstraße 83, about 492 m from Brandenburg Gate. The mission did not finish done.
- M4 blocked: planner done evidence failed the live checker, then the planner turn cap. Operator reason: no available action; canvas and nested scroll.
- M5 done. Answer: WatchHouse Tower Bridge — 37 Shad Thames, rated 4.6, near the Tower of London. The results list shows that name, 4.6, Coffee shop, and 37 Shad Thames in a search anchored on the Tower. The harness verifier missed it because the first heading is Results and there is no address element. Reviewer verdict: the page supports the answer. That does not satisfy the criterion, because there was no installed playbook.

Consent was Reject all on M1 and M5.

## What changed since the last run, and what still fails

Structural agreement now compiles. Books installed a parameterized category click from two done traces whose labels differed. Flights also reached the compiler. Last time nothing agreed, so nothing was compiled.

The replay gate held: the collection draft that did not collect was not installed. The naming validator then dropped the next books compile and both flights compiles. A draft that keeps the inferred name `flights` or `page-<id>` is rejected, and a flight procedure with an empty `until` is rejected. Nothing from those compiles was installed.

No compiler-written script appeared. Collection traces did not retain a structural outline, and the capture path records no error when that read fails. Without an outline the compiler wrote scroll-and-collect goals. Those cannot return every title and price, and the operator can still say done on the first viewport.

Planner done-with-evidence ended the Tower of London mission with a page-supported answer, and it refused Sagrada Família and Eiffel Tower evidence that did not pass. It did not create a done training trace, so it did not feed learning.

Accept-all was not chosen when Reject all was present.

The action mask did not stop repeated Rating clicks on an unchanged Maps URL.

## Isolation

Private headless Chrome only, temp XDG. User `leash.service` pid 3662 and its Chrome pid 3730 kept their 11:54:12 start times. `~/.config/leash` mtime unchanged. Exact-key scan of 272 evidence files: 0 occurrences. Handles and temp paths: 0. Private processes after cleanup: 0.
