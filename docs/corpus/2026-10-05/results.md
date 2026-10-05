# Corpus run 2026-10-05

**Invalid: load and defects.** This run cannot answer the questions it was built for (notes? procedures? instruction detail?). 223 cells ended on a Leash defect (handoff offered on a headless browser, revert-r9ka), 70 on timeouts from about 60-way parallelism, Clef cells on HTTP 529, and upload was 0/63 by construction (revert-31w3). The variant differences are inside that noise. Draw no conclusions from it; the numbers below are kept only as a record.

## Conclusions (withdrawn)

The loop is now JEV's (ADR-0015, L62): the decision model decides every step, and the planner (`openai/gpt-6-luna`) is only consulted. All cells ran on one build (e6920a1). The run covers 20 public missions × 3 styles × {none, notes, procedures} × {jev, clef, clef-flash} × {image off, B, C} (JEV off only), 1,260 cells, plus U1/U2 on the operator's Tauron account (18 cells, JEV). Earlier results, measured on the pilot loop, are discarded. Paired cells differ in that factor only.

1. **JEV now does the work, and passes 38%.** 481 of 1,260 public cells passed. The decision model ran in 957 of 1,269 cells (it was 12% on the pilot loop). A cell averages 11.8 navigator steps, 1.5 planner consultations, $0.0034 and 50 s; the whole run cost $4.25. Pure navigation and reading pass well: books-price 61/63, wiki 55/63 each, maps postcode 53/63, poetry count 52/63, blue-top price 50/63, jeans search 49/63.
2. **Model: keep JEV.** Images off, JEV passed 73/180, Clef 69/180 and Clef Flash 64/180, at $0.0038, $0.0055 and $0.0035 per cell.
3. **Images: B helps a little, LOOK not at all.** Mode B passed 73/180 (Clef) and 69/180 (Flash) against 69 and 64 with images off; mode C (LOOK) passed 69 and 64, the same as off. Defaults stay: B at 3 rows, LOOK off. A screenshot was sent in 63 cells.
4. **Style and knowledge: numbered steps and notes.** Steps passed 174/423, goal 162/423, loose 146/423. Notes passed 169/423, no playbook 151/423, procedures 162/423 at 1.4× the cost and 68 s against 42 s.
5. **The failures are mostly Leash defects, filed.**
   - The planner chooses handoff on a headless browser: 223 public cells and 13 of 18 Tauron cells ended `headless` (revert-r9ka). The fixture portal and registration missions (0/63 each) end this way or wait for a password.
   - JEV's loop has no upload operation: u9 passed 0/63 (revert-31w3).
   - A collection script that JEV runs again writes the same records again (pilot-1gv0): the books JSONL missions passed 2/126; 40 cells wrote every record 2 to 20 times, and 84 wrote none (without procedures nothing writes records).
   - Load: 70 cells ended `model-timeout`, and many `error` cells were text-helper timeouts or Clef HTTP 529 under about 60 parallel drives (revert-8eqf).
   - Found and fixed during the run: Clef refuses a one-option choice (revert-v1hm) and more than 10 score bands (revert-ook4); `--secret` names were not resolved in JEV's loop (revert-k63o).
   - Not Leash: flights (1/126) is weakly checked against Google's overview price; the canvas (11/63) needs a picture, which JEV, text-only, does not get.

