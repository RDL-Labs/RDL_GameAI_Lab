import unittest
from copy import deepcopy
from runtime.exploration_horizon import update,proposals

class HorizonTests(unittest.TestCase):
    def test_cross_day_result_binding_and_success(self):
        p=dict(run_id='r',agent_id='a',capture_us=0)
        last=dict(day_cycle=dict(phase='exploration'));s=None
        for i in range(24):
            p['capture_us']=i*64000000
            r=dict(operation_id=str(i),status='moved',acquired=False)
            s=update(s,p,last,r,True)
            self.assertEqual(update(s,p,last,r,True),s)
        self.assertEqual(s['H'],3)
        self.assertEqual(update(s,p,dict(day_cycle=dict(phase='night')),dict(operation_id='n',status='waited'),True)['H'],3)
        self.assertEqual(update(s,p,last,dict(operation_id='bad',status='expired'),True)['H'],3)
        self.assertEqual(update(s,p,last,dict(operation_id='bad',status='moved'),False),s)
        self.assertEqual(update(s,p,last,dict(operation_id='food',status='picked_up',acquired=True),True)['H'],0)
        with self.assertRaises(ValueError):update(s,dict(p,agent_id='b'),last,None,False)

    def test_observed_far_score_grows_only_with_pressure(self):
        p=dict(landmarks=dict(features=[dict(ref='f',range_band='far',azimuth=[-5,5]),dict(ref='m',range_band='mid',azimuth=[40,50])]))
        s=dict(H=1,threshold=2)
        self.assertEqual(proposals(p,s,[0,45]),[])
        s['H']=4;before=deepcopy(p);out=proposals(p,s,[0,45])
        self.assertGreater(out[0]['score'],out[1]['score'])
        self.assertEqual(proposals(p,s,[]),[]);self.assertEqual(p,before)
        self.assertEqual(len(proposals(p,s,[45])),1)

    def test_runtime_gate_and_selection(self):
        from tests.test_continuous_selection import context
        from runtime.continuous_selection import review
        a,p,d,r=context('exploration');a.exploration_horizon_enabled=True
        old=next(iter(a.decisions.values()))
        old['continuous_selection']=dict(rule='continuous-local-method-selection-v1',binding=[p['run_id'],p['agent_id']],nodes={},events=[],sequence=0,
            exploration_horizon=dict(rule='cross-day-exploration-horizon-v1',binding=[p['run_id'],p['agent_id']],H=8,threshold=2,count=0,charged=None,events=[]))
        p['food']['visible']=[];p['landmarks']['features']=[dict(ref='far',range_band='far',azimuth=[-5,5],color='brown')]
        out=review(a,p,d)
        self.assertIn('food/horizon_0',[c['model'] for c in out['continuous_selection']['candidates']])
        self.assertEqual(out['continuous_selection']['selected'],'food/horizon_0')
        d['day_cycle']['phase']='night'
        self.assertFalse(any('horizon_' in c['model'] for c in review(a,p,d)['continuous_selection']['candidates']))
