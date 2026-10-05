# Corpus run 2026-10-05

## Conclusions

Paired cells: two cells compared differ in that factor only (same mission, style, knowledge, model, image). 20 public missions, 1,260 public cells, plus 9 U2 cells on the operator's account; one frozen build (`/tmp/leash-corpus-bin/leash`, sha256 `c08c4ada44b040f3…`).

1. **Model: keep JEV.** With images off, JEV passed 125/180 cells, Clef 118/180 and Clef Flash 115/180, at about the same cost per cell ($0.00376, $0.00374, $0.00337). The decision model was asked anything in only 153 of 1,260 cells (12%): the pilot does most missions with its own acts, so the model choice moves little.
2. **Images: no measured effect.** Mode B passed 126/180 (Clef) and 127/180 (Flash), against 118/180 and 115/180 with images off. But a screenshot was sent in only 3 cells, and none of them passed, so the difference is not the picture. Mode C (LOOK) passed 120/180 for both models. Defaults: B stays at 3, LOOK is now off. Neither applies to the text-only JEV default.
3. **Style: state the goal and its result.** The goal style ("…. Result: …") passed 321/420 (76%), steps 291/420 (69%), loose 239/420 (57%). It was also the cheapest ($0.00285 per cell, against $0.00314 and $0.00416) and the shortest (5.4 pilot turns, against 6.2 and 7.4).
4. **Knowledge: notes help a little, procedures hurt.** Notes passed 304/420, no playbook 293/420, at lower cost ($0.00326 against $0.00343) and wall time (50 s against 56 s). Procedures passed 254/420 and were the slowest (67 s). The loss is concentrated where the pilot re-ran a collection procedure: u8 passed 0/21 with procedures and 41/42 without (pilot-1gv0).
5. **Most failures are Leash defects, now filed.**
   - The pilot re-reads instead of answering (pilot-jx20; portal-welcome loose passed 0/21).
   - A re-run collection writes duplicate records (pilot-1gv0).
   - A `done` carrying 19 records times out (pilot-6ddo; 17/63 Poetry cells).
   - Found and fixed before this run: lost pilot fills in background tabs (pilot-izn0), and reads and uploads missing from the pilot's history (pilot-l7a5, pilot-nmq5).
   - The flights cells (2/126) compare with Google's overview price, which need not be next month's calendar price, so they are only weakly checked.
   - U2 (Tauron invoice, operator account) passed 3/9 cells, one per knowledge variant: steps/none, goal/notes and loose/procedures.

Also measured: 1 of 1,080 multimodal cells shows a decision call capped at the ~2.2K-token truncation. Two missions have no checker independent of the browser: u6-maps-cafe reads a fresh Maps tab with the low-level `new`/`text` commands, and the U1/U2 checks read the account the same way.

## Summary

| factor | level | cells | passed | pass rate | mean cost $ | mean pilot turns |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| model | clef | 540 | 364 | 67% | 0.00340 | 6.3 |
| model | clef-flash | 540 | 362 | 67% | 0.00321 | 6.4 |
| model | jev | 189 | 128 | 68% | 0.00391 | 6.6 |
| image | b | 360 | 253 | 70% | 0.00306 | 6.1 |
| image | c | 360 | 240 | 67% | 0.00329 | 6.4 |
| image | off | 549 | 361 | 66% | 0.00369 | 6.5 |
| style | goal | 423 | 322 | 76% | 0.00289 | 5.5 |
| style | loose | 423 | 240 | 57% | 0.00417 | 7.4 |
| style | steps | 423 | 292 | 69% | 0.00318 | 6.2 |
| knowledge | none | 423 | 294 | 70% | 0.00345 | 6.5 |
| knowledge | notes | 423 | 305 | 72% | 0.00328 | 6.1 |
| knowledge | procedures | 423 | 255 | 60% | 0.00358 | 6.5 |

## Cells

