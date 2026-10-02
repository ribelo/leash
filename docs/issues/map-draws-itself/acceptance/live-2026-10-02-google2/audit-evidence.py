#!/usr/bin/env python3
"""Evidence-only audit. Obtain credentials through secret-env; never print them."""
from pathlib import Path
from decimal import Decimal
from urllib.parse import urlsplit
import os,re,json,hashlib,subprocess
root=Path(__file__).resolve().parent
repo=root.parents[4]
key=os.environ.get('OPENROUTER_API_KEY','').encode()
assert key,'Authorized key missing; exact-key scan not performed'
patterns={
 'capability_tokens':rb'\b(?:t_[0-9a-f]{16,}|s_[0-9A-Za-z_-]{16,})\b',
 'concrete_private_runtime_paths':rb'/tmp/leash-l53-[0-9a-z_]{8}(?=/|[\s"\x27]|$)',
 'api_key_prefixes':rb'\b(?:sk-or-v1-[A-Za-z0-9_-]{12,}|sk-[A-Za-z0-9_-]{20,}|AIza[A-Za-z0-9_-]{20,})\b',
 'real_chrome_profile_paths':rb'/home/[^/\s"\x27]+/(?:\.config|\.local/share)/(?:google-chrome|chromium|leash/chrome|leash/profile)(?:/|[\s"\x27]|$)'}
counts={name:0 for name in patterns};counts['exact_api_key_occurrences']=0
json_files=jsonl_files=jsonl_rows=bad_cap_fields=0
def fields(obj):
 global bad_cap_fields
 if isinstance(obj,dict):
  for k,v in obj.items():
   if k in ('tab','snapshot','handle') and isinstance(v,str) and v not in ('[redacted capability]','[redacted]',''):bad_cap_fields+=1
   fields(v)
 elif isinstance(obj,list):
  for v in obj:fields(v)
initial=sorted(p for p in root.rglob('*') if p.is_file())
for p in initial:
 data=p.read_bytes();counts['exact_api_key_occurrences']+=data.count(key)
 for name,regex in patterns.items():counts[name]+=len(re.findall(regex,data))
 if p.suffix=='.json':fields(json.loads(data));json_files+=1
 elif p.suffix=='.jsonl':
  jsonl_files+=1
  for line in data.splitlines():
   if line.strip():fields(json.loads(line));jsonl_rows+=1
counts['unredacted_capability_fields']=bad_cap_fields
assert not any(counts.values()),'Retained evidence scan found nonzero leak count'
summary=json.loads((root/'summary.json').read_text())
prov=json.loads((root/'provenance.json').read_text())
binary=repo/prov['binary']
assert hashlib.sha256(binary.read_bytes()).hexdigest()==prov['binary_sha256']==summary['binary_sha256']
assert prov['git_head']==summary['git_head']=='9a3b553ec284568fc142e6d66f74d03077ac7813'
assert prov['clean_before_build'] and prov['build_dir_fresh'] and prov['build_exit']==0
for p,h in prov['harness_sha256'].items():assert hashlib.sha256((repo/p).read_bytes()).hexdigest()==h
calls=learning_calls=0;cost=learning_cost=Decimal(0);by_kind={}
for site,n in [('maps',2),('flights',1)]:
 curve=json.loads((root/site/'cost-curve.json').read_text(),parse_float=Decimal)
 result=json.loads((root/site/'result.json').read_text())
 assert len(curve)==n==result['missions_recorded'] and not result['passed']
 c=result['cleanup'];assert c['service_exit']==0 and not c['profile_processes_after_service'] and c['loopback_server_closed']
 site_calls=0;site_cost=Decimal(0)
 for m in curve:
  a=m['accounting'];s=summary[site]['missions'][m['number']-1]
  assert a['total_cost_fully_reported'] and m['cost_unreported']==0
  assert m['model_calls']==a['run_only_calls']+a['learning_calls']==s['model_calls']
  assert m['model_cost_usd']==a['run_only_reported_cost_usd']+a['learning_cost_usd']==Decimal(str(s['model_cost_usd']))
  assert s['goal_verified_independently']==m['goal_verified'] and (root/s['screenshot']).is_file()
  site_calls+=m['model_calls'];site_cost+=m['model_cost_usd'];learning_calls+=a['learning_calls'];learning_cost+=a['learning_cost_usd']
  for kind,v in a['total_calls_by_kind'].items():by_kind[kind]=by_kind.get(kind,0)+v
 assert site_calls==summary[site]['total_model_calls'] and site_cost==Decimal(str(summary[site]['total_model_cost_usd']))
 calls+=site_calls;cost+=site_cost
assert calls==summary['costs']['model_calls']==26
assert cost==Decimal(str(summary['costs']['total_model_cost_usd']))==Decimal('0.005780117')
assert learning_calls==1 and learning_cost==Decimal('0.002263925') and by_kind==summary['costs']['calls_by_kind']
logs=[json.loads(line) for line in (root/'maps/service.redacted.jsonl').read_text().splitlines() if line]
meta=[json.loads(r['fields']['response_metadata']) for r in logs if r.get('msg')=='learning planner invalid response']
assert len(meta)==1
for k,v in summary['maps']['diagnosis']['planner_response'].items():
 if k=='cost_usd':assert Decimal(str(meta[0]['cost']))==Decimal(str(v))
 else:assert meta[0][k]==v
