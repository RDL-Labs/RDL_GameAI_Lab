import hashlib,json,subprocess,sys
from pathlib import Path
from experiments.julia_migration.moving_social.reference import SPECS

def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
    specs=out/'specs.json';specs.write_text(json.dumps([s for s in SPECS if s['name'] in ('enabled','obstacle')]))
    files=['experiments/julia_migration/social_loop/models.jl','experiments/julia_migration/incremental_aid/state.jl',
           'experiments/julia_migration/compact_run/run.jl','experiments/julia_migration/moving_social/run.jl']
    (out/'provenance.json').write_text(json.dumps(dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        hashes={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in files}),indent=2))
    with (out/'stdout.txt').open('w') as stdout,(out/'stderr.txt').open('w') as stderr:
        subprocess.run(['julia','--startup-file=no','--project=experiments/julia_migration/julia',
            'experiments/julia_migration/compact_run/run.jl',str(specs),str(out/'report.json')],stdout=stdout,stderr=stderr,check=True,timeout=300)
    print((out/'report.json').read_text())

if __name__=='__main__':main()

