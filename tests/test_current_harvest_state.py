from copy import deepcopy
import unittest
from runtime.current_harvest_state import assess
from test_model_movement_field import CampaignSession
from test_resource_exploration import material


class CurrentHarvestTests(unittest.TestCase):
    def test_complete_absence_and_partial_unknown_are_distinct(self):
        s=CampaignSession('enabled')
        for complete,expected in ((True,'none_observed'),(False,'unknown')):
            p=s.packet(False,complete)
            self.assertEqual(assess(p,'brown_capped_ovoid',[])['status'],expected)

    def test_far_food_is_not_absent_or_reachable(self):
        s=CampaignSession('enabled');p=s.packet()
        p['food']['visible']=[material(distance=5)]
        r=assess(p,'brown_capped_ovoid',[])
        self.assertEqual(r['status'],'visible_out_of_reach')
        self.assertEqual(r['reachable_refs'],[])
        p['food']['visible']=[material(distance=1.25)]
        self.assertEqual(assess(p,'brown_capped_ovoid',[])['status'],'reachable_observed')

    def test_partial_food_even_with_visible_items_does_not_claim_complete(self):
        s=CampaignSession('enabled');p=s.packet(complete=False)
        r=assess(p,'brown_capped_ovoid',[])
        self.assertEqual(r['status'],'unknown')
        self.assertTrue(r['visible_refs'])

    def test_last_pickup_preserves_success_but_does_not_resurrect_prediction(self):
        s=CampaignSession('enabled');s.loop.harvest_state=True;s.learn()
        before=deepcopy(s.loop.learning['admission']);model=s.loop.model.to_json()
        p=s.packet(False);c,_=s.apply(p)
        d=s.loop.decisions[p['observation_id']]
        self.assertEqual(d['current_harvest']['status'],'none_observed')
        self.assertEqual(d['current_harvest']['historical_success']['count'],6)
        self.assertNotEqual(c['kind'],'pickup')
        self.assertIsNone(d['approach'])
        self.assertTrue(s.loop.learning['invalidated'])
        self.assertEqual(before,s.loop.learning['admission'])
        self.assertEqual(model,s.loop.model.to_json())
        self.assertEqual(s.loop.learning['comparisons'][-1]['prediction_difference'],
                         dict(acquired=0,affordance_persists=-1))

    def test_new_observation_replaces_absence_without_claiming_regrowth(self):
        s=CampaignSession('enabled');s.loop.harvest_state=True
        s.apply(s.packet(False));p=s.packet();s.apply(p)
        self.assertEqual(s.loop.decisions[p['observation_id']]['current_harvest']['status'],'reachable_observed')
        self.assertEqual(s.loop.decisions[p['observation_id']]['current_harvest']['source']['observation_id'],p['observation_id'])

    def test_opt_in_is_nonintervening_and_replay_does_not_add_experience(self):
        a=CampaignSession('enabled');b=CampaignSession('enabled');b.loop.harvest_state=True
        for food in (False,True,True,True,True,True,True,False):
            pa=a.packet(food);pb=b.packet(food)
            self.assertEqual(a.apply(pa),b.apply(pb))
        self.assertEqual(a.loop.learning,b.loop.learning)
        self.assertNotIn('current_harvest',a.loop.decisions[pa['observation_id']])
        before=b.loop.snapshot();b.multi.observe(pb)
        self.assertEqual(before,b.loop.snapshot())
        self.assertEqual(b.multi.agents['npc_b'].learning['records'],[])

    def test_result_does_not_alias_packet_or_records(self):
        s=CampaignSession('enabled');p=s.packet();before=deepcopy(p)
        r=assess(p,'brown_capped_ovoid',[]);r['visible_refs'].clear();r['source']['pose_ref']='changed'
        self.assertEqual(p,before)
