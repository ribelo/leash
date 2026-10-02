# kind-ir9l measurement — 2026-10-01

L30's state measurement (run story 18, README row L30) repeated on a site **without a playbook**: quotes.toscrape.com. Score: **inferred page kind 5/5, raw URL + title 5/5** (identical choices; tokens 3,511/381 vs 3,506/381; cost $0.000147462 vs $0.000147252). The inferred kind neither helped nor hurt on this site. A supplementary run without procedure history (below) also tied, 2/5 vs 2/5.

## Method

- **States.** Five real pages opened through a private headless Leash (L51 instance, commit b2e1b91); URL, title and the `snap` page kind recorded live:

| State | URL | Title | Inferred kind (`snap` and `Page_kind` session agree) |
| --- | --- | --- | --- |
| home | https://quotes.toscrape.com/ | Quotes to Scrape | `home` |
| page2 | https://quotes.toscrape.com/page/2/ | Quotes to Scrape | `page-<id>` |
| tag | https://quotes.toscrape.com/tag/love/ | Quotes to Scrape | `love` |
| author | https://quotes.toscrape.com/author/Albert-Einstein/ | Quotes to Scrape | `author-<slug>` |
| login | https://quotes.toscrape.com/login | Quotes to Scrape | `login` |

  Every page has the same title, so in the raw shape only the URL distinguishes them.
