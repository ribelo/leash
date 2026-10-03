#!/usr/bin/env python3
"""Evidence-only report renderer; no browser or model calls."""
import json
from pathlib import Path
root=Path(__file__).resolve().parent
s=json.loads((root/'summary.json').read_text()); audit=json.loads((root/'audit.json').read_text())
lines=['# L53 / map-op07 — op07c live acceptance','',
'**Acceptance fails on Books, Flights, and Maps. L53 remains open.** Books and Flights completed five distinct missions with no retries. No site installed a playbook. Maps mission 5 was infrastructure-killed, not judged, and not rerun.','',
'Baseline master 1690f49, unchanged binary SHA-256 10afe16378511bcb42e92402b8a54dde7bac7aaf98c109a63b13f8f7989366b0. No rebuild, product edit, commit, delegation, real-service modification, or everyday Chrome use. [Identity](<recovery-identity.json>). Canonical [summary](<summary.json>) and [audit](<audit.json>) distinguish harness/isolation checks from map-op07 acceptance; raw result passed flags do not mean acceptance passed.','',
'## Protocol and exclusions','',
'Books and Flights ran concurrently in separate private headless services with empty Chrome profiles and all-temporary XDG roots. Credentials entered only through secret-env ai --. Missions 1–4 used learning auto; each waited at most 900 seconds for pending learning to reach zero. All waits finished. Mission 5 used a fresh service/profile with learning off. Only installed playbooks could be copied; all transfer manifests were empty, with zero copied traces, learning state, drafts, or cookies. Next month was November 2026.','',
'Earlier infrastructure-killed [Books](<books-killed/>) and [Flights](<flights-killed/>) campaigns remain intact and excluded from judged campaigns. Maps fifth [verification](<maps/fresh/mission-5/verification.json>) records SIGTERM 15 and no drive reply: killed/not judged, unknown cost, not a harness bug, no rerun. Maps fails independently because nothing was installed.','',
'## Mission results and USD cost curves','',
'Browser and learning columns show model calls / USD, not DOM operations. Inclusive cost is browser plus asynchronous learning. Values are rounded here; exact provider-reported floats, per-kind calls, statuses, answers, verification, and artifacts are in [summary](<summary.json>). Unpriced or killed usage is unknown/null, never zero. Learning meters record last model-bearing work, not cumulative work; changed meter/account timestamps assign work once to the mission whose wait observed it.','']
def usd(x): return 'unknown' if x is None else f'{x:.9f}'
def meter(a,p): return str(a.get(p+'_calls') if a.get(p+'_calls') is not None else 'unknown')+' / '+usd(a.get(p+'_cost_usd'))
for site,data in s['sites'].items():
 lines += [f'### {site.title()}','','| Mission / argument | Status | Verified | Answer | Browser calls / USD | Learning calls / USD | Inclusive USD | Installed |','|---|---|---|---|---|---|---|---|']
 for r in data['missions']:
  arg=r['arguments'];arg=' → '.join(arg) if isinstance(arg,list) else str(arg)
  answer=r['delivered_result']['answer'] or 'none';v='not judged' if not r['judged'] else str(r['goal_verified']).lower();a=r['accounting']
  lines.append(f"| {r['number']}: {arg} | {r['status']} | {v} | {answer} | {meter(a,'browser')} | {meter(a,'learning')} | {usd(a.get('inclusive_cost_usd'))} | {len(r.get('installed_after',[]))} |")
 c=data['criterion']
 lines += ['',f"Criterion **FAIL**: installed {c['installed_playbook_present']}; fresh service/profile {c['fresh_service_and_profile']}; fifth independently verified {c['fifth_goal_independently_verified']}; cheaper inclusive fifth {c['lower_inclusive_cost_than_mission_1']}; learning off {c['acceptance_learning_off']}; no fifth learning calls {c['acceptance_no_learning_calls']}.",'']
