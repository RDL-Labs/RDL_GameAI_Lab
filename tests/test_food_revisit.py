import unittest
from copy import deepcopy
from types import SimpleNamespace
from integrations.lightweight.world import World
from runtime.initial_orientation import sample
from runtime.food_revisit import review, anchor

class FoodRevisitTests(unittest.TestCase):
    def setup(self, day=1):
        w=World('revisit');p=w.packet('npc_a',day*256+5);p['orientation']=sample(p,0)
        p['landmarks'].update(coverage='complete',features=[dict(ref='x',color='brown',azimuth=[-7.5,7.5],range_band='mid')])
        p['food'].update(coverage='complete',visible=[])
        for x in p['movement_surface']['ground']['samples']:x.update(status='sampled',height_delta=0)
        prev=deepcopy(p);prev['capture_us']-=250000;prev['observation_id']='previous'
        result=dict(operation_id='op:previous',status='waited',acquired=False,executed_us=p['capture_us']-1,after_pose_ref=p['pose_ref'],after_revision=p['body_revision'])
        memory=dict(anchors=[anchor(p,p['landmarks']['features'][0])],success='old-success',day=0)
        s=dict(rule='successful-landmark-food-revisit-v1',binding=['revisit','npc_a'],memory=memory,H=0,threshold=2,trail=[],trail_ids=[],trail_overflow=False,day=day,origin={'source':'home'},attempt=True,closed=False,cursor=0,operations=0,scans=0,selected=True)
        last=dict(food_revisit=s,day_cycle=dict(phase='exploration',return_state={}))
        a=SimpleNamespace(observations={'previous':prev},decisions={'previous':last},commands={'previous':{'operation_id':'op:previous'}},results={'op:previous':result},unload_receipts={})
        d=dict(action=['turn',90],target='',reason='landmark_active',day_cycle=dict(phase='exploration'),landmark={})
        return a,p,d,s,result

    def test_current_observation_guides_revisit_and_inputs_immutable(self):
        a,p,d,s,r=self.setup();before=deepcopy(s);out=review(a,p,d)
        self.assertEqual(out['action'],['move',1]);self.assertEqual(out['reason'],'food_revisit')
        self.assertEqual(s,before);self.assertEqual(d['action'],['turn',90])
        p['landmarks']['features'][0]['azimuth']=[22.5,37.5]
        self.assertEqual(review(a,p,d)['action'],['turn',30])

    def test_day_change_preserves_memory_and_selects_revisit(self):
        a,p,d,s,r=self.setup();s.update(day=0,attempt=False)
        a.decisions['previous']['day_cycle']['return_state']={'outcome':'home_like_observed'}
        out=review(a,p,d)['food_revisit'];self.assertEqual(out['memory'],s['memory']);self.assertTrue(out['attempt']);self.assertTrue(out['applied'])

    def test_no_home_no_success_no_revisit(self):
        for memory,home in [(None,True),({'anchors':[]},False)]:
            a,p,d,s,r=self.setup();s.update(day=0,attempt=False,memory=memory)
            if home:a.decisions['previous']['day_cycle']['return_state']={'outcome':'home_like_observed'}
            self.assertFalse(review(a,p,d)['food_revisit']['attempt'])

    def test_only_actual_acquisition_records_route(self):
        a,p,d,s,r=self.setup();s.update(memory=None,attempt=False,selected=False,trail=[anchor(p,p['landmarks']['features'][0])])
        self.assertIsNone(review(a,p,d)['food_revisit']['memory'])
        r['acquired']=True;out=review(a,p,d)['food_revisit'];self.assertEqual(out['memory']['success'],'op:previous')
        s['trail_overflow']=True;self.assertIsNone(review(a,p,d)['food_revisit']['memory'])

    def test_failure_once_then_exploration_and_threshold_persists(self):
        a,p,d,s,r=self.setup();s['operations']=48
        out=review(a,p,d);self.assertEqual(out['action'],d['action']);self.assertEqual(out['food_revisit']['H'],1)
        a.decisions['previous']['food_revisit']=out['food_revisit']
        self.assertEqual(review(a,p,d)['food_revisit']['H'],1)
        s=out['food_revisit'];s.update(H=2,day=0)
        a.decisions['previous']['day_cycle']['return_state']={'outcome':'home_like_observed'}
        self.assertFalse(review(a,p,d)['food_revisit']['attempt'])

    def test_incomplete_or_ambiguous_is_not_negative_evidence(self):
        a,p,d,s,r=self.setup();p['landmarks']['coverage']='partial'
        out=review(a,p,d)['food_revisit'];self.assertEqual(out['H'],0);self.assertIsNone(out['comparison']['E'])
        p['landmarks']['coverage']='complete';p['landmarks']['features']+=[dict(ref='y',color='brown',azimuth=[25,35],range_band='mid')]
        self.assertEqual(review(a,p,d)['food_revisit']['reason'],'landmark_ambiguous')

    def test_near_end_without_food_falls_back(self):
        a,p,d,s,r=self.setup();p['landmarks']['features'][0]['range_band']='near'
        out=review(a,p,d);self.assertEqual(out['food_revisit']['reason'],'route_end_without_food');self.assertEqual(out['action'],d['action'])

    def test_food_night_and_physical_gate(self):
        a,p,d,s,r=self.setup();d['action']=['pickup',0]
        self.assertEqual(review(a,p,d)['action'],['pickup',0])
        d['action']=['wait',0];d['day_cycle']['phase']='night'
        self.assertFalse(review(a,p,d)['food_revisit']['applied'])
        d['day_cycle']['phase']='exploration'
        for x in p['movement_surface']['ground']['samples']:x['status']='unavailable'
        self.assertFalse(review(a,p,d)['food_revisit']['applied'])

    def test_foreign_binding_and_missing_result(self):
        a,p,d,s,r=self.setup();a.results={}
        self.assertIsNone(review(a,p,d)['food_revisit']['comparison']['E'])
        s['binding'][1]='npc_b'
        with self.assertRaises(ValueError):review(a,p,d)

    def test_runtime_retry_keeps_revisit_state_and_command(self):
        from integrations.lightweight.timed_harvest import HarvestCampaign
        from runtime.local_return import sample as dock_sample
        w=World('revisit-runtime');loop=HarvestCampaign(w.run_id,1,harvest_state=True,mb_field_mode='enabled');aid='npc_a'
        a=loop.agents[aid];a.food_revisit_mode='enabled';a.orientation_mode='enabled';a.return_completion_mode='enabled'
        loop.configure(dict(w.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        for slot in range(24):
            p=w.packet(aid,slot);p['orientation']=sample(p,w.agents[aid]['yaw']);p['dock']=dock_sample(w,p)
            response=loop.observe(p);before=deepcopy(a.decisions[p['observation_id']]['food_revisit'])
            self.assertEqual(loop.observe(deepcopy(p))['command'],response['command'])
            self.assertEqual(a.decisions[p['observation_id']]['food_revisit'],before)
            loop.result(w.execute(response['command'],p))

    def test_partial_trial_deadline_defers(self):
        a,p,d,s,r=self.setup();s['food_complete']=False;d['day_cycle']['phase']='return'
        out=review(a,p,d)['food_revisit'];self.assertIsNone(out['comparison']['E']);self.assertEqual(out['H'],0)

if __name__=='__main__':unittest.main()
