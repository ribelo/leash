# Corpus run 2026-10-06-no-playbooks

## Conclusions

This run is on the cut build (80ce5f6, L63, ADR-0016: no playbooks). The configurations were JEV with images off, Clef with images off, and Clef with images B, each in three styles with `--parallel 4`, under a budget of $0.15 per configuration; it spent $0.40. The budget stopped every configuration after the same first 10 missions in alphabetical order (`ae-*`, `books-*`, `canvas-launch`, `flights-oneway`), so the comparisons are paired over those 30 cells per configuration. U1 and U2 ran on the operator's Tauron account, JEV, three styles each, for $0.02.

1. **Nothing regressed in the removal.** On the same 30 JEV cells the pre-cut takeover run (2026-10-06, no playbook) passed 26 and this build 23. The three differences come from code the cut did not touch. ae-polo-brand/steps ended on a JEV model timeout. In books-poetry-jsonl the planner copied one long title shortened ("The Collected Poems of W.B. Yeats") in all three styles, and one cell flipped the other way (ae-polo-brand/loose now passes).
2. **Model: JEV and Clef are within noise; Clef costs more.** JEV passed 23/30 at $0.0032 per cell, and Clef 22/30 at $0.0045. JEV handed the page to the planner more often (4.2 planner calls per cell against 1.4) and was slower (65 s against 32 s).
3. **Images B: a small gain on Clef.** 25/30 against 22/30 with images off, at $0.0054 per cell; 6 cells sent a screenshot.
4. **Instruction detail: no clear winner on these missions.** Goal passed 24/30, steps 24/30, loose 22/30. The larger run of 2026-10-06 (82% goal, 74% loose, 71% steps over 96 cells per style) still stands as the basis for the skill.
5. **The operator's account works on the cut build.** U1 passed 2/3: loose and steps read the three amounts; the goal cell answered without the amounts the check reads. U2 passed 2/3: goal and steps downloaded the newest invoice, E/TM2/UG533989/0003/26, exactly once. The loose cell ended on a model timeout after 21 planner turns. Still failing as before: flights-oneway 0/9 (weakly checked) and books-poetry-jsonl 2/9.

## Summary

| factor | level | cells | passed | pass rate | mean cost $ | mean planner calls |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| model | clef | 66 | 53 | 80% | 0.00504 | 1.3 |
| model | jev | 36 | 27 | 75% | 0.00312 | 4.6 |
| image | b | 33 | 28 | 85% | 0.00536 | 1.3 |
| image | off | 69 | 52 | 75% | 0.00388 | 3.0 |
| style | goal | 34 | 27 | 79% | 0.00419 | 2.2 |
| style | loose | 34 | 25 | 74% | 0.00435 | 2.6 |
| style | steps | 34 | 28 | 82% | 0.00465 | 2.6 |

## Cells

