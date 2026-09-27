"""Independent World conservation/timing checks and exact accepted-wire replay."""
import json
from pathlib import Path
import sys
from runtime.resource_use_learning import ResourceUseLearning
from runtime.v23_interpretation import GameAIFrozenComparisonSidecar


def replay(deliveries, run, *, activate=None, rename=False):
    canonical=GameAIFrozenComparisonSidecar();loop=ResourceUseLearning(run,canonical)
    names={}
    def rename_value(x):
        if isinstance(x,dict):return {k:rename_value(v) for k,v in x.items()}
        if isinstance(x,list):return [rename_value(v) for v in x]
        if isinstance(x,str) and (x.startswith(run+':') or x in ('npc_a','npc_b')):
            return names.setdefault(x,'renamed-reference-'+str(len(names)))
        return x
    for d in deliveries:
        request=json.loads(json.dumps(d['request']))
        if activate is not None and d['kind']=='learn':request['activate']=activate
        if rename:request=rename_value(request)
        # A counterfactual has different permits: physical display results belong
        # to the original World and cannot be fed into the alternate authority.
        if (activate is not None or rename) and d['kind']=='result':continue
        got=getattr(loop,d['kind'])(request)
        if activate is None and not rename:assert json.loads(json.dumps(got))==json.loads(d['response_wire']),d['kind']
    return json.loads(json.dumps(loop.snapshot())),json.loads(json.dumps(canonical.snapshot()))


