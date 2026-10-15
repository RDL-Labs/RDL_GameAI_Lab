"""Export a pinned Julia baseline; measure it and the typed implementation together."""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

BASELINE='bcbd706'
def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
    data=subprocess.check_output(['git','show',BASELINE+':experiments/julia_migration/social_loop/models.jl'])
    baseline=out/'baseline.jl';baseline.write_bytes(data)
    files=['experiments/julia_migration/social_loop/models.jl','experiments/julia_migration/typed_models/workload.jl']
    meta=dict(baseline_commit=subprocess.check_output(['git','rev-parse',BASELINE],text=True).strip(),
        current_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        baseline_sha256=hashlib.sha256(data).hexdigest(),
        sources={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in files})
    (out/'provenance.json').write_text(json.dumps(meta,indent=2)+'\n')
    with (out/'stdout.txt').open('w') as stdout,(out/'stderr.txt').open('w') as stderr:
        subprocess.run(['julia','--startup-file=no','--project=experiments/julia_migration/julia',
            'experiments/julia_migration/typed_models/measure.jl',str(baseline),str(out/'report.json')],
            check=True,stdout=stdout,stderr=stderr,timeout=300)
    print((out/'report.json').read_text())

if __name__=='__main__':main()