- **Candidates** (one sentence each), plus the production `DONE` and `NONE`: open-author "Open the author page of a quote shown on the current page."; open-tag "Open the list of quotes for a tag the mission names."; next-page "Open the next page of the current list of quotes."; open-login "Open the site's login page."; read-quotes "Read the quotes or the author details shown on the current page and report them."
- **Mission** (one for all states, as L30): "On quotes.toscrape.com, read the quotes on the second page of the main list, then open the quotes tagged love, open the author page of the first of them and report the author's birth date, and finally open the login page and stop there." Each state carries the `recent_procedures` of that workflow (all `verified`): home none; page2 next-page; tag +read-quotes, open-tag; author +open-author; login +read-quotes, open-login.
- **Correct answers, fixed in `states.json` before any call:** home → next-page, page2 → read-quotes, tag → open-author, author → read-quotes, login → DONE.
- **Production question.** `.scratch/research/kind-ir9l/measure.ml` runs the real `Leash.Run.loop` with a stub handler and a candidate playbook (no declared pages) and captures the `select_procedure` question it builds (`Questions.select_procedure`, the run's `state_json`, criteria procedures + DONE + NONE). It then asks it through the production `Leash.Models.choose` (System One, `typesafe/jev-1.13-20260917`) twice per state, with `site: null` and the fixture's history:
  - **inferred** — the production no-playbook state: `page_kind` = inferred kind and `url` = the same kind (Run.semantic substitutes the kind for the URL when there is no book); title kept.
  - **raw** — `page_kind` removed, `url` = the raw URL; title kept.
  The no-playbook run loop never asks `select_procedure` itself (no book, no procedures), so this is the question it would ask once a procedure set exists for the site — which is what the measurement is for.
- One call per state per shape, 10 calls, all answered. Probabilities are the model-reported distribution, not frequencies.

## Results (scored)

Columns oa/ot/np/ol/rq = open-author/open-tag/next-page/open-login/read-quotes.

| State | Shape | Correct | Chosen | p(chosen) | p(correct) | conf | oa | ot | np | ol | rq | DONE | NONE | in/out tokens | Cost USD |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| home | inferred | next-page | next-page | 1.00 | 1.00 | 1.00 | 0.00 | 0.00 | 1.00 | 0.00 | 0.00 | 0.00 | 0.00 | 643/76 | $0.000027006 |
| home | raw | next-page | next-page | 1.00 | 1.00 | 0.99 | 0.00 | 0.00 | 1.00 | 0.00 | 0.00 | 0.00 | 0.00 | 642/76 | $0.000026964 |
| page2 | inferred | read-quotes | read-quotes | 0.57 | 0.57 | 0.49 | 0.00 | 0.43 | 0.00 | 0.00 | 0.57 | 0.00 | 0.00 | 670/77 | $0.000028140 |
| page2 | raw | read-quotes | read-quotes | 0.60 | 0.60 | 0.53 | 0.00 | 0.40 | 0.00 | 0.00 | 0.60 | 0.00 | 0.00 | 664/77 | $0.000027888 |
| tag | inferred | open-author | open-author | 0.79 | 0.79 | 0.75 | 0.79 | 0.00 | 0.00 | 0.00 | 0.21 | 0.00 | 0.00 | 703/76 | $0.000029526 |
| tag | raw | open-author | open-author | 0.91 | 0.91 | 0.89 | 0.91 | 0.00 | 0.00 | 0.00 | 0.09 | 0.00 | 0.00 | 705/76 | $0.000029610 |
| author | inferred | read-quotes | read-quotes | 0.81 | 0.81 | 0.78 | 0.01 | 0.00 | 0.00 | 0.16 | 0.81 | 0.00 | 0.02 | 731/77 | $0.000030702 |
| author | raw | read-quotes | read-quotes | 0.83 | 0.83 | 0.79 | 0.00 | 0.00 | 0.00 | 0.15 | 0.83 | 0.00 | 0.02 | 732/77 | $0.000030744 |
| login | inferred | DONE | DONE | 0.79 | 0.79 | 0.75 | 0.00 | 0.00 | 0.00 | 0.00 | 0.18 | 0.79 | 0.03 | 764/75 | $0.000032088 |
| login | raw | DONE | DONE | 0.58 | 0.58 | 0.51 | 0.01 | 0.00 | 0.00 | 0.00 | 0.38 | 0.58 | 0.03 | 763/75 | $0.000032046 |

| Shape | Correct | in/out tokens | Cost USD |
| --- | ---: | ---: | ---: |
| inferred kind (no URL) | **5/5** | 3,511/381 | $0.000147462 |
| raw URL + title | **5/5** | 3,506/381 | $0.000147252 |

Margins: inferred is more confident at login (DONE 0.79 vs 0.58), raw at tag (0.91 vs 0.79); elsewhere within 0.03. With the workflow's history in the state, the history decides almost every choice; this site does not separate the two shapes. L30's 4/5 vs 2/5 compared kind+history against URL **without** history, so the two results are not in conflict: the history, not the kind, carried most of L30's gain.

## Supplementary: no history (not the scored repetition)

Same states, same candidates, `recent_procedures: []`, mission "Report the birth date of the author of the first quote tagged love." Correct answers fixed before the calls: home → open-tag, page2 → open-tag, tag → open-author, author → read-quotes, login → open-tag (author is debatable without history: nothing in the state says it is the right author). Results file `results-no-history.json`.

| State | Shape | Correct | Chosen | p(chosen) | p(correct) | in/out | Cost USD |
|---|---|---|---|---|---|---|---|
| home | inferred | open-tag | open-tag | 0.88 | 0.88 | 603/76 | $0.000025326 |
| home | raw | open-tag | open-tag | 0.91 | 0.91 | 602/76 | $0.000025284 |
| page2 | inferred | open-tag | open-tag | 0.87 | 0.87 | 611/76 | $0.000025662 |
| page2 | raw | open-tag | open-tag | 0.75 | 0.75 | 605/76 | $0.000025410 |
| tag | inferred | open-author | read-quotes ✗ | 0.53 | 0.05 (open-tag 0.39) | 603/77 | $0.000025326 |
| tag | raw | open-author | read-quotes ✗ | 0.79 | 0.16 | 605/77 | $0.000025410 |
| author | inferred | read-quotes | open-tag ✗ | 0.81 | 0.14 | 611/76 | $0.000025662 |
| author | raw | read-quotes | open-tag ✗ | 0.81 | 0.17 | 612/76 | $0.000025704 |
| login | inferred | open-tag | open-login ✗ | 0.76 | 0.19 | 603/76 | $0.000025326 |
| login | raw | open-tag | open-login ✗ | 0.52 | 0.40 | 602/76 | $0.000025284 |

Inferred 2/5 (3,031/381, $0.000127302), raw 2/5 (3,026/381, $0.000127092). On the tag page the inferred kind `love` does not say "tag": JEV still gives open-tag 0.39, against 0.05 with `/tag/love/`. On the login page both shapes choose open-login although the page is already the login page.

Total for both runs: 20 calls, $0.000549108.

## Defects and observations (not fixed)

1. **Tag pages are not one kind.** `/tag/love/` → `love`, `/tag/humor/` → `humor` (checked live with `leash new`): the last static segment wins, so every tag is its own page kind, and a compiled playbook would get one page per tag. The name drops the `tag` segment that carries the meaning; `tag-<slug>` is what kind-a7uy's examples imply. This follows the implementation rule (short single-word segments are static), so it is a rule gap rather than a code slip.
2. **The no-playbook state duplicates the kind**: `page_kind` and `url` both carry it (`"page_kind": "love", "url": "love"`). Harmless to JEV here, but there is no "no URL" shape; the URL slot holds the kind.
3. In `leash list`, a human `chrome://newtab/` tab shows `page_kind: home (inferred)`.
4. The no-playbook run loop never asks `select_procedure` (there are no procedures), so kind-ir9l's substitution reaches JEV only through `select_playbook` and the operator state until the compiler produces procedures.

## Files

- `.scratch/research/kind-ir9l/measure.ml` (+ `dune`, `dune-project`): the executable; built with `OCAMLPATH=_build_live52/install/default/lib`, run as `secret-env ai -- ./_build_live52/default/measure.exe [fixtures.json]` from that directory.
- `.scratch/research/kind-ir9l/states.json`, `no-history.json`: fixtures with the pre-decided answers.
- `.scratch/research/kind-ir9l/results.json`, `results-no-history.json`: every call's full state sent, criteria, chosen key, all probabilities, confidence, usage.
- `.scratch/research/kind-ir9l/l51-evidence/live-states.json`: the live `snap` capture.