def check(data):
    w=data['world'];s=data['runtime']['learning'];canonical=data['runtime']['canonical']
    assert not w.get('failure'),w.get('failure')
    assert w['lua_checks']==27 and w['warning_checks']==36
    assert w['finished_us']<=35000000
    assert len(w['episodes'])==len(s['episodes'])==7
    assert s['config']==w['config']
    assert s['config']['profile']['id']==('fixture-life-sensory' if s['config']['defender']=='npc_a' else 'fixture-life-sensory-compact')
    assert canonical['captures']==28 and canonical['duplicate_observations']==0 and not canonical['failures']
    actual,can=replay(w['deliveries'],w['run_id'])
    assert actual==s,'Runtime snapshot differs from exact wire replay'
    assert can==canonical,'canonical snapshot differs from exact wire replay'
    scenario=w['scenario'];positive=scenario=='positive_active'
    negative=scenario.startswith('negative')
    active=scenario in ('positive_active','negative_active')
    disp='REJECT' if scenario=='heldout_counterexample' else ('DEFER' if scenario=='heldout_incomplete' else 'RETAIN')
    j=s['learning'];assert j['phase']=='complete' and j['inspection']['disposition']==disp
    assert j['inspection']['formation_support']==3
    assert j['inspection']['validation_count']==(None if scenario=='heldout_incomplete' else 3)
    assert canonical['T1_materials']['count']==canonical['T1_selection']['count']==1
    assert canonical['T1_reconstruction']['count']==int(disp=='RETAIN')
    assert canonical['model_cutover']['count']==int(active)
    ids=[];events=[];packets=[]
    for i,e in enumerate(w['episodes'],1):
        T=e['scheduled_us'];r=e['use'];n=r['record']['notice'];own=e['result'];saved=s['episodes'][e['episode_id']]
        assert e['initial_observer']=={'x':0,'y':1,'z':0} and e['initial_actor']=={'x':1,'y':1,'z':0}
        assert e['counts']['peer']==e['counts']['own']==1
        returns=i==7 or (not negative and not (scenario=='heldout_counterexample' and i==6))
        assert e['counts'].get('return_unit',0)==int(returns)
        assert e['actual_acquired']==returns and own['acquired']==returns
        assert T<=n['capture_us']<T+250000 and T+2000000<=own['capture_us']<T+2250000
        assert own['capture_us']<=e['result_accepted_us']<=T+3000000
        states=e['conservation'];assert len(states)==(4 if returns else 3)
        for state in states:assert state['site']+state['observer']+state['actor']==1 and state['unit_ref']==e['unit_ref']
        assert [(states[k]['site'],states[k]['observer'],states[k]['actor']) for k in (0,1)]==[(1,0,0),(0,0,1)]
        assert (states[-1]['site'],states[-1]['observer'],states[-1]['actor'])==((0,1,0) if returns else (0,0,1))
        if returns:assert T+1500000<=e['return_us']<T+1750000
        section=saved['receipt']['section']
        assert section['capture_us']==n['capture_us'] and section['pose_ref']==n['pose_ref']
        assert section['source_ids']['before']==n['before_id'] and section['dimensions']==['own_food_acquired']
        assert saved['own']['receipt']['experience']['section']['capture_us']==own['capture_us']
        experience=saved['own']['receipt']['experience'];ids.append(experience['record_id']);events.extend([n['event_id'],own['event_id']])
        for record in (r['record'],own):
            for side in ('before','after'):packets.append(record[side]['packet_id'])
        if i<=6:
            assert saved['receipt']['status']=='training_disabled' and saved['receipt']['evaluation'] is None
        else:
            receipt=saved['receipt'];assert receipt['status']=='evaluated'
            assert receipt['evaluation']['warning_threshold']==(11000000 if positive else 3000000)
            assert receipt['evaluation']['appraisal_increment']==4000000
            assert receipt['prediction']['status']==('known' if active else 'unknown')
            if active:
                assert receipt['prediction']['values']=={'own_food_acquired':float(not negative)}
                assert saved['own']['receipt']['comparison']['E']['deltas']=={'own_food_acquired':float(negative)}
            else:assert saved['own']['receipt']['comparison']['E'] is None
            assert saved['own']['receipt']['F_prime']['model_ref']==receipt['prediction']['model_ref']
        if scenario=='heldout_incomplete' and i==6:assert experience['acquired'] is None and experience['section']['reasons']
        else:assert experience['acquired']==returns
    assert len(set(ids))==7 and len(set(events))==14 and len(set(packets))==28
    assert w['warning_count']==len(s['results'])==int(not positive)
    if not positive:
        result=w['warning_result'];last=w['episodes'][-1]
        assert result==next(iter(s['results'].values())) and result['readback']=='WARNING' and result['cleared']==''
        assert result['started_us']<last['return_us'] and result['ended_us']>=result['started_us']+250000
        assert all(w['guards'][k] for k in ('foreign_rejected','old_rejected','replay_rejected','completed_replay_rejected'))
    if w['loss_requested']:
        assert w['lost_response'] and w['loss_recovered']
        ds=[d for d in w['deliveries'] if d['kind']=='observe' and d['request']['episode_id']==w['episodes'][-1]['episode_id']]
        assert len(ds)==2 and ds[0]['request']['record']==ds[1]['request']['record']
        assert json.loads(ds[0]['response_wire'])['new_event'] and not json.loads(ds[1]['response_wire'])['new_event']
        assert all(d['received_us']-d['sent_us']>=100000 for d in ds)
    if scenario=='positive_active':
        off,_=replay(w['deliveries'],w['run_id'],activate=False)
        on=s['episodes'][w['episodes'][-1]['episode_id']]['receipt'];off_r=off['episodes'][w['episodes'][-1]['episode_id']]['receipt']
        assert on['section']==off_r['section'] and on['permit'] is None and off_r['permit'] is not None
        for e in w['episodes'][:6]:assert off['episodes'][e['episode_id']]==s['episodes'][e['episode_id']]
    renamed,_=replay(w['deliveries'],w['run_id'],rename=True)
    assert renamed['learning']['inspection']['disposition']==disp
    final=list(renamed['episodes'].values())[-1]['receipt']
    assert final['prediction']['status']==('known' if active else 'unknown')
    assert final['evaluation']['warning_threshold']==(11000000 if positive else 3000000)
    return {'scenario':scenario,'observer':w['config']['defender'],'episodes':7,'warning':w['warning_count'],
            'disposition':disp,'prediction':'known' if active else 'unknown','finished_us':w['finished_us']}


if __name__=='__main__':print('L12 PASS',check(json.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig'))))
