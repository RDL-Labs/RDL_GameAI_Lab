import unittest
from copy import deepcopy
from tests.test_continuous_selection import context, tick
from runtime.continuous_selection import review


class MovementCommitmentTests(unittest.TestCase):
    def turn(self):
        a,p,d,r=context('exploration')
        p['hazard'].update(features=[],coverage='complete')
        for x in p['movement_surface']['ground']['samples']:
            x['status']='sampled' if x['direction_deg']==-90 else 'unavailable'
        out=review(a,p,d)
        self.assertEqual(out['action'],['turn',-90])
        p=tick(a,p,out,r)
        for x in p['movement_surface']['ground']['samples']:x.update(status='sampled',height_delta=0)
        return a,p,d,r

    def test_new_baseline_and_far_candidate_cannot_replace_step(self):
        a,p,d,r=self.turn();a.exploration_horizon_enabled=True
        state=next(iter(a.decisions.values()))['continuous_selection']
        state['exploration_horizon']=dict(rule='cross-day-exploration-horizon-v1',binding=[p['run_id'],p['agent_id']],H=32,threshold=2,count=0,charged=None,events=[])
        p['food']['visible']=[]
        p['landmarks']['features']=[dict(ref='new',range_band='far',azimuth=[40,50],color='brown')]
        d.update(action=['turn',45],reason='new_candidate')
        before=deepcopy(p);out=review(a,p,d)
        self.assertEqual(out['action'],['move',1])
        self.assertEqual(out['continuous_selection']['gate'],'measured_turn_current_step')
        self.assertEqual(p,before)
        self.assertEqual(out['continuous_selection']['trial']['question'],'movement_progress')

    def test_turn_does_not_resolve_movement_H(self):
        a,p,d,r=context('return');p['hazard'].update(features=[],coverage='complete')
        d.update(action=['turn',90],reason='return_not_observed')
        out=review(a,p,d);p=tick(a,p,out,r)
        p['landmarks']['features']=[]
        out=review(a,p,d)
        self.assertEqual(out['continuous_selection']['nodes']['home/baseline']['H'],1)

    def test_current_blocked_surface_interrupts(self):
        a,p,d,r=self.turn()
        for x in p['movement_surface']['ground']['samples']:x['status']='unavailable'
        out=review(a,p,d)
        self.assertNotEqual(out['action'][0],'move')
        self.assertEqual(out['continuous_selection']['execution_commitment']['status'],'interrupted')

    def test_phase_change_and_pickup_preempt(self):
        for phase,action,reason in [('night',['wait',0],'day_night'),('exploration',['pickup',0],'reachable_food_work')]:
            a,p,d,r=self.turn();d['day_cycle']['phase']=phase;d.update(action=action,reason=reason)
            self.assertEqual(review(a,p,d)['action'],action)

    def test_new_near_threat_interrupts_commitment(self):
        a,p,d,r=self.turn()
        p['hazard']['features']=[dict(range_band='near',azimuth=[-10,10])]
        d['day_cycle']['phase']='safety'
        out=review(a,p,d)
        self.assertEqual(out['continuous_selection']['execution_commitment']['status'],'interrupted')
        self.assertNotEqual(out['continuous_selection']['gate'],'measured_turn_current_step')

    def test_body_limit_does_not_credit_wait(self):
        a,p,d,r=self.turn();a.body_candidate=lambda p,action:['wait',0] if action[0]=='move' else action
        out=review(a,p,d)
        self.assertEqual(out['action'],['wait',0])
        self.assertNotIn('trial',out['continuous_selection'])
        self.assertEqual(out['continuous_selection']['execution_commitment']['status'],'body_limited')

    def test_move_result_not_view_change_closes_trial(self):
        for moved in (True,False):
            a,p,d,r=self.turn();out=review(a,p,d);model=out['continuous_selection']['selected']
            p=tick(a,p,out,r)
            result=next(iter(a.results.values()))
            result.update(status='moved' if moved else 'blocked',forward=.5 if moved else 0,right=0)
            out=review(a,p,d)
            self.assertEqual(out['continuous_selection']['nodes'][model]['H'],0 if moved else 1)

if __name__=='__main__':unittest.main()
