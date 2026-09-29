import unittest
from copy import deepcopy
from integrations.lightweight.world import World
from runtime.terrain_resource_exploration import terrain_input
from runtime.subjective_movement_terrain import calculate_terrain
from runtime.approach_movement_field import approach_field

class ApproachFieldTests(unittest.TestCase):
    def fixture(self):
        w=World();w.objects=[];a=w.agents['npc_a'];w.resources=[dict(x=a['x'],z=a['z']+5,stock=12)]
        p=w.packet('npc_a',4)
        p['movement_surface']['obstacles']['items']=[dict(ref='seen-obstacle',forward=3.,right=1.)]
        return p,calculate_terrain(terrain_input(p,'brown_capped_ovoid'))

    def test_reweights_only_soft_obstacle_and_preserves_input(self):
        p,t=self.fixture();before=deepcopy(t);out=approach_field(t,p)
        self.assertEqual(t,before);self.assertTrue(out['approach_field']['applied'])
        for a,b in zip(t['directional_samples'],out['directional_samples']):
            self.assertEqual(b['obstacle'],a['obstacle']*.1)
            self.assertEqual(b['physical'],a['physical']);self.assertEqual(b['food'],a['food'])
            self.assertEqual(b['source_contributions'],a['source_contributions'])

    def test_blocked_direction_not_revived(self):
        p,_=self.fixture();p['movement_surface']['ground']['samples'][2].update(status='blocked',height_delta=None)
        t=calculate_terrain(terrain_input(p,'brown_capped_ovoid'));out=approach_field(t,p)
        self.assertEqual(out['directional_samples'][2],t['directional_samples'][2])
        self.assertNotIn(0,out['minimum_directions'])

    def test_incomplete_or_disappeared_target_keeps_original(self):
        p,t=self.fixture()
        for change in ('missing','partial'):
            q=deepcopy(p)
            if change=='missing':q['food']['visible']=[]
            else:q['food']['coverage']='partial'
            out=approach_field(t,q);self.assertFalse(out['approach_field']['applied'])
            out.pop('approach_field');self.assertEqual(out,t)

    def test_model_cost_is_preserved(self):
        p,t=self.fixture()
        for r in t['directional_samples']:r['model_field_cost']=-.2;r['total']-=.2
        out=approach_field(t,p)
        for r in out['directional_samples']:
            self.assertAlmostEqual(r['total'],r['physical']+r['food']+r['obstacle']-.2)
