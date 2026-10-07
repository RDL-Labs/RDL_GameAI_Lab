import unittest
from integrations.lightweight.ground_wear import GroundWear
class WearTests(unittest.TestCase):
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
