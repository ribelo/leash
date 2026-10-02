#!/usr/bin/env python3
"""Offline validation only: never runs browser missions; prints counts, never secrets."""
import hashlib,json,os,re,subprocess
from decimal import Decimal
from pathlib import Path
root=Path(__file__).resolve().parent;repo=root.parents[4]
key=os.environ.get('OPENROUTER_API_KEY','').encode();assert key,'Run through secret-env ai'
patterns={'capability_tokens':rb'\b(?:t|s|h)_[0-9a-f]{16,}\b','concrete_private_roots':rb'/tmp/leash-l53-[a-z0-9_]{8}(?=[/\s"\x27]|$)','key_prefixes':rb'\bsk-(?:or-|proj-)?[A-Za-z0-9_-]{20,}','real_chrome_paths':rb'/home/[^/\s]+/\.config/(?:google-chrome|chromium)(?:[/\s"\x27]|$)'}
def load(p):return json.loads(p.read_text(),parse_float=Decimal)
def close(a,b):return abs(Decimal(str(a))-Decimal(str(b)))<Decimal('0.000000000001')
def capfields(v):
 if isinstance(v,dict):
  return sum(int(k in ('tab','snapshot','handle') and isinstance(x,str) and x not in ('','[redacted]','[redacted capability]'))+capfields(x) for k,x in v.items())
 if isinstance(v,list):return sum(map(capfields,v))
 return 0
def scan():
 counts={k:0 for k in patterns};counts.update(exact_api_key_occurrences=0,unredacted_capability_fields=0);jc=jl=jr=0;files=sorted(p for p in root.rglob('*') if p.is_file())
 for p in files:
  d=p.read_bytes();counts['exact_api_key_occurrences']+=d.count(key)
  for k,v in patterns.items():counts[k]+=len(re.findall(v,d))
  if p.suffix=='.json':counts['unredacted_capability_fields']+=capfields(json.loads(d));jc+=1
  elif p.suffix=='.jsonl':
   jl+=1
   for line in d.splitlines():
    if line.strip():counts['unredacted_capability_fields']+=capfields(json.loads(line));jr+=1
 assert not any(counts.values()),'Nonzero evidence leak count'
 return {'leaks':counts,'files_scanned':len(files),'json_files_validated':jc,'jsonl_files_validated':jl,'jsonl_rows_validated':jr}
scan();p=load(root/'provenance.json');s=load(root/'summary.json')
assert p['git_head']==s['git_head'] and p['binary_sha256']==s['binary_sha256']
assert hashlib.sha256((repo/p['binary_path']).read_bytes()).hexdigest()==p['binary_sha256']
assert p['clean_at_build'] and p['clean_product_before_live'] and p['fresh_build'] and p['build_exit']==0
for f,h in p['base_harness_hashes'].items():assert hashlib.sha256((repo/f).read_bytes()).hexdigest()==h
assert hashlib.sha256((root/'harness.py').read_bytes()).hexdigest()==p['adapted_harness_sha256']
assert hashlib.sha256((root/'harness-test.py').read_bytes()).hexdigest()==p['adapter_tests_sha256']
links=[]
for f in root.rglob('*.md'):
 for url in re.findall(r'\]\(<([^>]+)>\)',f.read_text()):
  if not re.match(r'https?://',url):
   dest=(f.parent/url.split('#')[0]).resolve();assert dest.is_file(),'Broken evidence link';links.append(str(dest.relative_to(repo)))
bcalls=lcalls=0;bcost=lcost=Decimal(0);kinds={};checks=[]
for site in ('maps','flights'):
 curve=load(root/site/'cost-curve.json');result=load(root/site/'result.json');ss=s['sites'][site]
 assert not result['passed'] and ss['passed']==result['passed'] and ss['failures']==result['failures']
 assert len(curve)==result['missions_recorded']==ss['missions_recorded']==len(ss['missions'])
 assert ss['missions_skipped']==list(range(len(curve)+1,5))
 assert len(set(m['mission'] for m in curve))==1
 assert result['cleanup']['service_exit']==0 and result['cleanup']['profile_processes_after_service']==[] and result['cleanup']['loopback_server_closed']
 for m,sm in zip(curve,ss['missions']):
  a=m['accounting'];w=load(root/site/f"mission-{m['number']}"/'learning-wait.json');d=m['durable_accounting']
  assert a['total_cost_fully_reported'] and a['run_only_cost_unreported']==m['cost_unreported']==0
  assert m['model_calls']==a['total_calls']==a['run_only_calls']+a['learning_calls']==sm['total_calls']
  assert m['reply']['model_calls']==d['model_calls']==a['run_only_calls']
  assert close(m['reply']['model_cost'],a['run_only_reported_cost_usd']) and close(d['cost_usd'],a['run_only_reported_cost_usd'])
  assert close(m['model_cost_usd'],a['run_only_reported_cost_usd']+a['learning_cost_usd']) and close(m['model_cost_usd'],sm['total_cost_usd'])
  assert w['completed'] and w['bound_seconds']==900 and w['final_status']['learning']['pending']==0 and w['history'][-1]['pending']==0
  assert w['elapsed_s']<905 and a['learning_pending_finished'] and sm['learning_pending_at_finish']==0
  new=w['before']['mtime_ns']!=w['after']['mtime_ns'] and next(iter(w['after']['state']),None)=='account:google.com'
  assert new==a['new_learning_account']==sm['new_learning_account']
  if new:
   account=w['after']['state']['account:google.com'];assert account['model_calls']==a['learning_calls'] and close(account['model_cost'],a['learning_cost_usd'])
   assert a['last_work_status']['learning_calls']==a['learning_calls'] and close(a['last_work_status']['learning_cost'],a['learning_cost_usd'])
  else:assert a['learning_calls']==0 and close(a['learning_cost_usd'],0)
  bcalls+=a['run_only_calls'];lcalls+=a['learning_calls'];bcost+=a['run_only_reported_cost_usd'];lcost+=a['learning_cost_usd']
  for k,v in a['total_calls_by_kind'].items():kinds[k]=kinds.get(k,0)+v
  checks.append({'site':site,'mission':m['number'],'browser_trace_reconciled':True,'async_last_work_reconciled':True,'pending_finished':True})
