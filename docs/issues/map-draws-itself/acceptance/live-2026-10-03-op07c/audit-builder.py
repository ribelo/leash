#!/usr/bin/env python3
"""Evidence-only consolidation; never executes browser actions or changes product files."""
import json, re, hashlib, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parent

def read(path, fallback=None):
 try: return json.loads(path.read_text())
 except (OSError,ValueError): return fallback

def write(name,obj):
 (ROOT/name).write_text(json.dumps(obj,indent=2,ensure_ascii=False)+"\n")

def strings(obj):
 if isinstance(obj,str): return [obj]
 if isinstance(obj,list): return [s for x in obj for s in strings(x)]
 if isinstance(obj,dict): return [s for x in obj.values() for s in strings(x)]
 return []

def delivered(reply,directory):
 detail=reply.get('detail') or {}
 data=reply.get('data') or detail.get('data') or {}
 answer=reply.get('answer') or detail.get('answer')
 # Diagnostic DOM/page/operator snapshots are NOT a delivered collection or answer.
 output=[]
 path=directory/'operator-output.jsonl'
 if path.exists():
  for line in path.read_text().splitlines():
   try:
    item=json.loads(line)
    if isinstance(item,dict) and item.get('kind')=='script-record': output.append(item)
   except ValueError: pass
 return {'answer':answer,'collected':reply.get('collected',data.get('count',0)),
         'data':data,'output':output}

def independent(site,row,directory):
 raw=read(directory/'verification.json',{}) or {}
 drive=read(directory/'drive.json',{}) or {}
 reply=drive.get('reply') or {}
 terminal=delivered(reply,directory)
 manual=read(directory/'independent-review.json')
 if manual: return {'verified':bool(manual.get('verified')),'method':'independent manual review of retained terminal answer and live DOM evidence','manual_review':manual,'raw_verifier':raw}
 if site=='books':
  reference=raw.get('site') or {}
  records=reference.get('records') or []
  def pairs(value):
   if isinstance(value,dict):
    yield (value.get('title'),value.get('price'))
    for item in value.values(): yield from pairs(item)
   elif isinstance(value,list):
    for item in value: yield from pairs(item)
  actual={pair for pair in pairs({'output':terminal['output'],'data':terminal['data'].get('first',[])}) if all(isinstance(value,str) for value in pair)}
  answer_lines=(terminal['answer'] or '').splitlines() if isinstance(terminal['answer'],str) else []
  matches=[r for r in records if (r['title'],r['price']) in actual or any(r['title'] in line and r['price'] in line for line in answer_lines)]
  enough=terminal['collected']==len(records) and bool(records)
  verified=(row['status']=='done' and enough and len(matches)==len(records) and reference.get('counts_match') is True)
  return {'verified':verified,'method':'independent category HTML through private Leash; compare returned answer/validated collection and output only (diagnostic DOM excluded)',
   'expected_records':len(records),'delivered_count':terminal['collected'],'matched_records':len(matches),
   'missing_records':[r for r in records if r not in matches],'reference':reference,'raw_verifier':raw}
 if site=='flights':
  answer=terminal['answer']
  return {'verified':False,'method':'independent post-drive DOM and manual evidence review; terminal answer must give price/dates and corroborate cheapest November itinerary',
    'terminal_answer_present':bool(answer),'review':('No delivered terminal answer or collected itinerary; displayed fares/dates alone do not satisfy the request.' if not answer else 'Requires manual cheapest-month and answer corroboration.'),'raw_verifier':raw}
 if (raw.get('reason') or row.get('reason') or '').startswith('RuntimeError: Signal 15'):
  return {'verified':False,'judged':False,'reason':'infrastructure SIGTERM; no drive reply; no harness bug; no rerun','raw_verifier':raw}
 return {'verified':bool(raw.get('verified')),'judged':True,'raw_verifier':raw}

def artifacts(site_dir):
 # Final training installed snapshot is the installed-only seed, including scripts and sidecars.
 final=site_dir/'final'/'artifacts'/'config'/'leash'/'playbooks'
 installed={str(p.relative_to(final)):p.read_text() for p in sorted(final.rglob('*')) if p.is_file()} if final.exists() else {}
 # Previous Maps worker recorded complete JSON objects, with no installed playbook.
 snapshot=read(site_dir/'final'/'learning-store.json',{}) or {}
 drafts=[]; seen=set()
 for stage in sorted(site_dir.glob('mission-*')):
  state=read(stage/'learning-store.json',{}) or {}
  for item in state.get('proposed',[]):
   digest=hashlib.sha256(json.dumps(item,sort_keys=True).encode()).hexdigest()
   if digest not in seen: drafts.append({'first_observed':str(stage.relative_to(ROOT)),**item}); seen.add(digest)
 return {'final_installed_files':installed,'final_installed_snapshot':snapshot.get('installed',[]),
   'compiled_draft_versions':drafts,'final_proposed_files':{str(p.relative_to(site_dir/'final'/'artifacts'/'state'/'leash'/'proposed')):p.read_text() for p in sorted((site_dir/'final'/'artifacts'/'state'/'leash'/'proposed').rglob('*')) if p.is_file()},'repair_or_retirement_artifacts':[str(p.relative_to(ROOT)) for p in site_dir.rglob('*') if p.is_file() and any(x in p.parts for x in ('retired','repairs'))]}

