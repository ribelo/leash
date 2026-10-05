# Corpus run 2026-10-06

## Conclusions

The build is the takeover loop (ad950e2 + 6ed9b19): JEV drives, and Luna (`openai/gpt-6-luna`) takes the page over when JEV stops. The run used JEV only, images off, three styles × {none, notes, procedures}, `--parallel 2` in each of three processes, and a hard budget of $0.16 per variant. The rows record $0.31 in total, about $0.0024 per cell. The budget stopped each variant after the first 13 missions in alphabetical order (`ae-*` to `u10-portal-new-message`), the same 13 in every variant. The comparisons below are therefore paired over 38 cells per variant. u5, u6, u7, u8, u9 and the two Wikipedia missions are not in all three variants.

1. **The loop works: 93 of 114 paired cells pass (82%).** On the old JEV-only advisor loop these missions passed far less often: portal 0/63, canvas 11/63, stock 18/63. Now portal-welcome passes 8/9, canvas 9/9 and books-stock 9/9. Luna is asked 2.2 times per cell on average.
2. **Notes: no measured gain.** None passed 32/38 and notes 32/38, at the same cost ($0.0023 and $0.0024 per cell). Notes took longer (47 s against 35 s).
3. **Procedures: slightly worse.** 29/38 against 32/38, at the same cost and 47 s per cell. Three cells is within noise at this size, so this does not show that procedures hurt. It does show they do not help on these missions.
4. **Instruction detail: a goal with its result does best, numbered steps worst.** Goal passed 34/39, loose 32/39, steps 27/36. The skill now recommends the goal style.
5. **What still fails:**
   - Flights 0/9: weakly checked, and not a Leash defect shown here.
   - The Poetry JSONL collection 5/9.
   - u10, the new portal message, 4/6.
   - Nine cells ended `error`: model timeouts and one text-helper timeout.
   
   No new Leash defect stands out. Answering the questions with more confidence needs more cells per variant. At $0.0024 a cell, the full 180-cell matrix would cost about $0.45.

U2 on the operator's account (notes, three styles, this build): all three downloaded the newest invoice, E/TM2/UG533989/0003/26, exactly once, for about $0.01 in total.

## Summary

| factor | level | cells | passed | pass rate | mean cost $ | mean planner calls |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| model | jev | 127 | 99 | 78% | 0.00279 | 2.2 |
| image | off | 127 | 99 | 78% | 0.00279 | 2.2 |
| style | goal | 42 | 36 | 86% | 0.00286 | 2.7 |
| style | loose | 44 | 34 | 77% | 0.00276 | 2.3 |
| style | steps | 41 | 29 | 71% | 0.00274 | 1.8 |
| knowledge | none | 49 | 38 | 78% | 0.00315 | 2.0 |
| knowledge | notes | 38 | 32 | 84% | 0.00240 | 2.6 |
| knowledge | procedures | 40 | 29 | 72% | 0.00273 | 2.2 |

## Cells