**U1/U2 (operator's account, JEV):** U1 passed 1/9 (goal, notes: the three amounts on the page). U2 passed 1/9 (goal, notes: the latest invoice, E/TM2/UG533989/0003/26, downloaded twice, revert-3scf). The other 16 cells ended `headless` (13), `blocked` (1), `model-timeout` (1) or `error` (1).

## Summary

| factor | level | cells | passed | pass rate | mean cost $ | mean planner calls |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| model | clef | 540 | 211 | 39% | 0.00533 | 1.2 |
| model | clef-flash | 540 | 197 | 36% | 0.00379 | 1.7 |
| model | jev | 198 | 75 | 38% | 0.00370 | 1.7 |
| image | b | 360 | 142 | 39% | 0.00437 | 1.4 |
| image | c | 360 | 133 | 37% | 0.00481 | 1.5 |
| image | off | 558 | 208 | 37% | 0.00418 | 1.5 |
| style | goal | 426 | 163 | 38% | 0.00440 | 1.5 |
| style | loose | 426 | 146 | 34% | 0.00441 | 1.5 |
| style | steps | 426 | 174 | 41% | 0.00439 | 1.5 |
| knowledge | none | 426 | 151 | 35% | 0.00376 | 1.3 |
| knowledge | notes | 426 | 170 | 40% | 0.00431 | 1.4 |
| knowledge | procedures | 426 | 162 | 38% | 0.00522 | 1.8 |

## Cells

| mission | style | knowledge | model | image | pass | status | planner calls | navigator steps | calls | cost $ | wall s | image parts | truncated | note |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| ae-blue-top-price | goal | none | clef | b | yes | done | 1 | 1 | 2 | 0.001074 | 25 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | none | clef | b | yes | done | 1 | 1 | 2 | 0.001007 | 25 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | none | clef | b | no | blocked | 1 | 8 | 9 | 0.004355 | 57.4 | 7 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | steps | none | clef | b | yes | done | 1 | 2 | 5 | 0.003075 | 22.5 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | goal | none | clef | b | no | error | 0 | 3 | 11 | - | 51.6 | 0 | yes | result lacks 'Blue Top' |
| ae-polo-brand | loose | none | clef | b | no | failed | 1 | 1 | 5 | 0.004027 | 58.7 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | goal | none | clef | b | no | error | 0 | 0 | 3 | 0.000533 | 13.1 | 0 | no | result lacks 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | clef | b | no | error | 0 | 2 | 3 | - | 10.5 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-search-jeans | steps | none | clef | b | yes | done | 1 | 3 | 6 | 0.002331 | 23.7 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | loose | none | clef | b | yes | done | 1 | 3 | 9 | 0.003808 | 27.5 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-poetry-count | loose | none | clef | b | yes | done | 1 | 2 | 3 | 0.001928 | 9.2 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | none | clef | b | yes | done | 1 | 5 | 8 | 0.005967 | 18.1 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | none | clef | b | yes | done | 1 | 2 | 3 | 0.001926 | 8.3 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | none | clef | b | yes | done | 1 | 5 | 8 | 0.006039 | 20.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | steps | none | clef | b | yes | done | 1 | 2 | 3 | 0.001963 | 7.5 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | none | clef | b | no | done | 0 | 5 | 6 | 0.00461 | 13.7 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | none | clef | b | yes | done | 1 | 1 | 2 | 0.001142 | 6.7 | 0 | no | result names '£51.77' |
| books-price | goal | none | clef | b | yes | done | 1 | 1 | 2 | 0.00114 | 6.9 | 0 | no | result names '£51.77' |
| books-price | steps | none | clef | b | yes | done | 1 | 2 | 3 | 0.001376 | 8.7 | 0 | no | result names '£51.77' |
| books-stock | loose | none | clef | b | no | failed | 1 | 1 | 2 | 0.001258 | 9.4 | 0 | no | truth '20'; result differs |
| books-poetry-jsonl | steps | none | clef | b | no | done | 1 | 4 | 6 | 0.006425 | 54.9 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | steps | none | clef | b | yes | done | 1 | 2 | 3 | 0.001455 | 7.8 | 0 | no | truth '20'; result agrees |
| books-stock | goal | none | clef | b | no | failed | 1 | 1 | 3 | 0.001982 | 24.3 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | none | clef | b | yes | done | 0 | 2 | 2 | 0.001086 | 3.6 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | goal | none | clef | b | no | error:model-timeout | 1 | 5 | 7 | - | 75.6 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| canvas-launch | goal | none | clef | b | yes | failed | 1 | 2 | 3 | 0.001274 | 8.3 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | clef | b | yes | failed | 1 | 2 | 3 | 0.001334 | 8.3 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | steps | none | clef | b | no | error | 0 | 8 | 13 | - | 33.8 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | none | clef | b | no | error | 0 | 9 | 16 | - | 45.5 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | none | clef | b | no | done | 1 | 11 | 17 | 0.01271 | 42.6 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | clef | b | yes | done | 1 | 3 | 8 | 0.00454 | 22.5 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | none | clef | b | yes | done | 1 | 3 | 8 | 0.004647 | 22.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | clef | b | yes | done | 1 | 4 | 9 | 0.007031 | 25.6 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | none | clef | b | no | error:headless | 1 | 2 | 4 | 0.000986 | 13.5 | 0 | no | message 'old' not quoted |
| portal-welcome | loose | none | clef | b | no | error | 3 | 10 | 18 | - | 44.2 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | none | clef | b | no | error:headless | 2 | 8 | 13 | 0.004477 | 47.1 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | none | clef | b | no | error:headless | 3 | 5 | 11 | 0.003003 | 41.3 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | goal | none | clef | b | no | error:headless | 2 | 4 | 8 | 0.002047 | 25.9 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | none | clef | b | no | error | 0 | 0 | 1 | - | 8.5 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | steps | none | clef | b | no | error | 0 | 2 | 5 | - | 24 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | goal | none | clef | b | no | done | 1 | 11 | 15 | 0.013916 | 46.3 | 0 | yes | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | none | clef | b | no | done | 1 | 4 | 10 | 0.007771 | 30.3 | 0 | no | names on a fresh Maps search: []; ratings [4.7] |
| u10-portal-new-message | steps | none | clef | b | no | error | 5 | 14 | 26 | - | 78.5 | 0 | no | message 'new' not quoted |
| u7-register | loose | none | clef | b | no | error:headless | 1 | 2 | 4 | 0.000969 | 13 | 0 | no | registrations 0, confirmed False |
| u7-register | goal | none | clef | b | no | error:headless | 1 | 2 | 4 | 0.001023 | 11.3 | 0 | no | registrations 0, confirmed False |
| u6-maps-cafe | goal | none | clef | b | no | blocked | 1 | 10 | 17 | 0.016367 | 46.5 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | steps | none | clef | b | no | error | 0 | 3 | 8 | - | 32.3 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u8-books-travel-jsonl | loose | none | clef | b | no | done | 0 | 3 | 4 | 0.003629 | 13.5 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | steps | none | clef | b | no | error:headless | 1 | 7 | 15 | 0.002929 | 40 | 0 | no | registrations 0, confirmed False |
| u9-upload | loose | none | clef | b | no | error | 0 | 0 | 1 | - | 1.5 | 0 | no | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | goal | none | clef | b | no | failed | 1 | 3 | 5 | 0.005651 | 47.9 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | steps | none | clef | b | no | error:headless | 2 | 2 | 4 | 0.001442 | 20.2 | 0 | no | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | steps | none | clef | b | no | done | 1 | 3 | 6 | 0.006512 | 58.7 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| wiki-ada-born | loose | none | clef | b | no | error | 0 | 0 | 2 | - | 15.1 | 0 | no | result lacks '10 December 1815' |
| wiki-ada-born | goal | none | clef | b | yes | done | 1 | 3 | 6 | 0.006599 | 20.7 | 0 | no | result names '10 December 1815' |
| u9-upload | goal | none | clef | b | no | error:headless | 3 | 4 | 7 | 0.003948 | 68.2 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | steps | none | clef | b | yes | done | 1 | 3 | 6 | 0.006636 | 21.6 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | none | clef | b | yes | done | 1 | 3 | 5 | 0.004753 | 16.8 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | none | clef | b | yes | done | 1 | 3 | 7 | 0.007335 | 19.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef | b | yes | done | 1 | 3 | 6 | 0.006274 | 17.9 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | notes | clef | b | yes | done | 1 | 1 | 5 | 0.00285 | 33.6 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | notes | clef | b | yes | done | 1 | 1 | 5 | 0.002833 | 32.6 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | notes | clef | b | yes | done | 1 | 2 | 5 | 0.003033 | 34 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | notes | clef | b | yes | done | 1 | 2 | 4 | 0.002659 | 20.6 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | loose | notes | clef | b | no | failed | 1 | 1 | 4 | 0.003808 | 59.6 | 0 | yes | result lacks 'Blue Top' |
| ae-search-jeans | loose | notes | clef | b | yes | done | 1 | 3 | 7 | 0.002748 | 24.4 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef | b | yes | done | 1 | 3 | 6 | 0.002374 | 22.2 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | notes | clef | b | no | error | 0 | 3 | 4 | - | 20.5 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-search-jeans | steps | notes | clef | b | yes | done | 1 | 3 | 6 | 0.002393 | 23.6 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | notes | clef | b | yes | done | 1 | 5 | 7 | 0.005372 | 18.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | notes | clef | b | yes | done | 1 | 5 | 7 | 0.005439 | 18.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | clef | b | yes | done | 1 | 2 | 3 | 0.00194 | 7.6 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | notes | clef | b | yes | done | 1 | 2 | 3 | 0.001961 | 10.4 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef | b | yes | done | 1 | 2 | 3 | 0.001997 | 6.8 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | clef | b | no | done | 0 | 5 | 6 | 0.004606 | 12.3 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | goal | notes | clef | b | no | done | 1 | 5 | 7 | 0.005442 | 26.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | notes | clef | b | yes | done | 1 | 1 | 2 | 0.001152 | 6.6 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef | b | yes | done | 1 | 1 | 2 | 0.001158 | 5.8 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef | b | yes | done | 1 | 2 | 3 | 0.001429 | 8.3 | 0 | no | result names '£51.77' |
| books-stock | loose | notes | clef | b | no | failed | 1 | 1 | 2 | 0.001287 | 7.9 | 0 | no | truth '20'; result differs |
| books-stock | goal | notes | clef | b | no | failed | 1 | 1 | 2 | 0.001476 | 11.3 | 0 | no | truth '20'; result differs |
| books-poetry-jsonl | steps | notes | clef | b | no | done | 1 | 4 | 6 | 0.007637 | 67 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| canvas-launch | loose | notes | clef | b | no | error | 0 | 0 | 1 | - | 1.6 | 1 | no | 0 canvas click(s), 0 inside the drawn button |
| books-stock | steps | notes | clef | b | yes | done | 1 | 2 | 3 | 0.001468 | 9.4 | 0 | no | truth '20'; result agrees |
| canvas-launch | goal | notes | clef | b | yes | failed | 1 | 2 | 3 | 0.001274 | 8.6 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | clef | b | yes | failed | 1 | 2 | 3 | 0.001396 | 11.3 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| ae-blue-top-price | steps | notes | clef | b | no | blocked | 1 | 60 | 104 | 0.056984 | 278 | 0 | yes | truth 'rs. 500'; result differs |
| flights-oneway | loose | notes | clef | b | no | error | 0 | 7 | 14 | - | 40.7 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | notes | clef | b | no | done | 1 | 14 | 20 | 0.018578 | 55.1 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | steps | notes | clef | b | no | done | 1 | 9 | 16 | 0.011198 | 42.8 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | clef | b | no | error | 0 | 0 | 4 | - | 22.1 | 0 | no | Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | goal | notes | clef | b | no | error | 0 | 0 | 4 | 0.00139 | 14.2 | 0 | no | Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | steps | notes | clef | b | yes | done | 1 | 4 | 11 | 0.00928 | 30.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | notes | clef | b | no | error:headless | 3 | 5 | 10 | 0.002713 | 33.3 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | notes | clef | b | no | error:headless | 3 | 6 | 12 | 0.003295 | 39.3 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | notes | clef | b | no | error:headless | 1 | 6 | 9 | 0.003119 | 35.4 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | notes | clef | b | no | error | 0 | 0 | 2 | - | 12.4 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | notes | clef | b | no | error | 0 | 4 | 7 | - | 11.7 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | notes | clef | b | no | error | 0 | 2 | 6 | - | 26.2 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | loose | notes | clef | b | no | done | 1 | 11 | 17 | 0.01585 | 51.4 | 0 | no | truth 'pln 306'; result differs |
| u10-portal-new-message | loose | notes | clef | b | no | limit | 6 | 16 | 28 | 0.009794 | 113.2 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | notes | clef | b | yes | done | 1 | 7 | 14 | 0.011916 | 43.2 | 0 | no | names on a fresh Maps search: ['Café Fleur', 'Restaurant Eiffel']; ratings [4.3] |
| u6-maps-cafe | goal | notes | clef | b | no | error | 0 | 0 | 4 | 0.001414 | 14.6 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | notes | clef | b | no | error:headless | 1 | 2 | 4 | 0.000857 | 8.6 | 0 | no | registrations 0, confirmed False |
| u6-maps-cafe | steps | notes | clef | b | no | error | 0 | 2 | 5 | - | 15.5 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | goal | notes | clef | b | no | error:headless | 1 | 2 | 4 | 0.001027 | 14.1 | 0 | no | registrations 0, confirmed False |
| u5-flights-roundtrip | steps | notes | clef | b | no | done | 1 | 21 | 32 | 0.038464 | 95.5 | 0 | no | truth 'pln 306'; result differs |
| u8-books-travel-jsonl | loose | notes | clef | b | no | done | 0 | 4 | 4 | 0.003633 | 9.5 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | steps | notes | clef | b | no | error:headless | 1 | 5 | 10 | 0.002443 | 24.5 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | goal | notes | clef | b | no | failed | 1 | 4 | 5 | 0.004629 | 21.6 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u8-books-travel-jsonl | steps | notes | clef | b | no | done | 1 | 3 | 5 | 0.004595 | 20.9 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | goal | notes | clef | b | no | error:headless | 2 | 2 | 4 | 0.001567 | 23.4 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | loose | notes | clef | b | no | error:headless | 2 | 2 | 4 | 0.002694 | 48 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | notes | clef | b | yes | done | 1 | 3 | 6 | 0.006596 | 30.1 | 0 | no | result names '10 December 1815' |
| u9-upload | steps | notes | clef | b | no | error:headless | 3 | 3 | 6 | 0.003559 | 53.3 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | goal | notes | clef | b | yes | done | 1 | 3 | 6 | 0.006632 | 20.6 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | notes | clef | b | no | error | 0 | 0 | 3 | 0.001529 | 6.4 | 0 | no | result lacks 'Charles Babbage' |
| wiki-ada-born | steps | notes | clef | b | yes | done | 1 | 3 | 6 | 0.006658 | 18.9 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | clef | b | yes | done | 1 | 4 | 7 | 0.00643 | 18.2 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef | b | no | error | 0 | 2 | 5 | - | 11.1 | 0 | no | result lacks 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | clef | b | yes | done | 1 | 1 | 2 | 0.0011 | 24.7 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | procedures | clef | b | no | failed | 1 | 6 | 7 | 0.003479 | 46.2 | 5 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | goal | procedures | clef | b | yes | done | 1 | 2 | 5 | 0.003743 | 30.7 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | loose | procedures | clef | b | no | error | 1 | 12 | 22 | - | 75.4 | 0 | yes | result lacks 'Blue Top' |
| ae-polo-brand | steps | procedures | clef | b | yes | done | 1 | 2 | 5 | 0.003344 | 23.8 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | loose | procedures | clef | b | yes | done | 2 | 4 | 12 | 0.004958 | 47 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | clef | b | yes | done | 2 | 4 | 11 | 0.004885 | 56.6 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | clef | b | no | blocked | 1 | 3 | 10 | 0.004105 | 39.1 | 0 | yes | result lacks 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | procedures | clef | b | yes | done | 3 | 20 | 32 | 0.022842 | 107.4 | 2 | yes | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | procedures | clef | b | yes | done | 4 | 26 | 40 | - | 98.1 | 2 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | clef | b | no | error | 0 | 0 | 1 | - | 2.7 | 0 | no | truth '19'; result differs |
| ae-blue-top-price | steps | procedures | clef | b | no | error | 1 | 60 | 116 | - | 303.5 | 0 | yes | truth 'rs. 500'; result differs |
| books-poetry-count | goal | procedures | clef | b | yes | done | 1 | 3 | 6 | 0.003635 | 17.1 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | procedures | clef | b | yes | done | 1 | 2 | 3 | 0.002056 | 9.9 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | goal | procedures | clef | b | yes | error | 1 | 1 | 7 | - | 21.1 | 0 | no | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-mystery-page2 | steps | procedures | clef | b | no | error | 2 | 15 | 27 | - | 80.9 | 1 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | loose | procedures | clef | b | yes | done | 1 | 1 | 2 | 0.001184 | 8.2 | 0 | no | result names '£51.77' |
| books-price | goal | procedures | clef | b | no | error | 0 | 0 | 1 | - | 2.1 | 0 | no | result lacks '£51.77' |
| books-price | steps | procedures | clef | b | yes | done | 1 | 2 | 3 | 0.001502 | 8.8 | 0 | no | result names '£51.77' |
| books-stock | loose | procedures | clef | b | no | failed | 1 | 1 | 2 | 0.001342 | 10.6 | 0 | no | truth '20'; result differs |
| books-stock | goal | procedures | clef | b | no | failed | 1 | 1 | 3 | 0.001805 | 21.9 | 0 | no | truth '20'; result differs |
| books-stock | steps | procedures | clef | b | yes | done | 1 | 2 | 3 | 0.001509 | 7.1 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | loose | procedures | clef | b | no | done | 3 | 6 | 21 | 0.017082 | 146.1 | 0 | no | 19 on the page, 152 in the file, 0 missing, 0 extra |
| canvas-launch | goal | procedures | clef | b | yes | failed | 1 | 2 | 3 | 0.001324 | 8.1 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | clef | b | yes | failed | 1 | 2 | 3 | 0.001334 | 7.6 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | procedures | clef | b | no | error | 0 | 9 | 16 | - | 38.8 | 0 | no | truth 'pln 148'; result differs |
| canvas-launch | loose | procedures | clef | b | no | error:headless | 4 | 12 | 16 | 0.010973 | 120.3 | 0 | no | 12 canvas click(s), 12 inside the drawn button |
| books-poetry-jsonl | steps | procedures | clef | b | no | error:model-timeout | 3 | 66 | 102 | - | 300.6 | 0 | no | 19 on the page, 76 in the file, 0 missing, 0 extra |
| flights-oneway | goal | procedures | clef | b | no | error | 1 | 62 | 71 | - | 149.7 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | procedures | clef | b | yes | done | 1 | 4 | 10 | 0.005567 | 32 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | procedures | clef | b | yes | failed | 1 | 8 | 18 | 0.010436 | 62.3 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | clef | b | yes | done | 1 | 5 | 11 | 0.005831 | 33.9 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | procedures | clef | b | no | error:headless | 2 | 6 | 13 | - | 34.6 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | procedures | clef | b | no | error:headless | 1 | 4 | 8 | 0.001918 | 15.4 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | procedures | clef | b | no | error:headless | 1 | 4 | 8 | 0.002165 | 19.5 | 0 | no | message 'old' not quoted |
| flights-oneway | steps | procedures | clef | b | no | error | 1 | 72 | 99 | - | 223 | 16 | no | truth 'pln 148'; result differs |
| u10-portal-new-message | steps | procedures | clef | b | no | error:headless | 1 | 4 | 8 | 0.00193 | 16.6 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | loose | procedures | clef | b | no | error:headless | 2 | 6 | 13 | 0.002685 | 26.8 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | goal | procedures | clef | b | no | error:headless | 2 | 4 | 11 | - | 34.6 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | procedures | clef | b | no | error | 1 | 55 | 69 | - | 142.1 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | loose | procedures | clef | b | no | error | 1 | 63 | 74 | - | 145.5 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | steps | procedures | clef | b | no | error | 1 | 71 | 84 | - | 177.2 | 0 | yes | truth pattern not found on the source |
| u6-maps-cafe | goal | procedures | clef | b | no | blocked | 1 | 6 | 14 | 0.009628 | 69.7 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | loose | procedures | clef | b | yes | done | 2 | 7 | 16 | 0.010603 | 72.2 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | procedures | clef | b | no | error:headless | 1 | 2 | 4 | 0.001025 | 11 | 0 | no | registrations 0, confirmed False |
| u7-register | goal | procedures | clef | b | no | error | 0 | 3 | 8 | - | 20.1 | 0 | no | registrations 0, confirmed False |
| u6-maps-cafe | steps | procedures | clef | b | no | done | 2 | 4 | 11 | - | 49.1 | 0 | no | names on a fresh Maps search: []; ratings [4.6] |
| u8-books-travel-jsonl | loose | procedures | clef | b | no | error | 0 | 2 | 6 | - | 13.1 | 0 | no | 11 on the page, 22 in the file, 0 missing, 0 extra |
| u7-register | steps | procedures | clef | b | no | error | 1 | 5 | 12 | - | 40.8 | 0 | no | registrations 0, confirmed False |
| u9-upload | loose | procedures | clef | b | no | error:headless | 2 | 3 | 5 | 0.002188 | 28.8 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | goal | procedures | clef | b | no | error:model-timeout | 4 | 6 | 10 | - | 96.9 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | steps | procedures | clef | b | no | error:headless | 2 | 2 | 4 | 0.001585 | 21.1 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | procedures | clef | b | yes | done | 1 | 4 | 8 | 0.007672 | 29.8 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | procedures | clef | b | yes | done | 2 | 3 | 11 | 0.008551 | 27.7 | 0 | no | result names '10 December 1815' |
| u8-books-travel-jsonl | steps | procedures | clef | b | no | error:model-timeout | 3 | 31 | 64 | - | 234.2 | 0 | no | 11 on the page, 55 in the file, 0 missing, 0 extra |
| wiki-ada-born | steps | procedures | clef | b | yes | done | 1 | 4 | 8 | 0.008019 | 21.2 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | clef | b | yes | done | 1 | 4 | 8 | 0.007713 | 23.6 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | procedures | clef | b | no | error | 0 | 0 | 1 | - | 11.8 | 0 | no | result lacks 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef | b | yes | done | 1 | 4 | 9 | 0.007401 | 21 | 0 | no | result names 'Charles Babbage' |
| u8-books-travel-jsonl | goal | procedures | clef | b | no | error:model-timeout | 6 | 18 | 46 | - | 300 | 0 | no | 11 on the page, 154 in the file, 0 missing, 0 extra |
| ae-blue-top-price | loose | none | clef | c | yes | done | 1 | 1 | 2 | 0.000941 | 29.2 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | none | clef | c | yes | done | 1 | 1 | 2 | 0.000926 | 29 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | none | clef | c | no | error | 0 | 0 | 5 | - | 34.6 | 0 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | steps | none | clef | c | no | failed | 1 | 1 | 5 | 0.003251 | 35.2 | 0 | no | result lacks 'Blue Top' |
| ae-polo-brand | goal | none | clef | c | no | error | 0 | 4 | 15 | - | 49.6 | 1 | yes | result lacks 'Blue Top' |
| ae-polo-brand | loose | none | clef | c | no | failed | 1 | 1 | 4 | 0.003566 | 52.8 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | loose | none | clef | c | yes | done | 1 | 3 | 7 | 0.002897 | 24.4 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | clef | c | no | error | 0 | 1 | 2 | - | 8 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-search-jeans | steps | none | clef | c | yes | done | 1 | 3 | 7 | 0.002871 | 22.2 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | clef | c | yes | done | 2 | 4 | 10 | 0.003524 | 37.6 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | none | clef | c | yes | done | 1 | 5 | 7 | 0.005402 | 19.4 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | none | clef | c | yes | done | 1 | 5 | 8 | 0.006097 | 18.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | clef | c | yes | done | 1 | 2 | 3 | 0.001959 | 8.9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | none | clef | c | yes | done | 1 | 2 | 3 | 0.00197 | 7.9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | none | clef | c | no | error | 0 | 0 | 1 | - | 10.9 | 0 | no | truth '19'; result differs |
| books-poetry-jsonl | loose | none | clef | c | no | done | 0 | 4 | 6 | 0.004637 | 14.4 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | none | clef | c | yes | done | 1 | 1 | 2 | 0.001152 | 5.6 | 0 | no | result names '£51.77' |
| books-price | goal | none | clef | c | yes | done | 1 | 1 | 2 | 0.001161 | 6.4 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | goal | none | clef | c | no | done | 1 | 5 | 8 | 0.005256 | 25.3 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | steps | none | clef | c | yes | done | 1 | 2 | 3 | 0.001402 | 8.2 | 0 | no | result names '£51.77' |
| books-stock | goal | none | clef | c | no | failed | 1 | 1 | 2 | 0.001287 | 9.6 | 0 | no | truth '20'; result differs |
| books-stock | loose | none | clef | c | no | failed | 1 | 1 | 4 | 0.002937 | 20.9 | 1 | no | truth '20'; result differs |
| books-stock | steps | none | clef | c | yes | done | 1 | 2 | 3 | 0.00153 | 8.4 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | none | clef | c | no | error:headless | 1 | 1 | 2 | 0.000247 | 5.3 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | none | clef | c | no | error:headless | 1 | 1 | 2 | 0.000316 | 6.1 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | none | clef | c | no | failed | 1 | 3 | 7 | 0.002342 | 13.5 | 3 | no | 2 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | none | clef | c | no | error:model-timeout | 1 | 5 | 8 | - | 76 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | loose | none | clef | c | no | error | 0 | 9 | 11 | - | 20.6 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | steps | none | clef | c | no | error | 0 | 7 | 11 | - | 25.7 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | clef | c | yes | done | 1 | 3 | 10 | 0.005177 | 26.3 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| flights-oneway | goal | none | clef | c | no | error | 0 | 12 | 19 | - | 41.4 | 0 | yes | truth 'pln 148'; result differs |
| maps-eiffel-postcode | steps | none | clef | c | no | error | 0 | 0 | 1 | - | 7.9 | 0 | no | Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | goal | none | clef | c | yes | done | 1 | 3 | 10 | 0.00591 | 27.9 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | none | clef | c | no | error:headless | 2 | 4 | 8 | 0.001788 | 20.2 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | none | clef | c | no | error:headless | 1 | 7 | 10 | 0.003126 | 29.8 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | none | clef | c | no | error | 0 | 0 | 1 | - | 1.8 | 0 | no | message 'new' not quoted |
| portal-welcome | loose | none | clef | c | no | limit | 6 | 13 | 25 | 0.009592 | 132.2 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | none | clef | c | no | limit | 6 | 16 | 28 | 0.009195 | 106.3 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | none | clef | c | no | error | 0 | 0 | 2 | - | 18.8 | 0 | no | truth 'pln 306'; result differs |
| u10-portal-new-message | steps | none | clef | c | no | error | 6 | 17 | 32 | - | 97.6 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | none | clef | c | no | error | 0 | 0 | 2 | - | 18.1 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u5-flights-roundtrip | loose | none | clef | c | no | done | 1 | 10 | 15 | 0.014415 | 49.7 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | steps | none | clef | c | no | error | 0 | 2 | 7 | - | 26.5 | 1 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | goal | none | clef | c | no | error | 0 | 3 | 7 | - | 28.5 | 1 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | none | clef | c | no | error | 0 | 3 | 8 | - | 14.3 | 1 | no | registrations 0, confirmed False |
| u5-flights-roundtrip | steps | none | clef | c | no | done | 1 | 15 | 28 | 0.038222 | 91.6 | 1 | yes | truth 'pln 306'; result differs |
| u7-register | steps | none | clef | c | no | error:headless | 1 | 8 | 12 | 0.003283 | 27.6 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | none | clef | c | no | error | 0 | 2 | 3 | - | 16 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | goal | none | clef | c | no | error:headless | 2 | 9 | 21 | 0.007582 | 48.9 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | steps | none | clef | c | no | error | 0 | 2 | 3 | - | 6.5 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | goal | none | clef | c | no | error | 1 | 3 | 8 | - | 15 | 3 | no | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | goal | none | clef | c | no | failed | 1 | 3 | 5 | 0.005429 | 36.6 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | loose | none | clef | c | no | error:headless | 2 | 2 | 4 | 0.002094 | 35.3 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | steps | none | clef | c | no | error:headless | 2 | 2 | 4 | 0.002168 | 32.4 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | goal | none | clef | c | no | error | 0 | 0 | 3 | - | 15.3 | 0 | no | result lacks '10 December 1815' |
| wiki-ada-born | loose | none | clef | c | yes | done | 1 | 3 | 6 | 0.006648 | 23.6 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | none | clef | c | yes | done | 1 | 3 | 5 | 0.005183 | 22.5 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | none | clef | c | yes | done | 1 | 3 | 6 | 0.006226 | 24.5 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | none | clef | c | yes | done | 1 | 3 | 6 | 0.006253 | 24.2 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef | c | no | error | 0 | 0 | 2 | - | 14.2 | 0 | no | result lacks 'Charles Babbage' |
| ae-blue-top-price | goal | notes | clef | c | yes | done | 1 | 1 | 2 | 0.001098 | 25.1 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | notes | clef | c | yes | done | 1 | 1 | 12 | 0.007489 | 65.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | notes | clef | c | no | failed | 1 | 1 | 5 | 0.003573 | 51.8 | 0 | yes | result lacks 'Blue Top' |
| ae-polo-brand | goal | notes | clef | c | yes | done | 1 | 2 | 4 | 0.002847 | 24.8 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | notes | clef | c | yes | done | 1 | 2 | 4 | 0.002543 | 20.2 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | steps | notes | clef | c | no | error | 0 | 8 | 30 | - | 113.1 | 0 | yes | truth 'rs. 500'; result differs |
| ae-search-jeans | loose | notes | clef | c | yes | done | 1 | 3 | 6 | 0.002357 | 22 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef | c | yes | done | 1 | 3 | 6 | 0.002342 | 20.9 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | clef | c | yes | done | 1 | 3 | 5 | 0.001925 | 21.8 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | notes | clef | c | yes | done | 1 | 6 | 8 | 0.006038 | 20.9 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | notes | clef | c | yes | done | 1 | 5 | 8 | 0.006032 | 18.8 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | clef | c | yes | done | 1 | 2 | 3 | 0.001976 | 10.2 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | notes | clef | c | yes | done | 1 | 5 | 7 | 0.00546 | 17.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | notes | clef | c | yes | done | 1 | 2 | 3 | 0.001977 | 9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef | c | yes | done | 1 | 2 | 3 | 0.001977 | 8.5 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | clef | c | no | done | 0 | 5 | 6 | 0.004646 | 13.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | notes | clef | c | yes | done | 1 | 1 | 2 | 0.001166 | 5.9 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef | c | yes | done | 1 | 1 | 2 | 0.001152 | 5.5 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef | c | yes | done | 1 | 2 | 3 | 0.001463 | 8.9 | 0 | no | result names '£51.77' |
| books-stock | loose | notes | clef | c | no | failed | 1 | 1 | 4 | 0.002968 | 20 | 1 | no | truth '20'; result differs |
| books-poetry-jsonl | steps | notes | clef | c | no | error:model-timeout | 1 | 4 | 6 | - | 70.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | goal | notes | clef | c | no | error:model-timeout | 1 | 5 | 7 | - | 74 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | goal | notes | clef | c | no | failed | 1 | 1 | 3 | 0.002343 | 24.9 | 0 | no | truth '20'; result differs |
| books-stock | steps | notes | clef | c | yes | done | 1 | 2 | 3 | 0.001524 | 8.6 | 0 | no | truth '20'; result agrees |
| canvas-launch | goal | notes | clef | c | no | error:headless | 1 | 1 | 2 | 0.000289 | 5.2 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | loose | notes | clef | c | yes | error:headless | 2 | 3 | 6 | 0.001381 | 16.3 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | notes | clef | c | no | error | 0 | 1 | 2 | - | 6 | 0 | no | truth 'pln 148'; result differs |
| canvas-launch | steps | notes | clef | c | no | failed | 1 | 3 | 7 | 0.002376 | 14.1 | 3 | no | 2 canvas click(s), 1 inside the drawn button |
| flights-oneway | steps | notes | clef | c | no | error | 0 | 2 | 4 | - | 8.2 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | clef | c | yes | done | 1 | 3 | 9 | 0.004875 | 25.6 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | notes | clef | c | yes | done | 1 | 3 | 8 | 0.004629 | 27.3 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | clef | c | yes | done | 1 | 4 | 9 | 0.006912 | 27.8 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | goal | notes | clef | c | no | done | 1 | 16 | 25 | 0.022419 | 65.3 | 0 | yes | truth 'pln 148'; result differs |
| portal-welcome | loose | notes | clef | c | no | error:headless | 3 | 5 | 10 | 0.002731 | 35.1 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | notes | clef | c | no | error | 2 | 10 | 17 | - | 63.2 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | notes | clef | c | no | error | 2 | 4 | 10 | - | 26.4 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | loose | notes | clef | c | no | limit | 6 | 13 | 25 | 0.007989 | 94.6 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | notes | clef | c | no | error | 0 | 1 | 4 | - | 14.9 | 0 | no | message 'new' not quoted |
| portal-welcome | goal | notes | clef | c | no | error:headless | 5 | 10 | 20 | 0.008453 | 121.5 | 0 | no | message 'old' not quoted |
| u5-flights-roundtrip | loose | notes | clef | c | no | error | 0 | 0 | 2 | - | 18.5 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | steps | notes | clef | c | no | error | 0 | 8 | 13 | - | 45.9 | 1 | yes | truth 'pln 306'; result differs |
| u5-flights-roundtrip | goal | notes | clef | c | no | error | 0 | 13 | 19 | - | 58.9 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | notes | clef | c | no | error | 0 | 5 | 10 | - | 31.7 | 1 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | notes | clef | c | no | error | 0 | 0 | 2 | - | 12.6 | 0 | no | registrations 0, confirmed False |
| u6-maps-cafe | goal | notes | clef | c | no | error | 0 | 2 | 7 | - | 17.6 | 1 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | steps | notes | clef | c | no | error | 0 | 2 | 8 | - | 20.5 | 2 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | goal | notes | clef | c | no | error:headless | 1 | 2 | 7 | 0.002002 | 20.3 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | notes | clef | c | no | done | 0 | 3 | 3 | 0.002499 | 7.4 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | steps | notes | clef | c | no | error | 0 | 2 | 6 | - | 18.5 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | steps | notes | clef | c | no | done | 1 | 3 | 5 | 0.004358 | 17.3 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | loose | notes | clef | c | no | error:headless | 2 | 2 | 4 | 0.001466 | 18.8 | 0 | no | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | goal | notes | clef | c | no | done | 1 | 3 | 5 | 0.005764 | 39.8 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| wiki-ada-born | loose | notes | clef | c | no | error | 0 | 1 | 3 | - | 9 | 0 | no | result lacks '10 December 1815' |
| u9-upload | steps | notes | clef | c | no | error:headless | 2 | 2 | 4 | 0.001758 | 22.9 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | goal | notes | clef | c | no | error:headless | 2 | 2 | 4 | 0.002923 | 52 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | steps | notes | clef | c | yes | done | 1 | 3 | 6 | 0.006685 | 23.6 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | notes | clef | c | yes | done | 1 | 3 | 6 | 0.006626 | 24.2 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | clef | c | yes | done | 1 | 3 | 6 | 0.006232 | 18.4 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | notes | clef | c | yes | done | 1 | 3 | 6 | 0.006287 | 17.5 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef | c | yes | done | 1 | 3 | 6 | 0.006328 | 19.8 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | clef | c | yes | done | 1 | 1 | 3 | 0.001752 | 31.4 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | procedures | clef | c | yes | done | 1 | 1 | 7 | 0.004669 | 49.1 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | procedures | clef | c | yes | done | 1 | 2 | 5 | 0.003247 | 25.1 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | procedures | clef | c | yes | done | 1 | 2 | 4 | 0.002759 | 20.1 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | steps | procedures | clef | c | yes | done | 1 | 5 | 22 | 0.015405 | 99.4 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | procedures | clef | c | yes | done | 1 | 6 | 15 | 0.011016 | 65.6 | 3 | yes | result names 'Blue Top' |
| ae-search-jeans | goal | procedures | clef | c | no | blocked | 1 | 3 | 9 | 0.003533 | 36.4 | 0 | yes | result lacks 'Soft Stretch Jeans' |
| ae-search-jeans | loose | procedures | clef | c | no | blocked | 1 | 3 | 9 | 0.003658 | 40.1 | 0 | yes | result lacks 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | clef | c | no | error | 1 | 0 | 7 | - | 40.8 | 0 | no | result lacks 'Soft Stretch Jeans' |
| books-mystery-page2 | steps | procedures | clef | c | no | failed | 2 | 11 | 17 | 0.012795 | 62.4 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | clef | c | yes | done | 1 | 3 | 6 | 0.003676 | 16.7 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | loose | procedures | clef | c | yes | done | 3 | 21 | 33 | 0.022557 | 108.9 | 0 | yes | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | procedures | clef | c | yes | done | 2 | 2 | 6 | - | 25.8 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | procedures | clef | c | yes | done | 1 | 2 | 3 | 0.00206 | 8.8 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | procedures | clef | c | no | error:model-timeout | 2 | 6 | 15 | - | 100.8 | 0 | no | 19 on the page, 76 in the file, 0 missing, 0 extra |
| books-mystery-page2 | goal | procedures | clef | c | no | error | 1 | 61 | 100 | - | 234.4 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | loose | procedures | clef | c | yes | done | 1 | 1 | 2 | 0.0012 | 5.5 | 0 | no | result names '£51.77' |
| books-price | goal | procedures | clef | c | yes | done | 1 | 1 | 2 | 0.001228 | 8.6 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef | c | yes | done | 1 | 2 | 3 | 0.001451 | 8.7 | 0 | no | result names '£51.77' |
| books-stock | loose | procedures | clef | c | no | failed | 1 | 1 | 3 | 0.002627 | 11.2 | 1 | no | truth '20'; result differs |
| books-stock | goal | procedures | clef | c | no | failed | 1 | 1 | 2 | 0.001314 | 9.4 | 0 | no | truth '20'; result differs |
| books-poetry-jsonl | goal | procedures | clef | c | no | error:model-timeout | 4 | 7 | 26 | - | 172.8 | 0 | no | 19 on the page, 171 in the file, 0 missing, 0 extra |
| books-stock | steps | procedures | clef | c | yes | done | 1 | 2 | 3 | 0.001536 | 7.8 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | procedures | clef | c | no | error:headless | 1 | 1 | 2 | 0.000278 | 5.6 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | procedures | clef | c | no | error:headless | 1 | 1 | 2 | 0.000395 | 9.2 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | procedures | clef | c | yes | error | 0 | 1 | 4 | - | 9.8 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | goal | procedures | clef | c | no | done | 2 | 28 | 40 | 0.03359 | 99.7 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | procedures | clef | c | no | done | 3 | 34 | 44 | 0.027458 | 111.1 | 0 | yes | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | procedures | clef | c | no | blocked | 1 | 11 | 24 | 0.019237 | 70.1 | 0 | no | Wikidata P281 ['75007']; result differs |
| flights-oneway | steps | procedures | clef | c | no | error | 1 | 26 | 43 | - | 103.9 | 7 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | steps | procedures | clef | c | no | error:model-timeout | 5 | 56 | 98 | - | 300 | 0 | no | 19 on the page, 171 in the file, 0 missing, 0 extra |
| maps-eiffel-postcode | goal | procedures | clef | c | yes | done | 1 | 4 | 10 | 0.005577 | 31.6 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | procedures | clef | c | no | error:headless | 1 | 4 | 8 | 0.001849 | 20.2 | 0 | no | message 'old' not quoted |
| portal-welcome | loose | procedures | clef | c | no | error:headless | 2 | 10 | 17 | 0.004075 | 27.6 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | procedures | clef | c | no | error:headless | 1 | 4 | 8 | 0.001862 | 14.8 | 0 | no | message 'new' not quoted |
| maps-eiffel-postcode | steps | procedures | clef | c | yes | done | 1 | 6 | 15 | 0.011247 | 47.1 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| u10-portal-new-message | goal | procedures | clef | c | no | error:headless | 1 | 4 | 8 | 0.001831 | 14.3 | 0 | no | message 'new' not quoted |
| portal-welcome | steps | procedures | clef | c | no | error:headless | 2 | 6 | 12 | 0.003362 | 33.6 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | procedures | clef | c | no | error:headless | 1 | 4 | 8 | 0.002412 | 22.8 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | procedures | clef | c | no | error | 1 | 0 | 5 | - | 37.2 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | goal | procedures | clef | c | no | done | 2 | 23 | 41 | 0.030929 | 96.8 | 4 | yes | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | procedures | clef | c | yes | done | 2 | 7 | 17 | 0.011523 | 75.6 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | procedures | clef | c | no | error | 0 | 4 | 12 | - | 39.8 | 1 | no | names on a fresh Maps search: []; ratings [] |
| u5-flights-roundtrip | steps | procedures | clef | c | no | error | 1 | 28 | 46 | - | 133.5 | 2 | yes | truth 'pln 306'; result differs |
| u6-maps-cafe | steps | procedures | clef | c | no | error | 0 | 3 | 11 | - | 31.8 | 1 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | procedures | clef | c | no | error:headless | 1 | 6 | 14 | 0.004745 | 25.8 | 0 | no | registrations 0, confirmed False |
| u7-register | steps | procedures | clef | c | no | error | 0 | 0 | 2 | - | 11.7 | 0 | no | registrations 0, confirmed False |
| u7-register | goal | procedures | clef | c | no | error:headless | 1 | 6 | 14 | 0.004989 | 33.5 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | goal | procedures | clef | c | no | error | 3 | 3 | 16 | - | 104.5 | 0 | no | 11 on the page, 55 in the file, 0 missing, 0 extra |
| u9-upload | loose | procedures | clef | c | no | error:headless | 2 | 2 | 4 | 0.00241 | 38.7 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | goal | procedures | clef | c | no | error:headless | 2 | 2 | 4 | 0.00123 | 15.4 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | steps | procedures | clef | c | no | error:headless | 2 | 2 | 4 | 0.001446 | 17.3 | 0 | no | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | steps | procedures | clef | c | no | error:model-timeout | 3 | 19 | 41 | - | 181.8 | 0 | no | 11 on the page, 55 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | loose | procedures | clef | c | no | error | 3 | 15 | 43 | - | 191.1 | 0 | no | 11 on the page, 176 in the file, 0 missing, 0 extra |
| wiki-ada-born | loose | procedures | clef | c | yes | done | 1 | 4 | 10 | 0.009593 | 36.4 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef | c | yes | done | 1 | 4 | 10 | 0.009554 | 29.9 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | procedures | clef | c | yes | done | 2 | 3 | 8 | - | 34.3 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | clef | c | yes | done | 1 | 4 | 9 | 0.009576 | 24.1 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | procedures | clef | c | yes | done | 1 | 4 | 9 | 0.008995 | 21.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef | c | yes | done | 1 | 4 | 9 | 0.009029 | 21.3 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | loose | none | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000662 | 22.9 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | none | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000629 | 22.6 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | clef-flash | b | no | failed | 1 | 1 | 3 | 0.001186 | 25.5 | 0 | no | result lacks 'Blue Top' |
| ae-blue-top-price | steps | none | clef-flash | b | no | error:model-timeout | 1 | 1 | 4 | - | 66.1 | 0 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | steps | none | clef-flash | b | no | failed | 1 | 1 | 3 | 0.000999 | 20.1 | 0 | no | result lacks 'Blue Top' |
| ae-polo-brand | loose | none | clef-flash | b | no | failed | 1 | 2 | 6 | 0.002281 | 51.1 | 0 | yes | result lacks 'Blue Top' |
| ae-search-jeans | steps | none | clef-flash | b | yes | done | 1 | 3 | 7 | 0.001302 | 24 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-search-jeans | loose | none | clef-flash | b | yes | done | 1 | 18 | 25 | 0.005104 | 51.1 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | clef-flash | b | yes | done | 2 | 14 | 20 | 0.004282 | 55.2 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | none | clef-flash | b | yes | done | 1 | 5 | 7 | 0.002265 | 15.9 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | none | clef-flash | b | yes | done | 1 | 5 | 8 | 0.00248 | 17.7 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | clef-flash | b | no | blocked | 1 | 4 | 7 | 0.002182 | 20 | 0 | no | truth '19'; result differs |
| books-poetry-count | goal | none | clef-flash | b | yes | done | 1 | 2 | 3 | 0.000915 | 5.7 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | none | clef-flash | b | yes | done | 1 | 2 | 3 | 0.000926 | 6.8 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | none | clef-flash | b | no | done | 0 | 5 | 7 | 0.001943 | 10.1 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | steps | none | clef-flash | b | no | done | 1 | 4 | 6 | 0.004601 | 52.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | none | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000624 | 5.7 | 0 | no | result names '£51.77' |
| books-price | goal | none | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000665 | 6.1 | 0 | no | result names '£51.77' |
| books-price | steps | none | clef-flash | b | yes | done | 1 | 1 | 3 | 0.001509 | 23.2 | 0 | no | result names '£51.77' |
| books-stock | loose | none | clef-flash | b | no | failed | 1 | 1 | 3 | 0.000896 | 11 | 0 | no | truth '20'; result differs |
| books-stock | goal | none | clef-flash | b | no | failed | 1 | 1 | 2 | 0.000801 | 7.1 | 0 | no | truth '20'; result differs |
| books-stock | steps | none | clef-flash | b | no | failed | 1 | 1 | 2 | 0.000714 | 6.4 | 0 | no | truth '20'; result differs |
| books-mystery-page2 | loose | none | clef-flash | b | yes | done | 3 | 67 | 107 | 0.039378 | 198.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| canvas-launch | loose | none | clef-flash | b | no | error:headless | 1 | 3 | 4 | 0.000872 | 14.1 | 0 | no | 3 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | clef-flash | b | yes | failed | 1 | 2 | 3 | 0.000632 | 9.5 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | goal | none | clef-flash | b | no | error:headless | 2 | 24 | 37 | 0.016566 | 170 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| canvas-launch | goal | none | clef-flash | b | no | error:headless | 4 | 10 | 14 | 0.004144 | 71.6 | 0 | no | 9 canvas click(s), 0 inside the drawn button |
| flights-oneway | goal | none | clef-flash | b | no | error | 0 | 35 | 53 | - | 109.6 | 0 | yes | truth 'pln 148'; result differs |
| flights-oneway | loose | none | clef-flash | b | no | done | 3 | 40 | 63 | 0.018462 | 143 | 10 | yes | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | none | clef-flash | b | yes | done | 1 | 3 | 8 | 0.00192 | 20.1 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | none | clef-flash | b | no | blocked | 1 | 4 | 10 | 0.002022 | 35.5 | 0 | yes | Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | steps | none | clef-flash | b | yes | done | 1 | 4 | 9 | 0.002136 | 21.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | none | clef-flash | b | no | error | 1 | 2 | 6 | - | 21.7 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | none | clef-flash | b | no | error:headless | 1 | 2 | 3 | 0.00069 | 13.2 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | none | clef-flash | b | no | error | 0 | 1 | 4 | - | 14.6 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | none | clef-flash | b | no | done | 1 | 4 | 6 | 0.000627 | 8.3 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | loose | none | clef-flash | b | no | error | 1 | 1 | 4 | - | 18.4 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | none | clef-flash | b | no | failed | 1 | 11 | 16 | 0.0059 | 42.5 | 0 | no | truth 'pln 306'; result differs |
| u10-portal-new-message | steps | none | clef-flash | b | no | error | 4 | 14 | 26 | - | 67.1 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | none | clef-flash | b | no | failed | 1 | 5 | 9 | 0.003226 | 36.5 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | none | clef-flash | b | no | error | 0 | 0 | 3 | - | 19 | 0 | no | names on a fresh Maps search: []; ratings [] |
| flights-oneway | steps | none | clef-flash | b | no | blocked | 5 | 75 | 100 | 0.024468 | 273.1 | 26 | yes | truth 'pln 148'; result differs |
| u5-flights-roundtrip | steps | none | clef-flash | b | no | done | 1 | 8 | 12 | 0.006403 | 80.5 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | steps | none | clef-flash | b | yes | done | 1 | 4 | 11 | 0.00371 | 30.4 | 0 | no | names on a fresh Maps search: ['Eiffel Tower']; ratings [4.1] |
| u6-maps-cafe | goal | none | clef-flash | b | no | error | 1 | 3 | 8 | - | 35.2 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | goal | none | clef-flash | b | no | error:headless | 1 | 2 | 5 | 0.002053 | 42.6 | 0 | no | registrations 0, confirmed False |
| u7-register | loose | none | clef-flash | b | no | error | 1 | 29 | 39 | 0.00406 | 56.4 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | none | clef-flash | b | no | done | 0 | 3 | 4 | 0.001361 | 7.5 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | steps | none | clef-flash | b | no | error | 2 | 17 | 28 | - | 68.7 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | steps | none | clef-flash | b | no | done | 1 | 3 | 5 | 0.002067 | 17.6 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u8-books-travel-jsonl | goal | none | clef-flash | b | no | failed | 2 | 8 | 12 | 0.005644 | 59.9 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | steps | none | clef-flash | b | no | error | 1 | 1 | 3 | - | 15.4 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | none | clef-flash | b | no | error | 0 | 0 | 2 | - | 14.6 | 0 | no | result lacks '10 December 1815' |
| wiki-ada-born | goal | none | clef-flash | b | yes | done | 1 | 3 | 5 | 0.002296 | 15.8 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | none | clef-flash | b | yes | done | 1 | 3 | 7 | 0.003288 | 19.3 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | none | clef-flash | b | yes | done | 1 | 3 | 6 | 0.002651 | 14.5 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | none | clef-flash | b | yes | done | 1 | 3 | 6 | 0.00266 | 13.6 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef-flash | b | yes | done | 1 | 3 | 6 | 0.002665 | 12.3 | 0 | no | result names 'Charles Babbage' |
| u9-upload | goal | none | clef-flash | b | no | error:headless | 4 | 184 | 191 | 0.027465 | 245.7 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | loose | none | clef-flash | b | no | error | 6 | 275 | 286 | - | 300.2 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | loose | notes | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000668 | 23.8 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | notes | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000652 | 24.4 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | notes | clef-flash | b | no | blocked | 1 | 3 | 4 | 0.000737 | 33.9 | 2 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | goal | notes | clef-flash | b | no | failed | 1 | 2 | 8 | 0.001954 | 42 | 0 | no | result lacks 'Blue Top' |
| ae-polo-brand | steps | notes | clef-flash | b | yes | done | 1 | 4 | 11 | 0.002973 | 42.9 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | loose | notes | clef-flash | b | no | failed | 1 | 2 | 8 | 0.002828 | 55.1 | 0 | yes | result lacks 'Blue Top' |
| ae-search-jeans | steps | notes | clef-flash | b | yes | done | 1 | 3 | 7 | 0.001259 | 18.7 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | loose | notes | clef-flash | b | no | error | 0 | 24 | 30 | - | 53.3 | 1 | yes | result lacks 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef-flash | b | yes | done | 2 | 14 | 21 | 0.004386 | 51.1 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | notes | clef-flash | b | yes | done | 1 | 5 | 7 | 0.002266 | 14.8 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | notes | clef-flash | b | yes | done | 1 | 5 | 7 | 0.002263 | 12.8 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | notes | clef-flash | b | yes | done | 3 | 13 | 20 | 0.006537 | 48.4 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | notes | clef-flash | b | yes | done | 1 | 2 | 3 | 0.000936 | 6.7 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef-flash | b | yes | done | 1 | 2 | 3 | 0.000946 | 6.9 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | clef-flash | b | no | done | 0 | 6 | 7 | 0.001948 | 12.5 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-count | loose | notes | clef-flash | b | yes | done | 2 | 13 | 18 | 0.005445 | 38.9 | 0 | no | truth '19'; result agrees |
| books-price | loose | notes | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000658 | 4.7 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000659 | 5.9 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | steps | notes | clef-flash | b | no | done | 1 | 4 | 6 | 0.003587 | 43.7 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | loose | notes | clef-flash | b | no | failed | 1 | 1 | 3 | 0.001112 | 16.3 | 0 | no | truth '20'; result differs |
| books-price | steps | notes | clef-flash | b | yes | done | 1 | 1 | 3 | 0.003041 | 54.9 | 0 | no | result names '£51.77' |
| books-stock | goal | notes | clef-flash | b | no | failed | 1 | 1 | 2 | 0.001201 | 16.8 | 0 | no | truth '20'; result differs |
| books-stock | steps | notes | clef-flash | b | no | failed | 1 | 1 | 3 | 0.001308 | 19.1 | 0 | no | truth '20'; result differs |
| canvas-launch | goal | notes | clef-flash | b | no | failed | 2 | 4 | 6 | 0.001703 | 26.9 | 4 | no | 3 canvas click(s), 3 inside the drawn button |
| canvas-launch | steps | notes | clef-flash | b | no | error:headless | 1 | 1 | 2 | 0.000233 | 11.6 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| flights-oneway | loose | notes | clef-flash | b | no | done | 2 | 12 | 20 | 0.005791 | 46.6 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | notes | clef-flash | b | no | error:model-timeout | 4 | 29 | 43 | - | 228 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| canvas-launch | loose | notes | clef-flash | b | no | error:headless | 6 | 18 | 24 | 0.009111 | 142.3 | 0 | no | 18 canvas click(s), 18 inside the drawn button |
| maps-eiffel-postcode | loose | notes | clef-flash | b | yes | done | 1 | 3 | 8 | 0.00185 | 22.7 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | notes | clef-flash | b | yes | done | 1 | 3 | 8 | 0.001976 | 20.9 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | clef-flash | b | yes | done | 1 | 3 | 7 | 0.001832 | 28.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | goal | notes | clef-flash | b | no | error | 0 | 41 | 57 | - | 130.4 | 0 | yes | truth 'pln 148'; result differs |
| portal-welcome | goal | notes | clef-flash | b | no | error:headless | 2 | 5 | 9 | 0.001344 | 24.2 | 0 | no | message 'old' not quoted |
| flights-oneway | steps | notes | clef-flash | b | no | error | 1 | 43 | 57 | - | 131.1 | 13 | yes | truth 'pln 148'; result differs |
| portal-welcome | loose | notes | clef-flash | b | no | error | 2 | 15 | 24 | - | 60.2 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | notes | clef-flash | b | no | failed | 1 | 4 | 6 | 0.000659 | 12.1 | 0 | no | message 'new' not quoted |
| portal-welcome | steps | notes | clef-flash | b | no | limit | 6 | 20 | 35 | 0.004753 | 83.1 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | notes | clef-flash | b | no | error:headless | 6 | 12 | 26 | 0.005211 | 101.1 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | notes | clef-flash | b | no | error | 0 | 0 | 3 | 0.000296 | 12 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | loose | notes | clef-flash | b | no | failed | 1 | 11 | 18 | 0.006039 | 46.4 | 0 | no | truth 'pln 306'; result differs |
| u10-portal-new-message | steps | notes | clef-flash | b | no | limit | 6 | 21 | 36 | 0.006052 | 114.7 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | notes | clef-flash | b | yes | done | 1 | 3 | 6 | 0.001443 | 18.6 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | notes | clef-flash | b | yes | done | 2 | 6 | 11 | 0.00425 | 46.5 | 0 | no | names on a fresh Maps search: ['Café Fleur', 'Restaurant Eiffel']; ratings [4.3] |
| u5-flights-roundtrip | steps | notes | clef-flash | b | no | error:model-timeout | 1 | 8 | 12 | - | 84.3 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | steps | notes | clef-flash | b | no | done | 1 | 4 | 9 | 0.003863 | 44.6 | 0 | no | names on a fresh Maps search: []; ratings [4.7] |
| u7-register | steps | notes | clef-flash | b | no | error:headless | 2 | 8 | 14 | 0.001675 | 35.2 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | notes | clef-flash | b | no | done | 0 | 4 | 4 | 0.001362 | 8.8 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | goal | notes | clef-flash | b | no | error | 1 | 16 | 23 | - | 47.1 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | steps | notes | clef-flash | b | no | done | 1 | 4 | 5 | 0.002784 | 27.2 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | loose | notes | clef-flash | b | no | error:headless | 2 | 56 | 71 | 0.008074 | 98.9 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | goal | notes | clef-flash | b | no | failed | 2 | 9 | 15 | 0.007092 | 76.4 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | goal | notes | clef-flash | b | no | error:model-timeout | 3 | 66 | 70 | - | 142.3 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | notes | clef-flash | b | yes | done | 1 | 3 | 6 | 0.002837 | 16.5 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | notes | clef-flash | b | yes | done | 1 | 3 | 6 | 0.002828 | 15.7 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | notes | clef-flash | b | yes | done | 1 | 3 | 7 | 0.002911 | 16 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | clef-flash | b | yes | done | 1 | 3 | 5 | 0.002128 | 13.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | notes | clef-flash | b | yes | done | 1 | 3 | 6 | 0.002655 | 12.6 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef-flash | b | no | error | 0 | 0 | 2 | - | 13.1 | 0 | no | result lacks 'Charles Babbage' |
| u9-upload | loose | notes | clef-flash | b | no | error | 4 | 238 | 246 | - | 299.9 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | steps | notes | clef-flash | b | no | error | 6 | 283 | 294 | - | 300.2 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | loose | procedures | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000654 | 27.7 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | procedures | clef-flash | b | yes | done | 1 | 1 | 2 | 0.000655 | 27.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | procedures | clef-flash | b | yes | failed | 1 | 1 | 2 | 0.001296 | 38.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | procedures | clef-flash | b | no | error | 0 | 0 | 1 | - | 14.8 | 0 | no | result lacks 'Blue Top' |
| ae-polo-brand | goal | procedures | clef-flash | b | no | error | 1 | 15 | 27 | - | 77.3 | 1 | yes | result lacks 'Blue Top' |
| ae-search-jeans | loose | procedures | clef-flash | b | no | error:model-timeout | 1 | 11 | 20 | - | 106.3 | 0 | no | result lacks 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | clef-flash | b | yes | done | 2 | 16 | 24 | 0.005509 | 56.6 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | clef-flash | b | yes | done | 1 | 3 | 7 | 0.001228 | 22.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | procedures | clef-flash | b | no | error:model-timeout | 2 | 22 | 38 | - | 150.2 | 0 | no | result lacks 'Blue Top' |
| books-mystery-page2 | steps | procedures | clef-flash | b | yes | done | 2 | 10 | 16 | 0.005437 | 46.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | clef-flash | b | yes | done | 2 | 2 | 6 | 0.001656 | 13.9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | procedures | clef-flash | b | no | blocked | 1 | 2 | 8 | 0.002464 | 27 | 0 | no | truth '19'; result differs |
| books-poetry-count | steps | procedures | clef-flash | b | yes | done | 1 | 2 | 3 | 0.000976 | 6.5 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | procedures | clef-flash | b | no | blocked | 3 | 47 | 77 | - | 204.5 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | procedures | clef-flash | b | no | failed | 3 | 74 | 120 | 0.038715 | 246.6 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-jsonl | goal | procedures | clef-flash | b | no | error:model-timeout | 2 | 2 | 12 | - | 120.7 | 0 | no | 19 on the page, 133 in the file, 0 missing, 0 extra |
| books-price | loose | procedures | clef-flash | b | yes | done | 1 | 1 | 2 | 0.00063 | 6.1 | 0 | no | result names '£51.77' |
| books-price | goal | procedures | clef-flash | b | yes | done | 1 | 1 | 2 | 0.00065 | 5.8 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | loose | procedures | clef-flash | b | no | error:model-timeout | 5 | 3 | 26 | - | 240.4 | 0 | no | 19 on the page, 323 in the file, 0 missing, 0 extra |
| books-stock | loose | procedures | clef-flash | b | no | failed | 1 | 1 | 2 | 0.0007 | 5.9 | 0 | no | truth '20'; result differs |
| books-stock | goal | procedures | clef-flash | b | no | failed | 1 | 1 | 2 | 0.000923 | 10.4 | 0 | no | truth '20'; result differs |
| books-price | steps | procedures | clef-flash | b | yes | done | 1 | 1 | 3 | 0.002201 | 30.9 | 0 | no | result names '£51.77' |
| books-stock | steps | procedures | clef-flash | b | no | failed | 1 | 1 | 3 | 0.001009 | 13.8 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | procedures | clef-flash | b | no | error:headless | 1 | 3 | 4 | 0.001207 | 16.8 | 0 | no | 3 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | clef-flash | b | yes | failed | 1 | 2 | 3 | 0.00061 | 9.6 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | clef-flash | b | no | failed | 5 | 13 | 18 | 0.005428 | 86.9 | 13 | no | 12 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | procedures | clef-flash | b | no | error:model-timeout | 6 | 6 | 31 | - | 287.5 | 0 | no | 19 on the page, 304 in the file, 0 missing, 0 extra |
| flights-oneway | loose | procedures | clef-flash | b | no | error | 3 | 34 | 55 | - | 177.7 | 6 | yes | truth 'pln 148'; result differs |
| flights-oneway | goal | procedures | clef-flash | b | no | error:model-timeout | 1 | 22 | 32 | - | 127.5 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | procedures | clef-flash | b | yes | done | 1 | 5 | 12 | 0.002743 | 44.4 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | procedures | clef-flash | b | yes | done | 2 | 3 | 11 | - | 41.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | clef-flash | b | yes | done | 1 | 4 | 8 | 0.001707 | 26.9 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | procedures | clef-flash | b | no | error:headless | 2 | 3 | 10 | - | 34.4 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | procedures | clef-flash | b | no | error:headless | 2 | 6 | 12 | 0.001875 | 32.3 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | procedures | clef-flash | b | no | error:headless | 2 | 5 | 11 | 0.00147 | 26.7 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | goal | procedures | clef-flash | b | no | error:headless | 1 | 3 | 7 | 0.000822 | 16.8 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | procedures | clef-flash | b | no | error | 2 | 6 | 16 | - | 52 | 0 | no | message 'new' not quoted |
| portal-welcome | steps | procedures | clef-flash | b | no | error:model-timeout | 4 | 12 | 22 | - | 121.9 | 0 | no | message 'old' not quoted |
| flights-oneway | steps | procedures | clef-flash | b | no | error:model-timeout | 2 | 120 | 154 | - | 302.7 | 0 | no | truth 'pln 148'; result differs |
| u5-flights-roundtrip | loose | procedures | clef-flash | b | no | done | 2 | 6 | 14 | - | 104.2 | 0 | yes | truth 'pln 306'; result differs |
| u5-flights-roundtrip | goal | procedures | clef-flash | b | no | error:model-timeout | 1 | 20 | 32 | - | 119.5 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | procedures | clef-flash | b | yes | done | 2 | 3 | 12 | - | 42 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | procedures | clef-flash | b | no | blocked | 2 | 4 | 12 | 0.002867 | 35.3 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | steps | procedures | clef-flash | b | yes | done | 3 | 6 | 20 | - | 58.1 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | procedures | clef-flash | b | no | error | 2 | 26 | 37 | - | 50.3 | 0 | no | registrations 0, confirmed False |
| u7-register | goal | procedures | clef-flash | b | no | error:headless | 1 | 2 | 5 | 0.001215 | 22.6 | 0 | no | registrations 0, confirmed False |
| u7-register | steps | procedures | clef-flash | b | no | error:headless | 2 | 10 | 15 | 0.001958 | 25.5 | 0 | no | registrations 0, confirmed False |
| u5-flights-roundtrip | steps | procedures | clef-flash | b | no | done | 7 | 91 | 126 | - | 257.1 | 47 | no | truth 'pln 306'; result differs |
| u8-books-travel-jsonl | loose | procedures | clef-flash | b | no | error:model-timeout | 2 | 2 | 12 | - | 106.2 | 0 | no | 11 on the page, 77 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | goal | procedures | clef-flash | b | no | error:model-timeout | 2 | 2 | 12 | - | 104.9 | 0 | no | 11 on the page, 77 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | steps | procedures | clef-flash | b | no | error:model-timeout | 3 | 2 | 16 | - | 163.6 | 0 | no | 11 on the page, 110 in the file, 0 missing, 0 extra |
| u9-upload | loose | procedures | clef-flash | b | no | error:headless | 3 | 125 | 134 | - | 160.9 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | procedures | clef-flash | b | yes | done | 1 | 3 | 5 | 0.00235 | 14 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | procedures | clef-flash | b | yes | done | 1 | 4 | 8 | 0.003372 | 19.1 | 0 | no | result names '10 December 1815' |
| u9-upload | goal | procedures | clef-flash | b | no | error | 4 | 221 | 232 | - | 194.3 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | steps | procedures | clef-flash | b | yes | done | 1 | 4 | 8 | 0.003487 | 20.8 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | procedures | clef-flash | b | yes | done | 1 | 4 | 9 | 0.003683 | 18.2 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | procedures | clef-flash | b | yes | done | 1 | 5 | 13 | 0.004703 | 25.8 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef-flash | b | yes | done | 1 | 4 | 8 | 0.003207 | 14.9 | 0 | no | result names 'Charles Babbage' |
| u9-upload | steps | procedures | clef-flash | b | no | error | 5 | 196 | 208 | - | 206.7 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | loose | none | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000583 | 22.9 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | none | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000617 | 22.2 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | none | clef-flash | c | yes | failed | 1 | 1 | 3 | 0.003264 | 68.2 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | clef-flash | c | no | failed | 1 | 2 | 8 | 0.002625 | 51.7 | 0 | no | result lacks 'Blue Top' |
| ae-polo-brand | loose | none | clef-flash | c | no | failed | 1 | 2 | 8 | 0.002844 | 55.2 | 0 | yes | result lacks 'Blue Top' |
| ae-polo-brand | steps | none | clef-flash | c | no | failed | 1 | 1 | 3 | 0.000963 | 16.7 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | loose | none | clef-flash | c | yes | done | 1 | 3 | 7 | 0.001263 | 21.9 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | clef-flash | c | yes | done | 1 | 3 | 7 | 0.001272 | 20.2 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | none | clef-flash | c | yes | done | 1 | 5 | 8 | 0.002462 | 15.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| ae-search-jeans | goal | none | clef-flash | c | yes | done | 2 | 14 | 21 | 0.004432 | 53.2 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | clef-flash | c | yes | done | 2 | 10 | 16 | 0.005156 | 34.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | none | clef-flash | c | yes | done | 1 | 5 | 8 | 0.002515 | 15.7 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | none | clef-flash | c | yes | done | 1 | 2 | 3 | 0.000934 | 6.8 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | none | clef-flash | c | yes | done | 1 | 2 | 3 | 0.000949 | 9.1 | 0 | no | truth '19'; result agrees |
| books-poetry-count | loose | none | clef-flash | c | no | blocked | 1 | 5 | 7 | 0.002058 | 16 | 0 | no | truth '19'; result differs |
| books-poetry-jsonl | loose | none | clef-flash | c | no | done | 0 | 5 | 5 | 0.001529 | 8.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | none | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000645 | 5.4 | 0 | no | result names '£51.77' |
| books-price | goal | none | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000627 | 6.1 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | steps | none | clef-flash | c | no | done | 1 | 4 | 6 | 0.003927 | 46.7 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | steps | none | clef-flash | c | yes | failed | 1 | 1 | 2 | 0.00226 | 35 | 0 | no | result names '£51.77' |
| books-stock | loose | none | clef-flash | c | no | failed | 1 | 1 | 2 | 0.000908 | 9.8 | 0 | no | truth '20'; result differs |
| books-stock | goal | none | clef-flash | c | no | failed | 1 | 1 | 2 | 0.001011 | 12.1 | 0 | no | truth '20'; result differs |
| books-stock | steps | none | clef-flash | c | no | failed | 1 | 1 | 3 | 0.00097 | 13 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | none | clef-flash | c | no | error:headless | 1 | 1 | 2 | 0.000216 | 6.1 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | none | clef-flash | c | no | error:headless | 1 | 1 | 2 | 0.000194 | 5.4 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | none | clef-flash | c | no | error:headless | 1 | 1 | 2 | 0.000217 | 6.4 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| books-poetry-jsonl | goal | none | clef-flash | c | no | error:model-timeout | 3 | 22 | 35 | - | 199.7 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | none | clef-flash | c | no | done | 3 | 45 | 62 | 0.015789 | 136.9 | 0 | yes | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | clef-flash | c | no | error | 0 | 2 | 10 | - | 22.3 | 1 | yes | Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | goal | none | clef-flash | c | yes | done | 1 | 3 | 8 | 0.001952 | 21.1 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | clef-flash | c | no | error | 0 | 2 | 6 | - | 24 | 0 | no | Wikidata P281 ['75007']; result differs |
| flights-oneway | steps | none | clef-flash | c | no | error | 0 | 28 | 42 | - | 88.1 | 0 | yes | truth 'pln 148'; result differs |
| portal-welcome | goal | none | clef-flash | c | no | error:headless | 2 | 5 | 9 | 0.001307 | 29.6 | 0 | no | message 'old' not quoted |
| flights-oneway | loose | none | clef-flash | c | no | error | 3 | 75 | 108 | - | 281.5 | 0 | yes | truth 'pln 148'; result differs |
| portal-welcome | steps | none | clef-flash | c | no | error | 2 | 17 | 30 | - | 54.6 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | none | clef-flash | c | no | limit | 6 | 17 | 30 | 0.004392 | 80.4 | 0 | no | message 'new' not quoted |
| portal-welcome | loose | none | clef-flash | c | no | error | 5 | 36 | 52 | - | 172.3 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | none | clef-flash | c | no | error | 5 | 28 | 39 | - | 117.7 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | none | clef-flash | c | no | error | 0 | 6 | 11 | - | 31.7 | 1 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | loose | none | clef-flash | c | no | done | 1 | 8 | 16 | 0.008722 | 53.9 | 3 | no | truth 'pln 306'; result differs |
| u10-portal-new-message | steps | none | clef-flash | c | no | error | 4 | 14 | 27 | - | 67.7 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | none | clef-flash | c | no | blocked | 5 | 18 | 31 | 0.008102 | 92.8 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u5-flights-roundtrip | steps | none | clef-flash | c | no | error | 1 | 30 | 59 | - | 134.5 | 5 | yes | truth 'pln 306'; result differs |
| u6-maps-cafe | steps | none | clef-flash | c | no | done | 1 | 6 | 12 | 0.004482 | 31.1 | 0 | no | names on a fresh Maps search: []; ratings [4.7] |
| u6-maps-cafe | goal | none | clef-flash | c | no | blocked | 2 | 64 | 72 | 0.024772 | 129.1 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | none | clef-flash | c | no | error:headless | 2 | 18 | 22 | 0.002579 | 35 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | none | clef-flash | c | no | done | 0 | 3 | 4 | 0.001371 | 9.2 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | goal | none | clef-flash | c | no | error:headless | 2 | 24 | 33 | 0.003832 | 49.9 | 0 | no | registrations 0, confirmed False |
| u7-register | steps | none | clef-flash | c | no | error | 2 | 24 | 40 | - | 86.4 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | steps | none | clef-flash | c | no | done | 1 | 3 | 5 | 0.00362 | 39.9 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u8-books-travel-jsonl | goal | none | clef-flash | c | no | failed | 2 | 8 | 13 | 0.006688 | 68.7 | 1 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | goal | none | clef-flash | c | no | error:headless | 1 | 4 | 5 | 0.000756 | 10.4 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | none | clef-flash | c | yes | done | 1 | 3 | 6 | 0.002262 | 15.1 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | none | clef-flash | c | yes | done | 1 | 3 | 7 | 0.003401 | 16.6 | 0 | no | result names '10 December 1815' |
| u9-upload | steps | none | clef-flash | c | no | error:headless | 3 | 7 | 16 | 0.00396 | 51.6 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | steps | none | clef-flash | c | yes | done | 1 | 3 | 6 | 0.002753 | 15.4 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | none | clef-flash | c | yes | done | 1 | 3 | 6 | 0.002672 | 14.8 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | none | clef-flash | c | no | error | 0 | 3 | 8 | - | 18 | 1 | no | result lacks 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef-flash | c | yes | done | 1 | 3 | 6 | 0.002683 | 15.8 | 0 | no | result names 'Charles Babbage' |
| u9-upload | loose | none | clef-flash | c | no | error | 4 | 232 | 240 | - | 299.4 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | loose | notes | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000645 | 27.2 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | notes | clef-flash | c | yes | done | 1 | 1 | 3 | 0.000849 | 29.6 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | notes | clef-flash | c | yes | failed | 1 | 1 | 3 | 0.001815 | 47.3 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | notes | clef-flash | c | no | failed | 1 | 1 | 3 | 0.001465 | 31.4 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | loose | notes | clef-flash | c | yes | done | 1 | 3 | 6 | 0.001165 | 20.8 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | notes | clef-flash | c | yes | done | 1 | 4 | 11 | 0.003502 | 39.9 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | steps | notes | clef-flash | c | yes | done | 1 | 3 | 6 | 0.001088 | 19.5 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-polo-brand | goal | notes | clef-flash | c | no | failed | 1 | 2 | 8 | 0.00456 | 80.9 | 0 | no | result lacks 'Blue Top' |
| books-mystery-page2 | goal | notes | clef-flash | c | yes | done | 1 | 5 | 8 | 0.002483 | 18 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | notes | clef-flash | c | yes | done | 2 | 11 | 17 | 0.005424 | 36.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | notes | clef-flash | c | yes | done | 1 | 5 | 8 | 0.002565 | 18.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | notes | clef-flash | c | yes | done | 1 | 2 | 3 | 0.00094 | 6.6 | 0 | no | truth '19'; result agrees |
| books-poetry-count | loose | notes | clef-flash | c | no | blocked | 1 | 4 | 7 | 0.002092 | 14.7 | 0 | no | truth '19'; result differs |
| books-poetry-count | steps | notes | clef-flash | c | yes | done | 1 | 2 | 3 | 0.000949 | 7.2 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | clef-flash | c | no | done | 0 | 5 | 7 | 0.00196 | 12.1 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| ae-search-jeans | goal | notes | clef-flash | c | no | blocked | 2 | 38 | 49 | 0.010566 | 108.4 | 1 | yes | result lacks 'Soft Stretch Jeans' |
| books-price | loose | notes | clef-flash | c | no | error | 0 | 0 | 1 | - | 10.9 | 0 | no | result lacks '£51.77' |
| books-price | goal | notes | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000667 | 6.6 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | goal | notes | clef-flash | c | no | failed | 1 | 4 | 7 | 0.004657 | 58.1 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | steps | notes | clef-flash | c | no | done | 1 | 5 | 7 | 0.004512 | 56.9 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | goal | notes | clef-flash | c | no | failed | 1 | 1 | 3 | 0.001348 | 21 | 0 | no | truth '20'; result differs |
| books-stock | loose | notes | clef-flash | c | no | failed | 1 | 1 | 3 | 0.002448 | 37.3 | 0 | no | truth '20'; result differs |
| books-price | steps | notes | clef-flash | c | yes | failed | 1 | 1 | 2 | 0.003247 | 57.2 | 0 | no | result names '£51.77' |
| canvas-launch | goal | notes | clef-flash | c | no | error:headless | 1 | 1 | 2 | 0.000213 | 6 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| books-stock | steps | notes | clef-flash | c | no | failed | 1 | 1 | 3 | 0.001198 | 21 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | notes | clef-flash | c | no | error:headless | 2 | 2 | 4 | 0.000685 | 17.4 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | notes | clef-flash | c | no | error:headless | 1 | 1 | 2 | 0.000445 | 9.9 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| flights-oneway | goal | notes | clef-flash | c | no | done | 3 | 46 | 74 | 0.029625 | 214.8 | 4 | yes | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | clef-flash | c | yes | done | 1 | 3 | 10 | 0.002243 | 24.5 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | notes | clef-flash | c | yes | done | 1 | 4 | 8 | 0.002061 | 21.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | loose | notes | clef-flash | c | no | error:model-timeout | 4 | 47 | 78 | - | 270 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | steps | notes | clef-flash | c | yes | done | 1 | 3 | 7 | 0.002004 | 27 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | notes | clef-flash | c | no | error:headless | 2 | 5 | 9 | 0.001457 | 30.4 | 0 | no | message 'old' not quoted |
| flights-oneway | steps | notes | clef-flash | c | no | error | 6 | 101 | 136 | - | 303 | 4 | yes | truth 'pln 148'; result differs |
| portal-welcome | goal | notes | clef-flash | c | no | error:headless | 2 | 5 | 9 | 0.001254 | 26.5 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | notes | clef-flash | c | no | failed | 1 | 5 | 7 | 0.000862 | 13.5 | 0 | no | message 'new' not quoted |
| portal-welcome | steps | notes | clef-flash | c | no | error | 2 | 4 | 11 | - | 36.8 | 0 | no | message 'old' not quoted |
| u5-flights-roundtrip | loose | notes | clef-flash | c | no | done | 1 | 6 | 11 | 0.005134 | 42.5 | 1 | no | truth pattern not found on the source |
| u10-portal-new-message | loose | notes | clef-flash | c | no | limit | 6 | 14 | 27 | 0.00492 | 81.6 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | notes | clef-flash | c | no | error | 0 | 3 | 6 | - | 23.6 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | steps | notes | clef-flash | c | no | error | 0 | 4 | 7 | - | 27.5 | 0 | no | truth 'pln 306'; result differs |
| u10-portal-new-message | steps | notes | clef-flash | c | no | error:headless | 4 | 16 | 26 | 0.004903 | 88.1 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | notes | clef-flash | c | no | error | 0 | 0 | 2 | - | 17.8 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | goal | notes | clef-flash | c | no | error | 0 | 11 | 14 | - | 31.3 | 1 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | steps | notes | clef-flash | c | no | error:headless | 2 | 6 | 11 | 0.003991 | 50.3 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | goal | notes | clef-flash | c | no | error | 1 | 13 | 19 | - | 45.1 | 0 | no | registrations 0, confirmed False |
| u7-register | steps | notes | clef-flash | c | no | error:headless | 1 | 6 | 11 | 0.001433 | 23.5 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | notes | clef-flash | c | no | done | 0 | 4 | 4 | 0.001373 | 8.9 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u8-books-travel-jsonl | steps | notes | clef-flash | c | no | done | 1 | 3 | 5 | 0.002064 | 14.2 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u8-books-travel-jsonl | goal | notes | clef-flash | c | no | done | 2 | 8 | 13 | 0.004908 | 36.8 | 1 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | loose | notes | clef-flash | c | no | error:headless | 3 | 86 | 96 | 0.012881 | 142.9 | 0 | no | registrations 0, confirmed False |
| u9-upload | steps | notes | clef-flash | c | no | error:headless | 4 | 8 | 17 | 0.006292 | 100.1 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | notes | clef-flash | c | yes | done | 1 | 3 | 5 | 0.00237 | 18.3 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | notes | clef-flash | c | yes | done | 1 | 3 | 6 | 0.002839 | 16.1 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | notes | clef-flash | c | yes | done | 1 | 3 | 7 | 0.003322 | 18.7 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | clef-flash | c | yes | done | 1 | 4 | 7 | 0.003144 | 15.6 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | notes | clef-flash | c | yes | done | 1 | 3 | 5 | 0.00217 | 13.3 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef-flash | c | yes | done | 1 | 3 | 5 | 0.002151 | 13.3 | 0 | no | result names 'Charles Babbage' |
| u9-upload | goal | notes | clef-flash | c | no | limit | 6 | 202 | 211 | 0.029756 | 238.4 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | loose | notes | clef-flash | c | no | limit | 6 | 252 | 262 | 0.037886 | 299.1 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | goal | procedures | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000701 | 22.6 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | procedures | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000723 | 24.9 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | procedures | clef-flash | c | yes | done | 1 | 1 | 2 | 0.00129 | 34.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | procedures | clef-flash | c | yes | done | 2 | 20 | 40 | 0.010359 | 110.4 | 0 | yes | result names 'Blue Top' |
| ae-search-jeans | loose | procedures | clef-flash | c | yes | done | 1 | 25 | 33 | 0.007642 | 57.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | clef-flash | c | yes | done | 2 | 14 | 21 | 0.00464 | 51.7 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | clef-flash | c | yes | done | 1 | 3 | 6 | 0.001269 | 20.6 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | goal | procedures | clef-flash | c | no | failed | 6 | 54 | 96 | 0.025536 | 285.5 | 0 | yes | result lacks 'Blue Top' |
| ae-polo-brand | steps | procedures | clef-flash | c | no | failed | 6 | 49 | 95 | - | 284.6 | 0 | yes | result lacks 'Blue Top' |
| books-mystery-page2 | goal | procedures | clef-flash | c | no | blocked | 2 | 69 | 110 | 0.035469 | 218 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | clef-flash | c | no | blocked | 1 | 2 | 8 | 0.002402 | 23.2 | 0 | no | truth '19'; result differs |
| books-mystery-page2 | loose | procedures | clef-flash | c | no | error:model-timeout | 4 | 70 | 120 | - | 301.6 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | procedures | clef-flash | c | yes | done | 2 | 2 | 7 | 0.002392 | 22.7 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | procedures | clef-flash | c | yes | done | 1 | 2 | 3 | 0.000982 | 10.3 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | procedures | clef-flash | c | no | error:model-timeout | 3 | 71 | 113 | - | 293.3 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-jsonl | goal | procedures | clef-flash | c | no | error:model-timeout | 4 | 2 | 20 | - | 236.3 | 0 | no | 19 on the page, 247 in the file, 0 missing, 0 extra |
| books-price | loose | procedures | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000659 | 7.4 | 0 | no | result names '£51.77' |
| books-price | goal | procedures | clef-flash | c | yes | done | 1 | 1 | 2 | 0.000656 | 5.2 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | steps | procedures | clef-flash | c | no | error:model-timeout | 4 | 2 | 20 | - | 221.5 | 0 | no | 19 on the page, 247 in the file, 0 missing, 0 extra |
| books-poetry-jsonl | loose | procedures | clef-flash | c | no | error:model-timeout | 5 | 2 | 24 | - | 262 | 0 | no | 19 on the page, 304 in the file, 0 missing, 0 extra |
| books-stock | loose | procedures | clef-flash | c | no | failed | 1 | 1 | 2 | 0.001054 | 12.3 | 0 | no | truth '20'; result differs |
| books-price | steps | procedures | clef-flash | c | yes | failed | 1 | 1 | 2 | 0.002008 | 26.4 | 0 | no | result names '£51.77' |
| books-stock | goal | procedures | clef-flash | c | no | failed | 1 | 1 | 3 | 0.001669 | 22.8 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | procedures | clef-flash | c | no | error:headless | 1 | 1 | 2 | 0.000179 | 5.1 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| books-stock | steps | procedures | clef-flash | c | no | failed | 1 | 1 | 3 | 0.00143 | 18 | 0 | no | truth '20'; result differs |
| canvas-launch | goal | procedures | clef-flash | c | no | error:headless | 1 | 1 | 2 | 0.000228 | 5.9 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | procedures | clef-flash | c | no | error:headless | 1 | 1 | 2 | 0.000187 | 5.1 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| flights-oneway | steps | procedures | clef-flash | c | no | error | 1 | 4 | 9 | - | 28.4 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | procedures | clef-flash | c | yes | done | 2 | 3 | 10 | - | 38.1 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | loose | procedures | clef-flash | c | no | blocked | 2 | 30 | 55 | 0.019453 | 93.5 | 4 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | procedures | clef-flash | c | yes | done | 2 | 4 | 12 | - | 39.1 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | clef-flash | c | yes | done | 1 | 4 | 8 | 0.001719 | 25.8 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | procedures | clef-flash | c | no | error:headless | 1 | 3 | 7 | 0.000874 | 14.9 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | procedures | clef-flash | c | no | error:headless | 2 | 5 | 11 | 0.001552 | 24.5 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | procedures | clef-flash | c | no | error | 1 | 3 | 9 | - | 25.6 | 0 | no | message 'new' not quoted |
| portal-welcome | loose | procedures | clef-flash | c | no | limit | 6 | 25 | 47 | 0.006807 | 122.5 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | procedures | clef-flash | c | no | error:headless | 3 | 12 | 23 | 0.003166 | 51.2 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | procedures | clef-flash | c | no | error:headless | 2 | 5 | 11 | 0.001385 | 20.5 | 0 | no | message 'new' not quoted |
| flights-oneway | goal | procedures | clef-flash | c | no | limit | 6 | 69 | 110 | 0.020649 | 271.9 | 1 | yes | truth 'pln 148'; result differs |
| u5-flights-roundtrip | loose | procedures | clef-flash | c | no | error | 1 | 26 | 40 | - | 130.8 | 0 | yes | truth 'pln 306'; result differs |
| u5-flights-roundtrip | goal | procedures | clef-flash | c | no | error | 1 | 45 | 65 | - | 129.5 | 0 | yes | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | procedures | clef-flash | c | yes | done | 1 | 4 | 10 | 0.002322 | 28.6 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | procedures | clef-flash | c | yes | done | 1 | 4 | 9 | 0.002077 | 26.7 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | procedures | clef-flash | c | no | done | 2 | 6 | 13 | 0.004298 | 42.5 | 0 | no | names on a fresh Maps search: []; ratings [4.7] |
| u7-register | loose | procedures | clef-flash | c | no | error | 2 | 18 | 24 | - | 44.4 | 0 | no | registrations 0, confirmed False |
| u5-flights-roundtrip | steps | procedures | clef-flash | c | no | done | 3 | 43 | 70 | - | 204.9 | 0 | yes | truth 'pln 306'; result differs |
| u7-register | goal | procedures | clef-flash | c | no | error | 1 | 14 | 20 | - | 31.1 | 0 | no | registrations 0, confirmed False |
| u7-register | steps | procedures | clef-flash | c | no | error:headless | 4 | 26 | 38 | 0.006517 | 92.3 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | goal | procedures | clef-flash | c | no | error:model-timeout | 5 | 8 | 22 | - | 181.5 | 0 | no | 11 on the page, 53 in the file, 0 missing, 19 extra |
| u8-books-travel-jsonl | loose | procedures | clef-flash | c | no | error:model-timeout | 5 | 7 | 27 | - | 209.4 | 0 | no | 11 on the page, 110 in the file, 0 missing, 0 extra |
| u9-upload | goal | procedures | clef-flash | c | no | error | 2 | 99 | 108 | - | 114.1 | 2 | no | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | steps | procedures | clef-flash | c | no | error:model-timeout | 5 | 4 | 26 | - | 267.4 | 0 | no | 11 on the page, 154 in the file, 0 missing, 0 extra |
| u9-upload | steps | procedures | clef-flash | c | no | error:headless | 2 | 4 | 9 | 0.00256 | 41.6 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | procedures | clef-flash | c | yes | done | 1 | 4 | 9 | 0.004077 | 25.5 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef-flash | c | no | error | 0 | 0 | 2 | - | 12.6 | 0 | no | result lacks '10 December 1815' |
| wiki-ada-born | goal | procedures | clef-flash | c | yes | done | 1 | 4 | 8 | 0.003377 | 22.8 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | procedures | clef-flash | c | yes | done | 1 | 4 | 8 | 0.003137 | 18 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | procedures | clef-flash | c | yes | done | 1 | 5 | 11 | 0.004659 | 26.4 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef-flash | c | yes | done | 1 | 4 | 8 | 0.003246 | 19.2 | 0 | no | result names 'Charles Babbage' |
| u9-upload | loose | procedures | clef-flash | c | no | error | 5 | 270 | 285 | - | 299.9 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | steps | none | clef-flash | off | no | blocked | 1 | 2 | 3 | 0.0002 | 23 | 0 | no | truth 'rs. 500'; result differs |
| ae-blue-top-price | loose | none | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000683 | 25.6 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | none | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000672 | 25.7 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | clef-flash | off | no | failed | 1 | 2 | 8 | 0.002182 | 45.1 | 0 | yes | result lacks 'Blue Top' |
| ae-polo-brand | steps | none | clef-flash | off | yes | done | 1 | 4 | 12 | 0.003495 | 54.2 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | loose | none | clef-flash | off | no | error | 0 | 0 | 3 | - | 18.8 | 0 | no | result lacks 'Soft Stretch Jeans' |
| ae-polo-brand | loose | none | clef-flash | off | no | failed | 1 | 2 | 9 | 0.003833 | 72.5 | 0 | yes | result lacks 'Blue Top' |
| ae-search-jeans | steps | none | clef-flash | off | yes | done | 1 | 3 | 6 | 0.001062 | 18.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | clef-flash | off | no | error | 0 | 11 | 15 | - | 38.5 | 0 | yes | result lacks 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | none | clef-flash | off | yes | done | 1 | 5 | 8 | 0.002467 | 19.1 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | none | clef-flash | off | yes | done | 2 | 11 | 16 | 0.005118 | 37.1 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | none | clef-flash | off | yes | done | 1 | 5 | 8 | 0.00249 | 14.6 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | none | clef-flash | off | yes | done | 1 | 2 | 3 | 0.000916 | 5.7 | 0 | no | truth '19'; result agrees |
| books-poetry-count | loose | none | clef-flash | off | no | blocked | 1 | 5 | 6 | 0.001643 | 15.7 | 0 | no | truth '19'; result differs |
| books-poetry-count | steps | none | clef-flash | off | yes | done | 1 | 2 | 3 | 0.000924 | 9.7 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | none | clef-flash | off | no | done | 0 | 5 | 6 | 0.001729 | 10.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | none | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000633 | 5.2 | 0 | no | result names '£51.77' |
| books-price | goal | none | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000628 | 5.8 | 0 | no | result names '£51.77' |
| books-price | steps | none | clef-flash | off | yes | failed | 1 | 1 | 2 | 0.001146 | 14.4 | 0 | no | result names '£51.77' |
| books-stock | loose | none | clef-flash | off | no | failed | 1 | 1 | 3 | 0.000983 | 15.6 | 0 | no | truth '20'; result differs |
| books-stock | goal | none | clef-flash | off | no | failed | 1 | 1 | 2 | 0.00083 | 10.9 | 0 | no | truth '20'; result differs |
| books-poetry-jsonl | steps | none | clef-flash | off | no | error:model-timeout | 1 | 4 | 6 | - | 69 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | steps | none | clef-flash | off | no | failed | 1 | 1 | 2 | 0.000841 | 9.1 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | none | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.00021 | 6.3 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | none | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.000226 | 6.7 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | none | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.000203 | 5.2 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| flights-oneway | goal | none | clef-flash | off | no | error | 2 | 20 | 41 | - | 113.9 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | none | clef-flash | off | no | error | 3 | 35 | 56 | - | 151.1 | 0 | yes | truth 'pln 148'; result differs |
| flights-oneway | steps | none | clef-flash | off | no | done | 1 | 21 | 31 | 0.006572 | 56.8 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | clef-flash | off | yes | done | 1 | 3 | 9 | 0.002077 | 22.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | none | clef-flash | off | yes | done | 1 | 3 | 8 | 0.002016 | 21.4 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | clef-flash | off | yes | done | 1 | 3 | 7 | 0.001758 | 20 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | none | clef-flash | off | no | error:headless | 1 | 2 | 3 | 0.000649 | 10.1 | 0 | no | message 'old' not quoted |
| books-poetry-jsonl | goal | none | clef-flash | off | no | error:model-timeout | 4 | 41 | 64 | - | 300 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| u10-portal-new-message | loose | none | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.000571 | 13.6 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | goal | none | clef-flash | off | no | done | 1 | 4 | 6 | 0.000643 | 10.2 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | none | clef-flash | off | no | error | 1 | 6 | 12 | - | 28.2 | 0 | no | message 'new' not quoted |
| portal-welcome | steps | none | clef-flash | off | no | error | 4 | 14 | 26 | - | 76.3 | 0 | no | message 'old' not quoted |
| portal-welcome | loose | none | clef-flash | off | no | limit | 6 | 17 | 30 | 0.005109 | 98 | 0 | no | message 'old' not quoted |
| u5-flights-roundtrip | steps | none | clef-flash | off | no | error | 0 | 0 | 2 | - | 18.8 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | none | clef-flash | off | no | done | 1 | 3 | 8 | 0.00198 | 21.6 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [] |
| u5-flights-roundtrip | loose | none | clef-flash | off | no | done | 1 | 6 | 11 | 0.006723 | 71.1 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | goal | none | clef-flash | off | no | done | 1 | 8 | 12 | 0.006739 | 79.3 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | goal | none | clef-flash | off | no | blocked | 1 | 3 | 8 | 0.002053 | 30.2 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | steps | none | clef-flash | off | no | done | 1 | 6 | 11 | 0.003864 | 34.1 | 0 | no | names on a fresh Maps search: []; ratings [4.6] |
| u7-register | steps | none | clef-flash | off | no | error:headless | 2 | 9 | 13 | 0.001669 | 23.7 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | none | clef-flash | off | no | done | 0 | 3 | 4 | 0.001361 | 6.7 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | loose | none | clef-flash | off | no | error | 3 | 36 | 44 | - | 74.6 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | steps | none | clef-flash | off | no | done | 1 | 4 | 5 | 0.001856 | 14.8 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u8-books-travel-jsonl | goal | none | clef-flash | off | no | failed | 2 | 8 | 12 | 0.004749 | 44.3 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | loose | none | clef-flash | off | no | error | 2 | 14 | 17 | - | 40.3 | 0 | no | 0 upload(s); link None not in the result |
| u7-register | goal | none | clef-flash | off | no | error:headless | 5 | 57 | 78 | 0.008925 | 118.6 | 0 | no | registrations 0, confirmed False |
| wiki-ada-born | loose | none | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002815 | 17.3 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | none | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002176 | 16.3 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | none | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002815 | 14.2 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | none | clef-flash | off | yes | done | 1 | 3 | 5 | 0.002113 | 13.2 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | none | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002645 | 13.4 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002665 | 13.4 | 0 | no | result names 'Charles Babbage' |
| u9-upload | goal | none | clef-flash | off | no | error | 4 | 128 | 135 | - | 194.5 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | steps | none | clef-flash | off | no | error:model-timeout | 5 | 185 | 193 | - | 300 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | loose | notes | clef-flash | off | yes | done | 1 | 1 | 4 | 0.00108 | 32.5 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | notes | clef-flash | off | yes | done | 1 | 1 | 4 | 0.001095 | 33.8 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | notes | clef-flash | off | yes | done | 1 | 1 | 5 | 0.002753 | 68.9 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | notes | clef-flash | off | no | failed | 1 | 2 | 7 | 0.001765 | 35.3 | 0 | no | result lacks 'Blue Top' |
| ae-polo-brand | loose | notes | clef-flash | off | yes | done | 1 | 3 | 10 | 0.002589 | 43.5 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | notes | clef-flash | off | no | failed | 1 | 1 | 2 | 0.000899 | 17.4 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | steps | notes | clef-flash | off | yes | done | 1 | 3 | 6 | 0.001018 | 19.3 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | loose | notes | clef-flash | off | yes | done | 1 | 28 | 35 | 0.006889 | 67.7 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef-flash | off | no | blocked | 2 | 18 | 31 | 0.006299 | 69.5 | 0 | yes | result lacks 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | notes | clef-flash | off | yes | done | 3 | 12 | 19 | 0.006271 | 45.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | notes | clef-flash | off | yes | done | 1 | 5 | 8 | 0.002499 | 14.9 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | notes | clef-flash | off | yes | done | 1 | 5 | 7 | 0.002278 | 12.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | notes | clef-flash | off | yes | done | 1 | 2 | 3 | 0.000945 | 6.2 | 0 | no | truth '19'; result agrees |
| books-poetry-count | loose | notes | clef-flash | off | no | blocked | 1 | 4 | 7 | 0.002054 | 13.3 | 0 | no | truth '19'; result differs |
| books-poetry-count | steps | notes | clef-flash | off | yes | done | 1 | 2 | 3 | 0.000971 | 6.4 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | clef-flash | off | no | done | 0 | 5 | 6 | 0.001729 | 10 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | notes | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000685 | 5.3 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000662 | 6 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef-flash | off | yes | failed | 1 | 1 | 3 | 0.002615 | 45.2 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | steps | notes | clef-flash | off | no | done | 1 | 4 | 6 | 0.005273 | 66 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | goal | notes | clef-flash | off | no | failed | 1 | 1 | 3 | 0.001306 | 20.5 | 0 | no | truth '20'; result differs |
| books-stock | loose | notes | clef-flash | off | no | failed | 1 | 1 | 3 | 0.002027 | 27.3 | 0 | no | truth '20'; result differs |
| books-stock | steps | notes | clef-flash | off | no | failed | 1 | 1 | 3 | 0.00113 | 14 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | notes | clef-flash | off | no | error:headless | 2 | 2 | 4 | 0.00057 | 15.7 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | notes | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.000538 | 12 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | notes | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.000462 | 9.8 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| books-poetry-jsonl | goal | notes | clef-flash | off | no | error:model-timeout | 2 | 17 | 27 | - | 142.4 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | loose | notes | clef-flash | off | no | error | 1 | 8 | 17 | - | 47.3 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | clef-flash | off | yes | done | 1 | 3 | 10 | 0.002167 | 23.5 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | notes | clef-flash | off | no | error | 0 | 19 | 29 | - | 50.5 | 0 | yes | truth 'pln 148'; result differs |
| flights-oneway | goal | notes | clef-flash | off | no | done | 2 | 28 | 40 | 0.010134 | 76.6 | 0 | yes | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | notes | clef-flash | off | yes | done | 1 | 3 | 8 | 0.001675 | 22.3 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | clef-flash | off | yes | done | 1 | 3 | 8 | 0.002096 | 24.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | notes | clef-flash | off | no | error | 0 | 1 | 4 | - | 14.6 | 0 | no | message 'old' not quoted |
| portal-welcome | loose | notes | clef-flash | off | no | error:headless | 4 | 10 | 18 | 0.002537 | 46.7 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | notes | clef-flash | off | no | failed | 1 | 4 | 6 | 0.000721 | 12.8 | 0 | no | message 'new' not quoted |
| portal-welcome | goal | notes | clef-flash | off | no | error:headless | 3 | 7 | 13 | 0.002645 | 46.8 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | notes | clef-flash | off | no | error:headless | 5 | 10 | 20 | 0.003235 | 64.4 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | notes | clef-flash | off | no | error:headless | 3 | 11 | 19 | 0.002494 | 52.5 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | notes | clef-flash | off | no | done | 1 | 6 | 10 | 0.004248 | 53.3 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | notes | clef-flash | off | no | error | 0 | 0 | 3 | - | 19.5 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u5-flights-roundtrip | goal | notes | clef-flash | off | no | done | 1 | 8 | 13 | 0.007341 | 76.9 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | goal | notes | clef-flash | off | no | blocked | 1 | 5 | 10 | 0.002753 | 28 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | steps | notes | clef-flash | off | no | error:headless | 2 | 4 | 9 | 0.003487 | 53.4 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | notes | clef-flash | off | no | error | 1 | 23 | 27 | - | 58.6 | 0 | no | registrations 0, confirmed False |
| u7-register | steps | notes | clef-flash | off | no | error:headless | 3 | 44 | 60 | 0.00827 | 112.1 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | notes | clef-flash | off | no | done | 0 | 3 | 4 | 0.001361 | 9.6 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | goal | notes | clef-flash | off | no | error:headless | 4 | 50 | 67 | 0.009579 | 134.7 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | steps | notes | clef-flash | off | no | done | 1 | 4 | 5 | 0.0026 | 26.7 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u5-flights-roundtrip | steps | notes | clef-flash | off | no | error | 5 | 121 | 147 | - | 302.3 | 0 | yes | truth pattern not found on the source |
| u8-books-travel-jsonl | goal | notes | clef-flash | off | no | error:model-timeout | 3 | 12 | 20 | - | 154.1 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | steps | notes | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.000875 | 17.1 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | notes | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002836 | 18.1 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | notes | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002833 | 14.7 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | notes | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002852 | 16.4 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | clef-flash | off | yes | done | 1 | 3 | 6 | 0.00264 | 14.1 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | notes | clef-flash | off | yes | done | 1 | 3 | 6 | 0.00268 | 13.6 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef-flash | off | yes | done | 1 | 3 | 6 | 0.002687 | 14.3 | 0 | no | result names 'Charles Babbage' |
| u9-upload | loose | notes | clef-flash | off | no | error:model-timeout | 6 | 246 | 256 | - | 300 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | goal | notes | clef-flash | off | no | error | 6 | 271 | 282 | - | 300 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | loose | procedures | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000663 | 22.7 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | procedures | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000668 | 22.1 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | procedures | clef-flash | off | yes | failed | 1 | 1 | 3 | 0.001318 | 34.9 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | steps | procedures | clef-flash | off | no | failed | 1 | 1 | 3 | 0.002456 | 49.1 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | loose | procedures | clef-flash | off | yes | done | 2 | 26 | 35 | 0.007379 | 85.3 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-polo-brand | goal | procedures | clef-flash | off | no | error:headless | 4 | 20 | 33 | 0.0096 | 151.9 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | steps | procedures | clef-flash | off | yes | done | 1 | 3 | 6 | 0.001175 | 18.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | procedures | clef-flash | off | no | error | 3 | 34 | 65 | - | 196.5 | 0 | yes | result lacks 'Blue Top' |
| ae-search-jeans | goal | procedures | clef-flash | off | yes | done | 2 | 26 | 34 | 0.007369 | 74.5 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | procedures | clef-flash | off | no | blocked | 2 | 44 | 68 | - | 137.2 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | clef-flash | off | no | blocked | 1 | 2 | 8 | 0.002294 | 20.7 | 0 | no | truth '19'; result differs |
| books-mystery-page2 | steps | procedures | clef-flash | off | yes | failed | 3 | 13 | 25 | 0.012076 | 127.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | procedures | clef-flash | off | no | blocked | 1 | 2 | 8 | 0.002238 | 21.5 | 0 | no | truth '19'; result differs |
| books-poetry-count | steps | procedures | clef-flash | off | yes | done | 1 | 2 | 3 | 0.000989 | 7.5 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | procedures | clef-flash | off | no | blocked | 2 | 72 | 112 | 0.036583 | 222.2 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-jsonl | goal | procedures | clef-flash | off | no | error:model-timeout | 2 | 2 | 12 | - | 126.1 | 0 | no | 19 on the page, 133 in the file, 0 missing, 0 extra |
| books-price | loose | procedures | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000665 | 6 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | loose | procedures | clef-flash | off | no | error:model-timeout | 2 | 5 | 16 | - | 140 | 0 | no | 19 on the page, 95 in the file, 0 missing, 0 extra |
| books-price | goal | procedures | clef-flash | off | yes | done | 1 | 1 | 2 | 0.000661 | 5.3 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef-flash | off | yes | failed | 1 | 1 | 2 | 0.001171 | 17.8 | 0 | no | result names '£51.77' |
| books-stock | loose | procedures | clef-flash | off | no | failed | 1 | 1 | 2 | 0.001218 | 16.4 | 0 | no | truth '20'; result differs |
| books-stock | goal | procedures | clef-flash | off | no | failed | 1 | 1 | 2 | 0.000978 | 10.3 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | procedures | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.00015 | 5.4 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| books-stock | steps | procedures | clef-flash | off | no | failed | 1 | 1 | 3 | 0.001126 | 16.7 | 0 | no | truth '20'; result differs |
| canvas-launch | goal | procedures | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.000171 | 5.2 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | procedures | clef-flash | off | no | error:headless | 1 | 1 | 2 | 0.000297 | 7.6 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| books-poetry-jsonl | steps | procedures | clef-flash | off | no | error:model-timeout | 3 | 2 | 17 | - | 138.8 | 0 | no | 19 on the page, 190 in the file, 0 missing, 0 extra |
| flights-oneway | loose | procedures | clef-flash | off | no | failed | 2 | 11 | 16 | 0.00504 | 59.1 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | procedures | clef-flash | off | no | error | 1 | 20 | 40 | - | 84.3 | 0 | yes | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | procedures | clef-flash | off | yes | done | 1 | 4 | 9 | 0.00196 | 29.3 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | procedures | clef-flash | off | no | blocked | 2 | 9 | 24 | 0.005771 | 81.4 | 0 | yes | Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | steps | procedures | clef-flash | off | yes | done | 3 | 4 | 13 | - | 60.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | procedures | clef-flash | off | no | error:headless | 2 | 6 | 12 | 0.001405 | 25.8 | 0 | no | message 'old' not quoted |
| portal-welcome | loose | procedures | clef-flash | off | no | error:headless | 5 | 14 | 26 | 0.005736 | 101 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | procedures | clef-flash | off | no | error:headless | 4 | 12 | 22 | 0.004697 | 79.5 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | procedures | clef-flash | off | no | error:headless | 3 | 8 | 18 | 0.002362 | 44.6 | 0 | no | message 'new' not quoted |
| flights-oneway | steps | procedures | clef-flash | off | no | blocked | 3 | 81 | 121 | 0.029781 | 291.5 | 0 | yes | truth 'pln 148'; result differs |
| u10-portal-new-message | steps | procedures | clef-flash | off | no | error:headless | 2 | 5 | 11 | 0.001697 | 29.1 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | goal | procedures | clef-flash | off | no | done | 3 | 9 | 17 | 0.00301 | 59 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | procedures | clef-flash | off | no | error:model-timeout | 2 | 6 | 14 | - | 106.7 | 0 | no | truth 'pln 306'; result differs |
| u5-flights-roundtrip | steps | procedures | clef-flash | off | no | error:model-timeout | 1 | 20 | 31 | - | 122 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | procedures | clef-flash | off | yes | done | 2 | 3 | 11 | - | 44.2 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | procedures | clef-flash | off | yes | done | 1 | 5 | 13 | 0.003042 | 34.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | procedures | clef-flash | off | no | done | 2 | 6 | 16 | 0.005197 | 50.2 | 0 | no | names on a fresh Maps search: []; ratings [4.7] |
| u7-register | loose | procedures | clef-flash | off | no | error:headless | 2 | 15 | 20 | 0.002415 | 38.5 | 0 | no | registrations 0, confirmed False |
| u5-flights-roundtrip | goal | procedures | clef-flash | off | no | error:model-timeout | 3 | 97 | 124 | - | 300 | 0 | no | truth 'pln 306'; result differs |
| u7-register | goal | procedures | clef-flash | off | no | error | 3 | 44 | 62 | - | 94.2 | 0 | no | registrations 0, confirmed False |
| u7-register | steps | procedures | clef-flash | off | no | error:headless | 5 | 34 | 52 | 0.006774 | 92.3 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | procedures | clef-flash | off | no | error:model-timeout | 2 | 2 | 12 | - | 103.8 | 0 | no | 11 on the page, 77 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | goal | procedures | clef-flash | off | no | error:model-timeout | 2 | 2 | 12 | - | 114.7 | 0 | no | 11 on the page, 77 in the file, 0 missing, 0 extra |
| u9-upload | loose | procedures | clef-flash | off | no | error:headless | 3 | 74 | 81 | 0.011371 | 98.3 | 0 | no | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | steps | procedures | clef-flash | off | no | error:model-timeout | 6 | 1 | 25 | - | 240.1 | 0 | no | 11 on the page, 165 in the file, 0 missing, 0 extra |
| wiki-ada-born | loose | procedures | clef-flash | off | no | error | 0 | 0 | 2 | - | 15.5 | 0 | no | result lacks '10 December 1815' |
| wiki-ada-born | goal | procedures | clef-flash | off | yes | done | 2 | 3 | 13 | 0.004177 | 29.7 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef-flash | off | yes | done | 1 | 4 | 9 | 0.003964 | 21.1 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | clef-flash | off | yes | done | 1 | 5 | 11 | 0.0046 | 23.4 | 0 | no | result names 'Charles Babbage' |
| u9-upload | goal | procedures | clef-flash | off | no | limit | 6 | 314 | 328 | 0.043492 | 259.8 | 0 | no | 0 upload(s); link None not in the result |
| wiki-engine-designer | goal | procedures | clef-flash | off | yes | done | 2 | 3 | 12 | - | 32.5 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef-flash | off | yes | done | 1 | 4 | 8 | 0.003167 | 15.5 | 0 | no | result names 'Charles Babbage' |
| u9-upload | steps | procedures | clef-flash | off | no | error | 6 | 279 | 293 | - | 259.3 | 0 | no | 0 upload(s); link None not in the result |
| ae-blue-top-price | goal | none | clef | off | yes | done | 1 | 1 | 2 | 0.000911 | 27.9 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | none | clef | off | yes | done | 1 | 1 | 2 | 0.00095 | 29.4 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | none | clef | off | no | error | 0 | 2 | 4 | - | 36.7 | 0 | yes | truth 'rs. 500'; result differs |
| ae-polo-brand | goal | none | clef | off | yes | done | 1 | 2 | 6 | 0.003422 | 37.5 | 0 | yes | result names 'Blue Top' |
| ae-polo-brand | steps | none | clef | off | yes | done | 1 | 2 | 6 | 0.003468 | 32.4 | 0 | yes | result names 'Blue Top' |
| ae-search-jeans | loose | none | clef | off | yes | done | 1 | 3 | 7 | 0.002794 | 20.9 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | none | clef | off | no | failed | 1 | 1 | 3 | 0.003887 | 59.8 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | goal | none | clef | off | yes | done | 1 | 3 | 6 | 0.002352 | 22.9 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | clef | off | no | error | 0 | 1 | 4 | - | 13.8 | 0 | no | result lacks 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | clef | off | yes | done | 1 | 5 | 7 | 0.005342 | 20.9 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | none | clef | off | yes | done | 1 | 5 | 7 | 0.00535 | 17.6 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | clef | off | yes | done | 1 | 2 | 3 | 0.00191 | 7.2 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | none | clef | off | yes | done | 1 | 5 | 7 | 0.005417 | 15.4 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | none | clef | off | yes | done | 1 | 2 | 3 | 0.001924 | 8.2 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | none | clef | off | yes | done | 1 | 2 | 3 | 0.001972 | 8.5 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | none | clef | off | no | done | 0 | 5 | 6 | 0.004606 | 12.5 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | none | clef | off | yes | done | 1 | 1 | 2 | 0.001153 | 7.1 | 0 | no | result names '£51.77' |
| books-price | goal | none | clef | off | yes | done | 1 | 1 | 2 | 0.001155 | 7.8 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | goal | none | clef | off | no | failed | 1 | 5 | 7 | 0.005976 | 32.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | steps | none | clef | off | yes | done | 1 | 2 | 3 | 0.001362 | 8.5 | 0 | no | result names '£51.77' |
| books-stock | goal | none | clef | off | no | failed | 1 | 1 | 2 | 0.001262 | 7.8 | 0 | no | truth '20'; result differs |
| books-stock | loose | none | clef | off | no | failed | 1 | 1 | 2 | 0.001524 | 12.6 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | none | clef | off | no | error:headless | 1 | 1 | 2 | 0.000235 | 4.8 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | none | clef | off | no | error:headless | 1 | 1 | 2 | 0.000258 | 4.9 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| books-stock | steps | none | clef | off | yes | done | 1 | 2 | 3 | 0.001453 | 10.3 | 0 | no | truth '20'; result agrees |
| canvas-launch | steps | none | clef | off | no | error:headless | 1 | 1 | 2 | 0.000317 | 8 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| books-poetry-jsonl | steps | none | clef | off | no | error:model-timeout | 1 | 4 | 6 | - | 71 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | none | clef | off | no | done | 1 | 11 | 16 | 0.01201 | 41.1 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | none | clef | off | no | done | 1 | 14 | 21 | 0.017178 | 59.7 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | clef | off | yes | done | 1 | 3 | 11 | 0.006235 | 27.2 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | none | clef | off | yes | done | 1 | 8 | 16 | 0.010796 | 62.6 | 0 | no | truth 'pln 148'; result agrees |
| maps-eiffel-postcode | goal | none | clef | off | yes | done | 1 | 3 | 8 | 0.00461 | 24 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | clef | off | no | error | 0 | 0 | 2 | - | 9.7 | 0 | no | Wikidata P281 ['75007']; result differs |
| portal-welcome | steps | none | clef | off | no | error:headless | 2 | 8 | 13 | 0.003367 | 32.7 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | none | clef | off | no | error:headless | 1 | 1 | 2 | 0.000588 | 8.6 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | goal | none | clef | off | no | error | 0 | 0 | 1 | - | 2.1 | 0 | no | message 'new' not quoted |
| portal-welcome | loose | none | clef | off | no | error:headless | 6 | 11 | 22 | 0.006834 | 88.1 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | none | clef | off | no | limit | 6 | 14 | 27 | 0.007678 | 89.3 | 0 | no | message 'old' not quoted |
| u5-flights-roundtrip | loose | none | clef | off | no | error | 0 | 2 | 5 | - | 24.8 | 0 | no | truth 'pln 306'; result differs |
| u10-portal-new-message | steps | none | clef | off | no | error:headless | 4 | 13 | 22 | 0.006526 | 77.3 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | none | clef | off | no | error | 0 | 16 | 21 | - | 49 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | none | clef | off | no | error | 0 | 0 | 2 | - | 18.1 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | steps | none | clef | off | no | error | 0 | 4 | 7 | - | 22 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | none | clef | off | no | error:headless | 1 | 2 | 4 | 0.000857 | 11.6 | 0 | no | registrations 0, confirmed False |
| u5-flights-roundtrip | steps | none | clef | off | no | done | 1 | 18 | 28 | 0.034952 | 94.9 | 0 | no | truth 'pln 306'; result differs |
| u7-register | goal | none | clef | off | no | error:headless | 1 | 2 | 4 | 0.001019 | 12.2 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | none | clef | off | no | done | 0 | 3 | 4 | 0.003629 | 9.5 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u6-maps-cafe | goal | none | clef | off | no | error | 0 | 22 | 31 | - | 84 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | steps | none | clef | off | no | error:headless | 1 | 7 | 11 | 0.002872 | 24 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | goal | none | clef | off | no | failed | 1 | 3 | 5 | 0.004923 | 27.1 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | loose | none | clef | off | no | error:headless | 2 | 2 | 4 | 0.001406 | 19.8 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | goal | none | clef | off | no | error:headless | 2 | 2 | 4 | 0.001208 | 16 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | steps | none | clef | off | no | error:headless | 2 | 2 | 4 | 0.001958 | 29 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | none | clef | off | no | error | 0 | 0 | 2 | - | 15.8 | 0 | no | result lacks '10 December 1815' |
| wiki-ada-born | steps | none | clef | off | no | error | 0 | 0 | 2 | - | 13.9 | 0 | no | result lacks '10 December 1815' |
| u8-books-travel-jsonl | steps | none | clef | off | no | error:model-timeout | 1 | 3 | 5 | - | 69.3 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| wiki-ada-born | goal | none | clef | off | yes | done | 1 | 3 | 6 | 0.006592 | 21.9 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | none | clef | off | no | error | 0 | 0 | 3 | 0.001528 | 8.5 | 0 | no | result lacks 'Charles Babbage' |
| wiki-engine-designer | loose | none | clef | off | yes | done | 1 | 3 | 6 | 0.006194 | 21.6 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef | off | yes | done | 1 | 3 | 6 | 0.0063 | 23.6 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | notes | clef | off | yes | done | 1 | 1 | 4 | 0.002121 | 36.6 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | notes | clef | off | no | error | 0 | 0 | 5 | - | 43.5 | 0 | yes | truth 'rs. 500'; result differs |
| ae-polo-brand | loose | notes | clef | off | no | error | 0 | 1 | 5 | - | 23.6 | 0 | no | result lacks 'Blue Top' |
| ae-polo-brand | goal | notes | clef | off | yes | done | 1 | 2 | 5 | 0.002945 | 26.3 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | notes | clef | off | yes | done | 1 | 2 | 4 | 0.002691 | 21.8 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | loose | notes | clef | off | yes | done | 1 | 3 | 6 | 0.002323 | 21.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef | off | yes | done | 1 | 3 | 6 | 0.002328 | 23.5 | 0 | yes | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | clef | off | yes | done | 1 | 3 | 9 | 0.003572 | 30.1 | 0 | yes | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | notes | clef | off | yes | done | 1 | 5 | 7 | 0.005394 | 19.1 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | notes | clef | off | yes | done | 1 | 5 | 6 | 0.004205 | 14.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | notes | clef | off | yes | done | 1 | 5 | 7 | 0.005408 | 19.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | clef | off | yes | done | 1 | 2 | 3 | 0.001934 | 9.3 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef | off | yes | done | 1 | 2 | 3 | 0.001972 | 7.8 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | notes | clef | off | yes | done | 1 | 2 | 4 | 0.002038 | 10.6 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | clef | off | no | done | 0 | 5 | 5 | 0.004043 | 10.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | goal | notes | clef | off | no | done | 1 | 5 | 7 | 0.005108 | 17.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | notes | clef | off | yes | done | 1 | 1 | 2 | 0.001175 | 5.4 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef | off | yes | done | 1 | 1 | 2 | 0.001164 | 6.2 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef | off | yes | done | 1 | 2 | 3 | 0.001384 | 6.9 | 0 | no | result names '£51.77' |
| books-stock | loose | notes | clef | off | no | failed | 1 | 1 | 3 | 0.001606 | 15.5 | 0 | no | truth '20'; result differs |
| books-stock | goal | notes | clef | off | no | failed | 1 | 1 | 2 | 0.001241 | 14.4 | 0 | no | truth '20'; result differs |
| books-stock | steps | notes | clef | off | yes | done | 1 | 2 | 3 | 0.001453 | 6.8 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | steps | notes | clef | off | no | error:model-timeout | 1 | 8 | 9 | - | 78.6 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| canvas-launch | loose | notes | clef | off | no | error:headless | 1 | 1 | 2 | 0.00075 | 15.4 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | notes | clef | off | no | error:headless | 1 | 1 | 2 | 0.000371 | 7.4 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | notes | clef | off | no | error:headless | 1 | 1 | 2 | 0.000412 | 8.1 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| flights-oneway | goal | notes | clef | off | no | error | 0 | 9 | 13 | - | 23.3 | 0 | no | truth 'pln 148'; result differs |
| ae-blue-top-price | steps | notes | clef | off | yes | done | 1 | 43 | 116 | 0.062792 | 299.3 | 0 | yes | truth 'rs. 500'; result agrees |
| flights-oneway | loose | notes | clef | off | no | done | 1 | 14 | 20 | 0.015809 | 52.8 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | clef | off | yes | done | 1 | 3 | 10 | 0.005138 | 22.5 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | notes | clef | off | no | error | 0 | 5 | 9 | - | 28.3 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | notes | clef | off | yes | done | 1 | 3 | 8 | 0.004548 | 22.1 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | clef | off | yes | done | 1 | 4 | 9 | 0.006916 | 26.3 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | notes | clef | off | no | error:headless | 2 | 4 | 8 | 0.001869 | 20.7 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | notes | clef | off | no | error:headless | 2 | 3 | 6 | 0.001885 | 23 | 0 | no | message 'new' not quoted |
| portal-welcome | steps | notes | clef | off | no | error:headless | 3 | 10 | 17 | 0.004397 | 45.2 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | notes | clef | off | no | error | 0 | 0 | 2 | - | 11.8 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | notes | clef | off | no | error | 0 | 4 | 7 | - | 18.8 | 0 | no | truth 'pln 306'; result differs |
| portal-welcome | loose | notes | clef | off | no | error | 5 | 13 | 25 | - | 117.1 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | notes | clef | off | no | error | 2 | 14 | 23 | - | 51.5 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | notes | clef | off | no | done | 1 | 11 | 15 | 0.014286 | 54.1 | 0 | yes | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | notes | clef | off | no | error | 1 | 3 | 10 | - | 46.6 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | steps | notes | clef | off | no | error | 0 | 1 | 5 | - | 15 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u5-flights-roundtrip | steps | notes | clef | off | no | done | 1 | 18 | 32 | 0.042593 | 91.1 | 0 | no | truth 'pln 306'; result differs |
| u7-register | loose | notes | clef | off | no | error:headless | 1 | 2 | 4 | 0.000927 | 10.8 | 0 | no | registrations 0, confirmed False |
| u7-register | goal | notes | clef | off | no | error:headless | 1 | 2 | 4 | 0.001025 | 13.3 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | loose | notes | clef | off | no | done | 0 | 3 | 4 | 0.003629 | 10.2 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u7-register | steps | notes | clef | off | no | error:headless | 1 | 5 | 10 | 0.002247 | 23.7 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | steps | notes | clef | off | no | done | 1 | 3 | 5 | 0.005054 | 30 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u6-maps-cafe | goal | notes | clef | off | no | error | 0 | 35 | 54 | - | 140.6 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u8-books-travel-jsonl | goal | notes | clef | off | no | error:model-timeout | 1 | 3 | 5 | - | 68.5 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | loose | notes | clef | off | no | error:headless | 2 | 2 | 4 | 0.002703 | 44.2 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | notes | clef | off | yes | done | 1 | 3 | 5 | 0.004863 | 19.3 | 0 | no | result names '10 December 1815' |
| u9-upload | goal | notes | clef | off | no | error:headless | 2 | 3 | 5 | 0.003005 | 43.9 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | goal | notes | clef | off | yes | done | 1 | 3 | 6 | 0.006655 | 17.9 | 0 | no | result names '10 December 1815' |
| u9-upload | steps | notes | clef | off | no | error:headless | 2 | 2 | 4 | 0.003362 | 54.4 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | steps | notes | clef | off | yes | done | 1 | 3 | 6 | 0.006635 | 17.9 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | notes | clef | off | no | error | 0 | 2 | 5 | - | 11.6 | 0 | no | result lacks 'Charles Babbage' |
| wiki-engine-designer | loose | notes | clef | off | yes | done | 1 | 3 | 6 | 0.006221 | 17.7 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef | off | yes | done | 1 | 3 | 5 | 0.00472 | 13.9 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | loose | procedures | clef | off | no | error | 0 | 0 | 2 | - | 24.9 | 0 | no | truth 'rs. 500'; result differs |
| ae-blue-top-price | goal | procedures | clef | off | yes | done | 1 | 1 | 5 | 0.00303 | 39.3 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | procedures | clef | off | yes | done | 1 | 5 | 20 | 0.014645 | 92.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | steps | procedures | clef | off | yes | done | 1 | 2 | 5 | 0.003257 | 21.2 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | goal | procedures | clef | off | no | error | 1 | 14 | 27 | - | 79.2 | 0 | yes | result lacks 'Blue Top' |
| ae-search-jeans | loose | procedures | clef | off | yes | done | 2 | 3 | 11 | - | 50.8 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | clef | off | no | blocked | 1 | 3 | 10 | 0.004048 | 44 | 0 | yes | result lacks 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | clef | off | no | blocked | 1 | 3 | 8 | 0.002925 | 31.1 | 0 | no | result lacks 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | procedures | clef | off | no | blocked | 1 | 7 | 13 | 0.010915 | 55.4 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-polo-brand | loose | procedures | clef | off | no | error | 1 | 44 | 75 | - | 226.5 | 0 | yes | result lacks 'Blue Top' |
| books-poetry-count | loose | procedures | clef | off | yes | done | 1 | 3 | 6 | 0.003632 | 15 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | procedures | clef | off | yes | done | 2 | 11 | 18 | 0.013863 | 52.1 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | steps | procedures | clef | off | yes | done | 1 | 2 | 3 | 0.002032 | 7.8 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | procedures | clef | off | yes | done | 1 | 3 | 6 | 0.003636 | 16.2 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | procedures | clef | off | yes | done | 3 | 13 | 24 | 0.019742 | 112.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-jsonl | loose | procedures | clef | off | no | error | 4 | 10 | 28 | - | 149.4 | 0 | no | 19 on the page, 152 in the file, 0 missing, 0 extra |
| books-price | loose | procedures | clef | off | yes | done | 1 | 1 | 2 | 0.001182 | 9.4 | 0 | no | result names '£51.77' |
| books-price | goal | procedures | clef | off | yes | done | 1 | 1 | 2 | 0.001166 | 9.9 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef | off | yes | done | 1 | 2 | 3 | 0.001517 | 8.9 | 0 | no | result names '£51.77' |
| books-stock | loose | procedures | clef | off | no | failed | 1 | 1 | 2 | 0.001303 | 8.8 | 0 | no | truth '20'; result differs |
| books-poetry-jsonl | goal | procedures | clef | off | no | failed | 4 | 9 | 26 | 0.02447 | 192.6 | 0 | no | 19 on the page, 190 in the file, 0 missing, 0 extra |
| books-stock | steps | procedures | clef | off | yes | done | 1 | 2 | 3 | 0.00151 | 8 | 0 | no | truth '20'; result agrees |
| books-stock | goal | procedures | clef | off | no | failed | 1 | 1 | 2 | 0.001575 | 13.6 | 0 | no | truth '20'; result differs |
| canvas-launch | loose | procedures | clef | off | no | error:headless | 1 | 1 | 2 | 0.000264 | 6.1 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | procedures | clef | off | no | error:headless | 1 | 1 | 2 | 0.000297 | 5.5 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | procedures | clef | off | no | error:headless | 1 | 1 | 2 | 0.000327 | 6.3 | 0 | no | 0 canvas click(s), 0 inside the drawn button |
| flights-oneway | goal | procedures | clef | off | no | done | 1 | 12 | 17 | 0.01297 | 40.1 | 0 | yes | truth 'pln 148'; result differs |
| flights-oneway | loose | procedures | clef | off | no | done | 2 | 28 | 35 | 0.024291 | 82.9 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | steps | procedures | clef | off | no | error | 1 | 2 | 10 | - | 40.6 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | steps | procedures | clef | off | no | error:model-timeout | 3 | 69 | 113 | - | 300 | 0 | no | 19 on the page, 95 in the file, 0 missing, 0 extra |
| maps-eiffel-postcode | goal | procedures | clef | off | yes | done | 1 | 4 | 10 | 0.005339 | 33.4 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | procedures | clef | off | yes | done | 2 | 5 | 17 | - | 49 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | procedures | clef | off | no | error:headless | 1 | 4 | 8 | 0.001843 | 13.8 | 0 | no | message 'old' not quoted |
| maps-eiffel-postcode | steps | procedures | clef | off | yes | done | 1 | 5 | 12 | 0.008522 | 36.4 | 0 | yes | Wikidata P281 ['75007']; result agrees |
| u10-portal-new-message | loose | procedures | clef | off | no | error:headless | 1 | 4 | 8 | 0.001774 | 13.7 | 0 | no | message 'new' not quoted |
| portal-welcome | steps | procedures | clef | off | no | error:headless | 2 | 6 | 12 | 0.002924 | 25 | 0 | no | message 'old' not quoted |
| portal-welcome | loose | procedures | clef | off | no | error:headless | 2 | 5 | 10 | 0.004231 | 52.6 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | procedures | clef | off | no | error:headless | 1 | 4 | 8 | 0.001834 | 13.4 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | procedures | clef | off | no | error:headless | 5 | 12 | 24 | 0.006655 | 68.2 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | procedures | clef | off | no | error | 1 | 60 | 69 | - | 144.1 | 0 | no | truth pattern not found on the source |
| u5-flights-roundtrip | goal | procedures | clef | off | no | done | 3 | 76 | 88 | - | 193.1 | 0 | yes | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | procedures | clef | off | no | done | 2 | 7 | 18 | - | 59.6 | 0 | no | names on a fresh Maps search: []; ratings [4.7] |
| u6-maps-cafe | goal | procedures | clef | off | no | blocked | 1 | 6 | 16 | 0.010318 | 69 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | procedures | clef | off | no | error | 0 | 1 | 3 | - | 3.9 | 0 | no | registrations 0, confirmed False |
| u5-flights-roundtrip | steps | procedures | clef | off | no | error | 1 | 81 | 104 | - | 215.8 | 0 | no | truth 'pln 306'; result differs |
| u6-maps-cafe | steps | procedures | clef | off | no | done | 2 | 8 | 18 | 0.014194 | 73 | 0 | no | names on a fresh Maps search: []; ratings [4.7] |
| u7-register | steps | procedures | clef | off | no | error:headless | 1 | 7 | 14 | 0.00318 | 27.2 | 0 | no | registrations 0, confirmed False |
| u7-register | goal | procedures | clef | off | no | error | 1 | 6 | 14 | - | 60.1 | 0 | no | registrations 0, confirmed False |
| u8-books-travel-jsonl | goal | procedures | clef | off | no | failed | 2 | 5 | 13 | 0.012773 | 82.2 | 0 | no | 11 on the page, 33 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | loose | procedures | clef | off | no | error:model-timeout | 3 | 5 | 18 | - | 122.2 | 0 | no | 11 on the page, 88 in the file, 0 missing, 0 extra |
| u9-upload | goal | procedures | clef | off | no | error:headless | 2 | 3 | 5 | 0.001583 | 15.6 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | loose | procedures | clef | off | no | error:headless | 2 | 2 | 4 | 0.002416 | 39.7 | 0 | no | 0 upload(s); link None not in the result |
| u9-upload | steps | procedures | clef | off | no | error:headless | 2 | 2 | 4 | 0.001697 | 23 | 0 | no | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | procedures | clef | off | yes | done | 1 | 4 | 8 | 0.007709 | 24 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef | off | yes | done | 1 | 4 | 8 | 0.008059 | 23 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | procedures | clef | off | yes | done | 2 | 3 | 11 | - | 37.8 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | clef | off | yes | done | 1 | 4 | 9 | 0.009531 | 26.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | procedures | clef | off | yes | done | 2 | 3 | 9 | 0.006748 | 22 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef | off | yes | done | 2 | 3 | 9 | - | 33 | 0 | no | result names 'Charles Babbage' |
| u8-books-travel-jsonl | steps | procedures | clef | off | no | error | 3 | 41 | 82 | - | 240.4 | 0 | no | 11 on the page, 99 in the file, 0 missing, 0 extra |
| ae-blue-top-price | loose | none | jev | off | yes | done | 1 | 1 | 2 | 0.000572 | 27.1 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | none | jev | off | yes | done | 1 | 1 | 2 | 0.000563 | 26.5 | 0 | - | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | jev | off | no | failed | 1 | 1 | 2 | 0.000984 | 20.8 | 0 | - | result lacks 'Blue Top' |
| ae-polo-brand | loose | none | jev | off | no | failed | 1 | 1 | 3 | 0.001921 | 38.5 | 0 | - | result lacks 'Blue Top' |
| ae-polo-brand | steps | none | jev | off | no | failed | 1 | 1 | 2 | 0.001339 | 22.1 | 0 | - | result lacks 'Blue Top' |
| ae-search-jeans | loose | none | jev | off | yes | done | 1 | 4 | 11 | 0.001551 | 27.1 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | jev | off | yes | done | 1 | 3 | 8 | 0.001178 | 22.4 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | jev | off | no | failed | 1 | 3 | 4 | 0.001252 | 13.8 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| ae-search-jeans | steps | none | jev | off | yes | done | 1 | 3 | 6 | 0.000897 | 19.5 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | none | jev | off | no | failed | 1 | 3 | 4 | 0.001381 | 12.5 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | none | jev | off | no | failed | 1 | 3 | 5 | 0.001397 | 11.8 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | jev | off | yes | done | 1 | 2 | 3 | 0.000758 | 6.9 | 0 | - | truth '19'; result agrees |
| books-poetry-count | goal | none | jev | off | yes | done | 1 | 2 | 3 | 0.000747 | 6.6 | 0 | - | truth '19'; result agrees |
| books-poetry-count | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000753 | 6.6 | 0 | - | truth '19'; result agrees |
| ae-blue-top-price | steps | none | jev | off | no | error:model-timeout | 2 | 2 | 243 | - | 300 | 0 | - | truth 'rs. 500'; result differs |
| books-poetry-jsonl | steps | none | jev | off | no | error:model-timeout | 1 | 3 | 5 | - | 65.6 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | loose | none | jev | off | no | error:model-timeout | 3 | 44 | 72 | - | 232.1 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | none | jev | off | yes | done | 1 | 1 | 2 | 0.00054 | 5.8 | 0 | - | result names '£51.77' |
| books-price | goal | none | jev | off | yes | done | 1 | 1 | 2 | 0.000551 | 5.5 | 0 | - | result names '£51.77' |
| books-price | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000544 | 7.2 | 0 | - | result names '£51.77' |
| books-stock | loose | none | jev | off | yes | done | 1 | 2 | 3 | 0.000599 | 6.9 | 0 | - | truth '20'; result agrees |
| books-stock | goal | none | jev | off | yes | done | 1 | 2 | 3 | 0.000545 | 7.3 | 0 | - | truth '20'; result agrees |
| books-stock | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000537 | 8.4 | 0 | - | truth '20'; result agrees |
| canvas-launch | loose | none | jev | off | no | error:headless | 1 | 1 | 2 | 0.000155 | 5.2 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | none | jev | off | no | error:headless | 1 | 1 | 2 | 0.000157 | 4.7 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | none | jev | off | no | error:headless | 1 | 1 | 2 | 0.000195 | 5.9 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| flights-oneway | loose | none | jev | off | no | done | 1 | 14 | 20 | 0.004006 | 43.4 | 0 | - | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | none | jev | off | no | error | 4 | 90 | 148 | - | 301 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | none | jev | off | no | done | 2 | 16 | 26 | 0.006489 | 73.9 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | jev | off | yes | done | 1 | 3 | 11 | 0.001916 | 28 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | none | jev | off | no | error | 0 | 0 | 3 | - | 18.2 | 0 | - | Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | steps | none | jev | off | yes | done | 1 | 3 | 6 | 0.001192 | 18 | 0 | - | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | none | jev | off | no | error:headless | 1 | 4 | 6 | 0.001229 | 21 | 0 | - | message 'old' not quoted |
| flights-oneway | steps | none | jev | off | no | done | 1 | 31 | 50 | 0.010287 | 89.7 | 0 | - | truth 'pln 148'; result differs |
| u10-portal-new-message | loose | none | jev | off | no | error:headless | 1 | 1 | 2 | 0.000574 | 13.1 | 0 | - | message 'new' not quoted |
| portal-welcome | steps | none | jev | off | no | error | 1 | 18 | 25 | - | 36 | 0 | - | message 'old' not quoted |
| portal-welcome | loose | none | jev | off | no | error | 5 | 14 | 28 | - | 104.4 | 0 | - | message 'old' not quoted |
| u10-portal-new-message | goal | none | jev | off | no | error:headless | 5 | 10 | 20 | 0.003305 | 70.6 | 0 | - | message 'new' not quoted |
| u5-flights-roundtrip | loose | none | jev | off | no | done | 1 | 10 | 15 | 0.003848 | 38.4 | 0 | - | truth pattern not found on the source |
| u10-portal-new-message | steps | none | jev | off | no | limit | 6 | 14 | 27 | 0.004556 | 92.5 | 0 | - | message 'new' not quoted |
| u5-flights-roundtrip | goal | none | jev | off | no | done | 1 | 17 | 27 | 0.007761 | 48.4 | 0 | - | truth 'pln 306'; result differs |
| u5-flights-roundtrip | steps | none | jev | off | no | done | 1 | 26 | 39 | 0.014544 | 67.6 | 0 | - | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | none | jev | off | no | error:headless | 3 | 51 | 81 | 0.015625 | 116.3 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | goal | none | jev | off | no | error:headless | 3 | 51 | 84 | 0.016811 | 123.7 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | none | jev | off | no | error:headless | 1 | 2 | 4 | 0.001774 | 33 | 0 | - | registrations 0, confirmed False |
| u7-register | steps | none | jev | off | no | error:headless | 1 | 2 | 5 | 0.000582 | 12.9 | 0 | - | registrations 0, confirmed False |
| u7-register | goal | none | jev | off | no | error:headless | 1 | 2 | 4 | 0.001084 | 20.1 | 0 | - | registrations 0, confirmed False |
| u6-maps-cafe | steps | none | jev | off | no | error:headless | 3 | 89 | 119 | 0.020279 | 167.6 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u8-books-travel-jsonl | steps | none | jev | off | no | done | 1 | 3 | 5 | 0.001404 | 11 | 0 | - | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | loose | none | jev | off | no | error:headless | 2 | 10 | 12 | 0.001614 | 28.1 | 0 | - | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | goal | none | jev | off | no | error:model-timeout | 3 | 28 | 38 | - | 153.8 | 0 | - | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | steps | none | jev | off | no | error:headless | 2 | 2 | 4 | 0.001571 | 27.7 | 0 | - | 0 upload(s); link None not in the result |
| u8-books-travel-jsonl | loose | none | jev | off | no | error:model-timeout | 2 | 63 | 78 | - | 192.4 | 0 | - | 11 on the page, 0 in the file, 11 missing, 0 extra |
| wiki-ada-born | loose | none | jev | off | yes | done | 1 | 3 | 6 | 0.002195 | 16.4 | 0 | - | result names '10 December 1815' |
| wiki-ada-born | goal | none | jev | off | yes | done | 1 | 3 | 7 | 0.002086 | 15.5 | 0 | - | result names '10 December 1815' |
| wiki-ada-born | steps | none | jev | off | yes | done | 1 | 3 | 5 | 0.001789 | 12.7 | 0 | - | result names '10 December 1815' |
| wiki-engine-designer | loose | none | jev | off | yes | done | 1 | 3 | 5 | 0.001653 | 12 | 0 | - | result names 'Charles Babbage' |
| u9-upload | goal | none | jev | off | no | error:headless | 2 | 120 | 124 | 0.011751 | 122.2 | 0 | - | 0 upload(s); link None not in the result |
| wiki-engine-designer | goal | none | jev | off | yes | done | 1 | 3 | 5 | 0.00164 | 10.4 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | jev | off | yes | done | 1 | 3 | 5 | 0.00165 | 12.1 | 0 | - | result names 'Charles Babbage' |
| ae-blue-top-price | loose | notes | jev | off | yes | done | 1 | 1 | 3 | 0.00073 | 32 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | notes | jev | off | yes | done | 1 | 1 | 5 | 0.000977 | 35.4 | 0 | - | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | notes | jev | off | no | failed | 1 | 1 | 3 | 0.001033 | 24.7 | 0 | - | result lacks 'Blue Top' |
| ae-polo-brand | goal | notes | jev | off | no | failed | 1 | 1 | 3 | 0.001315 | 32.5 | 0 | - | result lacks 'Blue Top' |
| ae-polo-brand | steps | notes | jev | off | no | failed | 1 | 1 | 2 | 0.000998 | 14.6 | 0 | - | result lacks 'Blue Top' |
| ae-search-jeans | loose | notes | jev | off | yes | done | 1 | 3 | 6 | 0.00087 | 17.9 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-blue-top-price | steps | notes | jev | off | yes | done | 1 | 5 | 32 | 0.00499 | 93.6 | 0 | - | truth 'rs. 500'; result agrees |
| ae-search-jeans | goal | notes | jev | off | yes | done | 1 | 3 | 6 | 0.001018 | 20.7 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | jev | off | yes | done | 1 | 3 | 6 | 0.000891 | 19 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | notes | jev | off | no | failed | 1 | 3 | 5 | 0.001364 | 16.4 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | notes | jev | off | no | failed | 1 | 3 | 5 | 0.001383 | 13.5 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000759 | 7.2 | 0 | - | truth '19'; result agrees |
| books-poetry-count | goal | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000753 | 7 | 0 | - | truth '19'; result agrees |
| books-mystery-page2 | steps | notes | jev | off | no | failed | 1 | 3 | 5 | 0.001615 | 12.3 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-count | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000772 | 7 | 0 | - | truth '19'; result agrees |
| books-poetry-jsonl | steps | notes | jev | off | no | done | 1 | 4 | 6 | 0.003491 | 43.6 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | notes | jev | off | yes | done | 1 | 1 | 2 | 0.00055 | 5.1 | 0 | - | result names '£51.77' |
| books-price | goal | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000566 | 4.6 | 0 | - | result names '£51.77' |
| books-price | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000601 | 8.5 | 0 | - | result names '£51.77' |
| books-stock | loose | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000548 | 9.3 | 0 | - | truth '20'; result agrees |
| books-stock | goal | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000569 | 6.5 | 0 | - | truth '20'; result agrees |
| books-stock | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000542 | 6.2 | 0 | - | truth '20'; result agrees |
| canvas-launch | loose | notes | jev | off | no | error:headless | 2 | 2 | 4 | 0.000948 | 24 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | notes | jev | off | no | error:headless | 1 | 1 | 2 | 0.000176 | 5.3 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | notes | jev | off | no | error:headless | 1 | 1 | 2 | 0.000248 | 6.2 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| books-poetry-jsonl | goal | notes | jev | off | no | error:headless | 3 | 18 | 24 | 0.009406 | 134.8 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | loose | notes | jev | off | no | error:headless | 2 | 67 | 79 | 0.017389 | 138.2 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | notes | jev | off | no | error | 0 | 2 | 5 | - | 18.7 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | loose | notes | jev | off | no | done | 1 | 15 | 22 | 0.004774 | 42.7 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | jev | off | yes | done | 1 | 3 | 11 | 0.001933 | 22.1 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | notes | jev | off | yes | done | 1 | 3 | 9 | 0.001754 | 22.3 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | jev | off | yes | done | 1 | 4 | 9 | 0.001882 | 25 | 0 | - | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | notes | jev | off | no | error:headless | 4 | 9 | 17 | 0.002394 | 44.9 | 0 | - | message 'old' not quoted |
| flights-oneway | steps | notes | jev | off | no | error:model-timeout | 2 | 12 | 16 | - | 106.3 | 0 | - | truth 'pln 148'; result differs |
| portal-welcome | goal | notes | jev | off | no | error:headless | 3 | 12 | 18 | 0.002178 | 39.3 | 0 | - | message 'old' not quoted |
| u10-portal-new-message | goal | notes | jev | off | no | error:headless | 1 | 1 | 2 | 0.000436 | 8.8 | 0 | - | message 'new' not quoted |
| u10-portal-new-message | steps | notes | jev | off | no | error:headless | 4 | 7 | 14 | 0.002683 | 54 | 0 | - | message 'new' not quoted |
| u10-portal-new-message | loose | notes | jev | off | no | error:model-timeout | 2 | 5 | 9 | - | 75.7 | 0 | - | message 'new' not quoted |
| portal-welcome | steps | notes | jev | off | no | limit | 6 | 18 | 29 | 0.00414 | 86 | 0 | - | message 'old' not quoted |
| u5-flights-roundtrip | goal | notes | jev | off | no | error | 0 | 0 | 2 | - | 20.4 | 0 | - | truth 'pln 306'; result differs |
| u5-flights-roundtrip | loose | notes | jev | off | no | done | 1 | 11 | 17 | 0.004722 | 47.5 | 0 | - | truth 'pln 306'; result differs |
| u5-flights-roundtrip | steps | notes | jev | off | no | done | 1 | 16 | 25 | 0.007697 | 51.7 | 0 | - | truth 'pln 306'; result differs |
| u6-maps-cafe | goal | notes | jev | off | no | error:headless | 3 | 58 | 99 | 0.020614 | 152.8 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | loose | notes | jev | off | no | error:headless | 3 | 65 | 121 | 0.024243 | 172.5 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | notes | jev | off | no | error:headless | 1 | 2 | 4 | 0.000714 | 13.6 | 0 | - | registrations 0, confirmed False |
| u7-register | goal | notes | jev | off | no | error:headless | 1 | 2 | 4 | 0.000496 | 9.3 | 0 | - | registrations 0, confirmed False |
| u7-register | steps | notes | jev | off | no | error:headless | 2 | 12 | 18 | 0.001752 | 28.8 | 0 | - | registrations 0, confirmed False |
| u6-maps-cafe | steps | notes | jev | off | no | error:headless | 4 | 67 | 116 | 0.027632 | 222.4 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u8-books-travel-jsonl | steps | notes | jev | off | no | done | 1 | 3 | 5 | 0.002353 | 22.1 | 0 | - | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u8-books-travel-jsonl | goal | notes | jev | off | no | error:headless | 2 | 23 | 31 | 0.010419 | 96.4 | 0 | - | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u8-books-travel-jsonl | loose | notes | jev | off | no | error:headless | 2 | 65 | 83 | 0.021947 | 160.9 | 0 | - | 11 on the page, 0 in the file, 11 missing, 0 extra |
| u9-upload | steps | notes | jev | off | no | error:headless | 2 | 2 | 4 | 0.001013 | 22.8 | 0 | - | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | notes | jev | off | yes | done | 1 | 3 | 6 | 0.002198 | 16.4 | 0 | - | result names '10 December 1815' |
| u9-upload | goal | notes | jev | off | no | error:headless | 3 | 73 | 77 | 0.006937 | 82.1 | 0 | - | 0 upload(s); link None not in the result |
| wiki-ada-born | goal | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001807 | 16.4 | 0 | - | result names '10 December 1815' |
| wiki-ada-born | steps | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001706 | 13 | 0 | - | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001674 | 10.7 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | goal | notes | jev | off | yes | done | 1 | 3 | 6 | 0.002091 | 12.8 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001668 | 11.7 | 0 | - | result names 'Charles Babbage' |
| u9-upload | loose | notes | jev | off | no | error:model-timeout | 4 | 134 | 140 | - | 214.2 | 0 | - | 0 upload(s); link None not in the result |
| ae-blue-top-price | goal | procedures | jev | off | yes | done | 1 | 1 | 3 | 0.000773 | 28.9 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000584 | 27.9 | 0 | - | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | procedures | jev | off | no | failed | 1 | 1 | 2 | 0.001288 | 26.8 | 0 | - | result lacks 'Blue Top' |
| ae-polo-brand | loose | procedures | jev | off | no | failed | 1 | 1 | 3 | 0.002985 | 61.5 | 0 | - | result lacks 'Blue Top' |
| ae-polo-brand | steps | procedures | jev | off | no | failed | 1 | 2 | 16 | 0.003261 | 36.4 | 0 | - | result lacks 'Blue Top' |
| ae-search-jeans | loose | procedures | jev | off | yes | done | 1 | 3 | 6 | 0.000928 | 22 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | jev | off | yes | done | 1 | 3 | 6 | 0.00089 | 19.3 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-blue-top-price | steps | procedures | jev | off | yes | done | 2 | 9 | 44 | 0.007 | 131 | 0 | - | truth 'rs. 500'; result agrees |
| ae-search-jeans | steps | procedures | jev | off | yes | done | 1 | 3 | 6 | 0.000943 | 19.3 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | procedures | jev | off | yes | done | 2 | 9 | 15 | 0.003664 | 29.6 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000755 | 6.7 | 0 | - | truth '19'; result agrees |
| books-mystery-page2 | steps | procedures | jev | off | yes | done | 2 | 10 | 18 | 0.003842 | 35.4 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000771 | 7.2 | 0 | - | truth '19'; result agrees |
| books-poetry-count | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000756 | 6.3 | 0 | - | truth '19'; result agrees |
| books-mystery-page2 | loose | procedures | jev | off | no | failed | 3 | 12 | 21 | 0.006572 | 84.7 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-jsonl | steps | procedures | jev | off | yes | done | 1 | 2 | 4 | 0.001225 | 12 | 0 | - | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-price | loose | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000546 | 5.5 | 0 | - | result names '£51.77' |
| books-price | goal | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000554 | 5.8 | 0 | - | result names '£51.77' |
| books-price | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000509 | 6.9 | 0 | - | result names '£51.77' |
| books-stock | loose | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000538 | 7 | 0 | - | truth '20'; result agrees |
| books-poetry-jsonl | goal | procedures | jev | off | no | error:model-timeout | 1 | 1 | 5 | - | 68 | 0 | - | 19 on the page, 57 in the file, 0 missing, 0 extra |
| books-stock | goal | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000559 | 5.9 | 0 | - | truth '20'; result agrees |
| books-stock | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000629 | 7.4 | 0 | - | truth '20'; result agrees |
| canvas-launch | loose | procedures | jev | off | no | error:headless | 1 | 1 | 2 | 0.000207 | 5.9 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | goal | procedures | jev | off | no | error:headless | 1 | 1 | 2 | 0.000184 | 5 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| canvas-launch | steps | procedures | jev | off | no | error:headless | 1 | 1 | 2 | 0.000199 | 4.8 | 0 | - | 0 canvas click(s), 0 inside the drawn button |
| flights-oneway | goal | procedures | jev | off | no | done | 1 | 15 | 22 | 0.004868 | 41.5 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | loose | procedures | jev | off | no | done | 1 | 13 | 20 | 0.004742 | 44.8 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | procedures | jev | off | yes | done | 1 | 4 | 12 | 0.002069 | 24.8 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | procedures | jev | off | yes | done | 1 | 3 | 10 | 0.001935 | 19.2 | 0 | - | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | procedures | jev | off | no | blocked | 1 | 9 | 21 | - | 53.6 | 0 | - | truth 'pln 148'; result differs |
| portal-welcome | loose | procedures | jev | off | no | error:headless | 1 | 4 | 8 | 0.000742 | 15.6 | 0 | - | message 'old' not quoted |
| maps-eiffel-postcode | steps | procedures | jev | off | yes | done | 1 | 3 | 9 | 0.001782 | 20.2 | 0 | - | Wikidata P281 ['75007']; result agrees |
| books-poetry-jsonl | loose | procedures | jev | off | no | error:model-timeout | 5 | 6 | 27 | - | 230.6 | 0 | - | 19 on the page, 266 in the file, 0 missing, 0 extra |
| portal-welcome | steps | procedures | jev | off | no | error:headless | 3 | 8 | 16 | 0.002012 | 40.1 | 0 | - | message 'old' not quoted |
| portal-welcome | goal | procedures | jev | off | no | error:headless | 5 | 13 | 25 | 0.003913 | 83.6 | 0 | - | message 'old' not quoted |
| u10-portal-new-message | goal | procedures | jev | off | no | error:headless | 2 | 6 | 12 | 0.002867 | 56.5 | 0 | - | message 'new' not quoted |
| u10-portal-new-message | loose | procedures | jev | off | no | error:headless | 4 | 9 | 19 | 0.003062 | 72 | 0 | - | message 'new' not quoted |
| u10-portal-new-message | steps | procedures | jev | off | no | error | 2 | 6 | 14 | - | 42.4 | 0 | - | message 'new' not quoted |
| u5-flights-roundtrip | loose | procedures | jev | off | no | done | 1 | 17 | 24 | 0.007096 | 44.4 | 0 | - | truth 'pln 306'; result differs |
| u5-flights-roundtrip | goal | procedures | jev | off | no | done | 1 | 12 | 21 | 0.005886 | 42.8 | 0 | - | truth 'pln 306'; result differs |
| u5-flights-roundtrip | steps | procedures | jev | off | no | done | 1 | 51 | 77 | 0.032755 | 138.6 | 0 | - | truth 'pln 306'; result differs |
| u6-maps-cafe | loose | procedures | jev | off | no | error:headless | 3 | 48 | 82 | 0.016458 | 127.2 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | goal | procedures | jev | off | no | error:headless | 3 | 55 | 92 | 0.018156 | 137.5 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u7-register | loose | procedures | jev | off | no | error:headless | 1 | 2 | 4 | 0.001047 | 19.6 | 0 | - | registrations 0, confirmed False |
| u7-register | goal | procedures | jev | off | no | error:headless | 1 | 2 | 4 | 0.000763 | 14.6 | 0 | - | registrations 0, confirmed False |
| u7-register | steps | procedures | jev | off | no | error:headless | 2 | 32 | 42 | 0.004163 | 52.9 | 0 | - | registrations 0, confirmed False |
| u6-maps-cafe | steps | procedures | jev | off | no | error:headless | 3 | 91 | 124 | 0.021244 | 165.1 | 0 | - | names on a fresh Maps search: []; ratings [] |
| u8-books-travel-jsonl | loose | procedures | jev | off | no | done | 5 | 9 | 41 | 0.019372 | 253.8 | 0 | - | 11 on the page, 220 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | steps | procedures | jev | off | no | error:model-timeout | 3 | 3 | 16 | - | 130.4 | 0 | - | 11 on the page, 88 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | goal | procedures | jev | off | no | done | 7 | 12 | 45 | 0.018518 | 230 | 0 | - | 11 on the page, 209 in the file, 0 missing, 0 extra |
| u9-upload | steps | procedures | jev | off | no | error:headless | 2 | 2 | 4 | 0.000981 | 17.6 | 0 | - | 0 upload(s); link None not in the result |
| u9-upload | goal | procedures | jev | off | no | error:headless | 2 | 10 | 12 | 0.00196 | 33.1 | 0 | - | 0 upload(s); link None not in the result |
| wiki-ada-born | loose | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001753 | 14.6 | 0 | - | result names '10 December 1815' |
| wiki-ada-born | goal | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001797 | 13.9 | 0 | - | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001727 | 12.9 | 0 | - | result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001648 | 11.2 | 0 | - | result names 'Charles Babbage' |
| u9-upload | loose | procedures | jev | off | no | error:headless | 3 | 9 | 12 | 0.003949 | 77.7 | 0 | - | 0 upload(s); link None not in the result |
| wiki-engine-designer | steps | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001651 | 10.3 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | goal | procedures | jev | off | yes | done | 1 | 3 | 6 | 0.002082 | 11.7 | 0 | - | result names 'Charles Babbage' |
| u1-tauron-overdue | loose | none | jev | off | no | error:headless | 4 | 32 | 51 | 0.006176 | 95.1 | 0 | - | page (fresh tab, low-level text) shows [] |
| u1-tauron-overdue | goal | none | jev | off | no | error:headless | 1 | 2 | 3 | 0.000444 | 9.3 | 0 | - | page (fresh tab, low-level text) shows [] |
| u1-tauron-overdue | steps | none | jev | off | no | error:headless | 1 | 3 | 5 | 0.000664 | 12.8 | 0 | - | page (fresh tab, low-level text) shows [] |
| u2-tauron-invoice | loose | none | jev | off | no | error:headless | 1 | 2 | 3 | 0.000599 | 11.2 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | goal | none | jev | off | no | error:headless | 3 | 7 | 11 | 0.001645 | 29.5 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | steps | none | jev | off | no | error:headless | 4 | 10 | 16 | 0.002744 | 49.6 | 0 | - | new PDF(s): [] |
| u1-tauron-overdue | loose | notes | jev | off | no | error:headless | 5 | 11 | 18 | 0.002931 | 49.9 | 0 | - | page (fresh tab, low-level text) shows [] |
| u1-tauron-overdue | goal | notes | jev | off | yes | done | 3 | 25 | 39 | 0.004922 | 79.2 | 0 | - | page (fresh tab, low-level text) shows ['756,88 zł', '544,92 zł', '211,96 zł'] |
| u1-tauron-overdue | steps | notes | jev | off | no | blocked | 1 | 4 | 7 | 0.001125 | 18.2 | 0 | - | page (fresh tab, low-level text) shows ['756,88 zł', '544,92 zł', '211,96 zł'] |
| u2-tauron-invoice | loose | notes | jev | off | no | error:model-timeout | 4 | 185 | 219 | - | 300 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | goal | notes | jev | off | yes | error | 3 | 177 | 202 | - | 302.8 | 0 | - | new PDF(s): ['E_TM2_UG533989_0003_26_4.pdf', 'E_TM2_UG533989_0003_26_2.pdf'] |
| u2-tauron-invoice | steps | notes | jev | off | no | error:headless | 2 | 65 | 75 | 0.014605 | 121.8 | 0 | - | new PDF(s): [] |
| u1-tauron-overdue | loose | procedures | jev | off | no | error:headless | 1 | 2 | 3 | 0.000398 | 9.8 | 0 | - | page (fresh tab, low-level text) shows [] |
| u1-tauron-overdue | goal | procedures | jev | off | no | error:headless | 1 | 2 | 3 | 0.000506 | 12 | 0 | - | page (fresh tab, low-level text) shows [] |
| u1-tauron-overdue | steps | procedures | jev | off | no | error:headless | 6 | 13 | 20 | 0.003489 | 62.2 | 0 | - | page (fresh tab, low-level text) shows [] |
| u2-tauron-invoice | loose | procedures | jev | off | no | error:headless | 1 | 2 | 3 | 0.000517 | 13 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | goal | procedures | jev | off | no | error:headless | 2 | 5 | 8 | 0.001372 | 27.6 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | steps | procedures | jev | off | no | error:headless | 1 | 2 | 3 | 0.00056 | 11.6 | 0 | - | new PDF(s): [] |
