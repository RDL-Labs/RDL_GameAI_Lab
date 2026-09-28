from copy import deepcopy
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
from pathlib import Path
import unittest
from runtime.goal_reassessment import ReassessingExploration, SCHEMA, candidates
from runtime.rest_reactivation import ReactivatingExploration
from test_rest_reactivation import Session as BaseSession
from test_terrain_steering import food_packet
from test_resource_exploration import config


class Session(BaseSession):
    def __init__(self,review='enabled',memory='enabled'):
        self.multi=ReassessingExploration('r',3,assignment='steady')
        self.agent='npc_a';self.loop=self.multi.agents[self.agent]
        self.seq,self.revision,self.pose=0,0,'r:npc_a:pose:0'
        c=config();c.update(schema=SCHEMA,selection_profile='steady',rest_mode='fatigue',
            reactivation_mode=memory,reassessment_mode=review)
        self.multi.configure(c)


class GoalReassessmentTests(unittest.TestCase):
    def prefix(self,index=2,agent='npc_b',seq=29):
        path=Path(__file__).parent/'fixtures/luanti_l15a_goal_reassessment.json.gz'
        with gzip.open(path,'rt') as f:run=json.load(f)['runs'][index]['data']
        w=run['world'];s=run['runtime']['exploration']
        loop=ReassessingExploration(w['run_id'],s['periods'],s['seed'],s['assignment'])
        for d in w['deliveries']:
            p=d['request']
            if d['kind']=='observe' and p['agent_id']==agent and p['sample_seq']==seq:return loop,deepcopy(p)
            getattr(loop,d['kind'])(p)
        self.fail('missing prefix')

    def test_disabled_keeps_existing_actions(self):
        a=Session('disabled');b=BaseSession()
        for _ in range(16):self.assertEqual(a.apply(food_packet(a)),b.apply(food_packet(b)))
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertEqual(a.loop.store.snapshot(),b.loop.store.snapshot())

    def test_candidate_scope_and_memory_cost_are_separate(self):
        s=Session();p=food_packet(s)
        p['landmarks']['features']=[dict(ref='f0',color='gray',azimuth=[-5,5],range_band='mid'),
            dict(ref='f1',color='brown',azimuth=[25,35],range_band='far'),
            dict(ref='f2',color='green',azimuth=[40,50],range_band='far')]
        held=dict(current_feature=dict(color='green'))
        clean,_=candidates(p,held,None);memory,_=candidates(p,held,dict(forward_penalty=.5))
        eligible=lambda rows:[r for r in rows if not r['reasons']]
        self.assertEqual(min(eligible(clean),key=lambda r:r['cost'])['feature']['ref'],'f0')
        self.assertEqual(min(eligible(memory),key=lambda r:r['cost'])['feature']['ref'],'f1')
        self.assertEqual(clean[2]['reasons'],['held_color_excluded'])
        q=deepcopy(p);q['food']['coverage']='partial'
        self.assertEqual(candidates(q,held,None),([], 'acquisition_incomplete'))
        self.assertEqual(candidates(p,None,None),([], 'held_descriptor_unavailable'))

    def test_pickup_and_rest_keep_priority(self):
        s=Session()
        for _ in range(5):s.apply(food_packet(s))
        c,_=s.apply(s.packet())
        self.assertEqual(c['kind'],'pickup')
        self.assertFalse(next(reversed(s.loop.decisions.values()))['goal_reassessment']['triggered'])

    def test_replay_conflict_and_agent_isolation(self):
        s=Session();p=food_packet(s);first=s.multi.observe(p);before=s.multi.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:out=list(pool.map(s.multi.observe,[deepcopy(p) for _ in range(8)]))
        self.assertTrue(all(x['command']==first['command'] for x in out))
        q=deepcopy(p);q['food']['visible'][0]['distance']+=1
        with self.assertRaises(ValueError):s.multi.observe(q)
        self.assertEqual(s.multi.snapshot(),before)
        self.assertFalse(s.multi.agents['npc_b'].decisions)

    def test_world_archive(self):
        path=Path(__file__).parent/'fixtures/luanti_l15a_goal_reassessment.json.gz'
        from integrations.luanti.tests.check_goal_reassessment import check
        with gzip.open(path,'rt') as f:r=json.load(f)
        self.assertEqual(len(r['runs']),8)
        for run in r['runs']:self.assertEqual(check(run['data']),run['summary'])

    def test_memory_ablation_on_same_actual_wire_has_same_commands(self):
        path=Path(__file__).parent/'fixtures/luanti_l15a_goal_reassessment.json.gz'
        with gzip.open(path,'rt') as f:matrix=json.load(f)
        for index in (3,7):
            data=matrix['runs'][index]['data'];w=data['world'];s=data['runtime']['exploration']
            loop=ReassessingExploration(w['run_id'],s['periods'],s['seed'],s['assignment'])
            for delivery in w['deliveries']:
                q=deepcopy(delivery['request'])
                if delivery['kind']=='configure':q['reactivation_mode']='disabled'
                actual=getattr(loop,delivery['kind'])(q)
                if delivery['kind']=='observe':
                    self.assertEqual(actual['command'],json.loads(delivery['response_wire'])['command'])
            for aid,a in loop.agents.items():
                self.assertEqual(a.snapshot()['learning'],s['agents'][aid]['learning'])

    def test_configuration_is_frozen(self):
        s=Session();before=s.multi.snapshot()
        c=config();c.update(schema=SCHEMA,selection_profile='steady',rest_mode='fatigue',
            reactivation_mode='enabled',reassessment_mode='disabled')
        with self.assertRaises(ValueError):s.multi.configure(c)
        self.assertEqual(s.multi.snapshot(),before)

    def test_trigger_consumes_once_without_resetting_budget(self):
        # Actual accepted prefix; B resumes at 29 in this fixture.
        loop,p=self.prefix();before=loop.snapshot();reply=loop.observe(p)
        d=loop.agents['npc_b'].decisions[p['observation_id']]
        self.assertTrue(d['goal_reassessment']['triggered'])
        self.assertEqual(d['landmark']['selected_count'],8)
        state=loop.snapshot()
        with ThreadPoolExecutor(max_workers=4) as pool:out=list(pool.map(loop.observe,[deepcopy(p) for _ in range(8)]))
        self.assertTrue(all(x['command']==reply['command'] for x in out))
        self.assertEqual(loop.snapshot(),state)
        self.assertEqual(before['agents']['npc_a'],state['agents']['npc_a'])
        q=deepcopy(p);q['landmarks']['features']=[]
        with self.assertRaises(ValueError):loop.observe(q)
        self.assertEqual(loop.snapshot(),state)

    def test_failed_admission_does_not_consume_review(self):
        loop,p=self.prefix();before=loop.snapshot()
        p['distant']['payload']['world_id']='forbidden'
        with self.assertRaises(ValueError):loop.observe(p)
        self.assertEqual(loop.snapshot(),before)

    def test_no_candidates_and_tie_do_not_force_action(self):
        for features,status in (([], 'no_candidate'),([
            dict(ref='left',color='red',range_band='far',azimuth=[-35,-25]),
            dict(ref='right',color='red',range_band='far',azimuth=[25,35])], 'ambiguous_minimum')):
            loop,p=self.prefix();p['landmarks']['features']=features
            reply=loop.observe(p);d=loop.agents['npc_b'].decisions[p['observation_id']]
            self.assertTrue(d['goal_reassessment']['state']['used'])
            self.assertEqual(d['goal_reassessment']['status'],status)
            self.assertEqual(reply['command']['kind'],'wait')


if __name__=='__main__':unittest.main()