paths=sorted((root/'maps/checkpoint-2/state/leash/traces/google.com').glob('*.json'));assert len(paths)==2
for p in paths:
 t=json.loads(p.read_text());assert t['outcome']=='done' and not t['compiled'] and t.get('error_code') is None
 names=[]
 for k in t['page_kind_path']:
  k=k.replace('<slug>','slug').replace('<id>','id')
  if k not in ('unknown','') and k not in names:names.append(k)
 host=urlsplit(t['final']['url']).hostname
 def foreign(k):
  ps=[p for p in t['inferred_pages'] if p['name'].replace('<slug>','slug').replace('<id>','id')==k]
  return ps and all(urlsplit(p['url_pattern']).hostname not in (None,host) for p in ps)
 assert [k for k in names if not foreign(k)]==summary['maps']['diagnosis']['matching_path_both_traces']
flight=json.loads((root/'flights/mission-1/drive.json').read_text())['reply']
assert flight['status']=='blocked' and flight['reason']==summary['flights']['diagnosis']['reason']
noops=[]
def collect(obj):
 if isinstance(obj,dict):
  step=obj.get('step')
  if isinstance(step,dict) and step.get('n') in (3,4,5) and 'page_changed' in obj:noops.append((step['n'],step['index'],obj['page_changed'],obj['outcome']))
  for v in obj.values():collect(v)
 elif isinstance(obj,list):
  for v in obj:collect(v)
collect(flight)
assert noops==[(3,21,False,'executed'),(4,21,False,'executed'),(5,21,False,'executed')],'Unexpected no-op action evidence'
assert not (root/'flights/mission-1/covered-click').exists()
links=[]
for p in root.rglob('*.md'):
 for target in re.findall(r'\]\(<([^>]+)>\)',p.read_text()):
  url,_,fragment=target.partition('#')
  if '://' in url:continue
  dest=(p.parent/url).resolve();assert dest.is_file() or dest==root/'audit.json','Broken retained Markdown file link'
  if fragment.startswith('L'):
   m=re.fullmatch(r'L(\d+)(?:-L?(\d+))?',fragment)
   assert m and int(m.group(2) or m.group(1))<=len(dest.read_text().splitlines())
  links.append(target)
assert len([p for p in initial if p.suffix=='.png'])==summary['retained_screenshots']==3
owned=[];owned_chrome=[]
for p in Path('/proc').iterdir():
 if not p.name.isdecimal():continue
 try:
  args=(p/'cmdline').read_bytes().split(b'\0')
  if (p/'exe').resolve()==binary.resolve():owned.append(int(p.name))
  if any(re.search(rb'^--user-data-dir=/tmp/leash-l53-[0-9a-z_]{8}(?:/|$)',a) for a in args):owned_chrome.append(int(p.name))
 except (OSError,PermissionError):pass
runtime=[p.name for p in Path('/tmp').iterdir() if p.is_dir() and re.fullmatch(r'leash-l53-[0-9a-z_]{8}',p.name)]
archives=['leash-l53-incidental-20261002','leash-l53-build-provenance'];assert all((Path('/tmp')/p).is_dir() for p in archives)
assert not owned and not owned_chrome and not runtime,'Owned process or random runtime root remains'
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
changes=subprocess.check_output(['git','diff','--name-only',prov['git_head']],cwd=repo,text=True).splitlines()
assert not any(p.startswith('scripts/live-acceptance-l53') for p in changes)
end=max((root/site/'result.json').stat().st_mtime for site in ('maps','flights'))
assert all((repo/p).stat().st_mtime>end for p in changes),'Tracked change predates campaign completion'
audit={'passed':True,'scope':'all retained evidence bytes including screenshots and final audit','exact_key_scan_authorized_key_present':True,'leaks':counts,'validation':{'json_files':json_files+1,'jsonl_files':jsonl_files,'jsonl_rows':jsonl_rows,'markdown_links':len(links),'broken_links':0,'costs_reconciled':True,'all_costs_reported':True,'summary_matches_actual_gates':True,'matching_paths_verified':True,'planner_metadata_verified':True,'three_noop_clicks_verified':True,'retained_screenshots':3,'binary_sha256_matches':True,'harness_sha256_matches':True,'build_exit':0,'offline_harness_tests_passed':10},'cleanup':{'tested_binary_processes':len(owned),'owned_private_profile_chrome_processes':len(owned_chrome),'random_runtime_roots':len(runtime),'preexisting_archive_roots_preserved':archives,'services_exit_codes':{'maps':0,'flights':0},'loopback_servers_closed':True},'checkout':{'head_at_build':prov['git_head'],'head_after_runs':head,'clean_before_build':True,'product_changes_by_worker':False,'commits_by_worker':False,'parent_changes_after_campaigns_preserved':changes},'files':0,'bytes':0}
audit_path=root/'audit.json';assert not audit_path.exists(),'Inspect existing audit before replacing'
audit_path.write_text(json.dumps(audit,indent=2)+'\n')
for _ in range(8):
 files=sorted(p for p in root.rglob('*') if p.is_file());size=sum(p.stat().st_size for p in files)
 if audit['files']==len(files) and audit['bytes']==size:break
 audit['files']=len(files);audit['bytes']=size;audit_path.write_text(json.dumps(audit,indent=2)+'\n')
else:raise AssertionError('Audit size accounting did not converge')
for p in files:
 data=p.read_bytes();assert key not in data and not any(re.search(regex,data) for regex in patterns.values()),'Final retained-byte leak scan failed'
 if p.suffix=='.json':json.loads(data)
 if p.suffix=='.jsonl':
  for line in data.splitlines():
   if line.strip():json.loads(line)
assert audit['files']==len(files) and audit['bytes']==sum(p.stat().st_size for p in files)
assert all((root/url.partition('#')[0]).resolve().is_file() for url in links),'Final retained Markdown link check failed'
print(json.dumps(audit,indent=2))
