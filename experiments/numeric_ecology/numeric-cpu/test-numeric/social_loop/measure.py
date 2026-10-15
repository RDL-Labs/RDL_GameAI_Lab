"""A1 parity supervisor; performance is deliberately not an acceptance target."""
import hashlib
import json
import math
import platform
import subprocess
import sys
import time
from pathlib import Path
from .reference import scenario, boundaries, SPECS


def compare(a,b,path='root'):
    if isinstance(a,dict):
        assert isinstance(b,dict) and a.keys()==b.keys(),path
        for k in a:compare(a[k],b[k],path+'.'+k)
    elif isinstance(a,list):
        assert isinstance(b,list) and len(a)==len(b),path
        for i,(x,y) in enumerate(zip(a,b)):compare(x,y,f'{path}[{i}]')
    elif type(a) in (int,float) and path.rsplit('.',1)[-1] in {
            'burst','strain','reserve','damage','expectation','score','time'}:
        assert type(b) in (int,float) and math.isclose(a,b,abs_tol=1e-12,rel_tol=1e-12),(path,a,b)
    else:assert type(a)==type(b) and a==b,(path,a,b)


def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
    spec=out/'specs.json';spec.write_text(json.dumps(SPECS,indent=2)+'\n')
    before=hashlib.sha256(spec.read_bytes()).hexdigest()
    start=time.perf_counter();p=dict(boundaries=boundaries(),scenarios={})
    for s in SPECS:
        r=scenario(s);compare(r,scenario(s));p['scenarios'][s['name']]=r
    py_seconds=time.perf_counter()-start
    (out/'python.json').write_text(json.dumps(p,indent=2)+'\n')
    start=time.perf_counter()
    with (out/'julia.stdout').open('w') as stdout,(out/'julia.stderr').open('w') as stderr:
        subprocess.run(['julia','--startup-file=no','--project=experiments/julia_migration/julia',
                        'experiments/julia_migration/social_loop/run.jl',str(spec),str(out/'julia.json')],
                       stdout=stdout,stderr=stderr,check=True,timeout=300)
    julia_seconds=time.perf_counter()-start
    j=json.loads((out/'julia.json').read_text());compare(p,j)
    assert hashlib.sha256(spec.read_bytes()).hexdigest()==before
    cases=p['scenarios']
    assert [r['selection']['selected']['target'] for r in cases['enabled']['rows']]==['npc_b','npc_b','npc_c','npc_c','npc_c','npc_c']
    assert cases['shadow']['rows'][2]['selection']['selected']['target']=='npc_b'
    assert cases['shadow']['rows'][3]['selection']['selected']['target']=='npc_c'
    for name in ('short','interrupt'):
        assert all(n['npc_a']['sleep']['cycle']['status']=='pending' for n in cases[name]['nights'])
        assert not cases[name]['states']['npc_a']['model']
    assert cases['unheard']['rows'][0]['state']['records']['npc_a:request:0:0']['outcome']=='no_response_observed'
    assert p['boundaries']['sleep']['last']['sleep']['cycle']['rest_us']==2_880_000_000
    assert [s['H'] for s in p['boundaries']['goal_sequence']]==[1,1,2,0]
    files=['runtime/goal_difference.py','runtime/aid_method_pressure.py','runtime/social_sleep.py',
           'runtime/harvest_sleep.py','runtime/layered_body.py','integrations/lightweight/minimal_communication.py']
    report=dict(status='parity_pass',scope='A1 local social/goal/Sleep subset; not full LW or canonical T1',
        platform=platform.platform(),spec_sha256=before,
        source_sha256={f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in files},
        correctness_execution_seconds=dict(python_with_replay=py_seconds,julia_process_with_replay=julia_seconds),
        note='Different startup/output boundaries; NOT a speed benchmark',
        scenarios={name:dict(targets=[r['selection']['selected']['target'] for r in r0['rows']],
            consumed=r0['consumed'],sleep=[n['npc_a']['sleep']['cycle']['status'] for n in r0['nights']],
            expectation=r0['states']['npc_a']['model']) for name,r0 in cases.items()},
        boundary_rejections=p['boundaries']['errors'])
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))


if __name__=='__main__':main()
