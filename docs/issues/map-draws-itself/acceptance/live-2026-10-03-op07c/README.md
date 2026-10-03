# L53 / map-op07 — op07c live acceptance

**Acceptance fails on Books, Flights, and Maps. L53 remains open.** Books and Flights completed five distinct missions with no retries. No site installed a playbook. Maps mission 5 was infrastructure-killed, not judged, and not rerun.

Baseline master 1690f49, unchanged binary SHA-256 10afe16378511bcb42e92402b8a54dde7bac7aaf98c109a63b13f8f7989366b0. No rebuild, product edit, commit, delegation, real-service modification, or everyday Chrome use. [Identity](<recovery-identity.json>). Canonical [summary](<summary.json>) and [audit](<audit.json>) distinguish harness/isolation checks from map-op07 acceptance; raw result passed flags do not mean acceptance passed.

## Protocol and exclusions

Books and Flights ran concurrently in separate private headless services with empty Chrome profiles and all-temporary XDG roots. Credentials entered only through secret-env ai --. Missions 1–4 used learning auto; each waited at most 900 seconds for pending learning to reach zero. All waits finished. Mission 5 used a fresh service/profile with learning off. Only installed playbooks could be copied; all transfer manifests were empty, with zero copied traces, learning state, drafts, or cookies. Next month was November 2026.

Earlier infrastructure-killed [Books](<books-killed/>) and [Flights](<flights-killed/>) campaigns remain intact and excluded from judged campaigns. Maps fifth [verification](<maps/fresh/mission-5/verification.json>) records SIGTERM 15 and no drive reply: killed/not judged, unknown cost, not a harness bug, no rerun. Maps fails independently because nothing was installed.

## Mission results and USD cost curves

Browser and learning columns show model calls / USD, not DOM operations. Inclusive cost is browser plus asynchronous learning. Values are rounded here; exact provider-reported floats, per-kind calls, statuses, answers, verification, and artifacts are in [summary](<summary.json>). Unpriced or killed usage is unknown/null, never zero. Learning meters record last model-bearing work, not cumulative work; changed meter/account timestamps assign work once to the mission whose wait observed it.

### Books

| Mission / argument | Status | Verified | Answer | Browser calls / USD | Learning calls / USD | Inclusive USD | Installed |
|---|---|---|---|---|---|---|---|
| 1: Travel | done | false | none | 4 / 0.000937188 | 0 / 0.000000000 | 0.000937188 | 0 |
| 2: Mystery | limit | false | none | 62 / 0.014604618 | 0 / 0.000000000 | 0.014604618 | 0 |
| 3: Poetry | done | false | none | 7 / 0.001358952 | 4 / 0.030678900 | 0.032037852 | 0 |
| 4: Historical Fiction | done | false | none | 13 / 0.002921730 | 2 / 0.013367475 | 0.016289205 | 0 |
| 5: Horror | done | false | none | 12 / 0.002837450 | 0 / 0.000000000 | 0.002837450 | 0 |

Criterion **FAIL**: installed False; fresh service/profile True; fifth independently verified False; cheaper inclusive fifth False; learning off True; no fifth learning calls True.

### Flights

| Mission / argument | Status | Verified | Answer | Browser calls / USD | Learning calls / USD | Inclusive USD | Installed |
|---|---|---|---|---|---|---|---|
| 1: Warsaw → Lisbon | done | false | none | 20 / 0.005410836 | 0 / 0.000000000 | 0.005410836 | 0 |
| 2: Kraków → Barcelona | done | false | none | 16 / 0.004447282 | 2 / 0.032179575 | 0.036626857 | 0 |
| 3: Gdańsk → Rome | done | false | none | 45 / 0.015366600 | 2 / 0.033920170 | 0.049286770 | 0 |
| 4: Wrocław → Paris | done | false | none | 30 / 0.009802438 | 0 / 0.000000000 | 0.009802438 | 0 |
| 5: Poznań → Amsterdam | done | false | none | 42 / 0.013961108 | 0 / 0.000000000 | 0.013961108 | 0 |

Criterion **FAIL**: installed False; fresh service/profile True; fifth independently verified False; cheaper inclusive fifth False; learning off True; no fifth learning calls True.

### Maps

| Mission / argument | Status | Verified | Answer | Browser calls / USD | Learning calls / USD | Inclusive USD | Installed |
|---|---|---|---|---|---|---|---|
| 1: Eiffel Tower | limit | false | none | 116 / unknown | 0 / 0.000000000 | unknown | 0 |
| 2: Colosseum | done | false | Caffè Antica Roma — Via Marco Aurelio, 28 | 21 / 0.004445197 | 0 / 0.000000000 | 0.004445197 | 0 |
| 3: Brandenburg Gate | limit | false | none | 117 / 0.028472246 | 0 / 0.000000000 | 0.028472246 | 0 |
| 4: Sagrada Família | blocked | false | none | 175 / 0.034932099 | 0 / 0.000000000 | 0.034932099 | 0 |
| 5: Tower of London | killed-infrastructure | not judged | none | unknown / unknown | unknown / unknown | unknown | 0 |

Criterion **FAIL**: installed False; fresh service/profile True; fifth independently verified False; cheaper inclusive fifth False; learning off True; no fifth learning calls None.

Maps mission 1 has one unpriced browser call. Reported priced usage was $0.023903548, but complete browser/inclusive cost remains unknown. The fifth has no drive reply and unknown usage; neither supports a cheaper-run claim.

## Independent output review

**Books:** all five delivered zero script-records and no terminal answer. Independent category HTML was read through private Leash and compared with delivered title/price pairs, not diagnostic snapshots. Mission 2 exhausted its action budget; the four done statuses did not constitute collection. The fifth Horror category had valid reference records but no delivered collection. All verdicts are false.