| mission | style | model | image | pass | status | planner calls | navigator steps | calls | cost $ | wall s | image parts | truncated | note |
| --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| ae-blue-top-price | goal | jev | off | yes | done | 1 | 1 | 2 | 0.000631 | 11.6 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | jev | off | yes | done | 1 | 1 | 2 | 0.000627 | 12.6 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | jev | off | yes | done | 1 | 5 | 12 | 0.002123 | 23.8 | 0 | - | truth 'rs. 500'; result agrees |
| ae-search-jeans | loose | jev | off | yes | done | 1 | 3 | 7 | 0.000992 | 16.5 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | jev | off | yes | done | 1 | 3 | 7 | 0.001057 | 16.9 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-polo-brand | loose | jev | off | yes | done | 6 | 3 | 9 | 0.004736 | 67.3 | 0 | - | result names 'Blue Top' |
| ae-polo-brand | goal | jev | off | yes | done | 4 | 1 | 6 | 0.003537 | 55.7 | 0 | - | result names 'Blue Top' |
| ae-search-jeans | steps | jev | off | yes | done | 1 | 3 | 6 | 0.000912 | 15.5 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | goal | jev | off | yes | done | 3 | 3 | 7 | 0.002278 | 20 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | loose | jev | off | yes | done | 3 | 6 | 10 | 0.003495 | 21.5 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | jev | off | yes | done | 3 | 7 | 10 | 0.003635 | 18.1 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | jev | off | yes | done | 1 | 2 | 3 | 0.000796 | 5.3 | 0 | - | truth '19'; result agrees |
| books-poetry-count | loose | jev | off | yes | done | 1 | 2 | 3 | 0.000796 | 6 | 0 | - | truth '19'; result agrees |
| books-poetry-count | steps | jev | off | yes | done | 1 | 2 | 3 | 0.000798 | 5.5 | 0 | - | truth '19'; result agrees |
| books-poetry-jsonl | steps | jev | off | no | done | 4 | 4 | 10 | 0.007247 | 86.4 | 0 | - | 19 on the page, 19 in the file, 2 missing, 2 extra |
| books-price | loose | jev | off | yes | done | 1 | 1 | 2 | 0.000602 | 5.1 | 0 | - | result names '£51.77' |
| books-price | goal | jev | off | yes | done | 1 | 1 | 2 | 0.000602 | 5.7 | 0 | - | result names '£51.77' |
| books-price | steps | jev | off | yes | done | 1 | 2 | 3 | 0.000521 | 4.6 | 0 | - | result names '£51.77' |
| books-stock | loose | jev | off | yes | done | 1 | 2 | 3 | 0.000571 | 5.1 | 0 | - | truth '20'; result agrees |
| books-stock | goal | jev | off | yes | done | 1 | 2 | 3 | 0.000589 | 4.7 | 0 | - | truth '20'; result agrees |
| books-stock | steps | jev | off | yes | done | 1 | 2 | 3 | 0.00058 | 4.5 | 0 | - | truth '20'; result agrees |
| canvas-launch | loose | jev | off | yes | done | 2 | 1 | 3 | 0.000688 | 9.1 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | jev | off | yes | done | 2 | 1 | 3 | 0.00074 | 7.7 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | jev | off | yes | done | 2 | 1 | 3 | 0.00069 | 7.8 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | loose | jev | off | no | done | 10 | 7 | 18 | 0.015946 | 210.4 | 0 | - | 19 on the page, 19 in the file, 2 missing, 2 extra |
| ae-polo-brand | steps | jev | off | no | error | 4 | 2 | 474 | - | 302.3 | 0 | - | result lacks 'Blue Top' |
| books-poetry-jsonl | goal | jev | off | no | done | 16 | 16 | 36 | 0.02422 | 289.8 | 0 | - | 19 on the page, 19 in the file, 1 missing, 1 extra |
| flights-oneway | goal | jev | off | no | error | 9 | 10 | 27 | 0.007182 | 106 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | loose | jev | off | no | error | 7 | 199 | 283 | - | 302.7 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | steps | jev | off | no | error:model-timeout | 37 | 7 | 49 | - | 300 | 0 | - | truth 'pln 148'; result differs |
| ae-blue-top-price | goal | clef | off | yes | done | 1 | 1 | 2 | 0.001024 | 11.9 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | clef | off | no | error | 0 | 0 | 1 | - | 15.7 | 0 | no | truth 'rs. 500'; result differs |
| ae-polo-brand | goal | clef | off | yes | done | 1 | 2 | 4 | 0.002219 | 16.4 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | clef | off | yes | done | 1 | 2 | 3 | 0.001722 | 16 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | loose | clef | off | yes | done | 1 | 3 | 7 | 0.002811 | 17.1 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | clef | off | yes | done | 1 | 3 | 6 | 0.002333 | 17.3 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | clef | off | yes | done | 1 | 3 | 7 | 0.002873 | 19.5 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | clef | off | yes | done | 1 | 6 | 7 | 0.005368 | 17.1 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | clef | off | yes | done | 1 | 6 | 7 | 0.005393 | 12.2 | 0 | no | result names 'The Mysterious Affair at Styles' |
| ae-polo-brand | loose | clef | off | no | error | 3 | 32 | 36 | - | 82.4 | 0 | no | result lacks 'Blue Top' |
| books-mystery-page2 | steps | clef | off | yes | done | 1 | 6 | 7 | 0.005469 | 14.2 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | clef | off | yes | done | 1 | 2 | 3 | 0.001968 | 5.8 | 0 | no | truth '19'; result agrees |
| books-poetry-count | goal | clef | off | yes | done | 1 | 2 | 3 | 0.001987 | 6 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | clef | off | yes | done | 1 | 2 | 3 | 0.001988 | 6.1 | 0 | no | truth '19'; result agrees |
| books-poetry-jsonl | loose | clef | off | no | done | 0 | 11 | 12 | 0.009866 | 20.9 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | clef | off | yes | done | 1 | 1 | 2 | 0.001188 | 4.9 | 0 | no | result names '£51.77' |
| books-price | goal | clef | off | yes | done | 1 | 1 | 2 | 0.001191 | 4.6 | 0 | no | result names '£51.77' |
| books-price | steps | clef | off | yes | done | 1 | 2 | 3 | 0.001416 | 6.2 | 0 | no | result names '£51.77' |
| books-stock | loose | clef | off | yes | done | 2 | 1 | 3 | 0.001549 | 9.3 | 0 | no | truth '20'; result agrees |
| books-stock | goal | clef | off | yes | done | 2 | 1 | 3 | 0.00147 | 8.1 | 0 | no | truth '20'; result agrees |
| books-stock | steps | clef | off | yes | done | 1 | 2 | 3 | 0.001493 | 6 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | clef | off | yes | done | 2 | 1 | 3 | 0.000797 | 7.8 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | clef | off | yes | done | 2 | 1 | 3 | 0.000812 | 9.2 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | clef | off | yes | done | 2 | 1 | 3 | 0.000845 | 8.2 | 0 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | clef | off | yes | done | 4 | 8 | 12 | 0.011623 | 86.5 | 0 | no | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-poetry-jsonl | goal | clef | off | no | done | 5 | 5 | 11 | 0.011871 | 107.6 | 0 | no | 19 on the page, 19 in the file, 2 missing, 2 extra |
| flights-oneway | goal | clef | off | no | done | 1 | 12 | 19 | 0.014091 | 34.9 | 0 | yes | truth 'pln 148'; result differs |
| flights-oneway | loose | clef | off | no | done | 1 | 14 | 23 | 0.019213 | 42.3 | 0 | no | truth 'pln 148'; result differs |
| flights-oneway | steps | clef | off | no | done | 1 | 9 | 14 | 0.010066 | 30.6 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | clef | off | yes | done | 1 | 3 | 6 | 0.003572 | 17.8 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | clef | off | yes | done | 1 | 3 | 8 | 0.004942 | 19.9 | 0 | no | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | clef | off | yes | done | 1 | 4 | 12 | 0.009381 | 22 | 0 | no | Wikidata P281 ['75007']; result agrees |
| ae-blue-top-price | steps | clef | off | no | error | 0 | 82 | 159 | - | 302.2 | 0 | yes | truth 'rs. 500'; result differs |
| ae-blue-top-price | loose | clef | b | yes | done | 1 | 1 | 2 | 0.00104 | 11.6 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | clef | b | yes | done | 1 | 1 | 2 | 0.001027 | 12.7 | 0 | yes | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | clef | b | yes | done | 1 | 2 | 6 | 0.003721 | 20 | 0 | no | result names 'Blue Top' |
| ae-polo-brand | steps | clef | b | yes | done | 1 | 2 | 5 | 0.003287 | 25.1 | 0 | no | result names 'Blue Top' |
| ae-search-jeans | loose | clef | b | yes | done | 1 | 3 | 5 | 0.001812 | 15.7 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | clef | b | yes | done | 1 | 3 | 5 | 0.001912 | 20.3 | 0 | no | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | clef | b | yes | done | 1 | 3 | 7 | 0.002875 | 16.7 | 0 | no | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | clef | b | yes | done | 1 | 6 | 7 | 0.00537 | 15.4 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | clef | b | yes | done | 1 | 6 | 7 | 0.005401 | 12.8 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | clef | b | yes | done | 1 | 2 | 3 | 0.00197 | 7.1 | 0 | no | truth '19'; result agrees |
| ae-blue-top-price | steps | clef | b | yes | done | 1 | 20 | 46 | 0.025286 | 89.5 | 0 | yes | truth 'rs. 500'; result agrees |
| books-mystery-page2 | steps | clef | b | yes | done | 1 | 6 | 7 | 0.005545 | 15.2 | 0 | no | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | goal | clef | b | yes | done | 1 | 2 | 3 | 0.00197 | 5.5 | 0 | no | truth '19'; result agrees |
| books-poetry-count | steps | clef | b | yes | done | 1 | 2 | 3 | 0.002007 | 6.4 | 0 | no | truth '19'; result agrees |
| ae-polo-brand | loose | clef | b | yes | done | 9 | 3 | 16 | 0.011264 | 101 | 0 | yes | result names 'Blue Top' |
| books-poetry-jsonl | loose | clef | b | no | done | 0 | 5 | 6 | 0.00461 | 9.8 | 0 | no | 19 on the page, 0 in the file, 19 missing, 0 extra |
| books-price | loose | clef | b | yes | done | 1 | 1 | 2 | 0.001166 | 4.9 | 0 | no | result names '£51.77' |
| books-price | goal | clef | b | yes | done | 1 | 1 | 2 | 0.001191 | 5.2 | 0 | no | result names '£51.77' |
| books-price | steps | clef | b | yes | done | 1 | 2 | 3 | 0.001414 | 5.7 | 0 | no | result names '£51.77' |
| books-stock | loose | clef | b | yes | done | 2 | 1 | 3 | 0.001487 | 9.1 | 0 | no | truth '20'; result agrees |
| books-stock | goal | clef | b | yes | done | 2 | 1 | 3 | 0.001506 | 8.4 | 0 | no | truth '20'; result agrees |
| books-stock | steps | clef | b | yes | done | 1 | 2 | 3 | 0.001489 | 5.3 | 0 | no | truth '20'; result agrees |
| canvas-launch | loose | clef | b | yes | done | 0 | 2 | 2 | 0.001086 | 2.5 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | clef | b | yes | done | 1 | 2 | 3 | 0.001444 | 5.7 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | clef | b | yes | done | 1 | 2 | 3 | 0.001492 | 6.3 | 2 | no | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | clef | b | yes | done | 2 | 6 | 12 | 0.010736 | 54.2 | 0 | no | 19 on the page, 19 in the file, 0 missing, 0 extra |
| flights-oneway | goal | clef | b | no | done | 1 | 12 | 20 | 0.014815 | 34.6 | 0 | yes | truth 'pln 148'; result differs |
| flights-oneway | loose | clef | b | no | done | 1 | 14 | 24 | 0.019955 | 43.9 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | clef | b | yes | done | 1 | 3 | 6 | 0.003315 | 16.1 | 0 | no | Wikidata P281 ['75007']; result agrees |
| flights-oneway | steps | clef | b | no | done | 1 | 9 | 17 | 0.01338 | 35 | 0 | no | truth 'pln 148'; result differs |
| maps-eiffel-postcode | goal | clef | b | yes | done | 1 | 3 | 7 | 0.004127 | 20.2 | 0 | no | Wikidata P281 ['75007']; result agrees |
| books-poetry-jsonl | goal | clef | b | no | done | 3 | 5 | 9 | 0.010707 | 101.5 | 0 | no | 19 on the page, 19 in the file, 3 missing, 3 extra |
| maps-eiffel-postcode | steps | clef | b | yes | done | 1 | 4 | 11 | 0.00854 | 22 | 0 | no | Wikidata P281 ['75007']; result agrees |
| u1-tauron-overdue | loose | jev | off | yes | done | 4 | 10 | 14 | 0.002751 | 41.2 | 0 | - | page (fresh tab, low-level text) shows ['756,88 zł', '544,92 zł', '211,96 zł'] |
| u1-tauron-overdue | goal | jev | off | no | done | 1 | 12 | 16 | 0.002608 | 23.3 | 0 | - | page (fresh tab, low-level text) shows ['756,88 zł', '544,92 zł', '211,96 zł'] |
| u1-tauron-overdue | steps | jev | off | yes | done | 1 | 4 | 7 | 0.00131 | 14.8 | 0 | - | page (fresh tab, low-level text) shows ['756,88 zł', '544,92 zł', '211,96 zł'] |
| u2-tauron-invoice | loose | jev | off | no | error:model-timeout | 21 | 21 | 50 | - | 300 | 0 | - | new PDF(s): []; invoices []; newest listed not on the page |
| u2-tauron-invoice | goal | jev | off | yes | done | 5 | 5 | 11 | 0.003141 | 35.6 | 0 | - | new PDF(s): ['E_TM2_UG533989_0003_26_1.pdf']; invoices [('26', '0003')]; newest listed not on the page |
| u2-tauron-invoice | steps | jev | off | yes | done | 5 | 5 | 13 | 0.003424 | 34.1 | 0 | - | new PDF(s): ['E_TM2_UG533989_0003_26_1.pdf']; invoices [('26', '0003')]; newest listed not on the page |
