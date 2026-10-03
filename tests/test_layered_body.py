from copy import deepcopy
import unittest
from runtime.layered_body import initial,step,capabilities
from integrations.lightweight.body_fixture import BodyWorld,scenario


class LayeredBodyTests(unittest.TestCase):
    def test_burst_exhaustion_still_allows_walking(self):
        s=initial()
        for _ in range(3):s,r=step(s,'run');self.assertEqual(r['status'],'performed')
        s,r=step(s,'run');self.assertEqual(r['status'],'body_limited')
        s,r=step(s,'walk');self.assertEqual(r['status'],'performed')
        for _ in range(5):s,r=step(s,'rest')
        s,r=step(s,'run');self.assertEqual(r['status'],'performed')

    def test_reserve_needed_for_recovery_and_food_not_instant_burst(self):
        s=initial();s.update(reserve=0.,burst=0.,strain=.8)
        rested,r=step(s,'rest');self.assertEqual(rested,s)
        fed,r=step(s,'eat',food_available=True)
        self.assertEqual(fed['burst'],0);self.assertEqual(fed['reserve'],20)
        self.assertEqual(step(fed,'run')[1]['status'],'body_limited')
        for _ in range(2):fed,_=step(fed,'rest')
        self.assertEqual(step(fed,'run')[1]['status'],'performed')

    def test_sustained_load_recovers_and_damage_limits_geometry(self):
        s=initial()
        for _ in range(34):s,_=step(s,'walk')
        self.assertEqual(step(s,'walk')[1]['status'],'body_limited')
        s,_=step(s,'rest');self.assertTrue(capabilities(s)['can_walk'])
        s['damage']=.5
        self.assertEqual(capabilities(s)['climb_height'],.3)
        self.assertEqual(capabilities(s)['run_distance'],.75)

    def test_replay_conflict_and_individual_isolation(self):
        w=BodyWorld();before=deepcopy(w.states['npc_b'])
        r=w.execute('npc_a','x','run',0);snapshot=deepcopy(w.states)
        self.assertEqual(w.execute('npc_a','x','run',0),r)
        self.assertEqual(w.states,snapshot)
        self.assertEqual(w.states['npc_b'],before)
        with self.assertRaises(ValueError):w.execute('npc_a','x','walk',0)
        with self.assertRaises(ValueError):w.execute('npc_a','y','walk',0)

    def test_obstacle_height_and_landing_clearance(self):
        for height,radius,expected in ((.4,.1,'performed'),(2.,.1,'blocked'),(.4,.8,'blocked')):
            w=BodyWorld();a=w.world.agents['npc_a']
            w.world.objects=[dict(x=a['x'],z=a['z']+.5,radius=radius,height=height,solid=True)]
            self.assertEqual(w.execute('npc_a','x','climb',0)['result']['status'],expected)

    def test_food_consumed_once_and_missing_food(self):
        w=BodyWorld();a=w.world.agents['npc_a'];a['inventory']=1
        w.states['npc_a']['reserve']=20
        r=w.execute('npc_a','eat','eat',0)
        self.assertEqual(r['after']['reserve'],40);self.assertEqual(a['inventory'],0)
        w.execute('npc_a','eat','eat',0);self.assertEqual(a['inventory'],0)
        self.assertEqual(w.execute('npc_a','eat2','eat',1000000)['result']['status'],'no_food')

    def test_invalid_state_and_pure_input(self):
        s=initial();before=deepcopy(s);step(s,'run');self.assertEqual(s,before)
        for val in (float('nan'),-1,101):
            with self.assertRaises(ValueError):step(dict(s,reserve=val),'rest')

    def test_world_scenario(self):
        events=scenario()['events']
        self.assertTrue(any(e['result']['action']=='climb' and e['result']['status']=='performed' for e in events))
        self.assertTrue(any(e['result']['action']=='climb' and e['result']['status']=='blocked' for e in events))
        self.assertEqual(events[-1]['result']['status'],'performed')


if __name__=='__main__':unittest.main()