| mission | style | knowledge | model | image | pass | status | pilot turns | navigator steps | calls | cost $ | wall s | image parts | truncated | note |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| u2-tauron-invoice | loose | none | jev | off | no | limit | 12 | 0 | 13 | 0.00473 | 111.2 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | goal | none | jev | off | no | limit | 12 | 4 | 16 | 0.007597 | 94.2 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | steps | none | jev | off | yes | done | 10 | 1 | 11 | 0.005224 | 66.6 | 0 | - | new PDF(s): ['E_TM2_UG533989_0003_26_1.pdf'] |
| u2-tauron-invoice | loose | notes | jev | off | no | limit | 12 | 0 | 13 | 0.004722 | 97.3 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | goal | notes | jev | off | yes | done | 10 | 0 | 10 | 0.005046 | 66.8 | 0 | - | new PDF(s): ['E_TM2_UG533989_0003_26_1.pdf'] |
| u2-tauron-invoice | steps | notes | jev | off | no | limit | 12 | 0 | 12 | 0.006996 | 96.6 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | loose | procedures | jev | off | yes | done | 9 | 4 | 13 | 0.004752 | 69 | 0 | - | new PDF(s): ['E_TM2_UG533989_0003_26_1.pdf'] |
| u2-tauron-invoice | goal | procedures | jev | off | no | limit | 12 | 9 | 22 | 0.010188 | 109.8 | 0 | - | new PDF(s): [] |
| u2-tauron-invoice | steps | procedures | jev | off | no | limit | 12 | 8 | 20 | 0.012804 | 170.3 | 0 | - | new PDF(s): [] |
| ae-blue-top-price | loose | none | jev | off | yes | done | 8 | 0 | 8 | 0.004087 | 38.4 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | none | jev | off | no | limit | 12 | 0 | 12 | 0.006378 | 57.7 | 0 | - | truth 'rs. 500'; result differs |
| ae-search-jeans | loose | none | jev | off | yes | done | 3 | 0 | 3 | 0.001326 | 24.5 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | none | jev | off | yes | done | 6 | 0 | 6 | 0.004955 | 73 | 0 | - | result names 'Blue Top' |
| ae-search-jeans | goal | none | jev | off | yes | done | 3 | 0 | 3 | 0.001293 | 24.7 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | none | jev | off | yes | done | 8 | 0 | 8 | 0.005752 | 87.3 | 0 | - | result names 'Blue Top' |
| ae-search-jeans | steps | none | jev | off | yes | done | 3 | 0 | 3 | 0.001231 | 23.7 | 0 | - | result names 'Soft Stretch Jeans' |
| books-poetry-count | loose | none | jev | off | yes | done | 2 | 0 | 2 | 0.000801 | 8.8 | 0 | - | truth '19'; result agrees |
| books-poetry-count | goal | none | jev | off | yes | done | 2 | 0 | 2 | 0.000769 | 7.1 | 0 | - | truth '19'; result agrees |
| books-poetry-count | steps | none | jev | off | yes | done | 2 | 0 | 2 | 0.000772 | 5.8 | 0 | - | truth '19'; result agrees |
| books-mystery-page2 | loose | none | jev | off | yes | done | 9 | 0 | 9 | 0.00427 | 43.7 | 0 | - | result names 'The Mysterious Affair at Styles' |
| ae-blue-top-price | steps | none | jev | off | yes | done | 12 | 0 | 13 | 0.007854 | 118.8 | 0 | - | truth 'rs. 500'; result agrees |
| books-mystery-page2 | goal | none | jev | off | yes | done | 8 | 0 | 8 | 0.004029 | 43.4 | 0 | - | result names 'The Mysterious Affair at Styles' |
| ae-polo-brand | goal | none | jev | off | yes | done | 10 | 0 | 10 | 0.009677 | 138.6 | 0 | - | result names 'Blue Top' |
| books-price | loose | none | jev | off | yes | done | 4 | 0 | 4 | 0.001638 | 15.9 | 0 | - | result names '£51.77' |
| books-price | goal | none | jev | off | yes | done | 2 | 0 | 2 | 0.000802 | 6.9 | 0 | - | result names '£51.77' |
| books-poetry-jsonl | steps | none | jev | off | yes | done | 2 | 0 | 2 | 0.002028 | 26.5 | 0 | - | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-price | steps | none | jev | off | yes | done | 2 | 0 | 2 | 0.000734 | 6.9 | 0 | - | result names '£51.77' |
| books-stock | goal | none | jev | off | yes | done | 2 | 0 | 2 | 0.000777 | 8.7 | 0 | - | truth '20'; result agrees |
| books-stock | steps | none | jev | off | yes | done | 2 | 0 | 2 | 0.000701 | 6.7 | 0 | - | truth '20'; result agrees |
| canvas-launch | goal | none | jev | off | yes | done | 2 | 0 | 2 | 0.000686 | 8.3 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | loose | none | jev | off | yes | done | 2 | 0 | 2 | 0.000879 | 12.1 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| books-mystery-page2 | steps | none | jev | off | yes | done | 10 | 0 | 10 | 0.006681 | 81.4 | 0 | - | result names 'The Mysterious Affair at Styles' |
| canvas-launch | steps | none | jev | off | yes | done | 2 | 0 | 2 | 0.000796 | 11.3 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| books-stock | loose | none | jev | off | yes | done | 10 | 0 | 10 | 0.003331 | 33 | 0 | - | truth '20'; result agrees |
| maps-eiffel-postcode | loose | none | jev | off | yes | done | 9 | 0 | 10 | 0.004015 | 64.1 | 0 | - | Wikidata P281 ['75007']; result agrees |
| flights-oneway | loose | none | jev | off | no | limit | 12 | 0 | 12 | 0.004833 | 80.8 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | goal | none | jev | off | no | done | 11 | 0 | 12 | 0.004675 | 81.3 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | none | jev | off | yes | done | 4 | 0 | 5 | 0.001588 | 33.2 | 0 | - | Wikidata P281 ['75007']; result agrees |
| books-poetry-jsonl | goal | none | jev | off | no | limit | 12 | 0 | 12 | 0.011736 | 168.3 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| portal-welcome | loose | none | jev | off | no | limit | 12 | 1 | 13 | 0.002735 | 42 | 0 | - | message 'old' not quoted |
| portal-welcome | goal | none | jev | off | yes | done | 5 | 0 | 5 | 0.001006 | 16.6 | 0 | - | message 'old' quoted |
| books-poetry-jsonl | loose | none | jev | off | no | limit | 12 | 0 | 12 | 0.013736 | 186.9 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | steps | none | jev | off | no | limit | 12 | 0 | 14 | 0.007176 | 121.4 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | steps | none | jev | off | yes | done | 5 | 1 | 6 | 0.003382 | 51.4 | 0 | - | Wikidata P281 ['75007']; result agrees |
| u10-portal-new-message | goal | none | jev | off | yes | done | 5 | 0 | 5 | 0.001046 | 16.6 | 0 | - | message 'new' quoted |
| u10-portal-new-message | steps | none | jev | off | yes | done | 8 | 0 | 8 | 0.002486 | 35.7 | 0 | - | message 'new' quoted |
| u10-portal-new-message | loose | none | jev | off | no | limit | 12 | 0 | 12 | 0.003874 | 61.4 | 0 | - | message 'new' not quoted |
| portal-welcome | steps | none | jev | off | no | limit | 12 | 0 | 13 | 0.004225 | 69.1 | 0 | - | message 'old' not quoted |
| u6-maps-cafe | loose | none | jev | off | yes | done | 3 | 0 | 3 | 0.001123 | 23.1 | 0 | - | names on a fresh Maps search: ['Kozy Bosquet', 'Av. Bosquet']; ratings [4.7] |
| u6-maps-cafe | goal | none | jev | off | yes | done | 3 | 0 | 3 | 0.001086 | 22.1 | 0 | - | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | none | jev | off | yes | done | 4 | 0 | 4 | 0.001687 | 27.1 | 0 | - | names on a fresh Maps search: ['Kozy Bosquet', 'Av. Bosquet']; ratings [4.7] |
| u5-flights-roundtrip | goal | none | jev | off | no | done | 8 | 2 | 12 | 0.0054 | 89.4 | 0 | - | truth 'pln 352'; result differs |
| u7-register | loose | none | jev | off | yes | done | 8 | 0 | 9 | 0.00228 | 39 | 0 | - | registrations 1, confirmed True, password delivered True |
| u7-register | goal | none | jev | off | yes | done | 8 | 0 | 8 | 0.001979 | 28.8 | 0 | - | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | steps | none | jev | off | no | limit | 12 | 0 | 12 | 0.006434 | 102.6 | 0 | - | truth 'pln 352'; result differs |
| u9-upload | loose | none | jev | off | yes | done | 3 | 0 | 3 | 0.000642 | 12.3 | 0 | - | 1 upload(s); link /files/1 in the result |
| u7-register | steps | none | jev | off | yes | done | 8 | 0 | 10 | 0.002344 | 39.2 | 0 | - | registrations 1, confirmed True, password delivered True |
| u9-upload | goal | none | jev | off | yes | done | 3 | 0 | 3 | 0.00069 | 10.9 | 0 | - | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | none | jev | off | yes | done | 3 | 0 | 3 | 0.002671 | 32 | 0 | - | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | steps | none | jev | off | yes | done | 5 | 0 | 5 | 0.001191 | 17.2 | 0 | - | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | none | jev | off | yes | done | 3 | 0 | 3 | 0.001763 | 14.1 | 0 | - | result names '10 December 1815' |
| u8-books-travel-jsonl | steps | none | jev | off | yes | done | 3 | 0 | 3 | 0.003198 | 41.6 | 0 | - | 11 on the page, 11 in the file, 0 missing, 0 extra |
| wiki-ada-born | steps | none | jev | off | yes | done | 3 | 0 | 4 | 0.00203 | 18.3 | 0 | - | result names '10 December 1815' |
| u5-flights-roundtrip | loose | none | jev | off | no | limit | 12 | 1 | 13 | 0.010415 | 170.5 | 0 | - | truth 'pln 352'; result differs |
| wiki-ada-born | loose | none | jev | off | yes | done | 7 | 0 | 7 | 0.004383 | 36 | 0 | - | result names '10 December 1815' |
| wiki-engine-designer | steps | none | jev | off | yes | done | 3 | 0 | 3 | 0.001784 | 12.8 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | goal | none | jev | off | yes | done | 6 | 0 | 6 | 0.003542 | 23.6 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | loose | none | jev | off | no | limit | 12 | 0 | 12 | 0.00769 | 56.1 | 0 | - | result lacks 'Charles Babbage' |
| u8-books-travel-jsonl | loose | none | jev | off | yes | done | 11 | 0 | 12 | 0.010689 | 153.9 | 0 | - | 11 on the page, 11 in the file, 0 missing, 0 extra |
| ae-blue-top-price | goal | notes | jev | off | yes | done | 1 | 0 | 1 | 0.000477 | 10.1 | 0 | - | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | notes | jev | off | yes | done | 6 | 0 | 6 | 0.003787 | 49.7 | 0 | - | result names 'Blue Top' |
| ae-polo-brand | goal | notes | jev | off | yes | done | 6 | 0 | 6 | 0.003985 | 54.7 | 0 | - | result names 'Blue Top' |
| ae-blue-top-price | loose | notes | jev | off | yes | done | 9 | 0 | 9 | 0.005618 | 55.8 | 0 | - | truth 'rs. 500'; result agrees |
| ae-search-jeans | loose | notes | jev | off | yes | done | 6 | 0 | 6 | 0.003528 | 44.6 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | notes | jev | off | yes | done | 7 | 0 | 8 | 0.004718 | 69.5 | 0 | - | result names 'Blue Top' |
| ae-search-jeans | goal | notes | jev | off | yes | done | 3 | 0 | 4 | 0.001362 | 25.1 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | jev | off | yes | done | 3 | 0 | 3 | 0.001295 | 23.2 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | notes | jev | off | yes | done | 6 | 0 | 6 | 0.002788 | 27.5 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | jev | off | yes | done | 2 | 0 | 2 | 0.000781 | 7.8 | 0 | - | truth '19'; result agrees |
| books-poetry-count | goal | notes | jev | off | yes | done | 3 | 0 | 3 | 0.001211 | 10.3 | 0 | - | truth '19'; result agrees |
| books-poetry-count | steps | notes | jev | off | yes | done | 3 | 0 | 3 | 0.001453 | 15.2 | 0 | - | truth '19'; result agrees |
| ae-blue-top-price | steps | notes | jev | off | no | limit | 12 | 0 | 13 | 0.007164 | 110.6 | 0 | - | truth 'rs. 500'; result differs |
| books-mystery-page2 | steps | notes | jev | off | yes | done | 7 | 0 | 7 | 0.004142 | 42.5 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-price | loose | notes | jev | off | yes | done | 1 | 0 | 1 | 0.000453 | 5.1 | 0 | - | result names '£51.77' |
| books-price | goal | notes | jev | off | yes | done | 1 | 0 | 1 | 0.000513 | 5.5 | 0 | - | result names '£51.77' |
| books-mystery-page2 | loose | notes | jev | off | no | limit | 12 | 0 | 12 | 0.006289 | 63.9 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| books-price | steps | notes | jev | off | yes | done | 2 | 0 | 2 | 0.000703 | 6.5 | 0 | - | result names '£51.77' |
| books-stock | goal | notes | jev | off | yes | done | 2 | 0 | 2 | 0.000748 | 7.9 | 0 | - | truth '20'; result agrees |
| books-stock | steps | notes | jev | off | yes | done | 2 | 0 | 2 | 0.00074 | 6.5 | 0 | - | truth '20'; result agrees |
| books-stock | loose | notes | jev | off | yes | done | 5 | 0 | 5 | 0.001747 | 16.6 | 0 | - | truth '20'; result agrees |
| canvas-launch | loose | notes | jev | off | yes | done | 2 | 0 | 2 | 0.000799 | 8.3 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | notes | jev | off | yes | done | 2 | 0 | 2 | 0.000698 | 6.9 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | jev | off | yes | done | 2 | 0 | 2 | 0.000762 | 10.8 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | notes | jev | off | no | limit | 12 | 0 | 12 | 0.007176 | 91.9 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | notes | jev | off | no | done | 11 | 0 | 12 | 0.004761 | 78.9 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | steps | notes | jev | off | no | done | 12 | 0 | 12 | 0.005009 | 78.4 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | loose | notes | jev | off | no | done | 12 | 2 | 17 | 0.007602 | 112.6 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | jev | off | yes | done | 7 | 0 | 7 | 0.003498 | 57.9 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | notes | jev | off | yes | done | 4 | 0 | 5 | 0.001828 | 33.9 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | jev | off | yes | done | 4 | 0 | 4 | 0.001747 | 40.7 | 0 | - | Wikidata P281 ['75007']; result agrees |
| books-poetry-jsonl | goal | notes | jev | off | no | limit | 12 | 0 | 13 | 0.014059 | 201.7 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | loose | notes | jev | off | no | limit | 12 | 0 | 12 | 0.014041 | 208.7 | 0 | - | 19 on the page, 0 in the file, 19 missing, 0 extra |
| portal-welcome | loose | notes | jev | off | no | limit | 12 | 0 | 12 | 0.002964 | 44.1 | 0 | - | message 'old' not quoted |
| u10-portal-new-message | loose | notes | jev | off | no | done | 7 | 0 | 7 | 0.001724 | 29.4 | 0 | - | message 'new' not quoted |
| portal-welcome | steps | notes | jev | off | no | limit | 12 | 0 | 14 | 0.003087 | 43.5 | 0 | - | message 'old' not quoted |
| u10-portal-new-message | goal | notes | jev | off | no | done | 8 | 0 | 8 | 0.001929 | 28.3 | 0 | - | message 'new' not quoted |
| u10-portal-new-message | steps | notes | jev | off | no | limit | 12 | 0 | 13 | 0.003039 | 42.9 | 0 | - | message 'new' not quoted |
| u5-flights-roundtrip | goal | notes | jev | off | no | done | 6 | 0 | 6 | 0.003634 | 58.6 | 0 | - | truth 'pln 352'; result differs |
| u6-maps-cafe | loose | notes | jev | off | yes | done | 5 | 0 | 6 | 0.002238 | 40.8 | 0 | - | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | notes | jev | off | yes | done | 3 | 0 | 4 | 0.001295 | 24.5 | 0 | - | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| portal-welcome | goal | notes | jev | off | yes | done | 12 | 0 | 12 | 0.008064 | 134.2 | 0 | - | message 'old' quoted |
| u5-flights-roundtrip | steps | notes | jev | off | no | done | 10 | 0 | 10 | 0.006538 | 99.2 | 0 | - | truth 'pln 352'; result differs |
| u7-register | loose | notes | jev | off | yes | done | 8 | 0 | 8 | 0.002177 | 36.2 | 0 | - | registrations 1, confirmed True, password delivered True |
| u7-register | steps | notes | jev | off | yes | done | 8 | 0 | 8 | 0.002303 | 34.8 | 0 | - | registrations 1, confirmed True, password delivered True |
| u6-maps-cafe | steps | notes | jev | off | yes | done | 7 | 0 | 8 | 0.00372 | 57.3 | 0 | - | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | goal | notes | jev | off | yes | done | 10 | 1 | 12 | 0.003708 | 61.3 | 0 | - | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | loose | notes | jev | off | yes | done | 3 | 0 | 3 | 0.002593 | 31 | 0 | - | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | notes | jev | off | yes | done | 3 | 0 | 3 | 0.000807 | 14.5 | 0 | - | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | notes | jev | off | yes | done | 3 | 0 | 3 | 0.002459 | 30.7 | 0 | - | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u5-flights-roundtrip | loose | notes | jev | off | no | done | 11 | 15 | 37 | 0.023055 | 142.8 | 0 | - | truth 'pln 352'; result differs |
| u8-books-travel-jsonl | steps | notes | jev | off | yes | done | 3 | 0 | 3 | 0.002205 | 25.2 | 0 | - | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | goal | notes | jev | off | yes | done | 4 | 0 | 4 | 0.000957 | 15.7 | 0 | - | 1 upload(s); link /files/1 in the result |
| u9-upload | steps | notes | jev | off | yes | done | 5 | 0 | 5 | 0.001133 | 16.3 | 0 | - | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | loose | notes | jev | off | yes | done | 3 | 0 | 3 | 0.001969 | 17.1 | 0 | - | result names '10 December 1815' |
| wiki-ada-born | goal | notes | jev | off | yes | done | 3 | 0 | 4 | 0.001923 | 17 | 0 | - | result names '10 December 1815' |
| wiki-ada-born | steps | notes | jev | off | yes | done | 4 | 0 | 4 | 0.002378 | 19.8 | 0 | - | result names '10 December 1815' |
| wiki-engine-designer | steps | notes | jev | off | yes | done | 3 | 0 | 3 | 0.001744 | 12 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | goal | notes | jev | off | yes | done | 5 | 0 | 5 | 0.002981 | 21.4 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | loose | notes | jev | off | yes | done | 11 | 0 | 11 | 0.006851 | 46.1 | 0 | - | result names 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | jev | off | yes | done | 2 | 0 | 2 | 0.001361 | 17.4 | 0 | - | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | procedures | jev | off | yes | done | 5 | 0 | 5 | 0.003553 | 48.5 | 0 | - | result names 'Blue Top' |
| ae-blue-top-price | loose | procedures | jev | off | no | limit | 12 | 0 | 12 | 0.007257 | 55 | 0 | - | truth 'rs. 500'; result differs |
| ae-search-jeans | goal | procedures | jev | off | yes | done | 2 | 2 | 7 | 0.001447 | 32.1 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | jev | off | yes | done | 2 | 2 | 7 | 0.001721 | 35.5 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | procedures | jev | off | yes | done | 6 | 2 | 8 | 0.006344 | 93.9 | 0 | - | result names 'Blue Top' |
| ae-blue-top-price | steps | procedures | jev | off | yes | done | 8 | 5 | 16 | 0.006521 | 100.1 | 0 | - | truth 'rs. 500'; result agrees |
| ae-search-jeans | loose | procedures | jev | off | yes | done | 5 | 13 | 24 | 0.00844 | 91.6 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | procedures | jev | off | yes | done | 3 | 3 | 6 | 0.002624 | 26.7 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | jev | off | yes | done | 2 | 1 | 4 | 0.001178 | 19 | 0 | - | truth '19'; result agrees |
| books-poetry-count | goal | procedures | jev | off | no | limit | 12 | 1 | 14 | 0.005983 | 48.5 | 0 | - | truth '19'; result differs |
| books-poetry-count | steps | procedures | jev | off | no | limit | 12 | 1 | 14 | 0.006054 | 49.1 | 0 | - | truth '19'; result differs |
| ae-polo-brand | loose | procedures | jev | off | no | limit | 12 | 1 | 13 | 0.013734 | 176.2 | 0 | - | result lacks 'Blue Top' |
| books-mystery-page2 | steps | procedures | jev | off | yes | done | 6 | 3 | 11 | 0.006545 | 83.5 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-price | goal | procedures | jev | off | yes | done | 1 | 0 | 1 | 0.000474 | 4.7 | 0 | - | result names '£51.77' |
| books-mystery-page2 | loose | procedures | jev | off | no | limit | 12 | 4 | 16 | 0.009669 | 100.8 | 0 | - | result lacks 'The Mysterious Affair at Styles' |
| books-price | steps | procedures | jev | off | yes | done | 2 | 0 | 2 | 0.00078 | 7.9 | 0 | - | result names '£51.77' |
| books-stock | goal | procedures | jev | off | yes | done | 2 | 0 | 2 | 0.000787 | 7.9 | 0 | - | truth '20'; result agrees |
| books-poetry-jsonl | loose | procedures | jev | off | no | done | 3 | 1 | 6 | 0.005282 | 81.8 | 0 | - | 19 on the page, 57 in the file, 0 missing, 38 extra |
| books-stock | steps | procedures | jev | off | yes | done | 2 | 0 | 2 | 0.000814 | 8.9 | 0 | - | truth '20'; result agrees |
| canvas-launch | loose | procedures | jev | off | yes | done | 2 | 0 | 2 | 0.000766 | 10.4 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| books-price | loose | procedures | jev | off | no | limit | 12 | 0 | 12 | 0.005402 | 42.2 | 0 | - | result lacks '£51.77' |
| canvas-launch | goal | procedures | jev | off | yes | done | 2 | 0 | 2 | 0.00075 | 11.2 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| books-stock | loose | procedures | jev | off | no | limit | 12 | 1 | 13 | 0.005035 | 48.9 | 0 | - | truth '20'; result differs |
| canvas-launch | steps | procedures | jev | off | yes | done | 2 | 0 | 2 | 0.001339 | 21.3 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| maps-eiffel-postcode | loose | procedures | jev | off | yes | done | 3 | 2 | 7 | 0.001757 | 39.7 | 0 | - | Wikidata P281 ['75007']; result agrees |
| flights-oneway | goal | procedures | jev | off | no | done | 8 | 4 | 16 | 0.004776 | 70.6 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | procedures | jev | off | yes | done | 3 | 0 | 3 | 0.001405 | 28.2 | 0 | - | Wikidata P281 ['75007']; result agrees |
| flights-oneway | loose | procedures | jev | off | no | done | 9 | 4 | 17 | 0.005703 | 90.6 | 0 | - | truth 'pln 148'; result differs |
| books-poetry-jsonl | steps | procedures | jev | off | no | error:model-timeout | 5 | 1 | 8 | - | 142.2 | 0 | - | 19 on the page, 57 in the file, 19 missing, 57 extra |
| flights-oneway | steps | procedures | jev | off | no | done | 9 | 4 | 18 | 0.005376 | 86 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | steps | procedures | jev | off | yes | done | 3 | 3 | 11 | 0.002672 | 43.4 | 0 | - | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | procedures | jev | off | yes | done | 6 | 0 | 7 | 0.001879 | 35.3 | 0 | - | message 'old' quoted |
| portal-welcome | loose | procedures | jev | off | no | limit | 12 | 0 | 13 | 0.002749 | 56.7 | 0 | - | message 'old' not quoted |
| portal-welcome | goal | procedures | jev | off | yes | done | 8 | 3 | 12 | 0.003412 | 57.7 | 0 | - | message 'old' quoted |
| u10-portal-new-message | loose | procedures | jev | off | no | limit | 12 | 3 | 16 | 0.004124 | 63.7 | 0 | - | message 'new' not quoted |
| u10-portal-new-message | goal | procedures | jev | off | yes | done | 11 | 3 | 15 | 0.003843 | 72.1 | 0 | - | message 'new' quoted |
| u10-portal-new-message | steps | procedures | jev | off | no | limit | 12 | 0 | 14 | - | 68.2 | 0 | - | message 'new' not quoted |
| books-poetry-jsonl | goal | procedures | jev | off | no | limit | 12 | 1 | 14 | 0.017374 | 276.9 | 0 | - | 19 on the page, 114 in the file, 19 missing, 114 extra |
| u6-maps-cafe | loose | procedures | jev | off | yes | done | 2 | 2 | 6 | 0.001338 | 28.3 | 0 | - | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | procedures | jev | off | yes | done | 2 | 2 | 6 | 0.001469 | 30.6 | 0 | - | names on a fresh Maps search: ['Kozy Bosquet', 'Av. Bosquet']; ratings [4.7] |
| u6-maps-cafe | steps | procedures | jev | off | no | done | 3 | 2 | 7 | 0.001935 | 33.3 | 0 | - | names on a fresh Maps search: []; ratings [4.6] |
| u7-register | loose | procedures | jev | off | yes | done | 8 | 0 | 8 | 0.002008 | 33.7 | 0 | - | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | goal | procedures | jev | off | no | done | 8 | 0 | 12 | - | 112.2 | 0 | - | truth 'pln 352'; result differs |
| u5-flights-roundtrip | loose | procedures | jev | off | no | done | 10 | 0 | 13 | 0.006511 | 127.8 | 0 | - | truth 'pln 352'; result differs |
| u7-register | goal | procedures | jev | off | yes | done | 8 | 0 | 8 | 0.002066 | 35.6 | 0 | - | registrations 1, confirmed True, password delivered True |
| u9-upload | loose | procedures | jev | off | yes | done | 3 | 0 | 3 | 0.000652 | 11.9 | 0 | - | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | procedures | jev | off | yes | done | 3 | 0 | 3 | 0.000794 | 12.9 | 0 | - | 1 upload(s); link /files/1 in the result |
| u7-register | steps | procedures | jev | off | no | done | 7 | 0 | 7 | 0.002788 | 48.3 | 0 | - | registrations 1, confirmed False, password delivered True |
| u5-flights-roundtrip | steps | procedures | jev | off | no | done | 12 | 0 | 14 | - | 152.3 | 0 | - | truth 'pln 352'; result differs |
| u9-upload | steps | procedures | jev | off | yes | done | 6 | 0 | 6 | 0.001435 | 24.6 | 0 | - | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | loose | procedures | jev | off | no | done | 4 | 1 | 6 | 0.004188 | 61.7 | 0 | - | 11 on the page, 33 in the file, 0 missing, 22 extra |
| wiki-ada-born | goal | procedures | jev | off | yes | done | 2 | 2 | 6 | 0.002173 | 17.3 | 0 | - | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | jev | off | yes | done | 2 | 2 | 6 | 0.00215 | 16.8 | 0 | - | result names '10 December 1815' |
| u8-books-travel-jsonl | steps | procedures | jev | off | no | done | 5 | 1 | 7 | 0.00526 | 71.8 | 0 | - | 11 on the page, 33 in the file, 0 missing, 22 extra |
| wiki-engine-designer | goal | procedures | jev | off | yes | done | 2 | 2 | 8 | 0.002698 | 19.8 | 0 | - | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | jev | off | yes | done | 2 | 2 | 6 | 0.002163 | 17 | 0 | - | result names 'Charles Babbage' |
| wiki-ada-born | loose | procedures | jev | off | no | limit | 12 | 2 | 16 | 0.009503 | 70.4 | 0 | - | result lacks '10 December 1815' |
| wiki-engine-designer | loose | procedures | jev | off | no | limit | 12 | 2 | 16 | 0.011004 | 126 | 0 | - | result lacks 'Charles Babbage' |
| u8-books-travel-jsonl | goal | procedures | jev | off | no | done | 12 | 1 | 14 | 0.017792 | 278.7 | 0 | - | 11 on the page, 66 in the file, 0 missing, 55 extra |
| ae-blue-top-price | loose | none | clef | off | no | limit | 12 | 0 | 12 | 0.006096 | 57.8 | 0 | no | truth 'rs. 500'; result differs |
| ae-blue-top-price | goal | none | clef | off | yes | done | 12 | 0 | 12 | 0.006334 | 69.2 | 0 | no | truth 'rs. 500'; result agrees |
| ae-search-jeans | loose | none | clef | off | yes | done | 3 | 0 | 3 | 0.001254 | 24.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | none | clef | off | yes | done | 7 | 0 | 7 | 0.006136 | 96 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | goal | none | clef | off | yes | done | 3 | 0 | 3 | 0.001196 | 26 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | clef | off | yes | done | 3 | 0 | 3 | 0.001164 | 23.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-blue-top-price | steps | none | clef | off | yes | done | 12 | 1 | 14 | 0.008834 | 128.7 | 0 | no | truth 'rs. 500'; result agrees |
| books-mystery-page2 | goal | none | clef | off | yes | done | 8 | 0 | 8 | 0.004496 | 43.7 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | clef | off | yes | done | 3 | 0 | 3 | 0.001119 | 12.4 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | none | clef | off | yes | done | 5 | 0 | 5 | 0.002048 | 20.4 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | none | clef | off | yes | done | 5 | 0 | 5 | 0.002193 | 23.6 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | loose | none | clef | off | no | limit | 12 | 4 | 18 | 0.010449 | 83.1 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-polo-brand | goal | none | clef | off | no | limit | 12 | 0 | 12 | 0.013729 | 205.6 | 0 | no | result lacks 'Blue Top' |
| books-mystery-page2 | steps | none | clef | off | no | limit | 12 | 2 | 15 | 0.010978 | 104.2 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-polo-brand | loose | none | clef | off | no | limit | 12 | 0 | 12 | 0.013151 | 216.4 | 0 | no | result lacks 'Blue Top' |
| books-price | steps | none | clef | off | yes | done | 2 | 0 | 2 | 0.000708 | 8.4 | 0 | no | result names '£51.77' |
| books-price | goal | none | clef | off | yes | done | 2 | 0 | 2 | 0.00083 | 13.2 | 0 | no | result names '£51.77' |
| books-price | loose | none | clef | off | yes | done | 7 | 0 | 7 | 0.002888 | 25.9 | 0 | no | result names '£51.77' |
| books-stock | loose | none | clef | off | yes | done | 2 | 0 | 2 | 0.000748 | 7.5 | 0 | no | truth '20'; result agrees |
| books-stock | goal | none | clef | off | yes | done | 3 | 0 | 3 | 0.001066 | 11.3 | 0 | no | truth '20'; result agrees |
| books-stock | steps | none | clef | off | yes | done | 2 | 0 | 2 | 0.000735 | 7.3 | 0 | no | truth '20'; result agrees |
| canvas-launch | goal | none | clef | off | yes | done | 2 | 0 | 2 | 0.000979 | 12.8 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | clef | off | yes | done | 2 | 0 | 2 | 0.000711 | 11.8 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | loose | none | clef | off | yes | done | 2 | 0 | 2 | 0.001219 | 20.1 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | none | clef | off | no | done | 12 | 0 | 12 | 0.005006 | 82.1 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | none | clef | off | no | limit | 12 | 0 | 12 | 0.00439 | 82.3 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | clef | off | yes | done | 3 | 0 | 4 | 0.001152 | 25.3 | 0 | no | Wikidata P281 ['75007']; result agrees |
| books-poetry-jsonl | goal | none | clef | off | no | limit | 12 | 0 | 12 | 0.01232 | 195 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | loose | none | clef | off | no | limit | 12 | 0 | 13 | 0.012419 | 205.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | steps | none | clef | off | no | limit | 12 | 0 | 14 | 0.006021 | 115.5 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | none | clef | off | yes | done | 4 | 0 | 4 | 0.00151 | 36.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | none | clef | off | yes | done | 5 | 0 | 5 | 0.00106 | 19.2 | 0 | no | message 'old' quoted |
| u10-portal-new-message | goal | none | clef | off | yes | done | 5 | 0 | 5 | 0.001057 | 17.6 | 0 | no | message 'new' quoted |
| maps-eiffel-postcode | steps | none | clef | off | yes | done | 5 | 0 | 7 | - | 46.4 | 0 | no | Wikidata P281 ['75007']; result agrees |
| books-poetry-jsonl | steps | none | clef | off | no | error:model-timeout | 11 | 0 | 11 | - | 240.7 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| u10-portal-new-message | loose | none | clef | off | no | limit | 12 | 0 | 12 | 0.003155 | 55.4 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | none | clef | off | no | limit | 12 | 0 | 12 | 0.00269 | 43.4 | 0 | no | message 'new' not quoted |
| portal-welcome | goal | none | clef | off | no | limit | 12 | 0 | 12 | 0.004716 | 85.4 | 0 | no | message 'old' not quoted |
| portal-welcome | loose | none | clef | off | no | limit | 12 | 0 | 13 | 0.005854 | 102 | 0 | no | message 'old' not quoted |
| u6-maps-cafe | goal | none | clef | off | yes | done | 3 | 0 | 3 | 0.001037 | 21.9 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | loose | none | clef | off | yes | done | 3 | 0 | 4 | 0.001238 | 31.4 | 0 | no | names on a fresh Maps search: ['Kozy Bosquet', 'Av. Bosquet']; ratings [4.7] |
| u5-flights-roundtrip | goal | none | clef | off | no | done | 7 | 0 | 7 | 0.004499 | 83.5 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | steps | none | clef | off | yes | done | 5 | 0 | 5 | 0.002518 | 44.7 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | none | clef | off | yes | done | 8 | 0 | 8 | 0.001887 | 34.3 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | goal | none | clef | off | yes | done | 8 | 0 | 9 | 0.001963 | 42.7 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | none | clef | off | yes | done | 8 | 0 | 9 | 0.002238 | 39.1 | 0 | no | registrations 1, confirmed True, password delivered True |
| u9-upload | loose | none | clef | off | yes | done | 3 | 0 | 3 | 0.000662 | 10.1 | 0 | no | 1 upload(s); link /files/1 in the result |
| u5-flights-roundtrip | steps | none | clef | off | no | done | 12 | 0 | 13 | 0.007895 | 129.1 | 0 | no | truth 'pln 352'; result differs |
| u9-upload | goal | none | clef | off | yes | done | 3 | 0 | 3 | 0.00064 | 11.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | steps | none | clef | off | yes | done | 3 | 0 | 3 | 0.000704 | 10.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | none | clef | off | yes | done | 3 | 0 | 3 | 0.002774 | 38.3 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | loose | none | clef | off | yes | done | 3 | 0 | 3 | 0.003723 | 57.8 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| wiki-ada-born | goal | none | clef | off | yes | done | 3 | 0 | 3 | 0.001813 | 13.8 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | none | clef | off | yes | done | 3 | 0 | 3 | 0.001988 | 21.4 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | none | clef | off | yes | done | 5 | 0 | 5 | 0.003035 | 28.3 | 0 | no | result names 'Charles Babbage' |
| u5-flights-roundtrip | loose | none | clef | off | no | limit | 12 | 0 | 15 | - | 195.6 | 0 | no | truth 'pln 352'; result differs |
| wiki-engine-designer | goal | none | clef | off | yes | done | 3 | 0 | 4 | 0.001885 | 21.8 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef | off | yes | done | 3 | 0 | 3 | 0.00176 | 20 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | loose | none | clef | off | yes | done | 7 | 0 | 9 | - | 50.6 | 0 | no | result names '10 December 1815' |
| u8-books-travel-jsonl | goal | none | clef | off | yes | done | 11 | 0 | 12 | 0.010655 | 168.9 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| ae-blue-top-price | loose | notes | clef | off | yes | done | 1 | 0 | 1 | 0.000474 | 10.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | notes | clef | off | yes | done | 3 | 0 | 3 | 0.001841 | 30.6 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | loose | notes | clef | off | yes | done | 3 | 0 | 3 | 0.002358 | 35.1 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | goal | notes | clef | off | yes | done | 5 | 0 | 5 | 0.003159 | 36.1 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | steps | notes | clef | off | yes | done | 5 | 0 | 5 | 0.002684 | 40.2 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | goal | notes | clef | off | yes | done | 3 | 0 | 3 | 0.00123 | 22.5 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | clef | off | yes | done | 3 | 0 | 3 | 0.001262 | 22.3 | 0 | no | result names 'Soft Stretch Jeans' |
| books-poetry-count | loose | notes | clef | off | yes | done | 4 | 0 | 4 | 0.001649 | 15.9 | 0 | no | truth '19'; result agrees |
| ae-search-jeans | loose | notes | clef | off | yes | done | 8 | 0 | 8 | 0.005057 | 67.7 | 0 | no | result names 'Soft Stretch Jeans' |
| books-poetry-count | goal | notes | clef | off | yes | done | 2 | 0 | 2 | 0.00078 | 7.9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef | off | yes | done | 2 | 0 | 2 | 0.000792 | 6.2 | 0 | no | truth '19'; result agrees |
| ae-blue-top-price | steps | notes | clef | off | no | limit | 12 | 0 | 13 | 0.007114 | 104.1 | 0 | no | truth 'rs. 500'; result differs |
| books-mystery-page2 | goal | notes | clef | off | yes | done | 11 | 0 | 12 | 0.005924 | 66.1 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | notes | clef | off | no | limit | 12 | 2 | 14 | 0.008804 | 84.7 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | notes | clef | off | no | limit | 12 | 0 | 12 | 0.006561 | 71.2 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | goal | notes | clef | off | yes | done | 1 | 0 | 1 | 0.000457 | 5.4 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef | off | yes | done | 3 | 0 | 3 | 0.000989 | 11.9 | 0 | no | result names '£51.77' |
| books-stock | goal | notes | clef | off | yes | done | 2 | 0 | 2 | 0.000781 | 7.4 | 0 | no | truth '20'; result agrees |
| books-stock | steps | notes | clef | off | yes | done | 2 | 0 | 2 | 0.000833 | 8.7 | 0 | no | truth '20'; result agrees |
| books-price | loose | notes | clef | off | no | limit | 12 | 0 | 12 | 0.005294 | 53.8 | 0 | no | result lacks '£51.77' |
| books-stock | loose | notes | clef | off | yes | done | 9 | 0 | 9 | 0.003161 | 36.2 | 0 | no | truth '20'; result agrees |
| canvas-launch | goal | notes | clef | off | yes | done | 2 | 0 | 2 | 0.00081 | 10.6 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | clef | off | yes | done | 2 | 0 | 2 | 0.000775 | 11.6 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | loose | notes | clef | off | no | done | 3 | 0 | 3 | 0.001539 | 22.5 | 0 | no | 2 canvas click(s), 2 inside the drawn button |
| books-poetry-jsonl | goal | notes | clef | off | no | limit | 12 | 0 | 12 | 0.01076 | 160.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | steps | notes | clef | off | no | done | 11 | 0 | 12 | 0.004649 | 74.1 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | notes | clef | off | no | limit | 12 | 0 | 12 | 0.00444 | 80.8 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | notes | clef | off | no | limit | 12 | 0 | 13 | 0.00548 | 89.7 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | steps | notes | clef | off | yes | done | 4 | 0 | 4 | 0.001707 | 29.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| books-poetry-jsonl | steps | notes | clef | off | no | limit | 12 | 0 | 12 | 0.012616 | 189.9 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| maps-eiffel-postcode | goal | notes | clef | off | yes | done | 5 | 0 | 6 | 0.00235 | 39.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| books-poetry-jsonl | loose | notes | clef | off | no | limit | 12 | 0 | 12 | 0.014856 | 216 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| portal-welcome | loose | notes | clef | off | no | limit | 12 | 0 | 12 | 0.002671 | 41.2 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | notes | clef | off | yes | done | 5 | 0 | 6 | 0.001221 | 24.1 | 0 | no | message 'old' quoted |
| u10-portal-new-message | goal | notes | clef | off | yes | done | 5 | 0 | 5 | 0.001423 | 22.5 | 0 | no | message 'new' quoted |
| u10-portal-new-message | loose | notes | clef | off | no | done | 7 | 0 | 7 | 0.001927 | 40.7 | 0 | no | message 'new' not quoted |
| maps-eiffel-postcode | loose | notes | clef | off | no | limit | 12 | 0 | 12 | 0.0055 | 85.1 | 0 | no | Wikidata P281 ['75007']; result differs |
| portal-welcome | steps | notes | clef | off | no | limit | 12 | 0 | 14 | - | 50.4 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | notes | clef | off | no | limit | 12 | 0 | 12 | 0.003199 | 49.4 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | goal | notes | clef | off | yes | done | 3 | 0 | 3 | 0.001156 | 24.3 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | loose | notes | clef | off | yes | done | 4 | 0 | 4 | 0.001578 | 32 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | notes | clef | off | yes | done | 4 | 0 | 4 | 0.001701 | 28.2 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | goal | notes | clef | off | yes | done | 8 | 0 | 8 | 0.002255 | 36.9 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | notes | clef | off | yes | done | 8 | 0 | 8 | 0.001925 | 28.6 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | loose | notes | clef | off | yes | done | 11 | 0 | 11 | 0.004787 | 78 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | loose | notes | clef | off | no | done | 8 | 0 | 9 | 0.008555 | 141.9 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | goal | notes | clef | off | no | done | 11 | 2 | 14 | 0.012678 | 131.8 | 0 | no | truth 'pln 352'; result differs |
| u8-books-travel-jsonl | goal | notes | clef | off | yes | done | 3 | 0 | 3 | 0.003083 | 38.8 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | notes | clef | off | yes | done | 3 | 0 | 3 | 0.000756 | 12.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | loose | notes | clef | off | yes | done | 3 | 0 | 4 | 0.003597 | 52.5 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u5-flights-roundtrip | steps | notes | clef | off | no | done | 10 | 0 | 11 | 0.008225 | 134.8 | 0 | no | truth 'pln 352'; result differs |
| u9-upload | goal | notes | clef | off | yes | done | 3 | 0 | 3 | 0.000805 | 16.4 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | steps | notes | clef | off | yes | done | 4 | 0 | 4 | 0.000934 | 14.8 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | notes | clef | off | yes | done | 3 | 0 | 3 | 0.002321 | 28.1 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| wiki-ada-born | steps | notes | clef | off | yes | done | 3 | 0 | 3 | 0.001803 | 16.2 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | notes | clef | off | yes | done | 3 | 0 | 3 | 0.00175 | 16.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | notes | clef | off | yes | done | 6 | 0 | 7 | 0.00346 | 25.7 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | goal | notes | clef | off | yes | done | 3 | 0 | 4 | 0.001955 | 29.9 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | steps | notes | clef | off | yes | done | 3 | 0 | 3 | 0.001787 | 16.1 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | loose | notes | clef | off | no | limit | 12 | 0 | 13 | 0.007731 | 76.3 | 0 | no | result lacks '10 December 1815' |
| ae-blue-top-price | goal | procedures | clef | off | yes | done | 2 | 0 | 2 | 0.00144 | 19.6 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | procedures | clef | off | yes | done | 5 | 0 | 7 | - | 55.1 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | loose | procedures | clef | off | no | limit | 12 | 0 | 12 | 0.007127 | 62.2 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | steps | procedures | clef | off | yes | done | 3 | 0 | 3 | 0.001501 | 24.8 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | clef | off | yes | done | 4 | 0 | 7 | - | 47.9 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | procedures | clef | off | yes | done | 4 | 3 | 8 | 0.005386 | 29.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| ae-search-jeans | loose | procedures | clef | off | yes | done | 9 | 0 | 15 | - | 102.3 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | procedures | clef | off | yes | done | 4 | 2 | 7 | 0.005032 | 38.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | clef | off | yes | done | 4 | 0 | 5 | - | 31.9 | 0 | no | truth '19'; result agrees |
| ae-polo-brand | steps | procedures | clef | off | no | error:model-timeout | 9 | 0 | 11 | - | 158.5 | 0 | no | result lacks 'Blue Top' |
| books-poetry-count | goal | procedures | clef | off | yes | done | 2 | 1 | 4 | 0.001892 | 16.5 | 0 | no | truth '19'; result agrees |
| ae-blue-top-price | steps | procedures | clef | off | no | limit | 12 | 1 | 19 | - | 170.6 | 0 | no | truth 'rs. 500'; result differs |
| books-poetry-count | steps | procedures | clef | off | yes | done | 10 | 1 | 11 | 0.005964 | 46.7 | 0 | no | truth '19'; result agrees |
| ae-polo-brand | loose | procedures | clef | off | no | limit | 12 | 0 | 14 | - | 214.3 | 0 | no | result lacks 'Blue Top' |
| books-price | goal | procedures | clef | off | yes | done | 2 | 0 | 2 | 0.001034 | 11.7 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef | off | yes | done | 2 | 0 | 2 | 0.000768 | 10.1 | 0 | no | result names '£51.77' |
| books-mystery-page2 | steps | procedures | clef | off | no | limit | 12 | 6 | 20 | 0.016478 | 129.4 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | loose | procedures | clef | off | no | limit | 12 | 0 | 12 | 0.00525 | 45.5 | 0 | no | result lacks '£51.77' |
| books-stock | steps | procedures | clef | off | yes | done | 2 | 0 | 2 | 0.000781 | 7.2 | 0 | no | truth '20'; result agrees |
| books-stock | goal | procedures | clef | off | yes | done | 3 | 0 | 3 | 0.001101 | 11 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | procedures | clef | off | yes | done | 2 | 0 | 2 | 0.000746 | 8 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | clef | off | yes | done | 2 | 0 | 2 | 0.001004 | 18.6 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | clef | off | yes | done | 2 | 0 | 2 | 0.001106 | 19.4 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-stock | loose | procedures | clef | off | no | limit | 12 | 0 | 12 | 0.004492 | 60.3 | 0 | no | truth '20'; result differs |
| flights-oneway | goal | procedures | clef | off | no | done | 12 | 0 | 15 | - | 103 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | procedures | clef | off | no | limit | 12 | 1 | 19 | - | 110.9 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | procedures | clef | off | no | limit | 12 | 0 | 15 | - | 232.1 | 0 | no | 19 on the page, 152 in the file, 19 missing, 152 extra |
| books-poetry-jsonl | steps | procedures | clef | off | no | limit | 12 | 1 | 15 | 0.017275 | 244.5 | 0 | no | 19 on the page, 76 in the file, 19 missing, 76 extra |
| flights-oneway | steps | procedures | clef | off | no | done | 10 | 0 | 11 | - | 120.4 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | loose | procedures | clef | off | no | error:model-timeout | 9 | 1 | 11 | - | 285.6 | 0 | no | 19 on the page, 95 in the file, 19 missing, 95 extra |
| maps-eiffel-postcode | goal | procedures | clef | off | yes | done | 6 | 0 | 9 | - | 60.8 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | procedures | clef | off | yes | done | 9 | 0 | 12 | - | 81.4 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | procedures | clef | off | yes | done | 7 | 0 | 7 | 0.001973 | 33.9 | 0 | no | message 'old' quoted |
| maps-eiffel-postcode | steps | procedures | clef | off | yes | done | 9 | 0 | 13 | - | 83.6 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | procedures | clef | off | no | limit | 12 | 1 | 15 | - | 66.1 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | procedures | clef | off | no | limit | 12 | 0 | 15 | - | 68.9 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | procedures | clef | off | yes | done | 5 | 0 | 5 | 0.001456 | 26 | 0 | no | message 'new' quoted |
| u10-portal-new-message | goal | procedures | clef | off | yes | done | 6 | 0 | 9 | - | 41.5 | 0 | no | message 'new' quoted |
| u10-portal-new-message | loose | procedures | clef | off | no | limit | 12 | 0 | 14 | - | 67 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | procedures | clef | off | yes | done | 4 | 0 | 8 | - | 47.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | procedures | clef | off | yes | done | 4 | 0 | 7 | - | 40.5 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | loose | procedures | clef | off | no | done | 8 | 0 | 11 | 0.004932 | 91.6 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | goal | procedures | clef | off | no | done | 8 | 0 | 9 | - | 93.9 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | steps | procedures | clef | off | no | done | 5 | 0 | 8 | - | 49.4 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u7-register | goal | procedures | clef | off | yes | done | 8 | 0 | 8 | 0.002133 | 35.5 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | steps | procedures | clef | off | no | done | 10 | 0 | 14 | - | 113.1 | 0 | no | truth 'pln 352'; result differs |
| u7-register | loose | procedures | clef | off | yes | done | 9 | 0 | 11 | 0.002563 | 48.1 | 0 | no | registrations 1, confirmed True, password delivered True |
| u9-upload | loose | procedures | clef | off | yes | done | 3 | 0 | 3 | 0.000737 | 11.4 | 0 | no | 1 upload(s); link /files/1 in the result |
| u7-register | steps | procedures | clef | off | yes | done | 8 | 1 | 9 | 0.002998 | 45.8 | 0 | no | registrations 1, confirmed True, password delivered True |
| u9-upload | goal | procedures | clef | off | yes | done | 3 | 0 | 3 | 0.000701 | 12.1 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | steps | procedures | clef | off | yes | done | 3 | 0 | 3 | 0.000677 | 9.8 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | procedures | clef | off | no | done | 3 | 1 | 6 | 0.003483 | 36.5 | 0 | no | 11 on the page, 22 in the file, 0 missing, 11 extra |
| wiki-ada-born | goal | procedures | clef | off | yes | done | 5 | 0 | 8 | - | 27.7 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | procedures | clef | off | yes | done | 4 | 0 | 7 | - | 19.8 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | steps | procedures | clef | off | yes | done | 6 | 0 | 10 | - | 46.1 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | clef | off | yes | done | 7 | 0 | 10 | 0.004882 | 44 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | loose | procedures | clef | off | no | limit | 12 | 0 | 15 | - | 62.9 | 0 | no | result lacks '10 December 1815' |
| u8-books-travel-jsonl | loose | procedures | clef | off | no | done | 5 | 1 | 7 | 0.008721 | 122.7 | 0 | no | 11 on the page, 44 in the file, 0 missing, 33 extra |
| wiki-engine-designer | steps | procedures | clef | off | yes | done | 4 | 0 | 8 | - | 29.5 | 0 | no | result names 'Charles Babbage' |
| u8-books-travel-jsonl | goal | procedures | clef | off | no | done | 8 | 1 | 10 | 0.009503 | 133.1 | 0 | no | 11 on the page, 55 in the file, 0 missing, 44 extra |
| ae-polo-brand | goal | none | clef | b | yes | done | 5 | 0 | 5 | 0.002761 | 40.3 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | none | clef | b | yes | done | 5 | 0 | 5 | 0.003439 | 51.7 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | goal | none | clef | b | no | limit | 12 | 0 | 12 | 0.006364 | 55.4 | 0 | no | truth 'rs. 500'; result differs |
| ae-blue-top-price | loose | none | clef | b | no | limit | 12 | 0 | 12 | 0.006218 | 57.5 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | loose | none | clef | b | yes | done | 3 | 0 | 4 | 0.001421 | 29.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | clef | b | yes | done | 3 | 0 | 4 | 0.001593 | 31.8 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | clef | b | yes | done | 6 | 0 | 6 | 0.003137 | 54.5 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | none | clef | b | yes | done | 10 | 0 | 10 | 0.008488 | 119.5 | 0 | no | result names 'Blue Top' |
| books-poetry-count | loose | none | clef | b | yes | done | 3 | 0 | 3 | 0.001185 | 10.8 | 0 | no | truth '19'; result agrees |
| ae-blue-top-price | steps | none | clef | b | no | limit | 12 | 0 | 13 | 0.008908 | 122.9 | 0 | no | truth 'rs. 500'; result differs |
| books-mystery-page2 | goal | none | clef | b | yes | done | 9 | 0 | 9 | 0.004788 | 57.4 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | none | clef | b | yes | done | 3 | 0 | 3 | 0.001189 | 11.2 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | none | clef | b | yes | done | 3 | 0 | 3 | 0.001157 | 10.4 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | none | clef | b | no | limit | 12 | 1 | 13 | 0.006198 | 65.1 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | none | clef | b | no | limit | 12 | 0 | 12 | 0.0079 | 93.6 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | goal | none | clef | b | yes | done | 2 | 0 | 2 | 0.000859 | 9.1 | 0 | no | result names '£51.77' |
| books-price | steps | none | clef | b | yes | done | 2 | 0 | 2 | 0.000676 | 11.8 | 0 | no | result names '£51.77' |
| books-stock | goal | none | clef | b | yes | done | 2 | 0 | 2 | 0.000701 | 8.6 | 0 | no | truth '20'; result agrees |
| books-stock | loose | none | clef | b | yes | done | 4 | 0 | 4 | 0.001411 | 19.1 | 0 | no | truth '20'; result agrees |
| books-stock | steps | none | clef | b | yes | done | 2 | 0 | 2 | 0.000743 | 9.4 | 0 | no | truth '20'; result agrees |
| books-price | loose | none | clef | b | no | limit | 12 | 0 | 12 | 0.005364 | 50 | 0 | no | result lacks '£51.77' |
| canvas-launch | loose | none | clef | b | yes | done | 2 | 0 | 2 | 0.000949 | 13.4 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | clef | b | yes | done | 2 | 0 | 2 | 0.000995 | 13.9 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | none | clef | b | yes | done | 2 | 0 | 2 | 0.001033 | 14.1 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | loose | none | clef | b | no | limit | 12 | 0 | 12 | 0.010957 | 151.3 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | loose | none | clef | b | no | limit | 12 | 0 | 13 | 0.004792 | 85.8 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | steps | none | clef | b | no | limit | 12 | 0 | 13 | 0.004543 | 81.6 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | none | clef | b | no | limit | 12 | 0 | 12 | 0.010765 | 162.9 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | none | clef | b | no | limit | 12 | 0 | 13 | 0.005662 | 100.6 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | steps | none | clef | b | yes | done | 11 | 0 | 11 | 0.011556 | 170.2 | 0 | no | 19 on the page, 19 in the file, 0 missing, 0 extra |
| maps-eiffel-postcode | goal | none | clef | b | yes | done | 4 | 0 | 4 | 0.001382 | 29.5 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | none | clef | b | yes | done | 5 | 0 | 5 | 0.001022 | 17.8 | 0 | no | message 'old' quoted |
| u10-portal-new-message | loose | none | clef | b | yes | done | 6 | 0 | 6 | 0.001245 | 24.9 | 0 | no | message 'new' quoted |
| u10-portal-new-message | goal | none | clef | b | yes | done | 5 | 0 | 6 | 0.001175 | 19.8 | 0 | no | message 'new' quoted |
| maps-eiffel-postcode | loose | none | clef | b | yes | done | 8 | 0 | 8 | 0.003092 | 59.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | clef | b | yes | done | 7 | 0 | 7 | 0.003117 | 50.4 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | none | clef | b | no | limit | 12 | 0 | 12 | 0.002872 | 51.4 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | none | clef | b | yes | done | 5 | 0 | 6 | 0.001264 | 21 | 0 | no | message 'new' quoted |
| portal-welcome | loose | none | clef | b | no | limit | 12 | 0 | 15 | - | 86.1 | 0 | no | message 'old' not quoted |
| u6-maps-cafe | loose | none | clef | b | yes | done | 3 | 0 | 3 | 0.001072 | 22.9 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | none | clef | b | yes | done | 3 | 0 | 3 | 0.001247 | 24.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | loose | none | clef | b | no | done | 7 | 0 | 7 | 0.004483 | 73.6 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | steps | none | clef | b | yes | done | 4 | 0 | 4 | 0.00174 | 29.9 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | none | clef | b | yes | done | 8 | 0 | 8 | 0.002195 | 37.3 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | goal | none | clef | b | yes | done | 8 | 0 | 8 | 0.001987 | 46 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | none | clef | b | yes | done | 8 | 1 | 9 | 0.003056 | 65.7 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | loose | none | clef | b | yes | done | 3 | 0 | 3 | 0.002925 | 53.9 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | goal | none | clef | b | yes | done | 3 | 0 | 3 | 0.003483 | 59.3 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u5-flights-roundtrip | steps | none | clef | b | no | done | 12 | 0 | 12 | 0.00649 | 134.1 | 0 | no | truth 'pln 352'; result differs |
| u9-upload | loose | none | clef | b | yes | done | 3 | 0 | 3 | 0.000638 | 12.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | none | clef | b | yes | done | 3 | 0 | 3 | 0.000612 | 11.6 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | steps | none | clef | b | yes | done | 4 | 0 | 4 | 0.001002 | 18.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | none | clef | b | yes | done | 3 | 0 | 3 | 0.003263 | 56.1 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| wiki-ada-born | loose | none | clef | b | yes | done | 4 | 0 | 4 | 0.00237 | 23.5 | 0 | no | result names '10 December 1815' |
| u5-flights-roundtrip | goal | none | clef | b | no | limit | 12 | 0 | 13 | 0.008689 | 176.9 | 0 | no | truth 'pln 352'; result differs |
| wiki-ada-born | goal | none | clef | b | yes | done | 3 | 0 | 3 | 0.001761 | 16 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | none | clef | b | yes | done | 6 | 0 | 6 | 0.003352 | 23.8 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | steps | none | clef | b | yes | done | 5 | 0 | 6 | 0.003545 | 36.4 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | none | clef | b | yes | done | 5 | 0 | 6 | 0.002902 | 30.1 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef | b | yes | done | 5 | 0 | 5 | 0.002978 | 27.9 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | notes | clef | b | no | failed | 1 | 0 | 1 | 0.000422 | 21.5 | 0 | no | truth 'rs. 500'; result differs |
| ae-blue-top-price | steps | notes | clef | b | yes | done | 4 | 0 | 4 | 0.002006 | 48.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | steps | notes | clef | b | yes | done | 2 | 0 | 2 | 0.000867 | 18.4 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | loose | notes | clef | b | no | failed | 3 | 0 | 7 | - | 75.5 | 2 | no | result lacks 'Blue Top' |
| ae-polo-brand | goal | notes | clef | b | yes | done | 6 | 0 | 6 | 0.003569 | 49.3 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | loose | notes | clef | b | no | limit | 12 | 0 | 12 | 0.007013 | 89.5 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | loose | notes | clef | b | yes | done | 3 | 0 | 3 | 0.001277 | 26.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef | b | yes | done | 3 | 0 | 4 | 0.001473 | 31.8 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | clef | b | yes | done | 3 | 0 | 3 | 0.001249 | 27 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | notes | clef | b | yes | done | 5 | 0 | 5 | 0.002297 | 20.7 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | clef | b | yes | done | 2 | 0 | 2 | 0.000805 | 7.2 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef | b | yes | done | 2 | 0 | 2 | 0.000892 | 9.3 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | notes | clef | b | yes | done | 3 | 0 | 3 | 0.001233 | 11.9 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | notes | clef | b | yes | done | 5 | 0 | 5 | 0.002659 | 32.8 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | notes | clef | b | yes | done | 10 | 3 | 13 | 0.00844 | 64.6 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-price | loose | notes | clef | b | yes | done | 7 | 0 | 7 | 0.003179 | 31.9 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef | b | yes | done | 1 | 0 | 1 | 0.000442 | 3.4 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef | b | yes | done | 2 | 0 | 2 | 0.000698 | 7.7 | 0 | no | result names '£51.77' |
| books-stock | loose | notes | clef | b | yes | done | 4 | 0 | 4 | 0.001409 | 21.6 | 0 | no | truth '20'; result agrees |
| books-stock | goal | notes | clef | b | yes | done | 3 | 0 | 3 | 0.001251 | 14.8 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | steps | notes | clef | b | no | limit | 12 | 0 | 12 | 0.007377 | 100.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | steps | notes | clef | b | yes | done | 2 | 0 | 2 | 0.000724 | 7.7 | 0 | no | truth '20'; result agrees |
| canvas-launch | goal | notes | clef | b | yes | done | 2 | 0 | 2 | 0.000863 | 11.5 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | loose | notes | clef | b | yes | done | 2 | 0 | 2 | 0.001111 | 16.8 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | clef | b | yes | done | 2 | 0 | 2 | 0.000785 | 11 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | goal | notes | clef | b | no | limit | 12 | 0 | 12 | 0.010418 | 173.7 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | loose | notes | clef | b | no | limit | 12 | 0 | 13 | 0.004673 | 86 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | loose | notes | clef | b | no | limit | 12 | 0 | 13 | 0.014253 | 229.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | notes | clef | b | no | limit | 12 | 0 | 13 | 0.005025 | 96.6 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | notes | clef | b | yes | done | 3 | 0 | 4 | 0.001247 | 28.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | notes | clef | b | no | done | 10 | 0 | 10 | 0.004365 | 87.8 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | steps | notes | clef | b | yes | done | 4 | 0 | 4 | 0.001916 | 41.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | notes | clef | b | yes | done | 5 | 0 | 5 | 0.001158 | 23.2 | 0 | no | message 'old' quoted |
| maps-eiffel-postcode | loose | notes | clef | b | yes | done | 10 | 0 | 10 | 0.004015 | 72 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | notes | clef | b | yes | done | 6 | 0 | 6 | 0.001529 | 26 | 0 | no | message 'old' quoted |
| u10-portal-new-message | loose | notes | clef | b | no | done | 6 | 0 | 6 | 0.001421 | 28.4 | 0 | no | message 'new' not quoted |
| portal-welcome | loose | notes | clef | b | no | limit | 12 | 0 | 14 | - | 56.6 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | notes | clef | b | yes | done | 6 | 0 | 6 | 0.00144 | 23.9 | 0 | no | message 'new' quoted |
| u10-portal-new-message | goal | notes | clef | b | no | limit | 12 | 0 | 15 | 0.004511 | 80.7 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | notes | clef | b | yes | done | 4 | 0 | 4 | 0.001556 | 35.9 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | goal | notes | clef | b | no | done | 11 | 0 | 11 | 0.006366 | 105.5 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | loose | notes | clef | b | no | done | 8 | 0 | 11 | 0.005573 | 108.2 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | notes | clef | b | yes | done | 3 | 0 | 4 | 0.001358 | 28.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | steps | notes | clef | b | no | error:model-timeout | 8 | 0 | 9 | - | 129.6 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | steps | notes | clef | b | yes | done | 4 | 0 | 4 | 0.001746 | 31.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | notes | clef | b | yes | done | 8 | 0 | 8 | 0.00223 | 42.4 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | loose | notes | clef | b | yes | done | 3 | 0 | 3 | 0.002601 | 42.4 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u7-register | goal | notes | clef | b | yes | done | 8 | 0 | 10 | 0.002835 | 59.1 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | goal | notes | clef | b | yes | done | 3 | 0 | 3 | 0.003008 | 47 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u7-register | steps | notes | clef | b | yes | done | 9 | 0 | 11 | 0.00272 | 55.5 | 0 | no | registrations 1, confirmed True, password delivered True |
| u9-upload | loose | notes | clef | b | yes | done | 3 | 0 | 3 | 0.000775 | 14.6 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | notes | clef | b | yes | done | 3 | 0 | 3 | 0.000752 | 14.7 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | loose | notes | clef | b | yes | done | 3 | 0 | 3 | 0.001801 | 16.6 | 0 | no | result names '10 December 1815' |
| u8-books-travel-jsonl | steps | notes | clef | b | yes | done | 3 | 0 | 3 | 0.002643 | 39.3 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | steps | notes | clef | b | yes | done | 7 | 0 | 7 | 0.001734 | 34.1 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | notes | clef | b | yes | done | 4 | 0 | 4 | 0.002515 | 23 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | notes | clef | b | yes | done | 3 | 0 | 3 | 0.001851 | 14.4 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | steps | notes | clef | b | yes | done | 4 | 0 | 4 | 0.002512 | 21.4 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | steps | notes | clef | b | yes | done | 3 | 0 | 3 | 0.001831 | 14.7 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | notes | clef | b | no | limit | 12 | 0 | 12 | 0.00679 | 43.8 | 0 | no | result lacks 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | clef | b | no | failed | 1 | 0 | 1 | 0.000466 | 19.1 | 0 | no | check failed: HTTP Error 503: Service Unavailable |
| ae-polo-brand | loose | procedures | clef | b | no | failed | 1 | 0 | 1 | 0.001413 | 40 | 0 | no | result lacks 'Blue Top' |
| ae-polo-brand | goal | procedures | clef | b | yes | done | 2 | 0 | 2 | 0.001523 | 37.2 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | steps | procedures | clef | b | no | failed | 3 | 0 | 7 | - | 81.5 | 2 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | steps | procedures | clef | b | yes | done | 5 | 0 | 5 | 0.003309 | 60.5 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | loose | procedures | clef | b | yes | done | 5 | 0 | 8 | - | 58.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | clef | b | yes | done | 4 | 0 | 7 | - | 44.7 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | clef | b | yes | done | 4 | 0 | 4 | 0.002255 | 41.6 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | procedures | clef | b | yes | done | 3 | 4 | 8 | 0.005839 | 33 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | clef | b | yes | done | 2 | 1 | 5 | 0.001819 | 18.2 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | procedures | clef | b | yes | done | 2 | 1 | 4 | 0.001706 | 13.2 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | procedures | clef | b | yes | done | 2 | 0 | 2 | 0.000895 | 7.9 | 0 | no | truth '19'; result agrees |
| ae-blue-top-price | loose | procedures | clef | b | no | failed | 5 | 0 | 9 | - | 200.8 | 1 | no | truth 'rs. 500'; result differs |
| books-mystery-page2 | steps | procedures | clef | b | yes | done | 9 | 2 | 12 | 0.007855 | 80.6 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | procedures | clef | b | yes | done | 10 | 3 | 14 | 0.012704 | 136.9 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-price | loose | procedures | clef | b | yes | done | 2 | 0 | 2 | 0.000785 | 6.1 | 0 | no | result names '£51.77' |
| books-price | goal | procedures | clef | b | yes | done | 1 | 0 | 1 | 0.000497 | 6.5 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef | b | yes | done | 2 | 0 | 2 | 0.000801 | 9.2 | 0 | no | result names '£51.77' |
| books-stock | loose | procedures | clef | b | yes | done | 3 | 0 | 3 | 0.001139 | 11.3 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | steps | procedures | clef | b | no | done | 4 | 0 | 6 | 0.004777 | 75.3 | 0 | no | 19 on the page, 38 in the file, 0 missing, 19 extra |
| books-stock | goal | procedures | clef | b | yes | done | 3 | 0 | 3 | 0.001137 | 13.5 | 0 | no | truth '20'; result agrees |
| books-stock | steps | procedures | clef | b | yes | done | 2 | 0 | 2 | 0.000811 | 7.4 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | procedures | clef | b | yes | done | 2 | 0 | 2 | 0.000736 | 9.1 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | clef | b | yes | done | 2 | 0 | 2 | 0.000728 | 16 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | clef | b | yes | done | 2 | 0 | 2 | 0.000922 | 14.5 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | loose | procedures | clef | b | no | error:model-timeout | 5 | 1 | 7 | - | 150 | 0 | no | 19 on the page, 57 in the file, 19 missing, 57 extra |
| flights-oneway | goal | procedures | clef | b | no | limit | 12 | 1 | 18 | - | 110.1 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | procedures | clef | b | no | limit | 12 | 1 | 19 | - | 131.7 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | steps | procedures | clef | b | no | done | 10 | 1 | 17 | - | 108.8 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | procedures | clef | b | no | error:model-timeout | 12 | 1 | 15 | - | 300 | 0 | no | 19 on the page, 133 in the file, 19 missing, 133 extra |
| maps-eiffel-postcode | loose | procedures | clef | b | yes | done | 7 | 0 | 10 | - | 69.1 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | clef | b | yes | done | 6 | 0 | 9 | - | 54.1 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | procedures | clef | b | yes | done | 7 | 0 | 8 | - | 60 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | procedures | clef | b | yes | done | 6 | 0 | 6 | 0.001637 | 27.7 | 0 | no | message 'old' quoted |
| portal-welcome | loose | procedures | clef | b | no | limit | 12 | 0 | 15 | - | 68.1 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | procedures | clef | b | no | limit | 12 | 0 | 15 | - | 84.6 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | procedures | clef | b | yes | done | 6 | 0 | 7 | 0.001809 | 36.6 | 0 | no | message 'new' quoted |
| u10-portal-new-message | goal | procedures | clef | b | no | limit | 12 | 0 | 18 | - | 66.4 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | loose | procedures | clef | b | no | limit | 12 | 0 | 15 | - | 101.8 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | procedures | clef | b | yes | done | 4 | 0 | 7 | - | 40.2 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | procedures | clef | b | yes | done | 4 | 0 | 9 | - | 45.2 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | steps | procedures | clef | b | no | done | 8 | 4 | 21 | - | 132.8 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | goal | procedures | clef | b | no | done | 11 | 1 | 17 | - | 149.6 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | loose | procedures | clef | b | no | done | 12 | 0 | 19 | - | 180.6 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | steps | procedures | clef | b | yes | done | 5 | 0 | 8 | - | 49.1 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7, 4.7] |
| u7-register | goal | procedures | clef | b | yes | done | 8 | 0 | 8 | 0.002055 | 36.7 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | loose | procedures | clef | b | yes | done | 9 | 0 | 10 | 0.003035 | 56.9 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | procedures | clef | b | yes | done | 8 | 0 | 8 | 0.001939 | 32.2 | 0 | no | registrations 1, confirmed True, password delivered True |
| u9-upload | loose | procedures | clef | b | yes | done | 3 | 0 | 3 | 0.000747 | 12.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | procedures | clef | b | yes | done | 3 | 0 | 3 | 0.000669 | 11.9 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | loose | procedures | clef | b | no | done | 4 | 1 | 7 | 0.005321 | 74 | 0 | no | 11 on the page, 33 in the file, 0 missing, 22 extra |
| u9-upload | steps | procedures | clef | b | yes | done | 4 | 0 | 4 | 0.001172 | 22.2 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | procedures | clef | b | yes | done | 4 | 0 | 7 | - | 22.7 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef | b | yes | done | 4 | 0 | 7 | - | 34.9 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | loose | procedures | clef | b | no | limit | 12 | 0 | 15 | - | 64.7 | 0 | no | result lacks '10 December 1815' |
| wiki-engine-designer | goal | procedures | clef | b | yes | done | 4 | 0 | 7 | - | 35.8 | 0 | no | result names 'Charles Babbage' |
| u8-books-travel-jsonl | steps | procedures | clef | b | no | done | 9 | 1 | 11 | 0.010812 | 155.2 | 0 | no | 11 on the page, 44 in the file, 0 missing, 33 extra |
| wiki-engine-designer | steps | procedures | clef | b | yes | done | 5 | 0 | 8 | - | 30 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | procedures | clef | b | no | limit | 12 | 0 | 15 | - | 92.6 | 0 | no | result lacks 'Charles Babbage' |
| u8-books-travel-jsonl | goal | procedures | clef | b | no | done | 12 | 1 | 15 | 0.017364 | 292.5 | 0 | no | 11 on the page, 77 in the file, 0 missing, 66 extra |
| ae-blue-top-price | goal | none | clef | c | no | failed | 1 | 0 | 1 | 0.00044 | 20.2 | 0 | no | truth 'rs. 500'; result differs |
| ae-blue-top-price | loose | none | clef | c | yes | done | 2 | 0 | 2 | 0.000993 | 27.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | none | clef | c | no | failed | 3 | 4 | 7 | 0.002282 | 47.5 | 0 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | steps | none | clef | c | yes | done | 2 | 0 | 2 | 0.000861 | 19.2 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | goal | none | clef | c | yes | done | 2 | 0 | 2 | 0.001244 | 27.2 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | steps | none | clef | c | yes | done | 6 | 0 | 6 | 0.002997 | 48.3 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | loose | none | clef | c | yes | done | 7 | 0 | 7 | 0.005005 | 79.5 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | clef | c | yes | done | 8 | 0 | 8 | 0.005307 | 85.1 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | none | clef | c | yes | done | 6 | 0 | 6 | 0.002792 | 35.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | clef | c | yes | done | 2 | 0 | 2 | 0.000762 | 9.9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | none | clef | c | yes | done | 3 | 0 | 3 | 0.001164 | 16.7 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | none | clef | c | yes | done | 2 | 0 | 2 | 0.000765 | 6.4 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | loose | none | clef | c | no | limit | 12 | 2 | 14 | 0.009979 | 111 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-polo-brand | loose | none | clef | c | yes | done | 12 | 0 | 12 | 0.015085 | 245.9 | 0 | no | result names 'Blue Top' |
| books-mystery-page2 | steps | none | clef | c | no | limit | 12 | 0 | 12 | 0.007986 | 117.6 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | loose | none | clef | c | no | limit | 12 | 0 | 12 | 0.004942 | 45 | 0 | no | result lacks '£51.77' |
| books-price | goal | none | clef | c | yes | done | 1 | 0 | 1 | 0.000384 | 3.8 | 0 | no | result names '£51.77' |
| books-price | steps | none | clef | c | yes | done | 2 | 0 | 2 | 0.00069 | 12.8 | 0 | no | result names '£51.77' |
| books-stock | loose | none | clef | c | yes | done | 2 | 0 | 2 | 0.000708 | 7.9 | 0 | no | truth '20'; result agrees |
| books-stock | goal | none | clef | c | yes | done | 3 | 0 | 3 | 0.001099 | 14 | 0 | no | truth '20'; result agrees |
| books-stock | steps | none | clef | c | yes | done | 2 | 0 | 2 | 0.000775 | 7.7 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | none | clef | c | yes | done | 2 | 0 | 2 | 0.000748 | 12.3 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | none | clef | c | yes | done | 2 | 0 | 2 | 0.000727 | 8.7 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | clef | c | yes | done | 2 | 0 | 2 | 0.000908 | 14 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | none | clef | c | yes | done | 10 | 0 | 10 | 0.012135 | 193 | 0 | no | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-poetry-jsonl | loose | none | clef | c | no | limit | 12 | 1 | 15 | 0.014473 | 263.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | loose | none | clef | c | no | limit | 12 | 0 | 14 | 0.00561 | 110.1 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | none | clef | c | no | limit | 12 | 0 | 13 | 0.015851 | 282.4 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | none | clef | c | no | limit | 12 | 0 | 14 | - | 95 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | none | clef | c | yes | done | 6 | 0 | 6 | 0.002569 | 43.6 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | clef | c | yes | done | 4 | 0 | 4 | 0.001938 | 33.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | none | clef | c | no | limit | 12 | 0 | 12 | 0.005362 | 87.1 | 0 | no | Wikidata P281 ['75007']; result differs |
| portal-welcome | loose | none | clef | c | no | limit | 12 | 0 | 12 | 0.002396 | 46 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | none | clef | c | yes | done | 6 | 0 | 6 | 0.001233 | 24.7 | 0 | no | message 'old' quoted |
| flights-oneway | steps | none | clef | c | no | limit | 12 | 0 | 14 | - | 150.3 | 0 | no | truth 'pln 148'; result differs |
| u10-portal-new-message | loose | none | clef | c | no | limit | 12 | 0 | 12 | 0.002978 | 51.9 | 0 | no | message 'new' not quoted |
| portal-welcome | steps | none | clef | c | no | limit | 12 | 0 | 14 | 0.003336 | 64.3 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | none | clef | c | no | limit | 12 | 0 | 13 | 0.0031 | 57.8 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | none | clef | c | no | limit | 12 | 0 | 14 | 0.003097 | 57.2 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | none | clef | c | yes | done | 3 | 0 | 3 | 0.001077 | 24.3 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | loose | none | clef | c | no | done | 9 | 0 | 9 | 0.004397 | 86 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | none | clef | c | yes | done | 3 | 0 | 3 | 0.001133 | 25.1 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | steps | none | clef | c | no | limit | 12 | 0 | 12 | 0.006339 | 118.5 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | steps | none | clef | c | yes | done | 4 | 0 | 4 | 0.001639 | 33.5 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | none | clef | c | yes | done | 8 | 0 | 8 | 0.001907 | 37.1 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | goal | none | clef | c | no | done | 7 | 0 | 8 | 0.006421 | 126.7 | 0 | no | truth 'pln 352'; result differs |
| u8-books-travel-jsonl | goal | none | clef | c | yes | done | 3 | 0 | 3 | 0.002902 | 44.6 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u7-register | goal | none | clef | c | yes | done | 8 | 0 | 10 | 0.002455 | 52.2 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | loose | none | clef | c | yes | done | 3 | 0 | 3 | 0.003232 | 51.7 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | none | clef | c | yes | done | 3 | 0 | 3 | 0.000637 | 14.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | none | clef | c | yes | done | 3 | 0 | 3 | 0.000658 | 12.6 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | none | clef | c | yes | done | 3 | 0 | 3 | 0.00182 | 23.1 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | steps | none | clef | c | yes | done | 3 | 0 | 3 | 0.000868 | 17.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u7-register | steps | none | clef | c | no | limit | 12 | 0 | 13 | 0.005389 | 96.7 | 0 | no | registrations 0, confirmed False, password delivered True |
| wiki-ada-born | goal | none | clef | c | yes | done | 4 | 0 | 5 | 0.002477 | 23.2 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | none | clef | c | yes | done | 4 | 0 | 5 | 0.002524 | 22.1 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | loose | none | clef | c | yes | done | 8 | 0 | 8 | 0.004964 | 43.1 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | none | clef | c | yes | done | 4 | 0 | 5 | 0.002469 | 22.1 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef | c | yes | done | 3 | 0 | 4 | 0.001899 | 17.5 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | none | clef | c | no | limit | 12 | 0 | 14 | - | 62 | 0 | no | result lacks 'Charles Babbage' |
| ae-blue-top-price | goal | notes | clef | c | no | failed | 1 | 0 | 1 | 0.000395 | 19.1 | 0 | no | check failed: HTTP Error 503: Service Unavailable |
| ae-polo-brand | goal | notes | clef | c | yes | done | 2 | 0 | 2 | 0.001144 | 31.9 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | loose | notes | clef | c | yes | done | 4 | 0 | 4 | 0.002709 | 61.8 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | steps | notes | clef | c | yes | done | 6 | 0 | 6 | 0.003202 | 72.2 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | notes | clef | c | no | limit | 12 | 0 | 12 | 0.006893 | 88.1 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | goal | notes | clef | c | yes | done | 3 | 0 | 4 | 0.001619 | 34.9 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | notes | clef | c | yes | done | 5 | 0 | 5 | 0.002869 | 57.3 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | steps | notes | clef | c | yes | done | 3 | 0 | 3 | 0.001426 | 27.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | loose | notes | clef | c | yes | done | 8 | 0 | 9 | 0.005105 | 73.6 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | steps | notes | clef | c | yes | done | 5 | 0 | 5 | 0.002416 | 26.7 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | clef | c | yes | done | 3 | 0 | 3 | 0.001194 | 11.5 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | notes | clef | c | yes | done | 7 | 0 | 7 | 0.003531 | 37.2 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | notes | clef | c | yes | done | 2 | 0 | 2 | 0.000808 | 5.9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef | c | yes | done | 3 | 0 | 3 | 0.001247 | 9.3 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | loose | notes | clef | c | no | limit | 12 | 0 | 13 | 0.007343 | 99.9 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | loose | notes | clef | c | yes | done | 1 | 0 | 1 | 0.000484 | 6.6 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef | c | yes | done | 1 | 0 | 1 | 0.000464 | 3.8 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef | c | yes | done | 2 | 0 | 2 | 0.000765 | 8.5 | 0 | no | result names '£51.77' |
| books-stock | loose | notes | clef | c | yes | done | 4 | 0 | 4 | 0.001405 | 20.7 | 0 | no | truth '20'; result agrees |
| books-stock | goal | notes | clef | c | yes | done | 2 | 0 | 2 | 0.000757 | 12.4 | 0 | no | truth '20'; result agrees |
| books-stock | steps | notes | clef | c | yes | done | 2 | 0 | 2 | 0.000783 | 8.5 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | goal | notes | clef | c | no | limit | 12 | 0 | 12 | 0.008458 | 129.9 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| canvas-launch | loose | notes | clef | c | yes | done | 2 | 0 | 2 | 0.000728 | 8.3 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | notes | clef | c | yes | done | 2 | 0 | 2 | 0.000777 | 11 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | clef | c | yes | done | 2 | 0 | 2 | 0.000757 | 9.4 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | loose | notes | clef | c | no | limit | 12 | 0 | 12 | 0.0114 | 191.4 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | notes | clef | c | no | done | 11 | 0 | 11 | 0.004916 | 80.9 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | notes | clef | c | no | limit | 12 | 0 | 13 | 0.004628 | 86.6 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | steps | notes | clef | c | no | limit | 12 | 0 | 13 | 0.0141 | 232.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| maps-eiffel-postcode | goal | notes | clef | c | yes | done | 5 | 0 | 5 | 0.002214 | 39.3 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | clef | c | yes | done | 5 | 0 | 5 | 0.002424 | 43.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | notes | clef | c | no | done | 11 | 0 | 12 | 0.005765 | 97.7 | 0 | no | truth 'pln 148'; result differs |
| portal-welcome | goal | notes | clef | c | yes | done | 5 | 0 | 5 | 0.001338 | 26.3 | 0 | no | message 'old' quoted |
| portal-welcome | loose | notes | clef | c | no | limit | 12 | 1 | 13 | 0.003256 | 45.8 | 0 | no | message 'old' not quoted |
| maps-eiffel-postcode | loose | notes | clef | c | no | limit | 12 | 0 | 13 | 0.005811 | 96 | 0 | no | Wikidata P281 ['75007']; result differs |
| u10-portal-new-message | loose | notes | clef | c | yes | done | 5 | 0 | 6 | 0.001569 | 27.4 | 0 | no | message 'new' quoted |
| u10-portal-new-message | goal | notes | clef | c | yes | done | 6 | 0 | 6 | 0.001525 | 24.7 | 0 | no | message 'new' quoted |
| portal-welcome | steps | notes | clef | c | no | limit | 12 | 0 | 16 | 0.003552 | 62.8 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | notes | clef | c | no | limit | 12 | 0 | 13 | 0.003367 | 60.1 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | notes | clef | c | yes | done | 3 | 0 | 4 | 0.001291 | 29.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | notes | clef | c | yes | done | 3 | 0 | 3 | 0.001332 | 27 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | loose | notes | clef | c | no | done | 8 | 0 | 10 | 0.006361 | 126 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | goal | notes | clef | c | no | limit | 12 | 0 | 12 | 0.007392 | 129.6 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | steps | notes | clef | c | yes | done | 4 | 0 | 4 | 0.001699 | 31 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | steps | notes | clef | c | no | done | 11 | 1 | 13 | 0.008911 | 145.1 | 0 | no | truth 'pln 352'; result differs |
| u7-register | loose | notes | clef | c | yes | done | 9 | 0 | 10 | 0.002353 | 46.3 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | goal | notes | clef | c | yes | done | 8 | 0 | 8 | 0.002315 | 44.9 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | notes | clef | c | yes | done | 8 | 1 | 9 | 0.002833 | 48.2 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | loose | notes | clef | c | yes | done | 3 | 0 | 3 | 0.003353 | 50 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | steps | notes | clef | c | yes | done | 3 | 0 | 3 | 0.002653 | 42.7 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | notes | clef | c | yes | done | 3 | 0 | 3 | 0.000801 | 14 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | notes | clef | c | yes | done | 3 | 0 | 3 | 0.000711 | 14.6 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | notes | clef | c | yes | done | 3 | 0 | 3 | 0.003578 | 56.1 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | steps | notes | clef | c | yes | done | 4 | 0 | 4 | 0.000972 | 17.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | notes | clef | c | yes | done | 3 | 0 | 3 | 0.001814 | 17.3 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | loose | notes | clef | c | yes | done | 4 | 0 | 4 | 0.002743 | 32.3 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | notes | clef | c | yes | done | 5 | 0 | 5 | 0.003167 | 30.4 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | notes | clef | c | yes | done | 5 | 0 | 5 | 0.002936 | 21.7 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef | c | yes | done | 3 | 0 | 3 | 0.001977 | 20.7 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | notes | clef | c | yes | done | 10 | 0 | 10 | 0.006315 | 50.2 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | clef | c | no | done | 1 | 0 | 1 | 0.000532 | 19.9 | 0 | no | check failed: HTTP Error 503: Service Unavailable |
| ae-blue-top-price | loose | procedures | clef | c | no | failed | 1 | 0 | 1 | 0.000897 | 28.8 | 0 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | goal | procedures | clef | c | yes | done | 2 | 0 | 2 | 0.001117 | 28 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | loose | procedures | clef | c | no | failed | 3 | 4 | 7 | 0.004184 | 91.2 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | loose | procedures | clef | c | yes | done | 7 | 0 | 10 | - | 80.5 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | clef | c | yes | done | 4 | 0 | 7 | - | 54 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-blue-top-price | steps | procedures | clef | c | no | limit | 12 | 0 | 20 | - | 176.4 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | steps | procedures | clef | c | yes | done | 5 | 0 | 8 | - | 54.6 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | procedures | clef | c | yes | done | 4 | 4 | 10 | 0.007036 | 38.9 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | clef | c | yes | done | 3 | 1 | 5 | 0.002258 | 20.2 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | loose | procedures | clef | c | yes | done | 9 | 3 | 13 | 0.010705 | 99.7 | 0 | no | result names 'The Mysterious Affair at Styles' |
| ae-polo-brand | steps | procedures | clef | c | no | limit | 12 | 0 | 12 | 0.014727 | 225.4 | 0 | no | result lacks 'Blue Top' |
| books-poetry-count | goal | procedures | clef | c | yes | done | 4 | 0 | 5 | 0.001704 | 16.3 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | procedures | clef | c | yes | done | 3 | 0 | 3 | 0.001664 | 19.4 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | procedures | clef | c | yes | done | 8 | 2 | 10 | 0.007589 | 88.9 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-price | loose | procedures | clef | c | no | limit | 12 | 0 | 12 | 0.00553 | 53.1 | 0 | no | result lacks '£51.77' |
| books-price | goal | procedures | clef | c | yes | done | 1 | 0 | 1 | 0.000448 | 4.3 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef | c | yes | done | 2 | 0 | 2 | 0.000808 | 8.7 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | steps | procedures | clef | c | no | error:model-timeout | 5 | 1 | 8 | - | 112.5 | 0 | no | 19 on the page, 38 in the file, 19 missing, 38 extra |
| books-stock | goal | procedures | clef | c | yes | done | 2 | 0 | 2 | 0.000843 | 8.3 | 0 | no | truth '20'; result agrees |
| books-stock | loose | procedures | clef | c | yes | done | 10 | 0 | 10 | 0.003536 | 43.3 | 0 | no | truth '20'; result agrees |
| books-stock | steps | procedures | clef | c | yes | done | 2 | 0 | 2 | 0.000738 | 8.3 | 0 | no | truth '20'; result agrees |
| canvas-launch | goal | procedures | clef | c | yes | done | 2 | 0 | 2 | 0.000843 | 12.7 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | loose | procedures | clef | c | yes | done | 2 | 0 | 2 | 0.001271 | 21.7 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | clef | c | yes | done | 2 | 0 | 2 | 0.000821 | 11 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | procedures | clef | c | no | limit | 12 | 1 | 19 | - | 124.9 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | procedures | clef | c | no | error:model-timeout | 10 | 1 | 12 | - | 281.6 | 0 | no | 19 on the page, 57 in the file, 19 missing, 57 extra |
| books-poetry-jsonl | loose | procedures | clef | c | no | limit | 12 | 1 | 15 | 0.018138 | 289 | 0 | no | 19 on the page, 114 in the file, 19 missing, 114 extra |
| flights-oneway | goal | procedures | clef | c | no | limit | 12 | 1 | 19 | - | 125.7 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | procedures | clef | c | yes | done | 5 | 0 | 6 | - | 47.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | procedures | clef | c | yes | done | 7 | 0 | 10 | - | 57 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | clef | c | yes | done | 6 | 0 | 9 | - | 52.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | procedures | clef | c | no | done | 8 | 1 | 15 | - | 99.2 | 0 | no | truth 'pln 148'; result differs |
| portal-welcome | goal | procedures | clef | c | yes | done | 8 | 0 | 11 | - | 47.3 | 0 | no | message 'old' quoted |
| portal-welcome | loose | procedures | clef | c | no | limit | 12 | 0 | 14 | - | 52.9 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | procedures | clef | c | no | limit | 12 | 0 | 17 | - | 69 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | procedures | clef | c | yes | done | 7 | 0 | 9 | - | 41.3 | 0 | no | message 'new' quoted |
| u10-portal-new-message | loose | procedures | clef | c | no | limit | 12 | 0 | 14 | - | 61.9 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | procedures | clef | c | no | limit | 12 | 0 | 14 | - | 62.7 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | procedures | clef | c | yes | done | 4 | 0 | 7 | - | 40.6 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | loose | procedures | clef | c | no | done | 7 | 1 | 13 | - | 114.2 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | procedures | clef | c | yes | done | 4 | 0 | 5 | - | 43 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | procedures | clef | c | yes | done | 5 | 0 | 8 | - | 46.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | procedures | clef | c | yes | done | 8 | 0 | 8 | 0.002032 | 37.1 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | goal | procedures | clef | c | no | done | 12 | 0 | 15 | - | 183.2 | 0 | no | truth 'pln 352'; result differs |
| u7-register | goal | procedures | clef | c | yes | done | 8 | 0 | 8 | 0.002011 | 35.5 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | procedures | clef | c | yes | done | 8 | 0 | 9 | 0.002297 | 41.4 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | steps | procedures | clef | c | no | done | 10 | 1 | 16 | - | 194 | 0 | no | truth 'pln 352'; result differs |
| u9-upload | loose | procedures | clef | c | yes | done | 4 | 0 | 4 | 0.001017 | 18.9 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | procedures | clef | c | yes | done | 4 | 0 | 4 | 0.000904 | 18.1 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | procedures | clef | c | no | done | 3 | 1 | 5 | 0.003516 | 39.8 | 0 | no | 11 on the page, 22 in the file, 0 missing, 11 extra |
| u9-upload | steps | procedures | clef | c | yes | done | 3 | 0 | 3 | 0.000904 | 15.6 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | procedures | clef | c | no | done | 6 | 0 | 7 | - | 73.1 | 0 | no | 11 on the page, 33 in the file, 0 missing, 22 extra |
| u8-books-travel-jsonl | loose | procedures | clef | c | no | done | 4 | 1 | 6 | 0.005998 | 87.2 | 0 | no | 11 on the page, 33 in the file, 0 missing, 22 extra |
| wiki-ada-born | loose | procedures | clef | c | yes | done | 5 | 0 | 8 | - | 34.5 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef | c | yes | done | 4 | 0 | 8 | - | 32 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | procedures | clef | c | yes | done | 5 | 0 | 8 | - | 43.7 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | procedures | clef | c | yes | done | 5 | 0 | 8 | - | 35.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef | c | yes | done | 4 | 0 | 7 | - | 34.4 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | procedures | clef | c | no | limit | 12 | 0 | 16 | - | 85.5 | 0 | no | result lacks 'Charles Babbage' |
| ae-blue-top-price | goal | none | clef-flash | b | yes | done | 7 | 0 | 7 | 0.00372 | 59.2 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | none | clef-flash | b | yes | done | 10 | 0 | 10 | 0.00513 | 66.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000947 | 19.6 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | loose | none | clef-flash | b | yes | done | 7 | 0 | 7 | 0.005088 | 94.3 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | none | clef-flash | b | yes | done | 2 | 0 | 2 | 0.001516 | 29.5 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | goal | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001296 | 27.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | clef-flash | b | yes | done | 5 | 0 | 5 | 0.002861 | 56.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | loose | none | clef-flash | b | yes | done | 6 | 0 | 7 | 0.005296 | 102.6 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | none | clef-flash | b | yes | done | 4 | 2 | 8 | - | 29 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | none | clef-flash | b | no | limit | 12 | 2 | 15 | 0.007473 | 66.1 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-blue-top-price | steps | none | clef-flash | b | no | limit | 12 | 0 | 14 | 0.01035 | 192.4 | 0 | no | truth 'rs. 500'; result differs |
| books-poetry-count | steps | none | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000766 | 7.8 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.00118 | 11.1 | 0 | no | truth '19'; result agrees |
| books-poetry-count | loose | none | clef-flash | b | yes | done | 5 | 0 | 5 | 0.002095 | 23.5 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | none | clef-flash | b | yes | done | 6 | 0 | 7 | 0.002781 | 30.4 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-price | loose | none | clef-flash | b | yes | done | 1 | 0 | 1 | 0.00045 | 4.9 | 0 | no | result names '£51.77' |
| books-price | goal | none | clef-flash | b | yes | done | 1 | 0 | 1 | 0.000471 | 6.3 | 0 | no | result names '£51.77' |
| books-price | steps | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.00101 | 11.5 | 0 | no | result names '£51.77' |
| books-stock | loose | none | clef-flash | b | no | limit | 12 | 0 | 12 | 0.004012 | 54.7 | 0 | no | truth '20'; result differs |
| books-stock | goal | none | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000745 | 9.9 | 0 | no | truth '20'; result agrees |
| books-stock | steps | none | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000714 | 8.1 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | none | clef-flash | b | yes | done | 2 | 0 | 2 | 0.001306 | 21 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | none | clef-flash | b | yes | done | 2 | 0 | 2 | 0.001316 | 20 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000759 | 11.5 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | goal | none | clef-flash | b | no | limit | 12 | 1 | 13 | 0.011761 | 208.4 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | steps | none | clef-flash | b | no | error:model-timeout | 10 | 0 | 12 | - | 212.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | loose | none | clef-flash | b | no | limit | 12 | 1 | 13 | 0.013233 | 237.6 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | loose | none | clef-flash | b | no | limit | 12 | 2 | 18 | 0.007597 | 108.6 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | none | clef-flash | b | no | done | 8 | 0 | 9 | 0.003995 | 77.8 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | none | clef-flash | b | yes | done | 4 | 0 | 5 | 0.001626 | 39.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | none | clef-flash | b | no | done | 10 | 0 | 10 | 0.00546 | 102 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | clef-flash | b | yes | done | 11 | 0 | 13 | - | 86.1 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | clef-flash | b | yes | done | 7 | 0 | 7 | 0.003291 | 60.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | none | clef-flash | b | yes | done | 5 | 0 | 6 | 0.001648 | 31.9 | 0 | no | message 'old' quoted |
| portal-welcome | loose | none | clef-flash | b | no | limit | 12 | 0 | 12 | 0.002463 | 49.2 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | none | clef-flash | b | no | limit | 12 | 0 | 13 | 0.002742 | 49.8 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | none | clef-flash | b | yes | done | 6 | 0 | 6 | 0.001451 | 28.5 | 0 | no | message 'new' quoted |
| u10-portal-new-message | loose | none | clef-flash | b | no | limit | 12 | 0 | 13 | 0.003355 | 58.8 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | none | clef-flash | b | no | limit | 12 | 0 | 13 | 0.003011 | 53.9 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001128 | 24 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | loose | none | clef-flash | b | no | done | 8 | 0 | 9 | 0.004075 | 78.5 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001075 | 26.1 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | none | clef-flash | b | yes | done | 4 | 0 | 5 | 0.001791 | 33.7 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | goal | none | clef-flash | b | no | done | 11 | 1 | 12 | 0.007951 | 128.8 | 0 | no | truth 'pln 352'; result differs |
| u7-register | loose | none | clef-flash | b | yes | done | 8 | 0 | 8 | 0.002008 | 37.7 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | goal | none | clef-flash | b | yes | done | 8 | 0 | 9 | 0.002577 | 48.9 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | loose | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.002913 | 51.6 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u5-flights-roundtrip | steps | none | clef-flash | b | no | done | 11 | 0 | 12 | 0.008829 | 171.9 | 0 | no | truth 'pln 352'; result differs |
| u8-books-travel-jsonl | goal | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.002804 | 42 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | none | clef-flash | b | yes | done | 4 | 0 | 4 | 0.000855 | 13.8 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.000575 | 9.7 | 0 | no | 1 upload(s); link /files/1 in the result |
| u7-register | steps | none | clef-flash | b | yes | done | 12 | 0 | 13 | 0.004421 | 87.7 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | steps | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.002388 | 29.7 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | steps | none | clef-flash | b | yes | done | 4 | 0 | 4 | 0.000819 | 12.9 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001717 | 16.5 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001894 | 16.2 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | loose | none | clef-flash | b | yes | done | 5 | 0 | 5 | 0.002808 | 25.4 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | none | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001769 | 13.4 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef-flash | b | yes | done | 4 | 0 | 4 | 0.002439 | 18.1 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | none | clef-flash | b | yes | done | 10 | 0 | 10 | 0.005733 | 41.7 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | loose | notes | clef-flash | b | yes | done | 4 | 0 | 4 | 0.002238 | 44.4 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | notes | clef-flash | b | yes | done | 5 | 0 | 5 | 0.003178 | 50.7 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.001502 | 27.8 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | steps | notes | clef-flash | b | yes | done | 8 | 0 | 8 | 0.005121 | 100.4 | 0 | no | truth 'rs. 500'; result agrees |
| ae-search-jeans | loose | notes | clef-flash | b | yes | done | 3 | 0 | 4 | 0.001369 | 29.3 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001371 | 25.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | notes | clef-flash | b | yes | done | 7 | 0 | 7 | 0.006524 | 130.6 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | steps | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001252 | 25.6 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | notes | clef-flash | b | yes | done | 8 | 0 | 8 | 0.004285 | 46 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001215 | 12.2 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | loose | notes | clef-flash | b | yes | done | 11 | 0 | 11 | 0.005592 | 69.2 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000855 | 10.2 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000806 | 6.6 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | notes | clef-flash | b | no | limit | 12 | 0 | 12 | 0.006437 | 77.8 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-polo-brand | steps | notes | clef-flash | b | no | error:model-timeout | 12 | 0 | 12 | - | 300 | 0 | no | result lacks 'Blue Top' |
| books-poetry-jsonl | steps | notes | clef-flash | b | no | limit | 12 | 0 | 12 | 0.009196 | 146.4 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | goal | notes | clef-flash | b | no | limit | 12 | 0 | 12 | 0.009649 | 153.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | notes | clef-flash | b | yes | done | 1 | 0 | 1 | 0.000403 | 4.9 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef-flash | b | yes | done | 1 | 0 | 1 | 0.000519 | 5.8 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.00075 | 9.8 | 0 | no | result names '£51.77' |
| books-stock | loose | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000738 | 10.2 | 0 | no | truth '20'; result agrees |
| books-stock | goal | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000735 | 7.8 | 0 | no | truth '20'; result agrees |
| books-stock | steps | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000755 | 7.3 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000703 | 10.1 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000727 | 7.9 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000899 | 14.5 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | loose | notes | clef-flash | b | no | limit | 12 | 0 | 12 | 0.014782 | 262.4 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | steps | notes | clef-flash | b | no | done | 11 | 0 | 11 | 0.004556 | 73.7 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | notes | clef-flash | b | no | done | 12 | 0 | 14 | 0.006235 | 111.5 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | notes | clef-flash | b | no | limit | 12 | 0 | 14 | 0.005965 | 115.6 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | clef-flash | b | yes | done | 4 | 0 | 4 | 0.001741 | 33.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | notes | clef-flash | b | yes | done | 5 | 0 | 5 | 0.00139 | 25.7 | 0 | no | message 'old' quoted |
| maps-eiffel-postcode | goal | notes | clef-flash | b | yes | done | 7 | 0 | 8 | 0.003231 | 61.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | notes | clef-flash | b | no | limit | 12 | 0 | 12 | 0.002738 | 46.1 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | notes | clef-flash | b | yes | done | 5 | 0 | 5 | 0.001242 | 19.9 | 0 | no | message 'new' quoted |
| maps-eiffel-postcode | steps | notes | clef-flash | b | yes | done | 9 | 0 | 9 | 0.00435 | 73.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | notes | clef-flash | b | no | limit | 12 | 0 | 12 | 0.00296 | 46.7 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | notes | clef-flash | b | yes | done | 6 | 0 | 6 | 0.001592 | 28 | 0 | no | message 'new' quoted |
| u10-portal-new-message | loose | notes | clef-flash | b | no | limit | 12 | 1 | 13 | 0.00381 | 62.2 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | notes | clef-flash | b | no | done | 6 | 0 | 6 | 0.002929 | 53.1 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | loose | notes | clef-flash | b | yes | done | 3 | 0 | 4 | 0.001231 | 30.4 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | notes | clef-flash | b | yes | done | 4 | 0 | 4 | 0.001872 | 33.1 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | notes | clef-flash | b | yes | done | 4 | 0 | 4 | 0.001711 | 35.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | goal | notes | clef-flash | b | yes | done | 8 | 0 | 8 | 0.002182 | 38.7 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | goal | notes | clef-flash | b | no | done | 11 | 0 | 11 | 0.009423 | 147.3 | 0 | no | truth 'pln 352'; result differs |
| u7-register | loose | notes | clef-flash | b | yes | done | 8 | 1 | 9 | 0.003534 | 60.9 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | steps | notes | clef-flash | b | no | done | 11 | 0 | 13 | 0.008551 | 143.6 | 0 | no | truth 'pln 352'; result differs |
| u7-register | steps | notes | clef-flash | b | yes | done | 8 | 0 | 9 | 0.00214 | 35.9 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | loose | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.002708 | 37.8 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | steps | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.002304 | 28.8 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.000793 | 15.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.002842 | 42.1 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | steps | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.000666 | 11.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | notes | clef-flash | b | yes | done | 4 | 0 | 4 | 0.001037 | 17 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | notes | clef-flash | b | yes | done | 3 | 0 | 4 | 0.001924 | 19.6 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | notes | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001803 | 14.9 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | loose | notes | clef-flash | b | yes | done | 4 | 0 | 5 | 0.002569 | 26.1 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | clef-flash | b | yes | done | 5 | 0 | 5 | 0.003291 | 26.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | notes | clef-flash | b | yes | done | 4 | 0 | 5 | 0.002566 | 22.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef-flash | b | yes | done | 3 | 0 | 4 | 0.001908 | 18.3 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.001398 | 34.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | procedures | clef-flash | b | no | limit | 12 | 0 | 12 | 0.006984 | 87.1 | 0 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | steps | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.001203 | 21.3 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | steps | procedures | clef-flash | b | yes | done | 11 | 0 | 16 | - | 143.1 | 0 | no | truth 'rs. 500'; result agrees |
| ae-search-jeans | loose | procedures | clef-flash | b | yes | done | 4 | 0 | 7 | - | 50.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | goal | procedures | clef-flash | b | no | error:model-timeout | 5 | 0 | 5 | - | 140.2 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | goal | procedures | clef-flash | b | yes | done | 4 | 0 | 7 | - | 40.2 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | procedures | clef-flash | b | no | limit | 12 | 0 | 14 | - | 185.4 | 0 | no | result lacks 'Blue Top' |
| ae-search-jeans | steps | procedures | clef-flash | b | yes | done | 4 | 0 | 9 | - | 49 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | steps | procedures | clef-flash | b | yes | done | 4 | 2 | 7 | - | 34.9 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.001008 | 13.4 | 0 | no | truth '19'; result agrees |
| books-poetry-count | loose | procedures | clef-flash | b | yes | done | 4 | 0 | 6 | - | 23.6 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | procedures | clef-flash | b | yes | done | 3 | 0 | 3 | 0.001286 | 11.8 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | procedures | clef-flash | b | yes | done | 10 | 3 | 15 | - | 71.1 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-jsonl | loose | procedures | clef-flash | b | no | error:model-timeout | 4 | 1 | 6 | - | 114.3 | 0 | no | 19 on the page, 38 in the file, 19 missing, 38 extra |
| books-price | loose | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000803 | 6.1 | 0 | no | result names '£51.77' |
| books-mystery-page2 | loose | procedures | clef-flash | b | no | limit | 12 | 7 | 23 | - | 181.3 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | goal | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000942 | 7.7 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000759 | 7.6 | 0 | no | result names '£51.77' |
| books-stock | goal | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000839 | 9.2 | 0 | no | truth '20'; result agrees |
| books-stock | loose | procedures | clef-flash | b | yes | done | 4 | 0 | 4 | 0.001489 | 18.2 | 0 | no | truth '20'; result agrees |
| books-stock | steps | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000791 | 7.6 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000738 | 10.7 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | clef-flash | b | yes | done | 2 | 0 | 2 | 0.000852 | 13.3 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | clef-flash | b | no | done | 3 | 0 | 3 | 0.001407 | 20.1 | 0 | no | 2 canvas click(s), 2 inside the drawn button |
| books-poetry-jsonl | steps | procedures | clef-flash | b | no | done | 8 | 1 | 10 | 0.011727 | 188.7 | 0 | no | 19 on the page, 76 in the file, 0 missing, 57 extra |
| flights-oneway | goal | procedures | clef-flash | b | yes | done | 8 | 1 | 15 | - | 80.5 | 0 | no | truth 'pln 148'; result agrees |
| flights-oneway | loose | procedures | clef-flash | b | no | limit | 12 | 1 | 18 | - | 120 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | procedures | clef-flash | b | no | error:model-timeout | 10 | 1 | 12 | - | 290.7 | 0 | no | 19 on the page, 76 in the file, 19 missing, 76 extra |
| flights-oneway | steps | procedures | clef-flash | b | no | done | 11 | 0 | 13 | - | 105.1 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | procedures | clef-flash | b | yes | done | 5 | 0 | 8 | - | 49.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | procedures | clef-flash | b | no | limit | 12 | 0 | 16 | - | 115.9 | 0 | no | Wikidata P281 ['75007']; result differs |
| portal-welcome | loose | procedures | clef-flash | b | no | limit | 12 | 0 | 14 | - | 58.8 | 0 | no | message 'old' not quoted |
| maps-eiffel-postcode | steps | procedures | clef-flash | b | yes | done | 9 | 0 | 13 | - | 77.3 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | procedures | clef-flash | b | no | limit | 12 | 0 | 14 | - | 52.8 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | procedures | clef-flash | b | yes | done | 8 | 0 | 8 | 0.002109 | 33.9 | 0 | no | message 'old' quoted |
| u10-portal-new-message | goal | procedures | clef-flash | b | no | limit | 12 | 0 | 15 | - | 61.8 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | loose | procedures | clef-flash | b | no | limit | 12 | 0 | 14 | - | 68.8 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | procedures | clef-flash | b | no | limit | 12 | 0 | 15 | - | 65.9 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | procedures | clef-flash | b | yes | done | 4 | 0 | 8 | - | 43.4 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | loose | procedures | clef-flash | b | no | done | 7 | 1 | 13 | - | 106.2 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | procedures | clef-flash | b | yes | done | 4 | 0 | 8 | - | 43.3 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | procedures | clef-flash | b | yes | done | 5 | 0 | 6 | - | 48.1 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | procedures | clef-flash | b | yes | done | 8 | 0 | 8 | 0.002048 | 36.9 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | goal | procedures | clef-flash | b | yes | done | 8 | 0 | 8 | 0.002009 | 37.6 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | goal | procedures | clef-flash | b | no | error:model-timeout | 10 | 1 | 16 | - | 183.1 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | steps | procedures | clef-flash | b | no | done | 12 | 1 | 19 | - | 183.1 | 0 | no | truth 'pln 352'; result differs |
| u7-register | steps | procedures | clef-flash | b | yes | done | 8 | 0 | 10 | 0.002425 | 45.8 | 0 | no | registrations 1, confirmed True, password delivered True |
| u9-upload | loose | procedures | clef-flash | b | yes | done | 3 | 0 | 3 | 0.000979 | 16.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | procedures | clef-flash | b | yes | done | 4 | 0 | 4 | 0.001017 | 19.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | procedures | clef-flash | b | no | done | 5 | 0 | 6 | - | 59.4 | 0 | no | 11 on the page, 22 in the file, 0 missing, 11 extra |
| u9-upload | steps | procedures | clef-flash | b | yes | done | 4 | 0 | 4 | 0.001001 | 17.1 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | procedures | clef-flash | b | no | done | 5 | 1 | 8 | 0.005793 | 74.5 | 0 | no | 11 on the page, 44 in the file, 0 missing, 33 extra |
| wiki-ada-born | goal | procedures | clef-flash | b | yes | done | 4 | 0 | 8 | - | 34.7 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef-flash | b | yes | done | 6 | 0 | 10 | - | 41.4 | 0 | no | result names '10 December 1815' |
| u8-books-travel-jsonl | loose | procedures | clef-flash | b | no | done | 7 | 1 | 10 | 0.009612 | 145.4 | 0 | no | 11 on the page, 66 in the file, 0 missing, 55 extra |
| wiki-ada-born | loose | procedures | clef-flash | b | no | limit | 12 | 0 | 16 | - | 77.2 | 0 | no | result lacks '10 December 1815' |
| wiki-engine-designer | goal | procedures | clef-flash | b | yes | done | 5 | 0 | 8 | - | 27.3 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef-flash | b | yes | done | 4 | 0 | 7 | - | 22.3 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | procedures | clef-flash | b | yes | done | 10 | 0 | 13 | - | 72.1 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | none | clef-flash | c | yes | done | 5 | 0 | 5 | 0.002641 | 46 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | none | clef-flash | c | yes | done | 5 | 0 | 5 | 0.002992 | 65.7 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | goal | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.001041 | 22.7 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | loose | none | clef-flash | c | no | limit | 12 | 0 | 12 | 0.006207 | 80 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | loose | none | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001348 | 29 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | clef-flash | c | no | done | 3 | 0 | 3 | 0.001322 | 28.4 | 0 | no | result lacks 'Soft Stretch Jeans' |
| ae-blue-top-price | steps | none | clef-flash | c | yes | done | 9 | 0 | 14 | - | 118.3 | 0 | no | truth 'rs. 500'; result agrees |
| ae-search-jeans | steps | none | clef-flash | c | yes | done | 3 | 0 | 3 | 0.0012 | 24 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | clef-flash | c | yes | done | 5 | 0 | 5 | 0.002443 | 29.2 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000766 | 7.8 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000758 | 7.9 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | none | clef-flash | c | yes | done | 10 | 0 | 10 | 0.004848 | 51.8 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | steps | none | clef-flash | c | yes | done | 4 | 0 | 4 | 0.001603 | 15 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | none | clef-flash | c | no | limit | 12 | 0 | 12 | 0.006031 | 72.6 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-polo-brand | steps | none | clef-flash | c | no | error:model-timeout | 12 | 0 | 12 | - | 300 | 0 | no | result lacks 'Blue Top' |
| books-poetry-jsonl | steps | none | clef-flash | c | no | error:model-timeout | 9 | 0 | 9 | - | 180.4 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | goal | none | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001176 | 10.4 | 0 | no | result names '£51.77' |
| books-price | steps | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000749 | 10.2 | 0 | no | result names '£51.77' |
| books-price | loose | none | clef-flash | c | yes | done | 9 | 0 | 9 | 0.003652 | 31.7 | 0 | no | result names '£51.77' |
| books-poetry-jsonl | loose | none | clef-flash | c | no | limit | 12 | 0 | 13 | 0.013797 | 239.6 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | goal | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000694 | 7.1 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | goal | none | clef-flash | c | no | limit | 12 | 0 | 13 | 0.013234 | 242.1 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-stock | steps | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000771 | 7.7 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000872 | 13.1 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.00091 | 15.4 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | none | clef-flash | c | yes | done | 2 | 0 | 2 | 0.001509 | 21.1 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-stock | loose | none | clef-flash | c | no | limit | 12 | 0 | 12 | 0.004062 | 52.4 | 0 | no | truth '20'; result differs |
| maps-eiffel-postcode | loose | none | clef-flash | c | yes | done | 4 | 0 | 4 | 0.001443 | 34 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | goal | none | clef-flash | c | no | limit | 12 | 0 | 13 | 0.005254 | 90.4 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | loose | none | clef-flash | c | no | limit | 12 | 0 | 14 | 0.006043 | 106.2 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | none | clef-flash | c | yes | done | 6 | 0 | 6 | 0.002314 | 44.5 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | none | clef-flash | c | no | limit | 12 | 0 | 15 | 0.005753 | 113 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | steps | none | clef-flash | c | yes | done | 4 | 0 | 4 | 0.001647 | 29 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | none | clef-flash | c | yes | done | 7 | 0 | 7 | 0.001759 | 38.5 | 0 | no | message 'old' quoted |
| u10-portal-new-message | loose | none | clef-flash | c | yes | done | 5 | 0 | 5 | 0.001093 | 20.5 | 0 | no | message 'new' quoted |
| portal-welcome | loose | none | clef-flash | c | no | limit | 12 | 1 | 13 | 0.002811 | 46.2 | 0 | no | message 'old' not quoted |
| portal-welcome | steps | none | clef-flash | c | yes | done | 12 | 0 | 12 | 0.002992 | 52.8 | 0 | no | message 'old' quoted |
| u10-portal-new-message | goal | none | clef-flash | c | yes | done | 8 | 0 | 9 | 0.001835 | 33.7 | 0 | no | message 'new' quoted |
| u10-portal-new-message | steps | none | clef-flash | c | no | limit | 12 | 0 | 15 | 0.003063 | 58.6 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | none | clef-flash | c | no | done | 6 | 0 | 6 | 0.002967 | 54 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | loose | none | clef-flash | c | yes | done | 3 | 0 | 4 | 0.001182 | 27.5 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | goal | none | clef-flash | c | yes | done | 3 | 0 | 4 | 0.001277 | 28.8 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | none | clef-flash | c | yes | done | 8 | 0 | 8 | 0.00217 | 43.2 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | loose | none | clef-flash | c | no | done | 12 | 0 | 15 | - | 166 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | steps | none | clef-flash | c | no | error:model-timeout | 9 | 0 | 10 | - | 142.4 | 0 | no | truth 'pln 352'; result differs |
| u7-register | goal | none | clef-flash | c | yes | done | 8 | 0 | 9 | 0.002139 | 44.8 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | none | clef-flash | c | yes | done | 8 | 0 | 9 | 0.002247 | 43.5 | 0 | no | registrations 1, confirmed True, password delivered True |
| u6-maps-cafe | steps | none | clef-flash | c | no | limit | 12 | 0 | 12 | 0.006822 | 117 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u8-books-travel-jsonl | loose | none | clef-flash | c | yes | done | 3 | 0 | 3 | 0.002913 | 46.5 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | none | clef-flash | c | yes | done | 4 | 0 | 4 | 0.000888 | 16.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | none | clef-flash | c | yes | done | 4 | 0 | 4 | 0.000868 | 14.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | none | clef-flash | c | yes | done | 3 | 0 | 3 | 0.002055 | 25.6 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | goal | none | clef-flash | c | yes | done | 3 | 0 | 3 | 0.002349 | 33.6 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | steps | none | clef-flash | c | yes | done | 4 | 0 | 4 | 0.000837 | 12.8 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | none | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001785 | 14 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | none | clef-flash | c | yes | done | 4 | 0 | 4 | 0.002525 | 21 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | none | clef-flash | c | yes | done | 6 | 0 | 6 | 0.00321 | 20.7 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef-flash | c | yes | done | 4 | 0 | 4 | 0.002513 | 19 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | loose | none | clef-flash | c | no | limit | 12 | 0 | 12 | 0.007516 | 62.5 | 0 | no | result lacks '10 December 1815' |
| wiki-engine-designer | loose | none | clef-flash | c | no | limit | 12 | 0 | 12 | 0.007123 | 53.3 | 0 | no | result lacks 'Charles Babbage' |
| ae-blue-top-price | goal | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.001451 | 41.1 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | notes | clef-flash | c | yes | done | 5 | 0 | 5 | 0.002726 | 43.6 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | loose | notes | clef-flash | c | yes | done | 12 | 0 | 12 | 0.006785 | 92.8 | 0 | no | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | notes | clef-flash | c | no | failed | 4 | 1 | 5 | 0.003906 | 93 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | loose | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001332 | 28.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef-flash | c | yes | done | 3 | 0 | 4 | 0.001363 | 32.8 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | notes | clef-flash | c | yes | done | 9 | 0 | 9 | 0.007689 | 129.2 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | steps | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001264 | 23.3 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | notes | clef-flash | c | yes | done | 5 | 0 | 5 | 0.004897 | 83.7 | 0 | no | result names 'Blue Top' |
| books-poetry-count | loose | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001207 | 12.2 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000836 | 8.9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000811 | 7.4 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | notes | clef-flash | c | no | limit | 12 | 0 | 13 | 0.007008 | 84.2 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | notes | clef-flash | c | no | limit | 12 | 1 | 14 | - | 69.8 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | notes | clef-flash | c | yes | done | 12 | 1 | 14 | 0.007908 | 93.6 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-price | loose | notes | clef-flash | c | no | limit | 12 | 0 | 12 | 0.005345 | 57.6 | 0 | no | result lacks '£51.77' |
| books-price | goal | notes | clef-flash | c | yes | done | 1 | 0 | 1 | 0.000397 | 3.7 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000734 | 7.3 | 0 | no | result names '£51.77' |
| books-stock | loose | notes | clef-flash | c | yes | done | 5 | 0 | 5 | 0.00175 | 21 | 0 | no | truth '20'; result agrees |
| books-stock | goal | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000754 | 8.2 | 0 | no | truth '20'; result agrees |
| books-stock | steps | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000692 | 13.5 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000735 | 9.8 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.001042 | 14.8 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000753 | 8.7 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | notes | clef-flash | c | no | limit | 12 | 0 | 13 | 0.011851 | 189.5 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | loose | notes | clef-flash | c | no | done | 12 | 0 | 13 | 0.005842 | 91.7 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | notes | clef-flash | c | no | limit | 12 | 0 | 13 | 0.014068 | 251 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | loose | notes | clef-flash | c | no | limit | 12 | 0 | 14 | 0.015712 | 262.7 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | goal | notes | clef-flash | c | no | done | 8 | 0 | 9 | 0.003694 | 69 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | notes | clef-flash | c | yes | done | 5 | 0 | 5 | 0.00209 | 40.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | clef-flash | c | yes | done | 4 | 0 | 4 | 0.001962 | 31.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | notes | clef-flash | c | no | done | 9 | 0 | 10 | 0.004203 | 75.7 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | clef-flash | c | yes | done | 12 | 0 | 12 | 0.005449 | 88 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | notes | clef-flash | c | no | limit | 12 | 0 | 12 | 0.002894 | 55 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | notes | clef-flash | c | yes | done | 5 | 0 | 5 | 0.001313 | 25.6 | 0 | no | message 'new' quoted |
| portal-welcome | steps | notes | clef-flash | c | no | limit | 12 | 0 | 13 | 0.003214 | 55.2 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | notes | clef-flash | c | no | limit | 12 | 0 | 13 | 0.004799 | 91.1 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | notes | clef-flash | c | yes | done | 7 | 0 | 7 | 0.001952 | 31.2 | 0 | no | message 'new' quoted |
| u10-portal-new-message | loose | notes | clef-flash | c | no | limit | 12 | 1 | 15 | 0.005547 | 104.6 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | notes | clef-flash | c | no | done | 8 | 0 | 9 | 0.004142 | 77.8 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | loose | notes | clef-flash | c | yes | done | 4 | 0 | 4 | 0.001488 | 34.7 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | goal | notes | clef-flash | c | no | done | 10 | 0 | 10 | 0.006051 | 101 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001237 | 29.5 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7, 4.7] |
| u6-maps-cafe | steps | notes | clef-flash | c | yes | done | 4 | 0 | 4 | 0.001679 | 30.2 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | steps | notes | clef-flash | c | no | done | 10 | 0 | 12 | 0.00726 | 124.6 | 0 | no | truth 'pln 352'; result differs |
| u7-register | goal | notes | clef-flash | c | yes | done | 8 | 0 | 8 | 0.002049 | 36.1 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | loose | notes | clef-flash | c | yes | done | 8 | 0 | 8 | 0.002397 | 47.7 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | notes | clef-flash | c | yes | done | 8 | 0 | 8 | 0.001962 | 33.4 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | steps | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.002334 | 30.6 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | loose | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.003039 | 39.1 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | notes | clef-flash | c | yes | done | 4 | 0 | 4 | 0.000942 | 14.2 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.003016 | 46.4 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | goal | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.000762 | 14.8 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | steps | notes | clef-flash | c | yes | done | 5 | 0 | 5 | 0.001326 | 25.1 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | notes | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001811 | 16 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | loose | notes | clef-flash | c | yes | done | 8 | 0 | 9 | 0.004891 | 40.1 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | clef-flash | c | yes | done | 5 | 0 | 5 | 0.002768 | 19.7 | 0 | no | result names 'Charles Babbage' |
| wiki-ada-born | steps | notes | clef-flash | c | yes | done | 4 | 0 | 4 | 0.003101 | 34 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | notes | clef-flash | c | yes | done | 4 | 0 | 5 | 0.002604 | 25 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef-flash | c | yes | done | 4 | 0 | 4 | 0.002481 | 19.7 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | clef-flash | c | no | done | 2 | 0 | 2 | 0.001131 | 28.5 | 0 | no | check failed: HTTP Error 503: Service Unavailable |
| ae-polo-brand | goal | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.001194 | 27.3 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.001273 | 23.1 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | loose | procedures | clef-flash | c | no | limit | 12 | 0 | 12 | 0.007171 | 83.4 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | goal | procedures | clef-flash | c | yes | done | 4 | 0 | 7 | - | 50.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | loose | procedures | clef-flash | c | no | done | 4 | 0 | 8 | - | 60.6 | 0 | no | result lacks 'Soft Stretch Jeans' |
| ae-blue-top-price | steps | procedures | clef-flash | c | yes | done | 12 | 0 | 18 | - | 170.8 | 0 | no | truth 'rs. 500'; result agrees |
| ae-search-jeans | steps | procedures | clef-flash | c | yes | done | 4 | 0 | 8 | - | 42.6 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | procedures | clef-flash | c | no | limit | 12 | 0 | 16 | - | 181.1 | 0 | no | result lacks 'Blue Top' |
| books-poetry-count | loose | procedures | clef-flash | c | yes | done | 2 | 1 | 4 | 0.001274 | 13.4 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | goal | procedures | clef-flash | c | yes | done | 3 | 3 | 7 | 0.003226 | 33.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | procedures | clef-flash | c | yes | done | 5 | 1 | 8 | 0.002836 | 28.9 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | procedures | clef-flash | c | no | limit | 12 | 0 | 12 | 0.005719 | 57.6 | 0 | no | truth '19'; result differs |
| books-mystery-page2 | loose | procedures | clef-flash | c | no | limit | 12 | 4 | 17 | 0.01192 | 133.2 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | procedures | clef-flash | c | no | limit | 12 | 2 | 16 | - | 131.9 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | loose | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000801 | 7.4 | 0 | no | result names '£51.77' |
| books-price | goal | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000898 | 9.2 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef-flash | c | yes | done | 3 | 0 | 3 | 0.001131 | 18.9 | 0 | no | result names '£51.77' |
| books-stock | loose | procedures | clef-flash | c | yes | done | 10 | 0 | 10 | 0.003636 | 46.6 | 0 | no | truth '20'; result agrees |
| books-stock | goal | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000833 | 9.1 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | steps | procedures | clef-flash | c | no | error:model-timeout | 5 | 1 | 7 | - | 136.3 | 0 | no | 19 on the page, 38 in the file, 19 missing, 38 extra |
| books-stock | steps | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000782 | 8.6 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | loose | procedures | clef-flash | c | no | error:model-timeout | 7 | 0 | 8 | - | 199 | 0 | no | 19 on the page, 19 in the file, 19 missing, 19 extra |
| canvas-launch | loose | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.000854 | 13.3 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.001285 | 19 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | clef-flash | c | yes | done | 2 | 0 | 2 | 0.001423 | 23.1 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | goal | procedures | clef-flash | c | yes | done | 11 | 1 | 17 | - | 106.8 | 0 | no | truth 'pln 148'; result agrees |
| flights-oneway | loose | procedures | clef-flash | c | no | limit | 12 | 0 | 16 | - | 117.1 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | procedures | clef-flash | c | no | error:model-timeout | 12 | 1 | 13 | - | 285.6 | 0 | no | 19 on the page, 171 in the file, 19 missing, 171 extra |
| maps-eiffel-postcode | goal | procedures | clef-flash | c | yes | done | 6 | 0 | 7 | - | 56.3 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | clef-flash | c | yes | done | 5 | 0 | 8 | - | 48.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | procedures | clef-flash | c | no | limit | 12 | 1 | 18 | - | 164.7 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | procedures | clef-flash | c | yes | done | 8 | 0 | 10 | - | 79.3 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | procedures | clef-flash | c | no | limit | 12 | 0 | 15 | - | 53.7 | 0 | no | message 'old' not quoted |
| portal-welcome | loose | procedures | clef-flash | c | no | limit | 12 | 0 | 15 | - | 60 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | procedures | clef-flash | c | yes | done | 8 | 0 | 10 | - | 42.2 | 0 | no | message 'new' quoted |
| portal-welcome | steps | procedures | clef-flash | c | no | limit | 12 | 0 | 13 | 0.003825 | 68.8 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | procedures | clef-flash | c | yes | done | 6 | 0 | 6 | 0.001709 | 29.5 | 0 | no | message 'new' quoted |
| u10-portal-new-message | steps | procedures | clef-flash | c | yes | done | 11 | 0 | 13 | - | 79.8 | 0 | no | message 'new' quoted |
| u5-flights-roundtrip | goal | procedures | clef-flash | c | no | done | 7 | 1 | 13 | - | 87.1 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | loose | procedures | clef-flash | c | no | done | 6 | 0 | 10 | - | 54.8 | 0 | no | names on a fresh Maps search: []; ratings [4.7] |
| u5-flights-roundtrip | loose | procedures | clef-flash | c | no | done | 11 | 0 | 14 | 0.00812 | 151.4 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | procedures | clef-flash | c | yes | done | 5 | 0 | 8 | - | 44.6 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | steps | procedures | clef-flash | c | no | done | 6 | 4 | 18 | 0.008647 | 136.4 | 0 | yes | truth 'pln 352'; result differs |
| u7-register | loose | procedures | clef-flash | c | yes | done | 8 | 0 | 8 | 0.001965 | 34.5 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | goal | procedures | clef-flash | c | yes | done | 8 | 0 | 8 | 0.001967 | 33.2 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | steps | procedures | clef-flash | c | no | limit | 12 | 0 | 14 | 0.004591 | 88.1 | 0 | no | registrations 0, confirmed False, password delivered True |
| u8-books-travel-jsonl | loose | procedures | clef-flash | c | no | done | 5 | 0 | 6 | - | 65.4 | 0 | no | 11 on the page, 22 in the file, 0 missing, 11 extra |
| u9-upload | loose | procedures | clef-flash | c | yes | done | 4 | 0 | 4 | 0.00095 | 14.9 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | procedures | clef-flash | c | yes | done | 4 | 0 | 4 | 0.000894 | 15.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| u6-maps-cafe | steps | procedures | clef-flash | c | no | limit | 12 | 0 | 15 | - | 139.1 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u9-upload | steps | procedures | clef-flash | c | yes | done | 7 | 0 | 7 | 0.001768 | 38.7 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | loose | procedures | clef-flash | c | yes | done | 5 | 0 | 9 | - | 35.2 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | procedures | clef-flash | c | yes | done | 4 | 0 | 7 | - | 21.6 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef-flash | c | yes | done | 6 | 0 | 10 | - | 41.9 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | clef-flash | c | yes | done | 4 | 0 | 8 | - | 39.7 | 0 | no | result names 'Charles Babbage' |
| u8-books-travel-jsonl | goal | procedures | clef-flash | c | no | limit | 12 | 0 | 14 | - | 195.8 | 0 | no | 11 on the page, 33 in the file, 11 missing, 33 extra |
| wiki-engine-designer | goal | procedures | clef-flash | c | yes | done | 4 | 0 | 7 | - | 26.5 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef-flash | c | yes | done | 4 | 0 | 8 | - | 24.5 | 0 | no | result names 'Charles Babbage' |
| u8-books-travel-jsonl | steps | procedures | clef-flash | c | no | done | 11 | 1 | 14 | 0.011973 | 173.6 | 0 | no | 11 on the page, 55 in the file, 0 missing, 44 extra |
| ae-blue-top-price | goal | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000962 | 28.1 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000964 | 22.3 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | loose | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.006301 | 81.9 | 0 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | steps | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000881 | 22.5 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | loose | none | clef-flash | off | yes | done | 3 | 0 | 4 | 0.001557 | 34.3 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | clef-flash | off | no | done | 4 | 0 | 6 | - | 46.3 | 0 | no | result lacks 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001262 | 24.8 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | none | clef-flash | off | yes | done | 5 | 0 | 5 | 0.002416 | 25 | 0 | no | result names 'The Mysterious Affair at Styles' |
| ae-blue-top-price | steps | none | clef-flash | off | no | limit | 12 | 0 | 13 | 0.010129 | 186.9 | 0 | no | truth 'rs. 500'; result differs |
| books-poetry-count | loose | none | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001197 | 10.5 | 0 | no | truth '19'; result agrees |
| ae-polo-brand | loose | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.013228 | 204.5 | 0 | no | result lacks 'Blue Top' |
| books-poetry-count | goal | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000799 | 7.3 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | loose | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.006126 | 72.8 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-poetry-count | steps | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000766 | 6.3 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.006393 | 68.1 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | loose | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.005277 | 57.5 | 0 | no | result lacks '£51.77' |
| books-price | goal | none | clef-flash | off | yes | done | 1 | 0 | 1 | 0.000397 | 3 | 0 | no | result names '£51.77' |
| books-price | steps | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000702 | 11.4 | 0 | no | result names '£51.77' |
| books-stock | loose | none | clef-flash | off | yes | done | 5 | 0 | 5 | 0.001646 | 26.9 | 0 | no | truth '20'; result agrees |
| books-stock | goal | none | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001044 | 11.1 | 0 | no | truth '20'; result agrees |
| books-stock | steps | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000717 | 8.1 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000999 | 15.2 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000766 | 15.9 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000985 | 18.2 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | loose | none | clef-flash | off | no | limit | 12 | 0 | 13 | 0.013389 | 211.9 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | steps | none | clef-flash | off | no | limit | 12 | 0 | 14 | 0.012395 | 206.5 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-poetry-jsonl | goal | none | clef-flash | off | no | limit | 12 | 0 | 14 | 0.015539 | 257.9 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| maps-eiffel-postcode | loose | none | clef-flash | off | yes | done | 6 | 0 | 6 | 0.002192 | 43.4 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | loose | none | clef-flash | off | no | limit | 12 | 2 | 18 | - | 102.8 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | steps | none | clef-flash | off | no | limit | 12 | 0 | 13 | 0.005713 | 108.2 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | none | clef-flash | off | no | done | 12 | 0 | 15 | 0.005558 | 109.3 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | none | clef-flash | off | yes | done | 3 | 0 | 3 | 0.00131 | 29.5 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | goal | none | clef-flash | off | yes | done | 5 | 0 | 5 | 0.001009 | 20.8 | 0 | no | message 'old' quoted |
| maps-eiffel-postcode | steps | none | clef-flash | off | yes | done | 4 | 0 | 4 | 0.001887 | 36.8 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.002582 | 46.7 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | none | clef-flash | off | yes | done | 6 | 0 | 7 | 0.001466 | 30.6 | 0 | no | message 'new' quoted |
| portal-welcome | steps | none | clef-flash | off | no | limit | 12 | 0 | 14 | 0.003083 | 53.2 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | goal | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.004523 | 83.4 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | steps | none | clef-flash | off | no | limit | 12 | 0 | 14 | 0.003607 | 68.5 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | goal | none | clef-flash | off | no | done | 6 | 0 | 6 | 0.00278 | 51.8 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | loose | none | clef-flash | off | no | done | 7 | 0 | 7 | 0.003809 | 68.4 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | loose | none | clef-flash | off | no | done | 3 | 0 | 4 | 0.001121 | 26.1 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [] |
| u6-maps-cafe | goal | none | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001235 | 26.4 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | goal | none | clef-flash | off | yes | done | 8 | 1 | 9 | 0.00222 | 40.5 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | loose | none | clef-flash | off | yes | done | 8 | 0 | 10 | 0.002322 | 51.6 | 0 | no | registrations 1, confirmed True, password delivered True |
| u6-maps-cafe | steps | none | clef-flash | off | no | done | 8 | 0 | 8 | 0.004415 | 74.8 | 0 | no | names on a fresh Maps search: []; ratings [] |
| u5-flights-roundtrip | steps | none | clef-flash | off | no | done | 11 | 0 | 11 | 0.007404 | 131.8 | 0 | no | truth 'pln 352'; result differs |
| u7-register | steps | none | clef-flash | off | yes | done | 8 | 0 | 9 | 0.002334 | 44 | 0 | no | registrations 1, confirmed True, password delivered True |
| u9-upload | loose | none | clef-flash | off | yes | done | 3 | 0 | 3 | 0.000726 | 14.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | none | clef-flash | off | yes | done | 3 | 0 | 3 | 0.000641 | 12 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | steps | none | clef-flash | off | yes | done | 3 | 0 | 3 | 0.002128 | 27.1 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | steps | none | clef-flash | off | yes | done | 4 | 0 | 4 | 0.000866 | 14.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | none | clef-flash | off | yes | done | 5 | 0 | 6 | 0.005631 | 84.3 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| wiki-ada-born | loose | none | clef-flash | off | yes | done | 4 | 0 | 5 | 0.002554 | 23.5 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | none | clef-flash | off | yes | done | 4 | 0 | 5 | 0.002402 | 22.2 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | none | clef-flash | off | yes | done | 3 | 0 | 4 | 0.001967 | 25.7 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | goal | none | clef-flash | off | yes | done | 5 | 0 | 5 | 0.002901 | 24.1 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | clef-flash | off | yes | done | 4 | 0 | 4 | 0.002341 | 17.3 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | loose | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.007398 | 59.4 | 0 | no | result lacks 'Charles Babbage' |
| u8-books-travel-jsonl | loose | none | clef-flash | off | no | limit | 12 | 0 | 12 | 0.011144 | 180.7 | 0 | no | 11 on the page, 0 in the file, 11 missing, 0 extra |
| ae-blue-top-price | goal | notes | clef-flash | off | no | done | 1 | 0 | 1 | 0.000621 | 26.5 | 0 | no | check failed: HTTP Error 503: Service Unavailable |
| ae-polo-brand | loose | notes | clef-flash | off | yes | done | 6 | 0 | 6 | 0.00377 | 74.1 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | loose | notes | clef-flash | off | yes | done | 11 | 0 | 11 | 0.006324 | 85.5 | 0 | no | truth 'rs. 500'; result agrees |
| ae-polo-brand | steps | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.001348 | 25.9 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | goal | notes | clef-flash | off | yes | done | 6 | 0 | 6 | 0.004615 | 81.8 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | steps | notes | clef-flash | off | no | limit | 12 | 0 | 13 | 0.006597 | 117.4 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | loose | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001263 | 29.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001235 | 23.4 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | clef-flash | off | yes | done | 3 | 0 | 4 | 0.001384 | 27.5 | 0 | no | result names 'Soft Stretch Jeans' |
| books-poetry-count | loose | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000821 | 7.8 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000778 | 6.3 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | steps | notes | clef-flash | off | yes | done | 5 | 2 | 8 | - | 31.5 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | notes | clef-flash | off | yes | done | 6 | 6 | 14 | - | 48 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | steps | notes | clef-flash | off | yes | done | 4 | 0 | 4 | 0.001705 | 17.5 | 0 | no | truth '19'; result agrees |
| books-mystery-page2 | loose | notes | clef-flash | off | no | limit | 12 | 2 | 14 | 0.009377 | 112.5 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| books-price | loose | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000887 | 10.4 | 0 | no | result names '£51.77' |
| books-price | goal | notes | clef-flash | off | yes | done | 5 | 0 | 5 | 0.002235 | 23.9 | 0 | no | result names '£51.77' |
| books-price | steps | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000762 | 11.8 | 0 | no | result names '£51.77' |
| books-stock | loose | notes | clef-flash | off | yes | done | 5 | 0 | 5 | 0.001758 | 17.7 | 0 | no | truth '20'; result agrees |
| books-stock | goal | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000719 | 8 | 0 | no | truth '20'; result agrees |
| books-stock | steps | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.00077 | 8.8 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | loose | notes | clef-flash | off | no | limit | 12 | 1 | 13 | 0.010036 | 151.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| canvas-launch | loose | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.00069 | 8.6 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000925 | 16.9 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | notes | clef-flash | off | no | limit | 12 | 0 | 12 | 0.010581 | 168.2 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| canvas-launch | steps | notes | clef-flash | off | yes | done | 2 | 0 | 2 | 0.001181 | 22.4 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | goal | notes | clef-flash | off | no | limit | 12 | 0 | 12 | 0.013858 | 218.7 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| flights-oneway | loose | notes | clef-flash | off | no | limit | 12 | 0 | 13 | 0.004757 | 94.6 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | notes | clef-flash | off | no | limit | 12 | 0 | 13 | 0.004819 | 96.5 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | steps | notes | clef-flash | off | no | limit | 12 | 0 | 13 | 0.00471 | 92.8 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | notes | clef-flash | off | yes | done | 5 | 0 | 5 | 0.002235 | 46 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | notes | clef-flash | off | no | limit | 12 | 0 | 12 | 0.005681 | 99 | 0 | no | Wikidata P281 ['75007']; result differs |
| portal-welcome | loose | notes | clef-flash | off | no | limit | 12 | 0 | 12 | 0.002842 | 51.3 | 0 | no | message 'old' not quoted |
| maps-eiffel-postcode | steps | notes | clef-flash | off | yes | done | 7 | 0 | 7 | 0.003864 | 65.4 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | notes | clef-flash | off | yes | done | 5 | 0 | 5 | 0.001229 | 25 | 0 | no | message 'old' quoted |
| u10-portal-new-message | goal | notes | clef-flash | off | yes | done | 7 | 0 | 9 | - | 35 | 0 | no | message 'new' quoted |
| u10-portal-new-message | steps | notes | clef-flash | off | no | limit | 12 | 0 | 15 | 0.003548 | 63 | 0 | no | message 'new' not quoted |
| portal-welcome | goal | notes | clef-flash | off | no | limit | 12 | 0 | 14 | 0.004949 | 99.1 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | loose | notes | clef-flash | off | no | limit | 12 | 0 | 14 | 0.004728 | 101.1 | 0 | no | message 'new' not quoted |
| u6-maps-cafe | loose | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001098 | 23.5 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | loose | notes | clef-flash | off | no | done | 9 | 0 | 9 | 0.006282 | 108.9 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001109 | 20.9 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u5-flights-roundtrip | steps | notes | clef-flash | off | no | done | 8 | 0 | 9 | 0.005969 | 98.2 | 0 | no | truth 'pln 352'; result differs |
| u7-register | loose | notes | clef-flash | off | yes | done | 8 | 0 | 8 | 0.00211 | 38.5 | 0 | no | registrations 1, confirmed True, password delivered True |
| u6-maps-cafe | steps | notes | clef-flash | off | yes | done | 5 | 0 | 5 | 0.002171 | 40.5 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | goal | notes | clef-flash | off | yes | done | 8 | 0 | 8 | 0.002339 | 37.2 | 0 | no | registrations 1, confirmed True, password delivered True |
| u5-flights-roundtrip | goal | notes | clef-flash | off | no | done | 11 | 1 | 13 | 0.009202 | 152.2 | 0 | no | truth 'pln 352'; result differs |
| u7-register | steps | notes | clef-flash | off | yes | done | 8 | 0 | 10 | 0.00278 | 50.4 | 0 | no | registrations 1, confirmed True, password delivered True |
| u8-books-travel-jsonl | loose | notes | clef-flash | off | yes | done | 3 | 1 | 4 | 0.00319 | 45 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | steps | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001982 | 24.9 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | goal | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.002519 | 35.3 | 0 | no | 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | notes | clef-flash | off | yes | done | 4 | 0 | 4 | 0.000945 | 15.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | notes | clef-flash | off | yes | done | 4 | 0 | 4 | 0.001032 | 16.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | steps | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.000737 | 10.5 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | goal | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001798 | 15.1 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001876 | 15.1 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | loose | notes | clef-flash | off | yes | done | 4 | 0 | 5 | 0.002474 | 23.6 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | notes | clef-flash | off | yes | done | 4 | 0 | 4 | 0.00236 | 18.4 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001749 | 12.1 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | notes | clef-flash | off | yes | done | 5 | 0 | 5 | 0.003092 | 23.8 | 0 | no | result names 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | clef-flash | off | no | done | 2 | 0 | 2 | 0.001097 | 28.1 | 0 | no | check failed: HTTP Error 503: Service Unavailable |
| ae-polo-brand | loose | procedures | clef-flash | off | yes | done | 4 | 0 | 4 | 0.003261 | 66.1 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | goal | procedures | clef-flash | off | yes | done | 3 | 0 | 5 | - | 39.5 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | procedures | clef-flash | off | yes | done | 2 | 0 | 2 | 0.001188 | 23.1 | 0 | no | result names 'Blue Top' |
| ae-blue-top-price | loose | procedures | clef-flash | off | no | limit | 12 | 0 | 12 | 0.007268 | 93.2 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | steps | procedures | clef-flash | off | yes | done | 6 | 0 | 6 | 0.004364 | 65.8 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-blue-top-price | steps | procedures | clef-flash | off | no | limit | 12 | 0 | 20 | - | 188.2 | 0 | no | truth 'rs. 500'; result differs |
| ae-search-jeans | goal | procedures | clef-flash | off | yes | done | 10 | 0 | 15 | - | 108.3 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | procedures | clef-flash | off | yes | done | 5 | 1 | 7 | - | 41.4 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | procedures | clef-flash | off | yes | done | 4 | 3 | 8 | - | 28.3 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | procedures | clef-flash | off | no | limit | 12 | 3 | 17 | - | 76.3 | 0 | no | result lacks 'The Mysterious Affair at Styles' |
| ae-search-jeans | loose | procedures | clef-flash | off | yes | done | 12 | 0 | 12 | 0.010791 | 174.4 | 0 | no | result names 'Soft Stretch Jeans' |
| books-poetry-count | loose | procedures | clef-flash | off | yes | done | 2 | 1 | 4 | 0.001319 | 18.1 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | procedures | clef-flash | off | yes | done | 5 | 0 | 5 | 0.002275 | 23.3 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | procedures | clef-flash | off | yes | done | 4 | 0 | 4 | 0.001815 | 18.4 | 0 | no | truth '19'; result agrees |
| books-price | loose | procedures | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000802 | 8.1 | 0 | no | result names '£51.77' |
| books-price | goal | procedures | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001321 | 13.1 | 0 | no | result names '£51.77' |
| books-price | steps | procedures | clef-flash | off | yes | done | 3 | 0 | 3 | 0.001205 | 13.8 | 0 | no | result names '£51.77' |
| books-stock | loose | procedures | clef-flash | off | no | limit | 12 | 0 | 12 | 0.004324 | 66.8 | 0 | no | truth '20'; result differs |
| books-stock | goal | procedures | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000756 | 8.8 | 0 | no | truth '20'; result agrees |
| books-poetry-jsonl | loose | procedures | clef-flash | off | no | error:model-timeout | 6 | 1 | 8 | - | 138 | 0 | no | 19 on the page, 76 in the file, 19 missing, 76 extra |
| books-stock | steps | procedures | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000859 | 11.4 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | procedures | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000914 | 12.1 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000945 | 12.8 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | clef-flash | off | yes | done | 2 | 0 | 2 | 0.000945 | 15.5 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | procedures | clef-flash | off | no | error:model-timeout | 7 | 1 | 11 | - | 232.1 | 0 | no | 19 on the page, 38 in the file, 19 missing, 38 extra |
| flights-oneway | loose | procedures | clef-flash | off | no | limit | 12 | 1 | 19 | - | 139.7 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | goal | procedures | clef-flash | off | no | limit | 12 | 0 | 14 | - | 134.4 | 0 | no | truth 'pln 148'; result differs |
| books-poetry-jsonl | goal | procedures | clef-flash | off | no | error:model-timeout | 11 | 1 | 15 | - | 300 | 0 | no | 19 on the page, 95 in the file, 19 missing, 95 extra |
| flights-oneway | steps | procedures | clef-flash | off | no | done | 10 | 0 | 11 | 0.006054 | 101.3 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | steps | procedures | clef-flash | off | yes | done | 5 | 0 | 6 | - | 47.7 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | procedures | clef-flash | off | yes | done | 5 | 0 | 7 | - | 50.5 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | loose | procedures | clef-flash | off | yes | done | 7 | 0 | 9 | - | 68.1 | 0 | no | Wikidata P281 ['75007']; result agrees |
| portal-welcome | steps | procedures | clef-flash | off | yes | done | 8 | 0 | 8 | 0.002168 | 41.7 | 0 | no | message 'old' quoted |
| portal-welcome | loose | procedures | clef-flash | off | no | limit | 12 | 0 | 14 | - | 52.2 | 0 | no | message 'old' not quoted |
| portal-welcome | goal | procedures | clef-flash | off | no | limit | 12 | 0 | 15 | - | 68.9 | 0 | no | message 'old' not quoted |
| u10-portal-new-message | steps | procedures | clef-flash | off | yes | done | 6 | 0 | 6 | 0.001637 | 28.5 | 0 | no | message 'new' quoted |
| u10-portal-new-message | loose | procedures | clef-flash | off | no | limit | 12 | 0 | 14 | - | 75.1 | 0 | no | message 'new' not quoted |
| u10-portal-new-message | goal | procedures | clef-flash | off | no | limit | 12 | 0 | 15 | - | 120.3 | 0 | no | message 'new' not quoted |
| u5-flights-roundtrip | loose | procedures | clef-flash | off | no | done | 9 | 1 | 15 | - | 115.6 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | loose | procedures | clef-flash | off | no | done | 4 | 0 | 6 | 0.001537 | 35.5 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [] |
| u5-flights-roundtrip | steps | procedures | clef-flash | off | no | done | 10 | 1 | 16 | - | 124.5 | 0 | no | truth 'pln 352'; result differs |
| u5-flights-roundtrip | goal | procedures | clef-flash | off | no | done | 11 | 1 | 17 | - | 162.1 | 0 | no | truth 'pln 352'; result differs |
| u6-maps-cafe | goal | procedures | clef-flash | off | yes | done | 4 | 0 | 7 | - | 42.9 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | procedures | clef-flash | off | yes | done | 5 | 0 | 9 | - | 61.4 | 0 | no | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | goal | procedures | clef-flash | off | yes | done | 8 | 0 | 8 | 0.002356 | 40.8 | 0 | no | registrations 1, confirmed True, password delivered True |
| u7-register | loose | procedures | clef-flash | off | no | limit | 12 | 0 | 12 | 0.004995 | 90.3 | 0 | no | registrations 1, confirmed False, password delivered True |
| u7-register | steps | procedures | clef-flash | off | no | limit | 12 | 1 | 14 | 0.004682 | 81.3 | 0 | no | registrations 1, confirmed False, password delivered True |
| u9-upload | loose | procedures | clef-flash | off | yes | done | 3 | 0 | 3 | 0.000708 | 14.2 | 0 | no | 1 upload(s); link /files/1 in the result |
| u9-upload | goal | procedures | clef-flash | off | yes | done | 4 | 0 | 4 | 0.00091 | 15.7 | 0 | no | 1 upload(s); link /files/1 in the result |
| u8-books-travel-jsonl | goal | procedures | clef-flash | off | no | done | 5 | 1 | 8 | 0.005054 | 73.9 | 0 | no | 11 on the page, 44 in the file, 0 missing, 33 extra |
| u8-books-travel-jsonl | steps | procedures | clef-flash | off | no | done | 4 | 1 | 7 | 0.004227 | 60.2 | 0 | no | 11 on the page, 33 in the file, 0 missing, 22 extra |
| u9-upload | steps | procedures | clef-flash | off | yes | done | 7 | 0 | 7 | 0.001752 | 33.3 | 0 | no | 1 upload(s); link /files/1 in the result |
| wiki-ada-born | loose | procedures | clef-flash | off | yes | done | 6 | 0 | 9 | - | 31.9 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | goal | procedures | clef-flash | off | yes | done | 5 | 0 | 8 | - | 24.4 | 0 | no | result names '10 December 1815' |
| wiki-ada-born | steps | procedures | clef-flash | off | yes | done | 4 | 0 | 6 | 0.002767 | 29.9 | 0 | no | result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | clef-flash | off | yes | done | 4 | 0 | 7 | - | 30.9 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | goal | procedures | clef-flash | off | yes | done | 5 | 0 | 10 | - | 29.1 | 0 | no | result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | clef-flash | off | yes | done | 5 | 0 | 8 | - | 23 | 0 | no | result names 'Charles Babbage' |
| u8-books-travel-jsonl | loose | procedures | clef-flash | off | no | deadline | 12 | 1 | 17 | 0.018136 | 300.3 | 0 | no | 11 on the page, 66 in the file, 11 missing, 66 extra |
