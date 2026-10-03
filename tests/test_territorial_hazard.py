import unittest
from integrations.lightweight.territorial_hazard import TerritorialHazard
from integrations.lightweight.world import World
from integrations.lightweight.moving_hazard import sample
from runtime.moving_hazard_safety import validate,review


class TerritoryTests(unittest.TestCase):
    def test_three_inside_layout_preserves_stock(self):
        from integrations.lightweight.territorial_hazard import resource_layout
        from math import hypot
        w=World(seed=20261001,layout='sparse');stock=[r['stock'] for r in w.resources]
        before=[dict(r) for r in w.resources];resource_layout(w)
        self.assertEqual(w.resources,before)
        resource_layout(w,'three_inside')
        self.assertEqual([r['stock'] for r in w.resources],stock)
        self.assertEqual([i for i,r in enumerate(w.resources) if hypot(r['x']+20,r['z']+2)<=8],[0,1,3])
        with self.assertRaises(ValueError):resource_layout(w,'other')

    def test_idle(self):
        h=TerritorialHazard(center=(0,0),home=(0,0))
        self.assertEqual(h.advance(0,{'a':dict(x=9,z=0)})['mode'],'idle')

    def test_approach_warning_exit_home(self):
        h=TerritorialHazard(center=(0,0),home=(0,0));agents={'a':dict(x=6,z=0)}
        history=[h.advance(i*250000,agents) for i in range(10)]
        self.assertEqual(history[0]['mode'],'approaching');self.assertEqual(history[-1]['mode'],'warning')
        self.assertEqual(history[-1]['position']['x'],3)
        agents['a']['x']=20
        back=[h.advance(i*250000,agents) for i in range(10,20)]
        self.assertEqual(back[0]['mode'],'returning');self.assertEqual(back[-1]['mode'],'idle')
        self.assertEqual(back[-1]['position']['x'],0)

    def test_leash(self):
        h=TerritorialHazard(center=(0,0),home=(0,0),radius=20,leash=2)
        history=[h.advance(i*250000,{'a':dict(x=10,z=0)}) for i in range(12)]
        self.assertTrue(any(x['mode']=='returning' for x in history))
        self.assertLessEqual(max(x['position']['x'] for x in history),2)

    def test_target_lock_and_order(self):
        agents={'b':dict(x=-7,z=0),'a':dict(x=7,z=0)}
        h=TerritorialHazard(center=(0,0),home=(0,0));self.assertEqual(h.advance(0,agents)['target'],'a')
        agents['b']['x']=-1
        self.assertEqual(h.advance(250000,agents)['target'],'a')

    def test_replay_and_clock(self):
        h=TerritorialHazard();a={'a':dict(x=-20,z=-2)};r=h.advance(0,a)
        r['position']['x']=999
        self.assertNotEqual(h.advance(0,a),r)
        with self.assertRaises(ValueError):h.advance(-1,a)
        with self.assertRaises(ValueError):h.advance(500000,a)

    def test_solid_blocks_body(self):
        h=TerritorialHazard(center=(0,0),home=(0,0));a={'a':dict(x=7,z=0)}
        obstacles=[dict(x=1,z=0,radius=.5,solid=True)]
        h.advance(0,a,obstacles);r=h.advance(250000,a,obstacles)
        self.assertTrue(r['blocked']);self.assertEqual(r['position']['x'],0)

    def test_warning_observation_bounded(self):
        w=World();w.objects=[];p=w.packet('npc_a',0)
        obj=dict(x=-2,z=6,radius=.5,display='warning',target='secret',territory='secret')
        p['hazard']=sample(w,p,object_state=obj);validate(p)
        self.assertEqual(p['hazard']['features'][0]['appearance'],'violet_warning')
        self.assertNotIn('secret',str(p['hazard']))
        self.assertTrue(review(p)['override'])

    def test_unseen_does_not_reveal_intrusion(self):
        w=World();w.objects=[];p=w.packet('npc_a',0)
        p['hazard']=sample(w,p,object_state=dict(x=-2,z=-8,display='warning'))
        self.assertEqual(p['hazard']['features'],[]);self.assertEqual(review(p)['mode'],'normal')

    def test_occluded_warning_not_visible(self):
        w=World();w.objects=[dict(x=-2,z=5,radius=.5,height=3,solid=True,color='gray')];p=w.packet('npc_a',0)
        p['hazard']=sample(w,p,object_state=dict(x=-2,z=7,display='warning'))
        self.assertEqual(p['hazard']['features'],[]);self.assertEqual(p['hazard']['coverage'],'partial')


if __name__=='__main__':unittest.main()
