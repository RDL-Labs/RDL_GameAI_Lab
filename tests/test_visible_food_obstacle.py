import unittest
from copy import deepcopy
from integrations.lightweight.visible_food_obstacle import FoodBarrierWorld, experiment, sight_blocked


class VisibleFoodObstacleTests(unittest.TestCase):
    def test_five_world_conditions(self):
        cases = experiment()['cases']
        self.assertEqual(cases['low_ready']['outcome'], 'harvested')
        self.assertEqual([r['action'] for r in cases['low_ready']['records']], ['walk','climb','pickup'])
        self.assertEqual(cases['low_ready']['records'][0]['receipt']['result']['status'], 'blocked')
        self.assertEqual(cases['low_recover']['outcome'], 'harvested')
        self.assertEqual([r['action'] for r in cases['low_recover']['records']], ['walk','rest','rest','climb','pickup'])
        self.assertTrue(cases['visible_too_high']['records'][0]['observation']['food_visible'])
        self.assertEqual(cases['visible_too_high']['outcome'], 'deferred')
        self.assertFalse(cases['occluded']['records'][0]['observation']['food_visible'])
        self.assertEqual(cases['occluded']['outcome'], 'deferred')
        self.assertEqual(cases['no_reserve']['outcome'], 'time_limit')
        self.assertEqual([r['action'] for r in cases['no_reserve']['records']], ['rest']*8)
        for name, case in cases.items():
            self.assertLessEqual(len(case['records']), 8)
            self.assertEqual(case['world_audit'], dict(stock=0,inventory=1) if name.startswith('low_') else dict(stock=1,inventory=0))

    def test_visible_near_food_cannot_be_taken_through_barrier(self):
        w = FoodBarrierWorld(); w.world.resources[0]['z']=1.2
        self.assertTrue(w.observe()['food_visible'])
        self.assertEqual(w.pickup('p')['result']['status'], 'inaccessible')
        self.assertEqual(w.world.resources[0]['stock'], 1)

    def test_pickup_replay_and_operation_conflict(self):
        w = FoodBarrierWorld(); other=deepcopy(w.world.agents['npc_b'])
        w.execute('npc_a','cross','climb',0)
        receipt=w.pickup('p'); clock=w.clock['npc_a']
        self.assertEqual(receipt['result']['status'],'picked_up')
        self.assertEqual(w.pickup('p'),receipt)
        self.assertEqual(w.clock['npc_a'],clock)
        self.assertEqual(w.world.agents['npc_a']['inventory'],1)
        self.assertEqual(w.world.agents['npc_b'],other)
        with self.assertRaises(ValueError): w.pickup('cross')
        with self.assertRaises(ValueError): w.execute('npc_a','p','walk',clock)

    def test_height_aware_occlusion_and_no_truth_coordinates(self):
        w=FoodBarrierWorld()
        o=w.world.objects[0]
        self.assertFalse(sight_blocked((0,0),(0,1.8),o))
        self.assertTrue(sight_blocked((0,0),(0,.7),o))
        obs=w.observe()
        self.assertNotIn('x',obs); self.assertNotIn('z',obs)
        self.assertNotIn('stock',obs)

    def test_recorded_fixture_replays(self):
        import json
        from pathlib import Path
        saved=json.loads(Path('tests/fixtures/visible_food_obstacle.json').read_text(encoding='utf8'))
        self.assertEqual(saved,experiment())