assert bcalls==s['costs']['browser_calls'] and lcalls==s['costs']['learning_calls'] and kinds==s['costs']['calls_by_kind']
assert close(bcost,s['costs']['browser_cost_usd']) and close(lcost,s['costs']['learning_cost_usd']) and close(bcost+lcost,s['costs']['total_cost_usd'])
draft=load(root/'flights/checkpoint-2/state/leash/proposed/google.com-explore-destinations.json')['procedures'][0]
installed=load(root/'flights/checkpoint-3/config/leash/playbooks/google.com/playbook.json')['procedures'][0]
new=load(root/'flights/mission-4/durable/state/leash/proposed/google.com-explore-destinations.json')['procedures'][0]
assert draft==installed and installed['provenance']['gate']=='replay' and installed['provenance']['repeatable'] and len(installed['provenance']['traces'])==2
assert installed['provenance']['path']==['travel-slug'] and installed['expect']==['the page is travel-slug']
assert new['provenance']['path']==['flights','travel-slug'] and len(new['provenance']['traces'])==2 and new['provenance']['model_calls']==2
assert close(new['provenance']['model_cost'],Decimal('0.003503975'))
for n,key_ in [(3,'draft:explore-destinations'),(4,'explore-destinations')]:
 m=load(root/'flights/cost-curve.json')[n-1];proc=m['reply']['procedures'][0]
 assert proc['choice']['key']==key_ and proc['outcome']=='verified'
visible=load(root/'flights/mission-4/after/visible-page.json')['reply']['value']['text']
assert 'Loading results' in visible and not re.search(r'PLN\s*\d',visible)
assert len(list(root.rglob('*.png')))==s['retained_screenshots']==6
owned=[]
for proc in Path('/proc').iterdir():
 if proc.name.isdigit():
  try:args=(proc/'cmdline').read_bytes().split(b'\0')
  except (OSError,ProcessLookupError):continue
  if args and (args[0]==str(repo/p['binary_path']).encode() or any(re.match(rb'--user-data-dir=/tmp/leash-l53-[a-z0-9_]{8}/profile$',a) for a in args)):owned.append(int(proc.name))
assert not owned,'Campaign-owned process remains'
private=[x for x in Path('/tmp').iterdir() if x.is_dir() and re.fullmatch(r'leash-l53-[a-z0-9_]{8}',x.name)]
assert not private,'Private campaign temp root remains'
product=subprocess.run(['git','status','--porcelain','--','.',':(exclude)docs/issues/map-draws-itself/acceptance/live-2026-10-02-google3/'],cwd=repo,text=True,capture_output=True,check=True)
assert not product.stdout,'Changes outside authorized evidence root'
assert (repo/'docs/issues/map-draws-itself/acceptance/live-2026-10-02-maps3').is_dir() and (repo/'docs/issues/map-draws-itself/acceptance/live-2026-10-02-google2').is_dir()
audit={'passed':True,'checks':checks,'browser_calls':bcalls,'learning_calls':lcalls,'total_calls':bcalls+lcalls,'browser_cost_usd':float(bcost),'learning_cost_usd':float(lcost),'inclusive_cost_usd':float(bcost+lcost),'markdown_links_validated':len(links),'goal_screenshots_retained':6,'no_owned_processes':True,'no_private_campaign_temp_roots':True,'product_worktree_unchanged':True,'prior_evidence_preserved':True,'frozen_binary_and_harness_hashes_verified':True,'replay_install_and_new_path_draft_verified':True}
audit['artifact_sha256']={name:hashlib.sha256((root/name).read_bytes()).hexdigest() for name in ['README.md','maps/README.md','flights/README.md','summary.json','provenance.json','harness.py','harness-test.py','audit-evidence.py','maps/cost-curve.json','maps/result.json','flights/cost-curve.json','flights/result.json']}
audit['goal_screenshot_sha256']={str(x.relative_to(root)):hashlib.sha256(x.read_bytes()).hexdigest() for x in sorted(root.rglob('*.png'))}
(root/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');audit.update(scan());(root/'audit.json').write_text(json.dumps(audit,indent=2)+'\n');scan();print(json.dumps(audit,indent=2))
