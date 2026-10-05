# Corpus run 2026-10-06

## Conclusions

The build is the takeover loop (ad950e2 + 6ed9b19): JEV drives, and Luna (`openai/gpt-6-luna`) takes the page over when JEV stops. The run used JEV, images off, all 20 public missions × 3 styles × {none, notes, procedures}, and two repetitions. Repetition 1 is complete (180 cells). Repetition 2 was stopped by its budget after 35 to 60 cells per variant. Comparisons are paired: 95 cells per variant, the same mission and style in each. Recorded cost for both repetitions is $0.96, about $0.003 per cell.

1. **Knowledge: no option is better, and procedures are worst.** No playbook passed 73/95 (77%), notes 74/95 (78%), procedures 69/95 (73%). Notes and no playbook are within one cell of each other. Notes cost 13% more per cell ($0.0035 against $0.0031) and take longer (48 s against 36 s). Procedures are the slowest (54 s) and pass least. The only clear effect of notes is on the Travel JSONL collection (3/6 against 0/6).
2. **Instruction detail: state the goal and its result.** Goal passed 79/96 (82%), loose 71/96 (74%), steps 66/93 (71%). It is the same order as in the first 38 cells.
3. **Recommended default:** drive without a playbook, written as a goal with "Result: …". Write notes only for a site where a mission keeps failing.
4. **The takeover loop works:** 216 of 285 paired cells pass overall (76%). Portal, canvas, stock and registration, which failed on the advisor-only loop, now pass most of the time.
5. **What still fails, the same in every variant:** flights (weakly checked), the Poetry JSONL collection, the Maps café and the new portal message. None is a variant effect.

U2 on the operator's account (notes, three styles, this build): all three downloaded the newest invoice, E/TM2/UG533989/0003/26, exactly once, for about $0.01 in total.

## Summary

| factor | level | cells | passed | pass rate | mean cost $ | mean planner calls |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| model | jev | 313 | 237 | 76% | 0.00342 | 2.4 |
| image | off | 313 | 237 | 76% | 0.00342 | 2.4 |
| style | goal | 105 | 86 | 82% | 0.00378 | 2.9 |
| style | loose | 105 | 77 | 73% | 0.00315 | 2.4 |
| style | steps | 103 | 74 | 72% | 0.00329 | 2.0 |
| knowledge | none | 120 | 92 | 77% | 0.00330 | 2.1 |
| knowledge | notes | 95 | 74 | 78% | 0.00350 | 2.5 |
| knowledge | procedures | 98 | 71 | 72% | 0.00348 | 2.7 |

## Cells

