"""Export actual LW World layout and clock; Julia owns the subsequent day."""
import hashlib,json,subprocess,sys
from pathlib import Path
from integrations.lightweight.world import World
from runtime.lw_time import metadata

def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
    assert metadata()['profile']=='human_scale_v1'
    w=World('julia-lw-day',seed=20261004,layout='sparse')
    natural=dict(name='lw_sparse',positions=[[a['x'],a['z']] for a in w.agents.values()],
        food=w.resources,obstacles=[o for o in w.objects if o['solid']],
        initial_inventory=[0,2,2],reserve=[30,90,90],home=[0,4],hearing=True)
    # Existing timed_harvest social_shared layout, not a successful-action script.
    camp=dict(name='social_shared',positions=[[-.25,5.8],[0,5.8],[.25,5.8]],
        food=[dict(x=-.4,z=6.8,stock=6),dict(x=.4,z=6.8,stock=6)],
        obstacles=[dict(x=0,z=8,radius=.3,height=12)],
        initial_inventory=[0,2,2],reserve=[30,90,90],home=[0,5.8],hearing=True)
    (out/'specs.json').write_text(json.dumps(dict(clock=metadata(),scenes=[camp,natural])))
    paths=['integrations/lightweight/world.py','integrations/lightweight/timed_harvest.py',
        'experiments/julia_migration/lw_day/run.jl','experiments/julia_migration/social_loop/models.jl',
        'experiments/julia_migration/moving_social/run.jl','experiments/julia_migration/all_loop/loop.jl']
    (out/'provenance.json').write_text(json.dumps(dict(commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        hashes={p:hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in paths}),indent=2))
    with (out/'stdout.txt').open('w') as so,(out/'stderr.txt').open('w') as se:
        subprocess.run(['julia','--startup-file=no','--project=experiments/julia_migration/julia',
            'experiments/julia_migration/lw_day/run.jl',str(out/'specs.json'),str(out/'report.json')],
            stdout=so,stderr=se,check=True,timeout=600)

if __name__=='__main__':main()
