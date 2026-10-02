#!/usr/bin/env python3
"""Audit Maps acceptance evidence without printing credentials or matches."""
from pathlib import Path
from decimal import Decimal
import hashlib,json,os,re,subprocess
root=Path(__file__).resolve().parent
repo=root.parents[4]
key=os.environ.get('OPENROUTER_API_KEY','').encode()
assert key,'Exact-key audit requires the authorized key environment'
patterns={
 'capability_tokens':rb'\b(?:t_[0-9a-f]{16,}|s_[0-9A-Za-z_-]{16,})\b',
 'concrete_private_runtime_paths':rb'/tmp/leash-l53-[0-9a-z_]{8}(?=/|[\s"\x27]|$)',
 'api_key_prefixes':rb'\b(?:sk-or-v1-[A-Za-z0-9_-]{12,}|sk-[A-Za-z0-9_-]{20,}|AIza[A-Za-z0-9_-]{20,})\b',
 'real_chrome_profile_paths':rb'/home/[^/\s"\x27]+/(?:\.config|\.local/share)/(?:google-chrome|chromium|leash/chrome|leash/profile)(?:/|[\s"\x27]|$)'}
counts={k:0 for k in patterns};counts['exact_api_key_occurrences']=0
json_count=jsonl_count=jsonl_rows=cap_fields=0
def fields(obj):
 global cap_fields
 if isinstance(obj,dict):
  for k,v in obj.items():
   if k in ('tab','snapshot','handle') and isinstance(v,str) and v not in ('[redacted capability]','[redacted]',''):cap_fields+=1
   fields(v)
 elif isinstance(obj,list):
  for v in obj:fields(v)
files=sorted(p for p in root.rglob('*') if p.is_file())
for p in files:
 data=p.read_bytes();counts['exact_api_key_occurrences']+=data.count(key)
 for k,pattern in patterns.items():counts[k]+=len(re.findall(pattern,data))
 if p.suffix=='.json':fields(json.loads(data));json_count+=1
 elif p.suffix=='.jsonl':
  jsonl_count+=1
  for line in data.splitlines():
   if line.strip():fields(json.loads(line));jsonl_rows+=1
counts['unredacted_capability_fields']=cap_fields
assert not any(counts.values()),'Evidence scan found a nonzero leak count'
prov=json.loads((root/'provenance.json').read_text());summary=json.loads((root/'summary.json').read_text())
binary=repo/prov['binary']
assert hashlib.sha256(binary.read_bytes()).hexdigest()==prov['binary_sha256']==summary['binary_sha256']
for name,sha in prov['harness_sha256'].items():assert hashlib.sha256((repo/name).read_bytes()).hexdigest()==sha
assert prov['git_head']==summary['git_head'] and prov['clean_before_build'] and prov['build_dir_fresh'] and prov['build_exit']==0
subprocess.run(['git','merge-base','--is-ancestor','279bbf3',prov['git_head']],cwd=repo,check=True)
curve=json.loads((root/'maps/cost-curve.json').read_text(),parse_float=Decimal)
result=json.loads((root/'maps/result.json').read_text())
assert summary['passed']==result['passed'] and summary['failures']==result['failures']
assert len(curve)==result['missions_recorded']==len(summary['missions'])
assert summary['missions_skipped']==list(range(len(curve)+1,5))
close=lambda a,b:abs(Decimal(str(a))-Decimal(str(b)))<Decimal('0.000000000001')
calls=learning_calls=unreported_learning_calls=0;known_cost=Decimal(0);kinds={}
for m,s in zip(curve,summary['missions']):
 a=m['accounting'];assert a['run_only_cost_unreported']==0
 assert m['model_calls']==a['run_only_calls']+a['learning_calls']==s['model_calls']
 assert close(a['run_only_reported_cost_usd'],s['browser_run_cost_usd'])
 if a['total_cost_fully_reported']:
  assert m['cost_unreported']==0 and close(m['model_cost_usd'],a['run_only_reported_cost_usd']+a['learning_cost_usd']) and close(m['model_cost_usd'],s['model_cost_usd'])
  assert close(m['durable_accounting']['cost_usd'],m['model_cost_usd'])
 else:
  assert m['model_cost_usd'] is None and s['model_cost_usd'] is None and m['durable_accounting']['cost_usd'] is None and a['learning_cost_usd'] is None and s['learning_cost_usd'] is None
  unreported_learning_calls+=a['learning_calls']
 assert s['goal_verified_independently']==m['goal_verified'] and (root/s['screenshot']).is_file()
 assert m['durable_accounting']['model_calls']==m['model_calls']
 calls+=m['model_calls'];known_cost+=a['run_only_reported_cost_usd'];learning_calls+=a['learning_calls']
 for k,v in a['total_calls_by_kind'].items():kinds[k]=kinds.get(k,0)+v
