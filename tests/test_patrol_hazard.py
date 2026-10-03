import unittest
from copy import deepcopy
from integrations.lightweight.patrol_hazard import PatrolHazard,sample_pair
from integrations.lightweight.world import World
from runtime.moving_hazard_safety import validate,review,MULTI_RULE
from runtime.continuous_selection import review as select
from tests.test_continuous_selection import context


class PatrolTests(unittest.TestCase):
    def test_clock_speed_replay(self):
        h=PatrolHazard();a=h.advance(0);b=h.advance(250000)
        self.assertAlmostEqual(b['position']['x']-a['position']['x'],.375)
        self.assertEqual(h.advance(250000),b)
        with self.assertRaises(ValueError):h.advance(0)
        with self.assertRaises(ValueError):h.advance(1000000)

    def test_collision_changes_heading_without_crossing(self):
        h=PatrolHazard();h.advance(0)
        obstacle=dict(x=-11.5,z=-8,radius=.5,solid=True)
        b=h.advance(250000,[obstacle])
        self.assertTrue(b['blocked']);self.assertEqual(b['position']['x'],-12)
        self.assertEqual(b['heading'],90)

    def test_two_visual_records_no_world_identity(self):
        w=World('two');w.objects=[];aid='npc_a';w.agents[aid].update(x=0,z=0,yaw=0)
        p=w.packet(aid,1);h=sample_pair(w,p,[dict(x=-1,z=3),dict(x=1,z=3)])
        p['hazard']=h;validate(p);self.assertEqual(len(h['features']),2)
        self.assertTrue(all(set(f)=={'appearance','azimuth','range_band'} for f in h['features']))
        with self.assertRaises(ValueError):sample_pair(w,p,[{}, {}, {}])

    def test_nearer_threat_prevents_far_release_regardless_of_order(self):
        a,p,d,r=context();near=p['hazard']['features'][0];far=dict(near,range_band='far')
        p['hazard'].update(rule=MULTI_RULE,features=[far,near])
        x=review(p,None,r,continuous=True)
        self.assertTrue(x['override']);self.assertEqual(x['far_count'],0)
        p['hazard']['features'].reverse()
        self.assertEqual(review(p,None,r,continuous=True),x)

    def test_selection_uses_both_threats_order_independently(self):
        a,p,d,r=context();p['hazard'].update(rule=MULTI_RULE,features=[dict(appearance='violet_hazard',azimuth=[-85,-75],range_band='near'),dict(appearance='violet_hazard',azimuth=[75,85],range_band='near')])
        x=select(a,p,d);p['hazard']['features'].reverse();y=select(a,p,d)
        self.assertEqual(x['action'],y['action'])
        self.assertEqual(x['continuous_selection']['candidates'],y['continuous_selection']['candidates'])
        p['hazard']['features'].append(deepcopy(p['hazard']['features'][0]))
        with self.assertRaises(ValueError):validate(p)


if __name__=='__main__':unittest.main()
