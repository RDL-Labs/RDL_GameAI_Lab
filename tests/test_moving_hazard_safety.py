import unittest
from copy import deepcopy
from runtime.moving_hazard_safety import review,validate,RULE,KEYS
from runtime.goal_difference import initial,begin,finish
from tests import test_relational_movement as fixture
from runtime.directional_routes import review as routes


def packet():
    a,p,d,s,r=fixture.RelationFieldTests().setup()
    p['hazard']=dict(rule=RULE,source={k:p[k] for k in KEYS},coverage='complete',features=[dict(appearance='violet_hazard',azimuth=[-7.5,7.5],range_band='near')])
    return a,p,d,s,r


def next_packet(p,r,**changes):
    q=deepcopy(p);q['capture_us']+=250000;q['observation_id']+='n'
    q['hazard']['source']={k:q[k] for k in KEYS}
    r=deepcopy(r);r.update(executed_us=q['capture_us']-1,**changes)
    return q,r


class SafetyTests(unittest.TestCase):
    def test_binding_reject(self):
        a,p,d,s,r=packet();p['hazard']['source']['agent_id']='other'
        with self.assertRaises(ValueError):validate(p)
    def test_initial_knowledge_only_visible(self):
        a,p,d,s,r=packet();p['hazard']['features']=[]
        self.assertEqual(review(p)['mode'],'normal')
    def test_near_overrides_and_turn_step(self):
        a,p,d,s,r=packet();x=review(p,None,r)
        self.assertEqual(x['reason'],'safety_turn')
        q,r=next_packet(p,r,status='turned',yaw=x['action'][1]);q['hazard']['features']=[]
        self.assertEqual(review(q,x,r)['action'],['move',1])
    def test_bad_rotation_no_step(self):
        a,p,d,s,r=packet();x=review(p,None,r);q,r=next_packet(p,r,status='turned',yaw=0);q['hazard']['features']=[]
        self.assertNotEqual(review(q,x,r)['action'][0],'move')
    def test_wait_crossing(self):
        a,p,d,s,r=packet();p['hazard']['features'][0]['range_band']='watch'
        self.assertEqual(review(p,None,r)['reason'],'safety_wait_crossing')
    def test_partial_not_clear(self):
        a,p,d,s,r=packet();x=review(p,None,r);p['hazard'].update(coverage='partial',features=[])
        self.assertTrue(review(p,x,r)['override'])
    def test_missing_is_scan_not_release(self):
        a,p,d,s,r=packet();x=review(p,None,r);x['pending_step']=False;p['hazard']['features']=[]
        self.assertEqual(review(p,x,r)['reason'],'safety_scan')
    def test_four_measured_scans_clear(self):
        a,p,d,s,r=packet();x=review(p,None,r);x['pending_step']=False;p['hazard']['features']=[]
        x=review(p,x,r)
        for i in range(4):
            p,r=next_packet(p,r,status='turned',yaw=90);x=review(p,x,r)
            self.assertEqual(x['override'],i!=3)
        self.assertEqual(x['reason'],'limited_clearance')
    def test_far_requires_two_fresh_reviews(self):
        a,p,d,s,r=packet();x=review(p,None,r);p,r=next_packet(p,r);p['hazard']['features'][0]['range_band']='far'
        x=review(p,x,r);self.assertTrue(x['override'])
        p,r=next_packet(p,r);self.assertFalse(review(p,x,r)['override'])
    def test_budget_is_unresolved(self):
        a,p,d,s,r=packet();x=review(p,None,r);x['operations']=32
        self.assertEqual(review(p,x,r)['mode'],'safety_unresolved')
    def test_no_unknown_ground_escape(self):
        a,p,d,s,r=packet();p['movement_surface']['ground']['coverage']='partial'
        self.assertEqual(review(p,None,r)['action'],['wait',0])
    def test_route_interruption_no_failure_or_credit(self):
        a,p,d,s,r=packet();key=next(k for k,n in s['routes'].items() if n['goal']=='food');s['active']=key;s['trial_complete']=True
        d['day_cycle']['phase']='safety';before=deepcopy(s['routes'])
        out=routes(a,p,d,propose_only=True)['directional_routes']
        self.assertEqual(out['routes'],before);self.assertIsNone(out['active']);self.assertTrue(out['outbound']['overflow'])
    def test_goal_interruption_defer_idempotent(self):
        s=begin(initial('g'),'t',{'capture_us':0});s['trial']['interrupted_by_safety']=True
        x=finish(s,'t',False,True,'obs');self.assertEqual(x['H'],0);self.assertEqual(x['records']['t']['status'],'defer')
        self.assertEqual(finish(x,'t',False,True,'obs'),x)
    def test_measured_block_before_interruption_is_retained(self):
        a,p,d,s,r=packet();key=next(k for k,n in s['routes'].items() if n['goal']=='food')
        s.update(active=key,trial_complete=True,applied=True)
        r['status']='blocked';d['day_cycle']['phase']='safety'
        out=routes(a,p,d,propose_only=True)['directional_routes']
        self.assertEqual(out['comparison']['reason'],'actual_blocked_before_safety')
        self.assertEqual(out['routes'][key]['H'],s['routes'][key]['H']+1)
    def test_final_operations_reserved_for_observation(self):
        a,p,d,s,r=packet();x=review(p,None,r);x['operations']=16
        y=review(p,x,r)
        self.assertEqual(y['action'],['turn',90]);self.assertEqual(y['operations'],17)
    def test_real_success_not_suppressed(self):
        s=begin(initial('g'),'t',{'capture_us':0});s['trial']['interrupted_by_safety']=True
        self.assertEqual(finish(s,'t',True,True,'obs')['records']['t']['E'],0)
    def test_runtime_retry(self):
        from integrations.lightweight.timed_harvest import HarvestCampaign
        from integrations.lightweight.world import World
        from integrations.lightweight.moving_hazard import sample
        w=World('safe');c=HarvestCampaign('safe',1,mb_field_mode='enabled',harvest_state=True)
        for aid in w.agents:
            c.configure(dict(w.context(aid),schema=c.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id=aid+':t',source='god_statue',sample_observation=aid+':s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        a=c.agents['npc_a'];a.hazard_mode='enabled'
        p=w.packet('npc_a',8);p['hazard']=sample(w,p)
        x=c.observe(p);before=a.snapshot();self.assertEqual(c.observe(p)['command'],x['command']);self.assertEqual(a.snapshot(),before)
        op=x['command'];r=w.execute(op,p);self.assertEqual(w.execute(op,p),r)

if __name__=='__main__':unittest.main()