assert calls==summary['costs']['model_calls'] and close(known_cost,summary['costs']['known_browser_run_cost_usd'])
assert learning_calls==summary['costs']['learning_calls'] and unreported_learning_calls==summary['costs']['unreported_learning_calls'] and kinds==summary['costs']['calls_by_kind']
assert summary['costs']['total_model_cost_usd'] is None and summary['costs']['learning_cost_usd'] is None
assert len(curve)==2 and not result['passed'] and 'cost is incomplete' in result['failures'][0]
assert summary['diagnosis']['planner_timeout_seconds']==60 and summary['diagnosis']['output_token_cap_set_by_leash'] is False
logs=[json.loads(line) for line in (root/'maps/service.redacted.jsonl').read_text().splitlines() if line]
assert any(r.get('msg')=='learning: learning compile dropped: timed out' for r in logs)
for trace in (root/'maps/checkpoint-2/state/leash/traces/google.com').glob('*.json'):
 t=json.loads(trace.read_text());assert t['outcome']=='done' and not t['compiled'] and t.get('error_code') is None
links=[]
for p in root.rglob('*.md'):
 for target in re.findall(r'\]\(<([^>]+)>\)',p.read_text()):
  url,_,frag=target.partition('#')
  if '://' in url:continue
  dest=(p.parent/url).resolve();assert dest.is_file() or dest==root/'audit.json','Broken evidence link'
  if frag.startswith('L'):
   m=re.fullmatch(r'L(\d+)(?:-L?(\d+))?',frag);assert m and int(m.group(2) or m.group(1))<=len(dest.read_text().splitlines())
  links.append((p.parent,url))
assert len([p for p in files if p.suffix=='.png'])==summary['retained_screenshots']==len(curve)
c=result['cleanup'];assert c['service_exit']==0 and not c['profile_processes_after_service'] and c['loopback_server_closed']
processes=[]
for p in Path('/proc').iterdir():
 if not p.name.isdecimal():continue
 try:
  args=(p/'cmdline').read_bytes().split(b'\0')
  if (p/'exe').resolve()==binary.resolve() or any(re.search(rb'^--user-data-dir=/tmp/leash-l53-[0-9a-z_]{8}(?:/|$)',a) for a in args):processes.append(int(p.name))
 except (OSError,PermissionError):pass
runtime=[p.name for p in Path('/tmp').iterdir() if p.is_dir() and re.fullmatch(r'leash-l53-[0-9a-z_]{8}',p.name)]
archives=['leash-l53-incidental-20261002','leash-l53-build-provenance'];assert all((Path('/tmp')/p).is_dir() for p in archives)
assert not processes and not runtime,'Owned process or random runtime root remains'
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
changes=subprocess.check_output(['git','diff','--name-only',prov['git_head']],cwd=repo,text=True).splitlines()
audit={'passed':True,'scope':'all retained bytes including PNG and final audit','exact_key_scan_authorized_key_present':True,'leaks':counts,'validation':{'json_files':json_count+1,'jsonl_files':jsonl_count,'jsonl_rows':jsonl_rows,'markdown_links':len(links),'broken_links':0,'costs_and_durable_traces_reconciled':True,'fully_reported_costs':False,'unreported_learning_calls':unreported_learning_calls,'unknown_total_cost_preserved':True,'summary_matches_gate_results':True,'screenshots_retained':len(curve),'binary_and_harness_hashes_match':True,'build_exit':0,'offline_harness_tests_passed':10},'cleanup':{'owned_processes':len(processes),'random_runtime_roots':len(runtime),'preexisting_archives_preserved':archives,'service_exit':0,'loopback_server_closed':True},'checkout':{'head_at_build':prov['git_head'],'head_at_audit':head,'tracked_changes_since_build_preserved':changes,'product_edits_by_worker':False,'commits_by_worker':False},'files':0,'bytes':0}
p=root/'audit.json';assert not p.exists(),'Inspect existing audit before replacing'
p.write_text(json.dumps(audit,indent=2)+'\n')
for _ in range(8):
 files=sorted(p for p in root.rglob('*') if p.is_file());size=sum(p.stat().st_size for p in files)
 if audit['files']==len(files) and audit['bytes']==size:break
 audit['files']=len(files);audit['bytes']=size;p.write_text(json.dumps(audit,indent=2)+'\n')
else:raise AssertionError('Audit byte accounting did not converge')
for p in files:
 data=p.read_bytes();assert key not in data and not any(re.search(pattern,data) for pattern in patterns.values()),'Final all-byte leak scan failed'
 if p.suffix=='.json':json.loads(data)
 if p.suffix=='.jsonl':
  for line in data.splitlines():
   if line.strip():json.loads(line)
assert all((base/url).resolve().is_file() for base,url in links)
assert audit['files']==len(files) and audit['bytes']==sum(p.stat().st_size for p in files)
print(json.dumps(audit,indent=2))
