import unittest
from integrations.lightweight.ground_wear import GroundWear
class WearTests(unittest.TestCase):
 def test_ordinary_ground_has_wear_discount_and_matching_body_cost(self):
  from copy import deepcopy
  from integrations.lightweight.energy_exploration import EnergyWorld
  from runtime.layered_body import step
  for worn,expected in ((False,1.5),(True,1.25)):
   w=EnergyWorld('ordinary');w.ground_wear_enabled=True;w.objects=[]
   w.agents['npc_a'].update(x=.5,z=.1,yaw=0.,inventory=0)
   if worn:
    for i in range(20):w.ground_wear.walk(str(i),'npc_b',(.1,.5),(.9,.5))
   p=w.packet('npc_a',8)
   resistance=next(s['resistance'] for s in p['locomotor']['energy']['samples'] if s['angle']==0)
   self.assertAlmostEqual(resistance,expected)
   before=deepcopy(w.bodies['npc_a'])
   c=dict(w.context('npc_a'),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],capture_us=p['capture_us'],expires_us=p['capture_us']+1500000,pose_ref=p['pose_ref'],body_revision=p['body_revision'],kind='move',amount=.5,reason='test',target_ref='')
   self.assertEqual(w.execute(c,p)['status'],'moved')
   after,_=step(before,'walk',load=0,resistance=resistance)
   self.assertEqual(w.bodies['npc_a'],after)
   w.ground_wear.recovery_enabled=True;w.ground_wear.advance(20*64000000)
   self.assertEqual(w.resistance('npc_a'),1.5)
 def test_unused_ground_recovers_but_history_and_replay_remain(self):
  w=GroundWear();w.recovery_enabled=True
  w.walk('a','a',(.1,.5),(.9,.5));raw=w.snapshot()['cells']['0,0']['distance']
  w.advance(64000000);self.assertAlmostEqual(w.cells['0,0']['wear'],raw)
  w.advance(128000000);self.assertEqual(w.factor(.5,.5),1.)
  self.assertEqual(w.cells['0,0']['distance'],raw)
  w.walk('a','a',(.1,.5),(.9,.5));self.assertEqual(w.cells['0,0']['wear'],0)
  w.walk('b','b',(.1,.5),(.9,.5));self.assertGreater(w.cells['0,0']['wear'],0)
  with self.assertRaises(ValueError):w.advance(0)
 def test_clock_partition_and_continued_use(self):
  a=GroundWear();b=GroundWear()
  for w in (a,b):
   w.recovery_enabled=True;w.walk('a','a',(.1,.5),(.9,.5))
  a.advance(80000000);a.advance(90000000);b.advance(90000000)
  self.assertAlmostEqual(a.cells['0,0']['wear'],b.cells['0,0']['wear'])
  before=a.snapshot();a.advance(90000000);self.assertEqual(a.snapshot(),before)
  a.walk('b','b',(.1,.5),(.9,.5));a.advance(130000000)
  self.assertGreater(a.cells['0,0']['wear'],b.cells['0,0']['wear'])

 def test_world_actual_effect_and_observation(self):
  from integrations.lightweight.energy_exploration import EnergyWorld
  w=EnergyWorld('w');w.ground_wear_enabled=True;w.objects=[]
  w.agents['npc_a'].update(x=-1.,z=0.,yaw=0.,inventory=0)
  p=w.packet('npc_a',8)
  c=dict(w.context('npc_a'),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],capture_us=p['capture_us'],expires_us=p['capture_us']+1500000,pose_ref=p['pose_ref'],body_revision=p['body_revision'],kind='move',amount=.5,reason='test',target_ref='')
  self.assertEqual(w.execute(c,p)['status'],'moved');before=w.ground_wear.snapshot()
  w.execute(c,p);self.assertEqual(before,w.ground_wear.snapshot())
  self.assertAlmostEqual(sum(x['distance'] for x in before['cells'].values()),.5)
  w.agents['npc_b'].update(x=-1.,z=0.,yaw=0.)
  observed=w.packet('npc_b',8)['locomotor']['energy']['samples']
  self.assertLess(next(x['resistance'] for x in observed if x['angle']==0),5)
  w2=EnergyWorld('w2');w2.ground_wear_enabled=True;w2.objects=[];w2.agents['npc_a'].update(x=-1.,z=0.,yaw=0.)
  q=w2.packet('npc_a',8);c.update(w2.context('npc_a'),operation_id='op:'+q['observation_id'],source_id=q['observation_id'],capture_us=q['capture_us'],expires_us=q['capture_us']+1500000,pose_ref=q['pose_ref'],body_revision=q['body_revision'],kind='wait',amount=0)
  w2.execute(c,q);self.assertFalse(w2.ground_wear.cells)

 def test_distance_shared_replay_and_stationary(self):
  w=GroundWear();w.walk('a','a',(0.1,.5),(.9,.5));w.walk('b','b',(.9,.5),(.1,.5))
  self.assertAlmostEqual(sum(c['distance'] for c in w.cells.values()),1.6)
  self.assertEqual(set(w.cells['0,0']['agents']),{'a','b'})
  before=w.snapshot();w.walk('a','a',(.1,.5),(.9,.5));self.assertEqual(before,w.snapshot())
  w.walk('c','a',(0,0),(0,0));self.assertEqual(before,w.snapshot())
  with self.assertRaises(ValueError):w.walk('a','a',(0,0),(1,1))
 def test_path_not_only_destination_and_saturation(self):
  w=GroundWear();w.walk('a','a',(-2,.5),(2,.5));self.assertEqual(len(w.cells),4)
  for i in range(20):w.walk(str(i),'b',(.1,.5),(.9,.5))
  self.assertEqual(w.factor(.5,.5),.5);self.assertEqual(w.factor(100,100),1)
  s=w.snapshot();s['cells'].clear();self.assertTrue(w.cells)
if __name__=='__main__':unittest.main()