lines += [
'Maps mission 1 has one unpriced browser call. Reported priced usage was $0.023903548, but complete browser/inclusive cost remains unknown. The fifth has no drive reply and unknown usage; neither supports a cheaper-run claim.','',
'## Independent output review','',
'**Books:** all five delivered zero script-records and no terminal answer. Independent category HTML was read through private Leash and compared with delivered title/price pairs, not diagnostic snapshots. Mission 2 exhausted its action budget; the four done statuses did not constitute collection. The fifth Horror category had valid reference records but no delivered collection. All verdicts are false.','',
'**Flights:** all five returned done, without a terminal answer or script-record itinerary. Real selected-date fares and November dates were reached. The [fifth screenshot](<flights/fresh/mission-5/page.png>) and [verification](<flights/fresh/mission-5/verification.json>) show Poznań → Amsterdam, November 1–4, 2026, and selected-date cheapest PLN 751. This does not prove the cheapest flight across the requested month and did not deliver an answer. Per-mission independent reviews retain that distinction. All verdicts are false.','',
'**Maps:** the sole terminal answer was “Caffè Antica Roma — Via Marco Aurelio, 28” in mission 2. Its [independent verifier](<maps/mission-2/verification.json>) could not corroborate cafe name/address/category, landmark navigation, or coordinate proximity. Missions 1/3 reached limits, 4 was blocked, and 5 is killed/not judged.','',
'Tagged operator-state output exposes diagnostic DOM, including titles/prices/fares. It is not a delivered answer or validated script-record collection. The consolidator excludes it from delivery verification.','',
'## Compilation, installation, repair, and format stories','',
'Books retained one draft after mission 4: two human-language goal steps, category argument, and two expectations. Its provenance records two model calls, $0.013367475, replay gate, repeatable true, repair false, tries 0. No extraction/pagination script exists. No later auto-learning mission could replay it before the fresh off-mode fifth. No site installed or repaired a playbook.','',
'Books [service events](<books/service-events.jsonl>) retain structural-outline warnings (missing, invalid or empty skeleton), invalid scripts-object rejection, and rejection of collection scripts without observed structural outline. Flights [service events](<flights/service-events.jsonl>) show two compile drops: compiled scripts require a repeatable collection procedure. No Flights/Maps draft or script survived. Rejected model payloads were not persisted; logs are not fabricated compiled scripts.','',
'| Story | Live evidence | Verdict |','|---|---|---|',
'| map-fmt01 | Books draft uses goal/args/expect with no removed fields; no old-file rejection or installation tested. | Partial draft evidence; end-to-end unproven |',
'| map-fmt02 | No inline draft provenance; full metadata is a separate sidecar. | Separation observed; installed behavior unexercised |',
'| map-fmt03 | Compiler drops and final replay-gated draft retained; no successful installation correction. | End-to-end unproven |',
'| map-fmt04 | Collection/out intent existed; outline/script validation failed; final Books draft has no script; Flights scripts rejected. | Script-first collection not achieved |','',
'Complete final proposal and sidecar follow. [Audit](<audit.json>) preserves exact text, unique draft versions, installed-file maps, and repair/retirement lists. All installed/script maps and repair lists are empty.','']
for name,text in audit['sites']['books']['artifacts']['final_proposed_files'].items():
 if not name.endswith('.json'): continue
 lines += [f'### [Full {name}](<books/final/artifacts/state/leash/proposed/{name}>)','', '~~~json',text.rstrip(),'~~~','']
lines += [
'## Harness recovery disclosure','',
'Exact launched fallback: [harness-launched](<harness-launched.py>); corrected reproduction: [harness-recovery](<harness-recovery.py>). The launched observer referenced a parsed value before initialization when a sidecar was first. [Observer guard](<observer-guard.py>) wrote ignored empty metadata outside private playbooks, initializing the observer without changing product configuration/playbooks. Raw sidecar observer values are not trusted; complete sidecars are rederived from exact artifacts. [Guard record](<observer-guard.json>) retains rationale and owned process identities without private paths.','',
'The corrected source continues distinct remaining missions after a bounded learning-wait timeout instead of prematurely omitting them. This branch was not exercised: both live campaigns completed every pending wait. No mission retry or silent dependent-state reset occurred.','',
'## Security and cleanup','',
'Final [exact-key and capability/path scan](<security-scan.json>) runs through secret-env and emits counts only: exact key matches 0; handle matches 0; private/other temporary path matches 0. [Process audit](<process-audit.json>) confirms no op07c binary or private-profile browser survives. Private campaign services exited 0 and closed loopback servers. The real user service remains active/running with unchanged MainPID 3662.','',
'Evidence-only [audit builder](<audit-builder.py>) and [report builder](<report-builder.py>) make no browser/model calls. No L54/L55 work started.','']
(root/'README.md').write_text('\n'.join(lines))
print('Final README written; all three site criteria false.')
