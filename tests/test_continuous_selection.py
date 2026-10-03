import unittest
from copy import deepcopy
from tests.test_moving_hazard_safety import packet
from runtime.continuous_selection import review
from runtime.moving_hazard_safety import review as safety_review,KEYS


def context(phase='safety'):
    a,p,d,s,r=packet();d['day_cycle']['phase']=phase;d['action']=['wait',0];d['reason']='safety_budget'
    d['safety']=dict(mode='safety_active',override=True,generation=1,operations=100,reason='safety_budget')
    a.commands['previous'].update(kind='wait',amount=0);r['yaw']=0
    return a,p,d,r


def tick(a,p,d,r):
    a.observations={p['observation_id']:deepcopy(p)};a.decisions={p['observation_id']:deepcopy(d)}
    a.commands={p['observation_id']:dict(operation_id='op:'+p['observation_id'],kind=d['action'][0],amount=d['action'][1])}
    a.results={'op:'+p['observation_id']:dict(r,operation_id='op:'+p['observation_id'],executed_us=p['capture_us']+1,
        status={'wait':'waited','turn':'turned','move':'moved'}[d['action'][0]],yaw=d['action'][1] if d['action'][0]=='turn' else 0)}
    p=deepcopy(p);p['observation_id']+='x';p['capture_us']+=250000;p['hazard']['source']={k:p[k] for k in KEYS}
    return p


class ContinuousTests(unittest.TestCase):
    def test_alternating_scan_does_not_claim_full_clearance(self):
        a,p,d,r=context();p['hazard'].update(features=[],coverage='complete')
        old=dict(mode='safety_active',generation=1,operations=100,started_us=0,clear_yaw=0,far_count=0,clearance_scan=True)
        for yaw in (90,-90,90,-90):
            r.update(status='turned',yaw=yaw)
            old=safety_review(p,old,r,continuous=True);old['clearance_scan']=True
            self.assertNotEqual(old['mode'],'normal')
        self.assertEqual(old['clear_yaw'],0)

    def test_runtime_retry_preserves_method_state(self):
        from integrations.lightweight.world import World
        from integrations.lightweight.timed_harvest import HarvestCampaign
        w=World('continuous-retry');loop=HarvestCampaign(w.run_id,1,harvest_state=True,mb_field_mode='enabled');aid='npc_a'
        loop.agents[aid].continuous_selection=True
        loop.configure(dict(w.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        for slot in range(16):
            p=w.packet(aid,slot);first=loop.observe(p)
            before=deepcopy(loop.agents[aid].decisions[p['observation_id']]['continuous_selection'])
            self.assertEqual(loop.observe(deepcopy(p))['command'],first['command'])
            self.assertEqual(loop.agents[aid].decisions[p['observation_id']]['continuous_selection'],before)
            loop.result(w.execute(first['command'],p))

    def test_safety_not_terminal_after_old_budget(self):
        a,p,d,r=context();old=dict(mode='safety_active',generation=1,operations=100,started_us=0,clear_yaw=0,far_count=0)
        self.assertEqual(safety_review(p,old,r)['mode'],'safety_unresolved')
        self.assertNotEqual(safety_review(p,old,r,continuous=True)['mode'],'safety_unresolved')

    def test_repeated_no_progress_changes_method_but_keeps_selecting(self):
        a,p,d,r=context();methods=[]
        for _ in range(140):
            out=review(a,p,d);methods.append(out['continuous_selection']['selected'])
            self.assertTrue(out['continuous_selection']['candidates'])
            p=tick(a,p,out,r)
        self.assertGreater(len(set(methods)),2)
        self.assertGreater(out['safety']['operations'],32)
        self.assertLessEqual(len(out['continuous_selection']['events']),32)
        self.assertTrue(any(n['H']>=n['threshold'] for n in out['continuous_selection']['nodes'].values()))

    def test_unknown_surface_does_not_become_move(self):
        a,p,d,r=context()
        for x in p['movement_surface']['ground']['samples']:x['status']='unavailable'
        out=review(a,p,d)
        self.assertTrue(all(c['action'][0]!='move' and 'step_' not in c['model'] for c in out['continuous_selection']['candidates']))

    def test_body_gate(self):
        a,p,d,r=context();r['after_pose_ref']='bad';out=review(a,p,d)
        self.assertEqual(out['action'],['wait',0]);self.assertEqual(out['continuous_selection']['gate'],'body_unlinked')

    def test_partial_clearance_is_missing_evidence_not_safe(self):
        a,p,d,r=context();out=review(a,p,d)
        out['continuous_selection']['trial']['question']='clearance_evidence'
        p=tick(a,p,out,r);p['hazard'].update(features=[],coverage='partial')
        out=review(a,p,d)
        self.assertEqual(out['continuous_selection']['events'][-1]['F_prime'],0)

    def test_exploration_and_return_budget_wait_are_proposals_only(self):
        for phase in ('exploration','return'):
            a,p,d,r=context(phase);d['reason']='landmark_goal_budget' if phase=='exploration' else 'return_approach_budget'
            out=review(a,p,d)
            self.assertNotEqual(out['action'][0],'wait')
            self.assertGreater(len(out['continuous_selection']['candidates']),1)

    def test_night_rest_remains_selected_wait(self):
        a,p,d,r=context('night');d['reason']='day_night'
        out=review(a,p,d);p=tick(a,p,out,r);out=review(a,p,d)
        self.assertEqual(out['action'],['wait',0]);self.assertEqual(out['continuous_selection']['events'][-1]['E'],0)

    def test_pickup_and_unload_preserved(self):
        a,p,d,r=context('exploration');d.update(action=['pickup',0],target='observed-food',reason='reachable_food_work')
        out=review(a,p,d);self.assertEqual(out['target'],'observed-food');self.assertEqual(out['action'],['pickup',0])
        d['day_cycle']['phase']='return';d.update(action=['wait',0],reason='return_unload_attempt')
        self.assertEqual(review(a,p,d)['reason'],'return_unload_attempt')

    def test_no_false_route_credit_and_no_input_mutation(self):
        a,p,d,r=context();before=deepcopy(d);out=review(a,p,d)
        self.assertEqual(d,before);self.assertEqual(out['directional_routes']['routes'],d['directional_routes']['routes'])
        self.assertTrue(out['directional_routes']['outbound']['overflow'])

    def test_binding_rejected(self):
        a,p,d,r=context();out=review(a,p,d);p=tick(a,p,out,r);p['agent_id']='other'
        with self.assertRaises(ValueError):review(a,p,d)

    def test_successful_turn_step_rechecks_current_surface(self):
        a,p,d,r=context('exploration');out=review(a,p,d)
        # Force one eligible rotation through the normal scoring path.
        for x in p['movement_surface']['ground']['samples']:
            if x['direction_deg']!=-90:x['status']='unavailable'
        out=review(a,p,d);self.assertEqual(out['action'],['turn',-90]);p=tick(a,p,out,r)
        for x in p['movement_surface']['ground']['samples']:x.update(status='sampled',height_delta=0)
        out=review(a,p,d);self.assertEqual(out['action'],['move',1])


if __name__=='__main__':unittest.main()