**Flights:** all five returned done, without a terminal answer or script-record itinerary. Real selected-date fares and November dates were reached. The [fifth screenshot](<flights/fresh/mission-5/page.png>) and [verification](<flights/fresh/mission-5/verification.json>) show Poznań → Amsterdam, November 1–4, 2026, and selected-date cheapest PLN 751. This does not prove the cheapest flight across the requested month and did not deliver an answer. Per-mission independent reviews retain that distinction. All verdicts are false.

**Maps:** the sole terminal answer was “Caffè Antica Roma — Via Marco Aurelio, 28” in mission 2. Its [independent verifier](<maps/mission-2/verification.json>) could not corroborate cafe name/address/category, landmark navigation, or coordinate proximity. Missions 1/3 reached limits, 4 was blocked, and 5 is killed/not judged.

Tagged operator-state output exposes diagnostic DOM, including titles/prices/fares. It is not a delivered answer or validated script-record collection. The consolidator excludes it from delivery verification.

## Compilation, installation, repair, and format stories

Books retained one draft after mission 4: two human-language goal steps, category argument, and two expectations. Its provenance records two model calls, $0.013367475, replay gate, repeatable true, repair false, tries 0. No extraction/pagination script exists. No later auto-learning mission could replay it before the fresh off-mode fifth. No site installed or repaired a playbook.

Books [service events](<books/service-events.jsonl>) retain structural-outline warnings (missing, invalid or empty skeleton), invalid scripts-object rejection, and rejection of collection scripts without observed structural outline. Flights [service events](<flights/service-events.jsonl>) show two compile drops: compiled scripts require a repeatable collection procedure. No Flights/Maps draft or script survived. Rejected model payloads were not persisted; logs are not fabricated compiled scripts.

| Story | Live evidence | Verdict |
|---|---|---|
| map-fm01 | Books draft uses goal/args/expect with no removed fields; no old-file rejection or installation tested. | Partial draft evidence; end-to-end unproven |
| map-fm02 | No inline draft provenance; full metadata is a separate sidecar. | Separation observed; installed behavior unexercised |
| map-fm03 | Compiler drops and final replay-gated draft retained; no successful installation correction. | End-to-end unproven |
| map-fm04 | Collection/out intent existed; outline/script validation failed; final Books draft has no script; Flights scripts rejected. | Script-first collection not achieved |

Complete final proposal and sidecar follow. [Audit](<audit.json>) preserves exact text, unique draft versions, installed-file maps, and repair/retirement lists. All installed/script maps and repair lists are empty.

### [Full open-books-category.provenance.json](<books/final/artifacts/state/leash/proposed/open-books-category.provenance.json>)

~~~json
{
  "traces": [
    "<PRIVATE_ROOT>/state/leash/traces/toscrape.com/2026-10-03T13:46:15.658484Z-done.json",
    "<PRIVATE_ROOT>/state/leash/traces/toscrape.com/2026-10-03T13:47:20.896986Z-done.json"
  ],
  "model": "openai/gpt-6-luna",
  "time": "2026-10-03T14:01:17.860524Z",
  "tries": 0,
  "path": [ "home", "books-category" ],
  "entry_kind": "home",
  "exit_kind": "books-<slug>",
  "signature": [ [ "click", { "role": "link", "label": "travel" } ] ],
  "kind_mapping": [ [ "books-<slug>", "books-category" ] ],
  "repeatable": true,
  "reason": "no irreversible submission in the observed path",
  "gate": "replay",
  "repair": false,
  "model_calls": 2,
  "model_cost": 0.013367475
}
~~~

### [Full toscrape.com-open-books-category.json](<books/final/artifacts/state/leash/proposed/toscrape.com-open-books-category.json>)

~~~json
{
  "site": "toscrape.com",
  "entry": "https://books.toscrape.com/",
  "description": "Learned toscrape.com",
  "pages": [
    {
      "name": "books-category",
      "url_pattern": "https://books.toscrape.com/catalogue/category/books/*/index.html"
    },
    { "name": "home", "url_pattern": "https://books.toscrape.com/" }
  ],
  "procedures": [
    {
      "slug": "open-books-category",
      "description": "Open the requested books category and collect every book title and price.",
      "args": { "category": { "from": "mission" } },
      "steps": [
        { "goal": "Click the link named {category}" },
        {
          "goal": "Collect every book title and price in the {category} category"
        }
      ],
      "expect": [
        "the page is books-category",
        "every book title and price in the requested category is collected"
      ]
    }
  ]
}
~~~

## Harness recovery disclosure

Exact launched fallback: [harness-launched](<harness-launched.py>); corrected reproduction: [harness-recovery](<harness-recovery.py>). The launched observer referenced a parsed value before initialization when a sidecar was first. [Observer guard](<observer-guard.py>) wrote ignored empty metadata outside private playbooks, initializing the observer without changing product configuration/playbooks. Raw sidecar observer values are not trusted; complete sidecars are rederived from exact artifacts. [Guard record](<observer-guard.json>) retains rationale and owned process identities without private paths.

The corrected source continues distinct remaining missions after a bounded learning-wait timeout instead of prematurely omitting them. This branch was not exercised: both live campaigns completed every pending wait. No mission retry or silent dependent-state reset occurred.

## Security and cleanup

Final [exact-key and capability/path scan](<security-scan.json>) runs through secret-env and emits counts only: exact key matches 0; handle matches 0; private/other temporary path matches 0. [Process audit](<process-audit.json>) confirms no op07c binary or private-profile browser survives. Private campaign services exited 0 and closed loopback servers. The real user service remains active/running with unchanged MainPID 3662.

Evidence-only [audit builder](<audit-builder.py>) and [report builder](<report-builder.py>) make no browser/model calls. No L54/L55 work started.