| mission | style | knowledge | model | image | pass | status | planner calls | navigator steps | calls | cost $ | wall s | image parts | truncated | note |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| ae-blue-top-price | loose | none | jev | off | yes | done | 1 | 1 | 2 | 0.000617 | 17.7 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | none | jev | off | yes | done | 1 | 1 | 2 | 0.000619 | 17.9 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | none | jev | off | yes | done | 1 | 5 | 29 | 0.004663 | 53.2 | 0 | - | truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | jev | off | yes | done | 2 | 1 | 3 | 0.00104 | 22 | 0 | - | result names 'Blue Top' |
| ae-polo-brand | steps | none | jev | off | yes | done | 2 | 1 | 5 | 0.001426 | 26.9 | 0 | - | result names 'Blue Top' |
| ae-search-jeans | loose | none | jev | off | yes | done | 1 | 3 | 8 | 0.001134 | 24.2 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | jev | off | yes | done | 1 | 3 | 8 | 0.001149 | 22.4 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | jev | off | yes | done | 1 | 3 | 8 | 0.001169 | 23.4 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | jev | off | yes | done | 3 | 6 | 10 | 0.00316 | 29.5 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | none | jev | off | yes | done | 3 | 6 | 10 | 0.0036 | 33.1 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | none | jev | off | yes | done | 4 | 3 | 8 | 0.003394 | 32.3 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | jev | off | yes | done | 1 | 2 | 3 | 0.000795 | 9.4 | 0 | - | truth '19'; result agrees |
| books-poetry-count | goal | none | jev | off | yes | done | 1 | 2 | 3 | 0.000794 | 7.8 | 0 | - | truth '19'; result agrees |
| ae-polo-brand | loose | none | jev | off | no | error | 3 | 1 | 207 | - | 302.8 | 0 | - | result lacks 'Blue Top' |
| books-poetry-count | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000782 | 8.2 | 0 | - | truth '19'; result agrees |
| books-poetry-jsonl | loose | none | jev | off | yes | done | 7 | 6 | 19 | 0.010629 | 142.2 | 0 | - | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-poetry-jsonl | steps | none | jev | off | yes | done | 1 | 4 | 7 | 0.003247 | 42.3 | 0 | - | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-price | loose | none | jev | off | yes | done | 1 | 1 | 2 | 0.000585 | 5.1 | 0 | - | result names '£51.77' |
| books-price | goal | none | jev | off | yes | done | 1 | 1 | 2 | 0.000606 | 4.9 | 0 | - | result names '£51.77' |
| books-price | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000539 | 6.3 | 0 | - | result names '£51.77' |
| books-poetry-jsonl | goal | none | jev | off | yes | done | 9 | 4 | 16 | 0.014338 | 201 | 0 | - | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-stock | loose | none | jev | off | yes | done | 1 | 2 | 3 | 0.000566 | 5.7 | 0 | - | truth '20'; result agrees |
| books-stock | goal | none | jev | off | yes | done | 1 | 2 | 3 | 0.000574 | 5 | 0 | - | truth '20'; result agrees |
| books-stock | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000575 | 5.6 | 0 | - | truth '20'; result agrees |
| canvas-launch | loose | none | jev | off | yes | done | 2 | 1 | 3 | 0.000702 | 10.1 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | none | jev | off | yes | done | 2 | 1 | 3 | 0.000703 | 11.3 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | jev | off | yes | done | 2 | 1 | 3 | 0.000716 | 9.5 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | none | jev | off | no | done | 1 | 15 | 22 | 0.005212 | 36.6 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | goal | none | jev | off | no | done | 1 | 20 | 32 | 0.005746 | 54.2 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | steps | none | jev | off | no | error | 0 | 3 | 7 | - | 24.4 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | jev | off | no | error | 0 | 0 | 3 | - | 17.5 | 0 | - | Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | goal | none | jev | off | yes | done | 1 | 5 | 11 | 0.002066 | 17.2 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | jev | off | yes | done | 1 | 3 | 11 | 0.002233 | 22.8 | 0 | - | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | none | jev | off | yes | done | 6 | 2 | 9 | 0.00146 | 27.7 | 0 | - | message 'old' quoted |
| portal-welcome | goal | none | jev | off | yes | done | 1 | 5 | 8 | 0.000639 | 9.9 | 0 | - | message 'old' quoted |
| portal-welcome | steps | none | jev | off | no | error | 0 | 1 | 4 | - | 13.5 | 0 | - | message 'old' not quoted |
| u10-portal-new-message | goal | none | jev | off | yes | done | 5 | 1 | 6 | 0.001001 | 15.2 | 0 | - | message 'new' quoted |
| u10-portal-new-message | loose | none | jev | off | yes | done | 5 | 3 | 8 | 0.001588 | 23.6 | 0 | - | message 'new' quoted |
| u10-portal-new-message | steps | none | jev | off | no | error | 0 | 1 | 4 | - | 12.7 | 0 | - | message 'new' not quoted |
| u5-flights-roundtrip | loose | none | jev | off | no | done | 1 | 11 | 18 | 0.00494 | 30.3 | 0 | - | truth 'pln 335'; result differs |
| u5-flights-roundtrip | goal | none | jev | off | no | error | 0 | 9 | 18 | - | 39.2 | 0 | - | truth 'pln 335'; result differs |
| u5-flights-roundtrip | steps | none | jev | off | no | done | 1 | 19 | 35 | 0.013229 | 70.7 | 0 | - | truth 'pln 335'; result differs |
| u6-maps-cafe | loose | none | jev | off | yes | done | 3 | 25 | 44 | 0.008977 | 78.4 | 0 | - | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | none | jev | off | yes | done | 4 | 7 | 16 | 0.004296 | 54.7 | 0 | - | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | none | jev | off | yes | done | 0 | 8 | 11 | 0.000776 | 15.7 | 0 | - | registrations 1, confirmed True |
| u7-register | goal | none | jev | off | yes | done | 1 | 8 | 12 | 0.000942 | 18.9 | 0 | - | registrations 1, confirmed True |
| u7-register | steps | none | jev | off | yes | done | 1 | 8 | 12 | 0.000948 | 18.3 | 0 | - | registrations 1, confirmed True |
| u8-books-travel-jsonl | loose | none | jev | off | no | done | 1 | 3 | 5 | 0.003292 | 42.4 | 0 | - | 11 on the page, 11 in the file, 2 missing, 2 extra |
| u6-maps-cafe | goal | none | jev | off | yes | done | 11 | 50 | 89 | 0.020016 | 188.7 | 0 | - | names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| ae-blue-top-price | goal | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000687 | 17.6 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | notes | jev | off | yes | done | 1 | 1 | 5 | 0.001078 | 19.7 | 0 | - | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | notes | jev | off | yes | done | 2 | 5 | 11 | 0.002627 | 33.3 | 0 | - | result names 'Blue Top' |
| ae-polo-brand | goal | notes | jev | off | yes | done | 2 | 3 | 9 | 0.002134 | 30.9 | 0 | - | result names 'Blue Top' |
| ae-polo-brand | steps | notes | jev | off | yes | done | 1 | 2 | 5 | 0.001151 | 18.3 | 0 | - | result names 'Blue Top' |
| ae-search-jeans | loose | notes | jev | off | yes | done | 1 | 3 | 7 | 0.001012 | 23.1 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | jev | off | yes | done | 1 | 3 | 8 | 0.001165 | 24.6 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | jev | off | yes | done | 1 | 3 | 9 | 0.00129 | 26.3 | 0 | - | result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | notes | jev | off | yes | done | 3 | 6 | 10 | 0.003296 | 36.3 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | notes | jev | off | yes | done | 2 | 6 | 10 | 0.002527 | 23.7 | 0 | - | result names 'The Mysterious Affair at Styles' |
| ae-blue-top-price | steps | notes | jev | off | no | error | 0 | 2 | 216 | - | 303.4 | 0 | - | truth 'rs. 500'; result differs |
| books-mystery-page2 | steps | notes | jev | off | yes | done | 3 | 5 | 9 | 0.004901 | 68.5 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000809 | 8.7 | 0 | - | truth '19'; result agrees |
| books-poetry-count | goal | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000808 | 8.3 | 0 | - | truth '19'; result agrees |
| books-poetry-count | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000829 | 7.4 | 0 | - | truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | jev | off | yes | done | 9 | 6 | 19 | 0.014865 | 203.8 | 0 | - | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-poetry-jsonl | goal | notes | jev | off | yes | done | 12 | 4 | 18 | 0.015494 | 212.8 | 0 | - | 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-price | loose | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000586 | 4.1 | 0 | - | result names '£51.77' |
| books-price | goal | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000598 | 4.5 | 0 | - | result names '£51.77' |
| books-price | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000559 | 5.2 | 0 | - | result names '£51.77' |
| books-stock | loose | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000596 | 5.3 | 0 | - | truth '20'; result agrees |
| books-stock | goal | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000584 | 4.8 | 0 | - | truth '20'; result agrees |
| books-stock | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000613 | 5.7 | 0 | - | truth '20'; result agrees |
| books-poetry-jsonl | steps | notes | jev | off | no | done | 1 | 3 | 5 | 0.003575 | 44.4 | 0 | - | 19 on the page, 19 in the file, 1 missing, 1 extra |
| canvas-launch | loose | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000747 | 9.6 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000767 | 9.3 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000761 | 8.5 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | notes | jev | off | no | done | 1 | 14 | 22 | 0.005401 | 39.6 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | steps | notes | jev | off | no | done | 10 | 7 | 19 | 0.005507 | 101.8 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | jev | off | yes | done | 1 | 3 | 11 | 0.001917 | 26.6 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | notes | jev | off | yes | done | 1 | 4 | 10 | 0.001972 | 22.6 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | jev | off | yes | done | 1 | 3 | 7 | 0.001447 | 15.7 | 0 | - | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | notes | jev | off | yes | done | 5 | 1 | 6 | 0.001175 | 18.5 | 0 | - | message 'old' quoted |
| portal-welcome | goal | notes | jev | off | yes | done | 5 | 3 | 8 | 0.001257 | 22.8 | 0 | - | message 'old' quoted |
| portal-welcome | steps | notes | jev | off | yes | done | 1 | 5 | 8 | 0.000697 | 17 | 0 | - | message 'old' quoted |
| u10-portal-new-message | loose | notes | jev | off | yes | done | 5 | 3 | 8 | 0.001737 | 29.3 | 0 | - | message 'new' quoted |
| flights-oneway | goal | notes | jev | off | no | error | 9 | 82 | 159 | - | 303.1 | 0 | - | truth 'pln 148'; result differs |
| u10-portal-new-message | goal | notes | jev | off | no | done | 4 | 5 | 9 | 0.001353 | 24.1 | 0 | - | message 'new' not quoted |
| ae-blue-top-price | goal | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000667 | 17.3 | 0 | - | truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | procedures | jev | off | yes | done | 1 | 1 | 4 | 0.000967 | 18.6 | 0 | - | truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | procedures | jev | off | yes | done | 5 | 3 | 10 | 0.005098 | 66.7 | 0 | - | result names 'Blue Top' |
| ae-polo-brand | goal | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.001113 | 22 | 0 | - | result names 'Blue Top' |
| ae-blue-top-price | steps | procedures | jev | off | no | error | 0 | 2 | 218 | - | 302.2 | 0 | - | truth 'rs. 500'; result differs |
| ae-search-jeans | loose | procedures | jev | off | yes | done | 1 | 3 | 7 | 0.001084 | 22.2 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | jev | off | yes | done | 1 | 3 | 9 | 0.001406 | 25.5 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | jev | off | yes | done | 1 | 3 | 7 | 0.001097 | 23 | 0 | - | result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | procedures | jev | off | no | error | 0 | 0 | 215 | - | 303.2 | 0 | - | result lacks 'Blue Top' |
| books-mystery-page2 | loose | procedures | jev | off | yes | done | 1 | 7 | 12 | 0.003545 | 45.8 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | procedures | jev | off | yes | done | 3 | 6 | 13 | 0.005242 | 53.2 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | procedures | jev | off | yes | done | 1 | 6 | 11 | 0.003531 | 30.2 | 0 | - | result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000807 | 8.5 | 0 | - | truth '19'; result agrees |
| books-poetry-count | goal | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000835 | 8.7 | 0 | - | truth '19'; result agrees |
| books-poetry-count | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000838 | 8.6 | 0 | - | truth '19'; result agrees |
| books-poetry-jsonl | loose | procedures | jev | off | no | done | 4 | 1 | 8 | 0.005989 | 80.4 | 0 | - | 19 on the page, 38 in the file, 0 missing, 1 extra |
| books-poetry-jsonl | goal | procedures | jev | off | no | done | 3 | 1 | 8 | 0.008209 | 119.8 | 0 | - | 19 on the page, 38 in the file, 0 missing, 3 extra |
| books-price | loose | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000599 | 4.5 | 0 | - | result names '£51.77' |
| books-price | goal | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000624 | 5.8 | 0 | - | result names '£51.77' |
| books-price | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000573 | 5.9 | 0 | - | result names '£51.77' |
| books-stock | loose | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000607 | 5.2 | 0 | - | truth '20'; result agrees |
| books-stock | goal | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000608 | 5.6 | 0 | - | truth '20'; result agrees |
| books-stock | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000618 | 5.4 | 0 | - | truth '20'; result agrees |
| canvas-launch | loose | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000722 | 9.5 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000724 | 8.9 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000749 | 12.4 | 0 | - | 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | procedures | jev | off | no | done | 6 | 1 | 10 | 0.010814 | 149.1 | 0 | - | 19 on the page, 38 in the file, 0 missing, 2 extra |
| flights-oneway | loose | procedures | jev | off | no | done | 1 | 15 | 25 | 0.005954 | 42.9 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | steps | procedures | jev | off | no | error | 0 | 3 | 7 | - | 25.3 | 0 | - | truth 'pln 148'; result differs |
| flights-oneway | goal | procedures | jev | off | no | done | 1 | 10 | 20 | 0.004183 | 47.8 | 0 | - | truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | procedures | jev | off | yes | done | 1 | 3 | 13 | 0.001974 | 30.2 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | procedures | jev | off | yes | done | 1 | 3 | 9 | 0.0018 | 21.8 | 0 | - | Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | jev | off | yes | done | 1 | 4 | 11 | 0.002646 | 20 | 0 | - | Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | procedures | jev | off | yes | done | 6 | 4 | 16 | - | 42.1 | 0 | - | message 'old' quoted |
| portal-welcome | steps | procedures | jev | off | yes | done | 1 | 5 | 8 | 0.000673 | 10.7 | 0 | - | message 'old' quoted |
| portal-welcome | goal | procedures | jev | off | yes | done | 7 | 9 | 27 | - | 62.9 | 0 | - | message 'old' quoted |
| u10-portal-new-message | loose | procedures | jev | off | no | done | 4 | 24 | 34 | - | 64.3 | 0 | - | message 'new' not quoted |
| u10-portal-new-message | goal | procedures | jev | off | yes | done | 5 | 2 | 10 | - | 36.2 | 0 | - | message 'new' quoted |
| u5-flights-roundtrip | loose | procedures | jev | off | no | error | 2 | 15 | 41 | - | 105.5 | 0 | - | truth 'pln 335'; result differs |
| u10-portal-new-message | steps | procedures | jev | off | no | done | 13 | 16 | 32 | 0.013105 | 225.8 | 0 | - | message 'new' not quoted |
