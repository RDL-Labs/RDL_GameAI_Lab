from copy import deepcopy
import json
from pathlib import Path
import unittest
from runtime.layered_body import initial,capabilities,step
from integrations.lightweight.cargo_obstacle import CargoWorld,experiment,select


class CargoObstacleTests(unittest.TestCase):
    def loaded(self,count):
        w=CargoWorld(count)
        for i in range(count):w.execute_cargo('npc_a',str(i),'pickup')
        return w

    def test_five_six_actual_collision_and_rest_not_weight_loss(self):
        five=self.loaded(5);six=self.loaded(6)
        self.assertEqual(five.execute_cargo('npc_a','cross','climb')['status'],'performed')
        self.assertEqual(six.execute_cargo('npc_a','cross','climb')['status'],'blocked')
        six.execute_cargo('npc_a','rest','rest')
        self.assertEqual(six.execute_cargo('npc_a','retry','climb')['status'],'blocked')
        six.execute_cargo('npc_a','drop','drop')
        self.assertEqual(six.execute_cargo('npc_a','lighter','climb')['status'],'performed')
        self.assertEqual(six.audit(),dict(carried=5,ground=1,total_weight=6.))

    def test_movement_costs_increase_with_mass(self):
        for action in ('walk','run','climb'):
            costs=[]
            for load in (0.,1.,5.,6.):
                s,r=step(initial(),action,load=load)
                self.assertEqual(r['status'],'performed')
                costs.append(100-s['reserve'])
            self.assertEqual(costs,sorted(set(costs)))
        self.assertAlmostEqual(capabilities(initial(),5)['climb_height'],.4)
        self.assertLess(capabilities(initial(),6)['climb_height'],.4)

    def test_drop_replay_and_other_agent_pickup(self):
        w=self.loaded(6);r=w.execute_cargo('npc_a','drop','drop');state=w.audit()
        self.assertEqual(w.execute_cargo('npc_a','drop','drop'),r);self.assertEqual(w.audit(),state)
        with self.assertRaises(ValueError):w.execute_cargo('npc_a','drop','rest')
        self.assertEqual(w.execute_cargo('npc_b','retrieve','pickup')['status'],'picked_up')
        self.assertEqual(w.cargo['npc_b'],[1.]);self.assertEqual(w.audit()['total_weight'],6.)

    def test_repickup_reinstates_load_constraint(self):
        w=self.loaded(6);w.execute_cargo('npc_a','drop','drop')
        w.execute_cargo('npc_a','retrieve','pickup')
        self.assertEqual(w.execute_cargo('npc_a','try','climb')['status'],'blocked')
        self.assertEqual(w.audit()['ground'],0)

    def test_goal_changes_selection_same_observation(self):
        w=self.loaded(6);o=w.observe('npc_a');before=deepcopy(o)
        self.assertEqual(select(o,'return',True)['selected'],'detour')
        self.assertEqual(select(o,'escape',True)['selected'],'drop')
        self.assertEqual(o,before)

    def test_fatigue_and_damage_are_separate(self):
        cases=experiment()
        self.assertEqual([d['selected'] for d in cases['six_tired']['decisions']],['drop','rest','rest','rest','climb'])
        s=initial();s['damage']=.5
        self.assertLess(capabilities(s,0)['climb_height'],.4)
        for load in (-1,float('nan'),float('inf'),True):
            with self.assertRaises(ValueError):step(initial(),'rest',load=load)

    def test_saved_experiment(self):
        self.assertEqual(json.loads(Path('tests/fixtures/cargo_obstacle.json').read_text(encoding='utf8')),experiment())
