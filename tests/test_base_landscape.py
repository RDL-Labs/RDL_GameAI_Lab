import unittest
from math import hypot
from integrations.lightweight.energy_exploration import EnergyWorld
from integrations.lightweight.base_landscape import install
from integrations.lightweight.ground_appearance import validate
from runtime.ground_pattern import recognize

class BaseLandscapeTests(unittest.TestCase):
    def world(self,seed=20261005):
        w=EnergyWorld('base',seed=seed);install(w);return w

    def test_seed_and_resource_placement(self):
        a=self.world();b=self.world();c=self.world(20261006)
        self.assertEqual(a.objects,b.objects);self.assertEqual(a.resources,b.resources)
        self.assertNotEqual(a.objects,c.objects)
        for w in (a,c):
            self.assertEqual(len(w.resources),10)
            self.assertEqual(w.landscape.material(0,6),'grassland')
            for r in w.resources:
                self.assertGreater(hypot(r['x'],r['z']-6),16)
                self.assertTrue(w.landscape.dry(r['x'],r['z']))
                self.assertTrue(all(hypot(r['x']-o['x'],r['z']-o['z'])>o['radius']+.5 for o in w.objects))

    def test_stream_continuity_and_local_observation(self):
        w=self.world();w.objects=[];w.ground_appearance_enabled=True
        for z in range(-58,70):
            x=w.landscape.river(z)
            self.assertEqual(w.landscape.material(x,z),'water')
        x=w.landscape.river(6)
        w.agents['npc_a'].update(x=x-1,z=6,yaw=90)
        p=w.packet('npc_a',8);validate(p['ground_appearance'],p)
        self.assertTrue(any(c['appearance']=='water' for c in p['ground_appearance']['cells']))
        self.assertNotIn('landscape',p);self.assertNotIn('resources',p)
        self.assertTrue(recognize(p)['groups'])
        self.assertTrue(all(c['clear'] for c in p['locomotor']['energy']['samples']))
        self.assertGreater(w.landscape.resistance(x,6),w.landscape.resistance(0,6))

    def test_water_never_accumulates_wear(self):
        w=self.world();x=w.landscape.river(6)
        w.ground_wear.walk('water','npc_a',(x-.2,6),(x+.2,6))
        self.assertEqual(w.ground_wear.cells,{})
        for i in range(30):w.ground_wear.walk(str(i),'npc_a',(x-3,6),(x+3,6))
        self.assertTrue(w.ground_wear.cells)
        # A boundary cell may contain dry shore samples; water samples add nothing.
        self.assertLess(sum(c['distance'] for c in w.ground_wear.cells.values()),180.)
        w.ground_wear_enabled=True;w.agents['npc_a'].update(x=x,z=6,yaw=0)
        self.assertEqual(w.resistance('npc_a'),3.)

    def test_crossing_has_body_cost_and_no_water_footprint(self):
        from integrations.lightweight.energy_exploration import EnergyCampaign
        w=self.world();w.objects=[];w.ground_wear_enabled=True
        x=w.landscape.river(6)
        w.agents['npc_a'].update(x=x-.25,z=6,yaw=90,inventory=0)
        loop=EnergyCampaign(w.run_id,1)
        loop.configure(dict(w.context('npc_a'),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',
            teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        packet=w.packet('npc_a',8);command=loop.observe(packet)['command']
        command=dict(command,kind='move',amount=.5)
        before=w.bodies['npc_a']['reserve']
        result=w.execute(command,packet)
        self.assertEqual(result['status'],'moved')
        self.assertAlmostEqual(before-w.bodies['npc_a']['reserve'],.3)
        self.assertEqual(w.ground_wear.cells,{})

    def test_checkpoint_does_not_silently_lose_stream(self):
        from integrations.lightweight.cohort_world import checkpoint,restore
        w=self.world();state=checkpoint(w,None,None,None,0)
        self.assertEqual(state['landscape']['rule'],'lw-riparian-base-v1')
        with self.assertRaisesRegex(ValueError,'landscape_checkpoint'):restore(w,None,None,None,state)

