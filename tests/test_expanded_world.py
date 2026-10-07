import unittest
from copy import deepcopy
from math import hypot
from integrations.lightweight.energy_exploration import EnergyWorld
from integrations.lightweight.expanded_world import extend


class ExpandedTests(unittest.TestCase):
    def world(self,seed=1):
        w=EnergyWorld('w',seed=seed);w.objects=[dict(x=0.,z=8.,radius=.3,height=12.,solid=True,color='ochre')]
        w.resources=[dict(x=-.4,z=6.8,stock=6),dict(x=.4,z=6.8,stock=6)]
        return w

    def test_extent_and_preserved_camp(self):
        w=self.world();before=deepcopy((w.objects,w.resources,w.agents));extend(w)
        self.assertEqual(w.objects[:1],before[0]);self.assertEqual(w.agents,before[2])
        self.assertEqual([r['stock'] for r in w.resources[:2]],[r['stock'] for r in before[1]])
        self.assertEqual([(r['x'],r['z']) for r in w.resources[:2]],[(-18.,6.),(18.,6.)])
        self.assertEqual(len(w.resources),10);self.assertEqual(len(w.objects),25)
        self.assertEqual([round(hypot(r['x'],r['z']-6)) for r in w.resources[2:]],[16,24,32,40,56,64,80,96])
        for r in w.resources:
            self.assertTrue(all(hypot(r['x']-o['x'],r['z']-o['z'])>o['radius'] for o in w.objects))

    def test_seed_replay_and_local_observation(self):
        a=self.world();b=self.world();c=self.world(2)
        for w in (a,b,c):extend(w)
        self.assertEqual(a.objects,b.objects);self.assertEqual(a.resources,b.resources)
        self.assertNotEqual(a.objects,c.objects)
        a.agents['npc_a'].update(x=0,z=6,yaw=0)
        p=a.packet('npc_a',8)
        self.assertTrue(all(x['distance']<=12 for x in p['food']['visible']))
        self.assertTrue(all(i<2 for i in a.tokens['npc_a'].values()))
        self.assertNotIn('resources',p)

    def test_no_food_visible_any_heading_in_camp_but_visible_on_approach(self):
        w=self.world();extend(w)
        for x,z in ((0,6),(-.25,5.8),(0,5.8),(.25,5.8),(1.25,6),(-1.25,6),(0,7.25),(0,4.75)):
            for yaw in range(-180,180,15):
                w.agents['npc_a'].update(x=x,z=z,yaw=yaw)
                self.assertEqual(w.packet('npc_a',8)['food']['visible'],[])
        w.objects=[] # Sensor-range control, independent of occluder placement.
        w.agents['npc_a'].update(x=-18,z=5,yaw=0)
        self.assertTrue(w.packet('npc_a',9)['food']['visible'])