| mission | style | knowledge | model | image | pass | status | planner calls | navigator steps | calls | cost $ | wall s | image parts | truncated | note |
| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| ae-blue-top-price | loose | none | jev | off | yes | done | 1 | 1 | 2 | 0.000617 | 17.7 | 0 | - | rep 1: truth 'rs. 500'; result agrees |
| ae-blue-top-price | goal | none | jev | off | yes | done | 1 | 1 | 2 | 0.000619 | 17.9 | 0 | - | rep 1: truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | none | jev | off | yes | done | 1 | 5 | 29 | 0.004663 | 53.2 | 0 | - | rep 1: truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | jev | off | yes | done | 2 | 1 | 3 | 0.00104 | 22 | 0 | - | rep 1: result names 'Blue Top' |
| ae-polo-brand | steps | none | jev | off | yes | done | 2 | 1 | 5 | 0.001426 | 26.9 | 0 | - | rep 1: result names 'Blue Top' |
| ae-search-jeans | loose | none | jev | off | yes | done | 1 | 3 | 8 | 0.001134 | 24.2 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | jev | off | yes | done | 1 | 3 | 8 | 0.001149 | 22.4 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | jev | off | yes | done | 1 | 3 | 8 | 0.001169 | 23.4 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | jev | off | yes | done | 3 | 6 | 10 | 0.00316 | 29.5 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | none | jev | off | yes | done | 3 | 6 | 10 | 0.0036 | 33.1 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | none | jev | off | yes | done | 4 | 3 | 8 | 0.003394 | 32.3 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | jev | off | yes | done | 1 | 2 | 3 | 0.000795 | 9.4 | 0 | - | rep 1: truth '19'; result agrees |
| books-poetry-count | goal | none | jev | off | yes | done | 1 | 2 | 3 | 0.000794 | 7.8 | 0 | - | rep 1: truth '19'; result agrees |
| ae-polo-brand | loose | none | jev | off | no | error | 3 | 1 | 207 | - | 302.8 | 0 | - | rep 1: result lacks 'Blue Top' |
| books-poetry-count | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000782 | 8.2 | 0 | - | rep 1: truth '19'; result agrees |
| books-poetry-jsonl | loose | none | jev | off | yes | done | 7 | 6 | 19 | 0.010629 | 142.2 | 0 | - | rep 1: 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-poetry-jsonl | steps | none | jev | off | yes | done | 1 | 4 | 7 | 0.003247 | 42.3 | 0 | - | rep 1: 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-price | loose | none | jev | off | yes | done | 1 | 1 | 2 | 0.000585 | 5.1 | 0 | - | rep 1: result names '£51.77' |
| books-price | goal | none | jev | off | yes | done | 1 | 1 | 2 | 0.000606 | 4.9 | 0 | - | rep 1: result names '£51.77' |
| books-price | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000539 | 6.3 | 0 | - | rep 1: result names '£51.77' |
| books-poetry-jsonl | goal | none | jev | off | yes | done | 9 | 4 | 16 | 0.014338 | 201 | 0 | - | rep 1: 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-stock | loose | none | jev | off | yes | done | 1 | 2 | 3 | 0.000566 | 5.7 | 0 | - | rep 1: truth '20'; result agrees |
| books-stock | goal | none | jev | off | yes | done | 1 | 2 | 3 | 0.000574 | 5 | 0 | - | rep 1: truth '20'; result agrees |
| books-stock | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000575 | 5.6 | 0 | - | rep 1: truth '20'; result agrees |
| canvas-launch | loose | none | jev | off | yes | done | 2 | 1 | 3 | 0.000702 | 10.1 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | none | jev | off | yes | done | 2 | 1 | 3 | 0.000703 | 11.3 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | jev | off | yes | done | 2 | 1 | 3 | 0.000716 | 9.5 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | none | jev | off | no | done | 1 | 15 | 22 | 0.005212 | 36.6 | 0 | - | rep 1: truth 'pln 148'; result differs |
| flights-oneway | goal | none | jev | off | no | done | 1 | 20 | 32 | 0.005746 | 54.2 | 0 | - | rep 1: truth 'pln 148'; result differs |
| flights-oneway | steps | none | jev | off | no | error | 0 | 3 | 7 | - | 24.4 | 0 | - | rep 1: truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | jev | off | no | error | 0 | 0 | 3 | - | 17.5 | 0 | - | rep 1: Wikidata P281 ['75007']; result differs |
| maps-eiffel-postcode | goal | none | jev | off | yes | done | 1 | 5 | 11 | 0.002066 | 17.2 | 0 | - | rep 1: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | jev | off | yes | done | 1 | 3 | 11 | 0.002233 | 22.8 | 0 | - | rep 1: Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | none | jev | off | yes | done | 6 | 2 | 9 | 0.00146 | 27.7 | 0 | - | rep 1: message 'old' quoted |
| portal-welcome | goal | none | jev | off | yes | done | 1 | 5 | 8 | 0.000639 | 9.9 | 0 | - | rep 1: message 'old' quoted |
| portal-welcome | steps | none | jev | off | no | error | 0 | 1 | 4 | - | 13.5 | 0 | - | rep 1: message 'old' not quoted |
| u10-portal-new-message | goal | none | jev | off | yes | done | 5 | 1 | 6 | 0.001001 | 15.2 | 0 | - | rep 1: message 'new' quoted |
| u10-portal-new-message | loose | none | jev | off | yes | done | 5 | 3 | 8 | 0.001588 | 23.6 | 0 | - | rep 1: message 'new' quoted |
| u10-portal-new-message | steps | none | jev | off | no | error | 0 | 1 | 4 | - | 12.7 | 0 | - | rep 1: message 'new' not quoted |
| u5-flights-roundtrip | loose | none | jev | off | no | done | 1 | 11 | 18 | 0.00494 | 30.3 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u5-flights-roundtrip | goal | none | jev | off | no | error | 0 | 9 | 18 | - | 39.2 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u5-flights-roundtrip | steps | none | jev | off | no | done | 1 | 19 | 35 | 0.013229 | 70.7 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u6-maps-cafe | loose | none | jev | off | yes | done | 3 | 25 | 44 | 0.008977 | 78.4 | 0 | - | rep 1: names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | none | jev | off | yes | done | 4 | 7 | 16 | 0.004296 | 54.7 | 0 | - | rep 1: names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | none | jev | off | yes | done | 0 | 8 | 11 | 0.000776 | 15.7 | 0 | - | rep 1: registrations 1, confirmed True |
| u7-register | goal | none | jev | off | yes | done | 1 | 8 | 12 | 0.000942 | 18.9 | 0 | - | rep 1: registrations 1, confirmed True |
| u7-register | steps | none | jev | off | yes | done | 1 | 8 | 12 | 0.000948 | 18.3 | 0 | - | rep 1: registrations 1, confirmed True |
| u8-books-travel-jsonl | loose | none | jev | off | no | done | 1 | 3 | 5 | 0.003292 | 42.4 | 0 | - | rep 1: 11 on the page, 11 in the file, 2 missing, 2 extra |
| u6-maps-cafe | goal | none | jev | off | yes | done | 11 | 50 | 89 | 0.020016 | 188.7 | 0 | - | rep 1: names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u8-books-travel-jsonl | steps | none | jev | off | no | done | 2 | 4 | 6 | 0.003419 | 47.2 | 0 | - | rep 1: 11 on the page, 11 in the file, 1 missing, 1 extra |
| u9-upload | loose | none | jev | off | yes | done | 1 | 3 | 4 | 0.000468 | 5.2 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| u9-upload | goal | none | jev | off | yes | done | 1 | 3 | 4 | 0.000457 | 6 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| u9-upload | steps | none | jev | off | yes | done | 1 | 3 | 4 | 0.000436 | 6.5 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| wiki-ada-born | loose | none | jev | off | yes | done | 1 | 3 | 6 | 0.002237 | 22.5 | 0 | - | rep 1: result names '10 December 1815' |
| wiki-ada-born | goal | none | jev | off | yes | done | 1 | 3 | 7 | 0.002422 | 14.7 | 0 | - | rep 1: result names '10 December 1815' |
| wiki-ada-born | steps | none | jev | off | yes | done | 1 | 3 | 5 | 0.001759 | 10.2 | 0 | - | rep 1: result names '10 December 1815' |
| wiki-engine-designer | loose | none | jev | off | yes | done | 1 | 3 | 5 | 0.001725 | 15.5 | 0 | - | rep 1: result names 'Charles Babbage' |
| u8-books-travel-jsonl | goal | none | jev | off | no | done | 6 | 6 | 13 | 0.010572 | 136.3 | 0 | - | rep 1: 11 on the page, 11 in the file, 1 missing, 1 extra |
| wiki-engine-designer | goal | none | jev | off | yes | done | 1 | 3 | 5 | 0.001719 | 8.5 | 0 | - | rep 1: result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | jev | off | no | error | 0 | 0 | 2 | - | 12.1 | 0 | - | rep 1: result lacks 'Charles Babbage' |
| ae-blue-top-price | goal | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000687 | 17.6 | 0 | - | rep 1: truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | notes | jev | off | yes | done | 1 | 1 | 5 | 0.001078 | 19.7 | 0 | - | rep 1: truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | notes | jev | off | yes | done | 2 | 5 | 11 | 0.002627 | 33.3 | 0 | - | rep 1: result names 'Blue Top' |
| ae-polo-brand | goal | notes | jev | off | yes | done | 2 | 3 | 9 | 0.002134 | 30.9 | 0 | - | rep 1: result names 'Blue Top' |
| ae-polo-brand | steps | notes | jev | off | yes | done | 1 | 2 | 5 | 0.001151 | 18.3 | 0 | - | rep 1: result names 'Blue Top' |
| ae-search-jeans | loose | notes | jev | off | yes | done | 1 | 3 | 7 | 0.001012 | 23.1 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | jev | off | yes | done | 1 | 3 | 8 | 0.001165 | 24.6 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | notes | jev | off | yes | done | 1 | 3 | 9 | 0.00129 | 26.3 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | notes | jev | off | yes | done | 3 | 6 | 10 | 0.003296 | 36.3 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | notes | jev | off | yes | done | 2 | 6 | 10 | 0.002527 | 23.7 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| ae-blue-top-price | steps | notes | jev | off | no | error | 0 | 2 | 216 | - | 303.4 | 0 | - | rep 1: truth 'rs. 500'; result differs |
| books-mystery-page2 | steps | notes | jev | off | yes | done | 3 | 5 | 9 | 0.004901 | 68.5 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000809 | 8.7 | 0 | - | rep 1: truth '19'; result agrees |
| books-poetry-count | goal | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000808 | 8.3 | 0 | - | rep 1: truth '19'; result agrees |
| books-poetry-count | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000829 | 7.4 | 0 | - | rep 1: truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | jev | off | yes | done | 9 | 6 | 19 | 0.014865 | 203.8 | 0 | - | rep 1: 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-poetry-jsonl | goal | notes | jev | off | yes | done | 12 | 4 | 18 | 0.015494 | 212.8 | 0 | - | rep 1: 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-price | loose | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000586 | 4.1 | 0 | - | rep 1: result names '£51.77' |
| books-price | goal | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000598 | 4.5 | 0 | - | rep 1: result names '£51.77' |
| books-price | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000559 | 5.2 | 0 | - | rep 1: result names '£51.77' |
| books-stock | loose | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000596 | 5.3 | 0 | - | rep 1: truth '20'; result agrees |
| books-stock | goal | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000584 | 4.8 | 0 | - | rep 1: truth '20'; result agrees |
| books-stock | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000613 | 5.7 | 0 | - | rep 1: truth '20'; result agrees |
| books-poetry-jsonl | steps | notes | jev | off | no | done | 1 | 3 | 5 | 0.003575 | 44.4 | 0 | - | rep 1: 19 on the page, 19 in the file, 1 missing, 1 extra |
| canvas-launch | loose | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000747 | 9.6 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000767 | 9.3 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000761 | 8.5 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | notes | jev | off | no | done | 1 | 14 | 22 | 0.005401 | 39.6 | 0 | - | rep 1: truth 'pln 148'; result differs |
| flights-oneway | steps | notes | jev | off | no | done | 10 | 7 | 19 | 0.005507 | 101.8 | 0 | - | rep 1: truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | jev | off | yes | done | 1 | 3 | 11 | 0.001917 | 26.6 | 0 | - | rep 1: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | notes | jev | off | yes | done | 1 | 4 | 10 | 0.001972 | 22.6 | 0 | - | rep 1: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | jev | off | yes | done | 1 | 3 | 7 | 0.001447 | 15.7 | 0 | - | rep 1: Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | notes | jev | off | yes | done | 5 | 1 | 6 | 0.001175 | 18.5 | 0 | - | rep 1: message 'old' quoted |
| portal-welcome | goal | notes | jev | off | yes | done | 5 | 3 | 8 | 0.001257 | 22.8 | 0 | - | rep 1: message 'old' quoted |
| portal-welcome | steps | notes | jev | off | yes | done | 1 | 5 | 8 | 0.000697 | 17 | 0 | - | rep 1: message 'old' quoted |
| u10-portal-new-message | loose | notes | jev | off | yes | done | 5 | 3 | 8 | 0.001737 | 29.3 | 0 | - | rep 1: message 'new' quoted |
| flights-oneway | goal | notes | jev | off | no | error | 9 | 82 | 159 | - | 303.1 | 0 | - | rep 1: truth 'pln 148'; result differs |
| u10-portal-new-message | goal | notes | jev | off | no | done | 4 | 5 | 9 | 0.001353 | 24.1 | 0 | - | rep 1: message 'new' not quoted |
| u5-flights-roundtrip | loose | notes | jev | off | no | error | 0 | 3 | 7 | - | 32.1 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u5-flights-roundtrip | goal | notes | jev | off | no | done | 1 | 13 | 23 | 0.006901 | 36.7 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u10-portal-new-message | steps | notes | jev | off | yes | done | 5 | 6 | 13 | 0.00494 | 81 | 0 | - | rep 1: message 'new' quoted |
| u5-flights-roundtrip | steps | notes | jev | off | no | done | 1 | 13 | 21 | 0.006472 | 40.5 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u6-maps-cafe | loose | notes | jev | off | no | done | 8 | 19 | 47 | 0.010362 | 111.1 | 0 | - | rep 1: names on a fresh Maps search: []; ratings [4.7] |
| u6-maps-cafe | steps | notes | jev | off | no | done | 4 | 10 | 20 | 0.005148 | 49.5 | 0 | - | rep 1: names on a fresh Maps search: []; ratings [4.7] |
| u7-register | loose | notes | jev | off | no | error | 0 | 2 | 6 | - | 14.8 | 0 | - | rep 1: registrations 0, confirmed False |
| u6-maps-cafe | goal | notes | jev | off | yes | done | 9 | 83 | 144 | 0.031514 | 188.2 | 0 | - | rep 1: names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | steps | notes | jev | off | yes | done | 1 | 8 | 12 | 0.001002 | 12.4 | 0 | - | rep 1: registrations 1, confirmed True |
| u8-books-travel-jsonl | loose | notes | jev | off | yes | done | 1 | 3 | 5 | 0.004128 | 49.3 | 0 | - | rep 1: 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | goal | notes | jev | off | yes | done | 3 | 8 | 15 | 0.007691 | 113.9 | 0 | - | rep 1: 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | steps | notes | jev | off | yes | done | 1 | 3 | 5 | 0.002744 | 30.3 | 0 | - | rep 1: 11 on the page, 11 in the file, 0 missing, 0 extra |
| u9-upload | loose | notes | jev | off | yes | done | 1 | 3 | 4 | 0.000494 | 6.4 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| u9-upload | goal | notes | jev | off | yes | done | 1 | 3 | 4 | 0.000528 | 6.9 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| u9-upload | steps | notes | jev | off | yes | done | 1 | 3 | 4 | 0.000481 | 6.1 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| wiki-ada-born | loose | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001757 | 11.4 | 0 | - | rep 1: result names '10 December 1815' |
| wiki-ada-born | goal | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001761 | 13.8 | 0 | - | rep 1: result names '10 December 1815' |
| u7-register | goal | notes | jev | off | no | error:model-timeout | 27 | 16 | 46 | - | 300 | 0 | - | rep 1: registrations 1, confirmed False |
| wiki-ada-born | steps | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001786 | 14.7 | 0 | - | rep 1: result names '10 December 1815' |
| wiki-engine-designer | loose | notes | jev | off | no | error | 0 | 0 | 2 | - | 12.2 | 0 | - | rep 1: result lacks 'Charles Babbage' |
| wiki-engine-designer | goal | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001715 | 8.4 | 0 | - | rep 1: result names 'Charles Babbage' |
| wiki-engine-designer | steps | notes | jev | off | yes | done | 1 | 3 | 5 | 0.001694 | 8.4 | 0 | - | rep 1: result names 'Charles Babbage' |
| ae-blue-top-price | goal | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000667 | 17.3 | 0 | - | rep 1: truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | procedures | jev | off | yes | done | 1 | 1 | 4 | 0.000967 | 18.6 | 0 | - | rep 1: truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | procedures | jev | off | yes | done | 5 | 3 | 10 | 0.005098 | 66.7 | 0 | - | rep 1: result names 'Blue Top' |
| ae-polo-brand | goal | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.001113 | 22 | 0 | - | rep 1: result names 'Blue Top' |
| ae-blue-top-price | steps | procedures | jev | off | no | error | 0 | 2 | 218 | - | 302.2 | 0 | - | rep 1: truth 'rs. 500'; result differs |
| ae-search-jeans | loose | procedures | jev | off | yes | done | 1 | 3 | 7 | 0.001084 | 22.2 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | jev | off | yes | done | 1 | 3 | 9 | 0.001406 | 25.5 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | procedures | jev | off | yes | done | 1 | 3 | 7 | 0.001097 | 23 | 0 | - | rep 1: result names 'Soft Stretch Jeans' |
| ae-polo-brand | steps | procedures | jev | off | no | error | 0 | 0 | 215 | - | 303.2 | 0 | - | rep 1: result lacks 'Blue Top' |
| books-mystery-page2 | loose | procedures | jev | off | yes | done | 1 | 7 | 12 | 0.003545 | 45.8 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | procedures | jev | off | yes | done | 3 | 6 | 13 | 0.005242 | 53.2 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | procedures | jev | off | yes | done | 1 | 6 | 11 | 0.003531 | 30.2 | 0 | - | rep 1: result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000807 | 8.5 | 0 | - | rep 1: truth '19'; result agrees |
| books-poetry-count | goal | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000835 | 8.7 | 0 | - | rep 1: truth '19'; result agrees |
| books-poetry-count | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000838 | 8.6 | 0 | - | rep 1: truth '19'; result agrees |
| books-poetry-jsonl | loose | procedures | jev | off | no | done | 4 | 1 | 8 | 0.005989 | 80.4 | 0 | - | rep 1: 19 on the page, 38 in the file, 0 missing, 1 extra |
| books-poetry-jsonl | goal | procedures | jev | off | no | done | 3 | 1 | 8 | 0.008209 | 119.8 | 0 | - | rep 1: 19 on the page, 38 in the file, 0 missing, 3 extra |
| books-price | loose | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000599 | 4.5 | 0 | - | rep 1: result names '£51.77' |
| books-price | goal | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000624 | 5.8 | 0 | - | rep 1: result names '£51.77' |
| books-price | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000573 | 5.9 | 0 | - | rep 1: result names '£51.77' |
| books-stock | loose | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000607 | 5.2 | 0 | - | rep 1: truth '20'; result agrees |
| books-stock | goal | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000608 | 5.6 | 0 | - | rep 1: truth '20'; result agrees |
| books-stock | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000618 | 5.4 | 0 | - | rep 1: truth '20'; result agrees |
| canvas-launch | loose | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000722 | 9.5 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000724 | 8.9 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000749 | 12.4 | 0 | - | rep 1: 1 canvas click(s), 1 inside the drawn button |
| books-poetry-jsonl | steps | procedures | jev | off | no | done | 6 | 1 | 10 | 0.010814 | 149.1 | 0 | - | rep 1: 19 on the page, 38 in the file, 0 missing, 2 extra |
| flights-oneway | loose | procedures | jev | off | no | done | 1 | 15 | 25 | 0.005954 | 42.9 | 0 | - | rep 1: truth 'pln 148'; result differs |
| flights-oneway | steps | procedures | jev | off | no | error | 0 | 3 | 7 | - | 25.3 | 0 | - | rep 1: truth 'pln 148'; result differs |
| flights-oneway | goal | procedures | jev | off | no | done | 1 | 10 | 20 | 0.004183 | 47.8 | 0 | - | rep 1: truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | procedures | jev | off | yes | done | 1 | 3 | 13 | 0.001974 | 30.2 | 0 | - | rep 1: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | procedures | jev | off | yes | done | 1 | 3 | 9 | 0.0018 | 21.8 | 0 | - | rep 1: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | jev | off | yes | done | 1 | 4 | 11 | 0.002646 | 20 | 0 | - | rep 1: Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | procedures | jev | off | yes | done | 6 | 4 | 16 | - | 42.1 | 0 | - | rep 1: message 'old' quoted |
| portal-welcome | steps | procedures | jev | off | yes | done | 1 | 5 | 8 | 0.000673 | 10.7 | 0 | - | rep 1: message 'old' quoted |
| portal-welcome | goal | procedures | jev | off | yes | done | 7 | 9 | 27 | - | 62.9 | 0 | - | rep 1: message 'old' quoted |
| u10-portal-new-message | loose | procedures | jev | off | no | done | 4 | 24 | 34 | - | 64.3 | 0 | - | rep 1: message 'new' not quoted |
| u10-portal-new-message | goal | procedures | jev | off | yes | done | 5 | 2 | 10 | - | 36.2 | 0 | - | rep 1: message 'new' quoted |
| u5-flights-roundtrip | loose | procedures | jev | off | no | error | 2 | 15 | 41 | - | 105.5 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u10-portal-new-message | steps | procedures | jev | off | no | done | 13 | 16 | 32 | 0.013105 | 225.8 | 0 | - | rep 1: message 'new' not quoted |
| u5-flights-roundtrip | goal | procedures | jev | off | no | done | 1 | 12 | 21 | 0.004989 | 45.2 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u5-flights-roundtrip | steps | procedures | jev | off | no | done | 1 | 13 | 22 | 0.006075 | 50.8 | 0 | - | rep 1: truth 'pln 335'; result differs |
| u6-maps-cafe | loose | procedures | jev | off | no | done | 8 | 20 | 44 | 0.009689 | 98.2 | 0 | - | rep 1: names on a fresh Maps search: []; ratings [4.7] |
| u6-maps-cafe | goal | procedures | jev | off | yes | done | 12 | 62 | 120 | 0.027201 | 213.9 | 0 | - | rep 1: names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | procedures | jev | off | no | error | 0 | 1 | 4 | - | 13.2 | 0 | - | rep 1: registrations 0, confirmed False |
| u6-maps-cafe | steps | procedures | jev | off | yes | done | 13 | 11 | 34 | 0.012995 | 134.6 | 0 | - | rep 1: names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | goal | procedures | jev | off | yes | done | 1 | 8 | 13 | 0.001092 | 14.1 | 0 | - | rep 1: registrations 1, confirmed True |
| u7-register | steps | procedures | jev | off | yes | done | 1 | 8 | 12 | 0.00098 | 11.5 | 0 | - | rep 1: registrations 1, confirmed True |
| u8-books-travel-jsonl | loose | procedures | jev | off | no | done | 7 | 3 | 13 | 0.010681 | 134 | 0 | - | rep 1: 11 on the page, 22 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | steps | procedures | jev | off | no | done | 2 | 1 | 6 | 0.004052 | 43.3 | 0 | - | rep 1: 11 on the page, 22 in the file, 0 missing, 2 extra |
| u9-upload | loose | procedures | jev | off | yes | done | 1 | 3 | 4 | 0.000557 | 6.8 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| u9-upload | goal | procedures | jev | off | yes | done | 1 | 3 | 4 | 0.000462 | 6.4 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| u9-upload | steps | procedures | jev | off | yes | done | 1 | 3 | 4 | 0.000481 | 4.8 | 0 | - | rep 1: 1 upload(s); link /files/1 in the result |
| wiki-ada-born | loose | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001812 | 15.2 | 0 | - | rep 1: result names '10 December 1815' |
| wiki-ada-born | goal | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001784 | 18.3 | 0 | - | rep 1: result names '10 December 1815' |
| wiki-ada-born | steps | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001804 | 11.1 | 0 | - | rep 1: result names '10 December 1815' |
| wiki-engine-designer | loose | procedures | jev | off | yes | done | 1 | 4 | 7 | 0.002172 | 15.2 | 0 | - | rep 1: result names 'Charles Babbage' |
| wiki-engine-designer | goal | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001685 | 8.5 | 0 | - | rep 1: result names 'Charles Babbage' |
| wiki-engine-designer | steps | procedures | jev | off | yes | done | 1 | 3 | 5 | 0.001714 | 8.3 | 0 | - | rep 1: result names 'Charles Babbage' |
| u8-books-travel-jsonl | goal | procedures | jev | off | no | done | 15 | 4 | 25 | 0.022637 | 288.8 | 0 | - | rep 1: 11 on the page, 34 in the file, 0 missing, 2 extra |
| ae-blue-top-price | goal | none | jev | off | yes | done | 1 | 1 | 2 | 0.000615 | 14.3 | 0 | - | rep 2: truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | none | jev | off | yes | done | 1 | 1 | 2 | 0.000587 | 13.6 | 0 | - | rep 2: truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | none | jev | off | yes | done | 1 | 5 | 24 | 0.003836 | 39.1 | 0 | - | rep 2: truth 'rs. 500'; result agrees |
| ae-polo-brand | goal | none | jev | off | yes | done | 2 | 1 | 3 | 0.001187 | 24.2 | 0 | - | rep 2: result names 'Blue Top' |
| ae-polo-brand | steps | none | jev | off | yes | done | 2 | 3 | 7 | 0.002366 | 34.8 | 0 | - | rep 2: result names 'Blue Top' |
| ae-search-jeans | loose | none | jev | off | no | error | 0 | 0 | 2 | - | 17.5 | 0 | - | rep 2: result lacks 'Soft Stretch Jeans' |
| ae-search-jeans | goal | none | jev | off | yes | done | 1 | 3 | 6 | 0.000876 | 14.9 | 0 | - | rep 2: result names 'Soft Stretch Jeans' |
| ae-search-jeans | steps | none | jev | off | yes | done | 1 | 3 | 8 | 0.001154 | 18 | 0 | - | rep 2: result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | none | jev | off | yes | done | 2 | 6 | 10 | 0.002789 | 22.1 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | none | jev | off | yes | done | 4 | 3 | 8 | 0.003181 | 24.3 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | none | jev | off | yes | done | 3 | 3 | 7 | 0.002297 | 18.8 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | none | jev | off | yes | done | 1 | 2 | 3 | 0.000789 | 5.3 | 0 | - | rep 2: truth '19'; result agrees |
| books-poetry-count | goal | none | jev | off | yes | done | 1 | 2 | 3 | 0.000786 | 4.9 | 0 | - | rep 2: truth '19'; result agrees |
| books-poetry-count | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000782 | 5 | 0 | - | rep 2: truth '19'; result agrees |
| ae-polo-brand | loose | none | jev | off | no | deadline | 14 | 1 | 18 | 0.022018 | 302.9 | 0 | - | rep 2: result lacks 'Blue Top' |
| books-poetry-jsonl | loose | none | jev | off | no | done | 8 | 6 | 17 | 0.01433 | 172.8 | 0 | - | rep 2: 19 on the page, 19 in the file, 2 missing, 2 extra |
| books-poetry-jsonl | steps | none | jev | off | no | done | 2 | 4 | 8 | 0.004064 | 43.4 | 0 | - | rep 2: 19 on the page, 19 in the file, 1 missing, 1 extra |
| books-poetry-jsonl | goal | none | jev | off | no | done | 9 | 6 | 21 | 0.012538 | 155.9 | 0 | - | rep 2: 19 on the page, 19 in the file, 1 missing, 1 extra |
| books-price | loose | none | jev | off | yes | done | 1 | 1 | 2 | 0.000587 | 4.7 | 0 | - | rep 2: result names '£51.77' |
| books-price | goal | none | jev | off | yes | done | 1 | 1 | 2 | 0.000583 | 4 | 0 | - | rep 2: result names '£51.77' |
| books-price | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000548 | 5.1 | 0 | - | rep 2: result names '£51.77' |
| books-stock | loose | none | jev | off | yes | done | 1 | 2 | 3 | 0.000566 | 5.6 | 0 | - | rep 2: truth '20'; result agrees |
| books-stock | goal | none | jev | off | yes | done | 1 | 2 | 3 | 0.000581 | 5.5 | 0 | - | rep 2: truth '20'; result agrees |
| books-stock | steps | none | jev | off | yes | done | 1 | 2 | 3 | 0.000581 | 4.9 | 0 | - | rep 2: truth '20'; result agrees |
| canvas-launch | loose | none | jev | off | yes | done | 2 | 1 | 3 | 0.000709 | 7.9 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | none | jev | off | yes | done | 2 | 1 | 3 | 0.000707 | 8 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | none | jev | off | yes | done | 2 | 1 | 3 | 0.000727 | 8.2 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | none | jev | off | no | done | 1 | 14 | 21 | 0.004865 | 37.8 | 0 | - | rep 2: truth 'pln 148'; result differs |
| flights-oneway | goal | none | jev | off | no | done | 1 | 11 | 21 | 0.005172 | 32.6 | 0 | - | rep 2: truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | none | jev | off | yes | done | 1 | 5 | 14 | 0.002626 | 19.6 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | none | jev | off | yes | done | 1 | 4 | 13 | 0.002497 | 20.5 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | none | jev | off | yes | done | 1 | 4 | 11 | 0.002243 | 18.2 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | none | jev | off | yes | done | 5 | 1 | 6 | 0.001005 | 17.9 | 0 | - | rep 2: message 'old' quoted |
| flights-oneway | steps | none | jev | off | no | done | 10 | 7 | 20 | 0.005429 | 92.9 | 0 | - | rep 2: truth 'pln 148'; result differs |
| portal-welcome | steps | none | jev | off | yes | done | 1 | 5 | 8 | 0.000652 | 9.6 | 0 | - | rep 2: message 'old' quoted |
| portal-welcome | goal | none | jev | off | yes | done | 6 | 12 | 19 | 0.0023 | 30 | 0 | - | rep 2: message 'old' quoted |
| u10-portal-new-message | loose | none | jev | off | yes | done | 5 | 3 | 8 | 0.001126 | 18.1 | 0 | - | rep 2: message 'new' quoted |
| u10-portal-new-message | steps | none | jev | off | no | failed | 3 | 8 | 13 | 0.005716 | 85.7 | 0 | - | rep 2: message 'new' not quoted |
| u5-flights-roundtrip | loose | none | jev | off | no | done | 1 | 11 | 17 | 0.004553 | 28.8 | 0 | - | rep 2: truth 'pln 335'; result differs |
| u5-flights-roundtrip | goal | none | jev | off | no | done | 1 | 11 | 18 | 0.00501 | 31.7 | 0 | - | rep 2: truth 'pln 335'; result differs |
| u5-flights-roundtrip | steps | none | jev | off | no | done | 1 | 11 | 18 | 0.005614 | 30.4 | 0 | - | rep 2: truth 'pln 335'; result differs |
| u10-portal-new-message | goal | none | jev | off | yes | done | 7 | 265 | 274 | 0.023664 | 196.6 | 0 | - | rep 2: message 'new' quoted |
| u6-maps-cafe | loose | none | jev | off | no | error | 0 | 0 | 3 | - | 17.6 | 0 | - | rep 2: names on a fresh Maps search: []; ratings [] |
| u6-maps-cafe | goal | none | jev | off | yes | done | 6 | 24 | 56 | 0.014706 | 99.3 | 0 | - | rep 2: names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u6-maps-cafe | steps | none | jev | off | yes | done | 8 | 13 | 29 | 0.008514 | 85 | 0 | - | rep 2: names on a fresh Maps search: ['Sunflower Café']; ratings [4.7] |
| u7-register | loose | none | jev | off | yes | done | 0 | 8 | 11 | 0.000774 | 9 | 0 | - | rep 2: registrations 1, confirmed True |
| u7-register | goal | none | jev | off | yes | done | 1 | 8 | 12 | 0.000931 | 12.2 | 0 | - | rep 2: registrations 1, confirmed True |
| u7-register | steps | none | jev | off | yes | done | 1 | 8 | 12 | 0.000968 | 12.8 | 0 | - | rep 2: registrations 1, confirmed True |
| u8-books-travel-jsonl | loose | none | jev | off | yes | done | 3 | 3 | 7 | 0.003954 | 39.6 | 0 | - | rep 2: 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | steps | none | jev | off | yes | done | 1 | 3 | 5 | 0.003178 | 35.1 | 0 | - | rep 2: 11 on the page, 11 in the file, 0 missing, 0 extra |
| u8-books-travel-jsonl | goal | none | jev | off | no | done | 3 | 14 | 23 | 0.008735 | 70.5 | 0 | - | rep 2: 11 on the page, 11 in the file, 1 missing, 1 extra |
| u9-upload | loose | none | jev | off | yes | done | 1 | 3 | 4 | 0.000461 | 5.5 | 0 | - | rep 2: 1 upload(s); link /files/1 in the result |
| u9-upload | goal | none | jev | off | yes | done | 1 | 3 | 4 | 0.000471 | 5.8 | 0 | - | rep 2: 1 upload(s); link /files/1 in the result |
| u9-upload | steps | none | jev | off | yes | done | 1 | 3 | 4 | 0.000462 | 5.4 | 0 | - | rep 2: 1 upload(s); link /files/1 in the result |
| wiki-ada-born | loose | none | jev | off | yes | done | 1 | 3 | 5 | 0.001769 | 12.8 | 0 | - | rep 2: result names '10 December 1815' |
| wiki-ada-born | goal | none | jev | off | yes | done | 1 | 3 | 5 | 0.0019 | 11.3 | 0 | - | rep 2: result names '10 December 1815' |
| wiki-engine-designer | loose | none | jev | off | yes | done | 1 | 3 | 5 | 0.001728 | 9.9 | 0 | - | rep 2: result names 'Charles Babbage' |
| wiki-ada-born | steps | none | jev | off | yes | done | 1 | 3 | 5 | 0.001751 | 11.9 | 0 | - | rep 2: result names '10 December 1815' |
| wiki-engine-designer | goal | none | jev | off | yes | done | 1 | 3 | 5 | 0.00172 | 8.9 | 0 | - | rep 2: result names 'Charles Babbage' |
| wiki-engine-designer | steps | none | jev | off | yes | done | 1 | 3 | 5 | 0.001746 | 8.8 | 0 | - | rep 2: result names 'Charles Babbage' |
| ae-blue-top-price | goal | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000673 | 14 | 0 | - | rep 2: truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000622 | 13.4 | 0 | - | rep 2: truth 'rs. 500'; result agrees |
| ae-blue-top-price | steps | notes | jev | off | no | deadline | 0 | 2 | 383 | 0.055995 | 302.8 | 0 | - | rep 2: truth 'rs. 500'; result differs |
| ae-polo-brand | loose | notes | jev | off | no | error | 5 | 1 | 345 | - | 303.1 | 0 | - | rep 2: result lacks 'Blue Top' |
| ae-polo-brand | goal | notes | jev | off | yes | done | 4 | 1 | 6 | 0.00276 | 39.5 | 0 | - | rep 2: result names 'Blue Top' |
| ae-polo-brand | steps | notes | jev | off | yes | done | 4 | 1 | 5 | 0.002668 | 40.4 | 0 | - | rep 2: result names 'Blue Top' |
| ae-search-jeans | loose | notes | jev | off | yes | done | 1 | 3 | 6 | 0.000892 | 14.9 | 0 | - | rep 2: result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | notes | jev | off | yes | done | 1 | 3 | 6 | 0.000901 | 15.4 | 0 | - | rep 2: result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | notes | jev | off | yes | done | 3 | 6 | 11 | 0.003477 | 24.8 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | notes | jev | off | yes | done | 3 | 5 | 9 | 0.003078 | 24.7 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | steps | notes | jev | off | yes | done | 2 | 6 | 10 | 0.002605 | 15.7 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000815 | 5.6 | 0 | - | rep 2: truth '19'; result agrees |
| books-poetry-count | goal | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000818 | 5.2 | 0 | - | rep 2: truth '19'; result agrees |
| books-poetry-count | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000848 | 4.8 | 0 | - | rep 2: truth '19'; result agrees |
| books-poetry-jsonl | loose | notes | jev | off | yes | done | 6 | 6 | 17 | 0.012211 | 142.5 | 0 | - | rep 2: 19 on the page, 19 in the file, 0 missing, 0 extra |
| books-poetry-jsonl | goal | notes | jev | off | yes | done | 2 | 4 | 8 | 0.004237 | 44.5 | 0 | - | rep 2: 19 on the page, 19 in the file, 0 missing, 0 extra |
| ae-search-jeans | steps | notes | jev | off | no | error | 7 | 22 | 294 | - | 302.9 | 0 | - | rep 2: result lacks 'Soft Stretch Jeans' |
| books-price | loose | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000605 | 4.7 | 0 | - | rep 2: result names '£51.77' |
| books-price | goal | notes | jev | off | yes | done | 1 | 1 | 2 | 0.000613 | 4.2 | 0 | - | rep 2: result names '£51.77' |
| books-price | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.00055 | 5 | 0 | - | rep 2: result names '£51.77' |
| books-stock | loose | notes | jev | off | yes | done | 1 | 2 | 3 | 0.00066 | 6.6 | 0 | - | rep 2: truth '20'; result agrees |
| books-stock | goal | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000589 | 4.8 | 0 | - | rep 2: truth '20'; result agrees |
| books-stock | steps | notes | jev | off | yes | done | 1 | 2 | 3 | 0.000609 | 5.2 | 0 | - | rep 2: truth '20'; result agrees |
| books-poetry-jsonl | steps | notes | jev | off | no | done | 3 | 3 | 7 | 0.00595 | 66.7 | 0 | - | rep 2: 19 on the page, 19 in the file, 1 missing, 1 extra |
| canvas-launch | loose | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000767 | 9.8 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000772 | 8.4 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | notes | jev | off | yes | done | 2 | 1 | 3 | 0.000759 | 9.9 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | notes | jev | off | no | error | 0 | 7 | 11 | - | 25.7 | 0 | - | rep 2: truth 'pln 148'; result differs |
| flights-oneway | goal | notes | jev | off | no | done | 1 | 14 | 24 | 0.005865 | 32.1 | 0 | - | rep 2: truth 'pln 148'; result differs |
| flights-oneway | steps | notes | jev | off | no | error | 0 | 3 | 6 | - | 21.3 | 0 | - | rep 2: truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | notes | jev | off | yes | done | 1 | 5 | 14 | 0.002879 | 19.7 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | notes | jev | off | yes | done | 1 | 3 | 8 | 0.001574 | 15.2 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | notes | jev | off | yes | done | 1 | 3 | 8 | 0.00178 | 17.6 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | notes | jev | off | yes | done | 6 | 2 | 9 | 0.001646 | 25.6 | 0 | - | rep 2: message 'old' quoted |
| portal-welcome | goal | notes | jev | off | yes | done | 5 | 9 | 15 | 0.001924 | 23.1 | 0 | - | rep 2: message 'old' quoted |
| ae-blue-top-price | goal | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000678 | 12.8 | 0 | - | rep 2: truth 'rs. 500'; result agrees |
| ae-blue-top-price | loose | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000656 | 13.4 | 0 | - | rep 2: truth 'rs. 500'; result agrees |
| ae-polo-brand | loose | procedures | jev | off | yes | done | 9 | 6 | 30 | 0.00955 | 99.2 | 0 | - | rep 2: result names 'Blue Top' |
| ae-blue-top-price | steps | procedures | jev | off | no | deadline | 1 | 6 | 382 | - | 302.4 | 0 | - | rep 2: truth 'rs. 500'; result differs |
| ae-polo-brand | steps | procedures | jev | off | yes | done | 4 | 1 | 7 | 0.003494 | 51.2 | 0 | - | rep 2: result names 'Blue Top' |
| ae-search-jeans | loose | procedures | jev | off | yes | done | 1 | 3 | 6 | 0.000954 | 14.8 | 0 | - | rep 2: result names 'Soft Stretch Jeans' |
| ae-polo-brand | goal | procedures | jev | off | no | error | 1 | 3 | 407 | - | 302.5 | 0 | - | rep 2: result lacks 'Blue Top' |
| ae-search-jeans | steps | procedures | jev | off | yes | done | 1 | 3 | 9 | 0.001454 | 23.1 | 0 | - | rep 2: result names 'Soft Stretch Jeans' |
| ae-search-jeans | goal | procedures | jev | off | yes | done | 5 | 10 | 31 | 0.005719 | 70.2 | 0 | - | rep 2: result names 'Soft Stretch Jeans' |
| books-mystery-page2 | loose | procedures | jev | off | yes | done | 1 | 8 | 13 | 0.00378 | 37.2 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-mystery-page2 | goal | procedures | jev | off | yes | done | 1 | 6 | 11 | 0.003325 | 25.5 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-poetry-count | loose | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000819 | 8 | 0 | - | rep 2: truth '19'; result agrees |
| books-poetry-count | goal | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.00083 | 5.6 | 0 | - | rep 2: truth '19'; result agrees |
| books-poetry-count | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000837 | 6.2 | 0 | - | rep 2: truth '19'; result agrees |
| books-mystery-page2 | steps | procedures | jev | off | yes | done | 3 | 7 | 12 | 0.005473 | 53.8 | 0 | - | rep 2: result names 'The Mysterious Affair at Styles' |
| books-poetry-jsonl | goal | procedures | jev | off | no | done | 2 | 1 | 6 | 0.004421 | 53.4 | 0 | - | rep 2: 19 on the page, 38 in the file, 0 missing, 3 extra |
| books-poetry-jsonl | steps | procedures | jev | off | no | done | 4 | 1 | 8 | 0.005433 | 61.8 | 0 | - | rep 2: 19 on the page, 38 in the file, 0 missing, 3 extra |
| books-poetry-jsonl | loose | procedures | jev | off | no | done | 8 | 4 | 16 | 0.011891 | 146.3 | 0 | - | rep 2: 19 on the page, 38 in the file, 0 missing, 2 extra |
| books-price | loose | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000642 | 5 | 0 | - | rep 2: result names '£51.77' |
| books-price | goal | procedures | jev | off | yes | done | 1 | 1 | 2 | 0.000629 | 5.1 | 0 | - | rep 2: result names '£51.77' |
| books-price | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000559 | 4.9 | 0 | - | rep 2: result names '£51.77' |
| books-stock | loose | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000624 | 5.4 | 0 | - | rep 2: truth '20'; result agrees |
| books-stock | goal | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000613 | 5.2 | 0 | - | rep 2: truth '20'; result agrees |
| books-stock | steps | procedures | jev | off | yes | done | 1 | 2 | 3 | 0.000615 | 4.9 | 0 | - | rep 2: truth '20'; result agrees |
| canvas-launch | loose | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000798 | 10.3 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | goal | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000755 | 9.8 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| canvas-launch | steps | procedures | jev | off | yes | done | 2 | 1 | 3 | 0.000798 | 10.9 | 0 | - | rep 2: 1 canvas click(s), 1 inside the drawn button |
| flights-oneway | loose | procedures | jev | off | no | done | 1 | 17 | 29 | 0.00731 | 38.1 | 0 | - | rep 2: truth 'pln 148'; result differs |
| flights-oneway | goal | procedures | jev | off | no | done | 4 | 24 | 42 | 0.005695 | 92.3 | 0 | - | rep 2: truth 'pln 148'; result differs |
| maps-eiffel-postcode | loose | procedures | jev | off | yes | done | 1 | 3 | 6 | 0.001349 | 15.5 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | goal | procedures | jev | off | yes | done | 1 | 3 | 6 | 0.001295 | 16.3 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| maps-eiffel-postcode | steps | procedures | jev | off | yes | done | 1 | 3 | 9 | 0.001943 | 19.2 | 0 | - | rep 2: Wikidata P281 ['75007']; result agrees |
| portal-welcome | loose | procedures | jev | off | yes | done | 4 | 5 | 14 | - | 30.5 | 0 | - | rep 2: message 'old' quoted |
| portal-welcome | goal | procedures | jev | off | yes | done | 6 | 5 | 17 | 0.002056 | 45.2 | 0 | - | rep 2: message 'old' quoted |
| portal-welcome | steps | procedures | jev | off | yes | done | 6 | 0 | 9 | - | 32.7 | 0 | - | rep 2: message 'old' quoted |
| u10-portal-new-message | loose | procedures | jev | off | no | done | 6 | 19 | 37 | 0.004577 | 62.3 | 0 | - | rep 2: message 'new' not quoted |
| flights-oneway | steps | procedures | jev | off | no | error | 9 | 233 | 249 | - | 302.9 | 0 | - | rep 2: truth 'pln 148'; result differs |
| u10-portal-new-message | goal | procedures | jev | off | yes | done | 6 | 6 | 18 | 0.002861 | 43.1 | 0 | - | rep 2: message 'new' quoted |
