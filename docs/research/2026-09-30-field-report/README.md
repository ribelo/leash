# Field report, 2026-09-30: registering API keys through Leash

An agent used the installed Leash (`094deda`) for real work: registering accounts on DVIDS, Europeana, api.data.gov and DPLA, confirming them from Gmail, and testing the keys. It completed four of six. This note records its findings as the L48 spec summarised them (the agent's own transcript was not kept in this repository), each mapped to the story that answers it.

| # | Finding | Where | Cause | Stories |
| --- | --- | --- | --- | --- |
| 1 | Password fields absent from `snap`; the agent fell back to `eval` with a native value setter | Europeana, DVIDS | L45 applied the operator's rule (fly-eoqg) to the agent's table | field-8bzc, field-sazr (landed in L46), field-5sdo |
| 2 | After the first load every CDP call on the tab (`eval`, `nav`, `shot`) ran to its 30 s deadline while `snap`/`text` answered | Pixabay (Cloudflare Turnstile), blank Google sign-in popup | a stuck renderer surfaced as plain per-call timeouts, no diagnosis | field-cde7, field-zr9n |
| 3 | `new` timed out yet created the tab, which then answered `unknown-tab` until `list` re-registered it | Pixabay | registration not atomic with the reply | field-m5jw |
| 4 | A popup opened blank and stayed unexplained | Google sign-in | empty-URL popups had no state | field-drpx |
| 5 | `click` refused custom checkboxes: "covered at its click point" | Europeana | the covering element is the target's own `<label>` | field-uls3, field-guda |
| 6 | `snap` returned 0 rows with `settled:true`; rows appeared seconds later, or never (Gmail's AX tree) | Gmail, pro.europeana.eu, the popup | settled meant "stable", not "populated" | field-lp65, field-jkx6 |
| 7 | `nav` returned `timeout` on pages that had loaded; a filled value missing from the next snapshot | Gmail, Pixabay; Europeana forms | load timeout lost what did happen; controlled inputs not re-read | field-m5jw, field-cct4 |
| 8 | A reCAPTCHA iframe was invisible, so the agent could not tell why nothing worked; long forms cost a `snap` per step; a usage error did not say which argument was missing | Flickr; every form; an empty shell variable | cross-origin frames not in the table; no snapshot on action replies; usage text | field-vji1, field-swvb, field-uqvp |

What worked, per the report: `new`/`list`, `fill` with Polish letters, `eval --argument` for secrets, `net body`, `debug` naming Turnstile, popup reporting, screenshots, reading confirmation links from Gmail. The installed skill was stale at the time; L44 closed that.

The regression page for these cases is the locally served registration form in the L48 live gate (field-i4x0).
