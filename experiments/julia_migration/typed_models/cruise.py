"""Measure unchanged-history and one-new-history update costs, without policy edits."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
    paths=['experiments/julia_migration/social_loop/models.jl',
           'experiments/julia_migration/typed_models/cruise.jl',
           'experiments/julia_migration/typed_models/workload.jl']
    meta=dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        sources={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths})
    (out/'provenance.json').write_text(json.dumps(meta,indent=2)+'\n')
    with (out/'stdout.txt').open('w') as stdout,(out/'stderr.txt').open('w') as stderr:
        subprocess.run(['julia','--startup-file=no','--project=experiments/julia_migration/julia',
                        'experiments/julia_migration/typed_models/cruise.jl',str(out/'report.json')],
                       stdout=stdout,stderr=stderr,check=True,timeout=300)
    print((out/'report.json').read_text())

if __name__=='__main__':main()