sites={}; audit_sites={}
for site in ('books','flights','maps'):
 directory=ROOT/site
 rows=read(directory/'cost-curve.json',[]) + read(directory/'fresh'/'cost-curve.json',[])
 assert [r['number'] for r in rows]==[1,2,3,4,5], (site,'must include all five missions')
 enriched=[]
 for row in rows:
  stage=directory/('fresh' if row['number']==5 else '')/('mission-'+str(row['number']))
  out=dict(row)
  out['independent_verification']=independent(site,row,stage)
  out['goal_verified']=out['independent_verification']['verified']
  out['delivered_result']=delivered((read(stage/'drive.json',{}) or {}).get('reply') or {},stage)
  out['provenance_sidecars_after']=[{'path':str(p.relative_to(stage/'artifacts')),'json':read(p)} for p in sorted((stage/'artifacts').rglob('*.provenance.json'))]
  out['raw_sidecar_capture_note']='Sidecars rederived from exact artifact copies; launched observer had a guarded ordering defect.'
  if site=='maps' and row['number']==5:
   out['raw_status']=out['status'];out['status']='killed-infrastructure';out['judged']=False
  else: out['judged']=True
  enriched.append(out)
 arts=artifacts(directory)
 final=enriched[-1]; baseline=enriched[0]
 b=baseline['accounting'].get('inclusive_cost_usd'); f=final['accounting'].get('inclusive_cost_usd')
 criterion={'installed_playbook_present':bool(arts['final_installed_files'] or arts['final_installed_snapshot']),
  'fresh_service_and_profile':bool(final.get('fresh_agent')),
  'fifth_goal_independently_verified':final['goal_verified'],
  'lower_inclusive_cost_than_mission_1':b is not None and f is not None and f<b,
  'acceptance_learning_off':final.get('learning_mode')=='off',
  'acceptance_no_learning_calls':(final['accounting'].get('learning_calls')==0 if final['accounting'].get('learning_calls') is not None else None)}
 cleanup={'training':read(directory/'cleanup.json',{}),'fresh':read(directory/'fresh'/'cleanup.json',{})}
 sites[site]={'criterion_pass':all(criterion.values()),'criterion':criterion,'missions':enriched,
  'installed_playbooks_full':arts['final_installed_files'],'installed_snapshot':arts['final_installed_snapshot'],
  'compiled_drafts':arts['compiled_draft_versions'],'repairs':arts['repair_or_retirement_artifacts'],'cleanup':cleanup}
 audit_sites[site]={'mission_count':len(enriched),'no_mission_retries':True,
  'learning_waits':[{'mission':r['number'],'pending_finished':r['accounting'].get('pending_finished')} for r in enriched[:4]],
  'cleanup':cleanup,'artifacts':arts,'harness_observer_guard':read(ROOT/'observer-guard.json',{}),
  'bounded_wait_timeout_branch_exercised':any(r['accounting'].get('pending_finished') is not True for r in enriched[:4]),
  'format_stories':{
   'map-fmt01':{'observed':('Books draft uses goal steps/args/expect and has no removed fields; old-file rejection not exercised.' if site=='books' else 'No persisted playbook to inspect.'),'end_to_end_proven':False},
   'map-fmt02':{'observed':('Full provenance sidecar is separate from executable Books draft.' if site=='books' else 'No persisted sidecar; unexercised.'),'end_to_end_proven':False},
   'map-fmt03':{'observed':('Two compiler drops then one replay-gated draft; no install or correction-success proof.' if site=='books' else 'Two compiler drops: scripts require a repeatable collection procedure; no draft/install.' if site=='flights' else 'No compiler/draft/install exercised.'),'end_to_end_proven':False},
   'map-fmt04':{'observed':('Missing/invalid structural_outline; invalid script declaration; script rejected without observed outline; final draft has no script.' if site=='books' else 'Scripts rejected because procedure was not repeatable collection; no retained script.' if site=='flights' else 'No compiled collection script.'),'end_to_end_proven':False}}}
write('summary.json',{'story':'map-op07','campaign':'op07c','baseline_head':'1690f49','binary_sha256':'10afe16378511bcb42e92402b8a54dde7bac7aaf98c109a63b13f8f7989366b0',
 'rebuild':False,'product_edits':False,'commit':False,'sites':sites,
 'exclusions':{'books-killed':'infrastructure killed during mission 3; not judged','flights-killed':'infrastructure killed during mission 3; not judged','maps-mission-5':'infrastructure killed; not judged; no rerun because not a harness bug'},
 'cost_notes':['USD provider-reported model costs; browser is synchronous drive model usage, not a count of DOM calls.','Inclusive = browser plus asynchronous learning after pending == 0.','Unknown/unreported or killed usage remains null, never zero.','Raw verifier retained; strict delivered-result check excludes diagnostic DOM.','Retained Maps mission 5 has null cost and cannot support a cheaper-run comparison.']})
write('audit.json',{'story':'map-op07','sites':audit_sites,'isolation':'private headless services, all-temp XDG/profile; key via secret-env ai --; user service untouched',
 'security_scans':read(ROOT/'security-scan.json',{}),'final_process_scan':read(ROOT/'process-audit.json',{}),
 'maps_diagnosis':{'signal':15,'source':'maps/fresh/mission-5/verification.json','harness_bug':False,'rerun':False},
 'preserved_killed_runs':['books-killed','flights-killed']})
print(json.dumps({site:{'pass':v['criterion_pass'],'statuses':[r['status'] for r in v['missions']],
 'inclusive_costs':[r['accounting'].get('inclusive_cost_usd') for r in v['missions']],
 'installed_files':list(v['installed_playbooks_full']),'draft_versions':len(v['compiled_drafts'])} for site,v in sites.items()},indent=2))
