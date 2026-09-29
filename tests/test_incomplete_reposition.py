import unittest
from copy import deepcopy
from types import SimpleNamespace
from runtime.incomplete_reposition import review
from integrations.lightweight.world import World

class RepositionTests(unittest.TestCase):
 def setup(self):
  w=World('r');p=w.packet('npc_a',8);old=w.packet('npc_a',7)
  c={'operation_id':'o','kind':'wait','amount':0}
  r=dict(after_pose_ref=p['pose_ref'],after_revision=p['body_revision'],executed_us=old['capture_us'],status='waited',yaw=0)
  state=dict(day=0,capture_us=old['capture_us'],residual=3,operations=0)
  a=SimpleNamespace(observations={'old':old},commands={old['observation_id']:c},results={'o':r},decisions={old['observation_id']:{'reposition':state}})
  d=dict(day_cycle={'phase':'exploration'},reason='acquisition_incomplete',action=['wait',0])
  return a,p,d,state
 def test_only_observed_directions_and_pure_replay(self):
  a,p,d,s=self.setup()
  for x in p['movement_surface']['ground']['samples']:x.update(status='blocked',height_delta=None)
  p['movement_surface']['ground']['samples'][2].update(status='sampled',height_delta=0)
  before=deepcopy((p,d,s));out=review(a,p,d)
  self.assertEqual(out['action'],['move',1]);self.assertEqual(out,review(a,p,d))
  self.assertEqual((p,d,s),before)
 def test_priority_body_and_budget(self):
  for gate in ('night','pickup','body','budget','missing'):
   a,p,d,s=self.setup()
   if gate=='night':d['day_cycle']['phase']='night'
   if gate=='pickup':d.update(action=['pickup',0],reason='reachable_food_work')
   if gate=='body':a.results={}
   if gate=='budget':s['operations']=16
   if gate=='missing':
    for x in p['movement_surface']['ground']['samples']:x.update(status='unavailable',height_delta=None)
   self.assertFalse(review(a,p,d)['reposition']['applied'])
 def test_turn_requires_fresh_forward_check(self):
  a,p,d,s=self.setup();s['pending_step']=True
  c=next(iter(a.commands.values()));c.update(kind='turn',amount=45)
  a.results['o'].update(status='turned',yaw=45)
  for x in p['movement_surface']['ground']['samples']:x.update(status='sampled',height_delta=0)
  out=review(a,p,d);self.assertEqual(out['action'],['move',1])
  p['movement_surface']['ground']['samples'][2].update(status='blocked',height_delta=None)
  self.assertNotEqual(review(a,p,d)['action'],['move',1])
 def test_decay_and_residual_bound(self):
  a,p,d,s=self.setup();s['residual']=100
  self.assertEqual(review(a,p,d)['reposition']['residual'],8)
  s['residual']=3;p['capture_us']+=10000000;d['reason']='other'
  self.assertEqual(review(a,p,d)['reposition']['residual'],0)
