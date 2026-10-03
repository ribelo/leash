#!/usr/bin/env python3
"""Count-only key and capability/path audit; credential never leaves the process."""
import os,re,json
from pathlib import Path
root=Path(__file__).resolve().parent
key=os.environ.get('OPENROUTER_API_KEY','').encode()
assert key, 'Run through secret-env ai --'
patterns={'handles':re.compile(rb'\b(?:t_[0-9a-f]{16,}|s_[0-9A-Za-z_-]{16,})\b'),
 'private_temp_paths':re.compile(rb'/tmp/(?:leash|op07|l53)[A-Za-z0-9_./-]*'),
 'other_temp_paths':re.compile(rb'/tmp/[A-Za-z0-9_./-]+')}
counts={'files_scanned':0,'exact_key_matches':0,'files_with_exact_key':0,
 'handles':0,'private_temp_paths':0,'other_temp_paths':0,'nonkey_matches_per_file':[]}
for path in sorted(root.rglob('*')):
 if not path.is_file() or path.name=='security-scan.json': continue
 raw=path.read_bytes();counts['files_scanned']+=1
 n=raw.count(key);counts['exact_key_matches']+=n;counts['files_with_exact_key']+=bool(n)
 local={name:len(regex.findall(raw)) for name,regex in patterns.items()}
 for name,n in local.items(): counts[name]+=n
 if any(local.values()): counts['nonkey_matches_per_file'].append({'file':str(path.relative_to(root)),**local})
(root/'security-scan.json').write_text(json.dumps(counts,indent=2)+'\n')
print(json.dumps({k:v for k,v in counts.items() if k!='nonkey_matches_per_file'}))
