"""A2 independent trace comparison, not a performance benchmark."""
import hashlib
import json
import math
import platform
import subprocess
import sys
from collections import Counter
from pathlib import Path
from .reference import scenario,contact_boundaries,SPECS,IDS

CONTINUOUS={'burst','strain','reserve','damage','expectation','score','time',
            'x','z','yaw','forward','right','distance','resistance','goal_cost','cost'}

def compare(a,b,path='root'):
    if isinstance(a,dict):
        assert isinstance(b,dict) and a.keys()==b.keys(),(path,list(a),list(b))
        for k in a:compare(a[k],b[k],path+'.'+k)
    elif isinstance(a,list):
        assert isinstance(b,list) and len(a)==len(b),(path,len(a),len(b))
        for i,(x,y) in enumerate(zip(a,b)):compare(x,y,f'{path}[{i}]')
    elif type(a) in (int,float) and path.rsplit('.',1)[-1] in CONTINUOUS:
        assert type(b) in (int,float) and math.isclose(a,b,abs_tol=1e-12,rel_tol=1e-12),(path,a,b)
    else:assert type(a)==type(b) and a==b,(path,a,b)

def audit(value,spec):
    rows=value['rows'];assert len(rows)==3*3*spec['ticks']
    assert len({(r['day'],r['tick'],r['actor']) for r in rows})==len(rows)
    for r in rows:
        assert r['observation']['self_id']==r['actor']
        assert all(v['agent_id']==r['actor'] for v in r['social']['records'].values())
        if r['plan']['action']=='request':
            assert r['plan']['target'] in {o['ref'] for o in r['observation']['others'] if o['holding_food']}
    assert sum(value['stock'])+sum(value['inventory'].values())+value['consumed']==60
    for day,n in enumerate(value['nights']):
        for actor in IDS:
            last=next(r for r in reversed(rows) if r['day']==day and r['actor']==actor)
            assert n[actor]['position']==last['position']
            assert n[actor]['inventory']==last['inventory'][actor]
            assert n[actor]['body']['reserve']<last['body']['reserve']
            assert n[actor]['body']['strain']<=last['body']['strain']
            cycle=n[actor]['sleep']['cycle']
            assert cycle['status']==('pending' if spec['interrupt'] else 'completed')
            assert cycle['rest_us']==(2779 if spec['interrupt'] else 2880)*1_000_000
            if not spec['adopt'] or spec['interrupt']:assert not n[actor]['social']['model']
    for actor in IDS:
        assert value['final_agents'][actor]=={k:value['nights'][-1][actor][k] for k in ('position','body','inventory')}
        assert value['final_agents'][actor]['inventory']==value['inventory'][actor]
    if spec['name']=='enabled':
        a=[r for r in rows if r['actor']=='npc_a']
        assert not a[0]['observation']['others']
        assert any(r['observation']['others'] for r in a)
        assert any(r['plan']['action']=='walk' for r in a)
        assert any(r['result']['status']=='transferred' for r in rows)
    return dict(actions=dict(Counter(r['plan']['action'] for r in rows)),
        requests={a:[r['plan']['target'] for r in rows if r['actor']==a and r['plan']['action']=='request'] for a in IDS},
        request_counts=value['request_counts'],consumed=value['consumed'],stock=value['stock'],inventory=value['inventory'],
        observed_contact_rows=sum(bool(r['observation']['others']) for r in rows),
        sleep=[n['npc_a']['sleep']['cycle']['status'] for n in value['nights']],
        final_models={a:value['nights'][-1][a]['social']['model'] for a in IDS},final_agents=value['final_agents'])

def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
    specs=out/'specs.json';specs.write_text(json.dumps(SPECS,indent=2)+'\n')
    p=dict(boundaries=contact_boundaries(),scenarios={});summaries={}
    for spec in SPECS:
        value=scenario(spec);compare(value,scenario(spec));summaries[spec['name']]=audit(value,spec)
        p['scenarios'][spec['name']]=value
    b=p['boundaries']
    assert b['near'] and b['returned_contact'] and not b['far'] and not b['occluded']
    assert b['departed_response']==b['old_response'] and b['old_response']['status']=='unavailable'
    assert b['new_response']['status']=='transferred' and b['final_inventory']==dict(npc_a=1,npc_b=11,npc_c=12)
    assert b['conflict']=='communication_conflict'
    (out/'python.json').write_text(json.dumps(p)+'\n')
    with (out/'julia.stdout').open('w') as stdout,(out/'julia.stderr').open('w') as stderr:
        subprocess.run(['julia','--startup-file=no','--project=experiments/julia_migration/julia',
                        'experiments/julia_migration/moving_social/run.jl',str(specs),str(out/'julia.json')],
                       stdout=stdout,stderr=stderr,check=True,timeout=300)
    compare(p,json.loads((out/'julia.json').read_text()))
    sources=['runtime/layered_body.py','runtime/energy_field.py','runtime/aid_method_pressure.py',
        'runtime/social_sleep.py','runtime/harvest_sleep.py','integrations/lightweight/minimal_communication.py',
        'integrations/lightweight/voice_rescue.py']
    report=dict(status='parity_pass',scope='A2 finite moving contact; not full LW/canonical T1',
        platform=platform.platform(),commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        spec_sha256=hashlib.sha256(specs.read_bytes()).hexdigest(),
        sources={f:hashlib.sha256(Path(f).read_bytes()).hexdigest() for f in sources},
        compared_daytime_rows=sum(len(s['rows']) for s in p['scenarios'].values()),
        compared_night_actor_states=sum(len(n) for s in p['scenarios'].values() for n in s['nights']),
        compared_final_actor_states=sum(len(s['final_agents']) for s in p['scenarios'].values()),
        note='Each implementation replayed independently; no speed claim',scenarios=summaries,boundaries=b)
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))

if __name__=='__main__':main()
