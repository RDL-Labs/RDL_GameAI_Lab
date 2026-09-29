import unittest
from copy import deepcopy
from types import SimpleNamespace
from integrations.lightweight.world import World
from runtime.local_return import sample,validate,review
from runtime.incomplete_reposition import review as release

class LocalReturnTests(unittest.TestCase):
 def setup(self):
  w=World('return');a=w.agents['npc_a'];a.update(x=0.,z=4.,yaw=0.)
  p=w.packet('npc_a',128);p['dock']=sample(w,p)
  agent=SimpleNamespace(carried_count=lambda:1,unload_receipts={})
  state=dict(scans=0,operations=0,outcome=None,diagnostic=None,candidates=[])
  return w,p,agent,state
 def test_local_visibility_and_binding(self):
  w,p,a,s=self.setup();validate(p);self.assertTrue(p['dock']['visible']);self.assertFalse(p['dock']['in_reach'])
  w.agents['npc_a']['z']=-20;p=w.packet('npc_a',128);p['dock']=sample(w,p);self.assertFalse(p['dock']['visible'])
  p['dock']['source']['agent_id']='foreign'
  with self.assertRaises(ValueError):validate(p)
 def test_near_is_not_completion(self):
  w,p,a,s=self.setup();action,state=review(a,p,{'color':'ochre'},s,True,None)
  self.assertEqual(action,['move',1]);self.assertIsNone(state['outcome'])
  w.agents['npc_a']['z']=5;p=w.packet('npc_a',129);p['dock']=sample(w,p)
  action,state=review(a,p,{'color':'ochre'},s,True,None)
  self.assertEqual(action,['wait',0]);self.assertEqual(state['diagnostic'],'unload_attempt');self.assertIsNone(state['outcome'])
  a.carried_count=lambda:0;a.unload_receipts={'op':{'executed_us':32000001}}
  self.assertEqual(review(a,p,None,s,True,None)[1]['outcome'],'delivery_confirmed')
 def test_body_and_budget(self):
  w,p,a,s=self.setup()
  self.assertEqual(review(a,p,None,s,False,None)[1]['outcome'],'body_correspondence_unavailable')
  s['operations']=64
  self.assertEqual(review(a,p,None,s,True,None)[1]['diagnostic'],'approach_budget')
 def test_actual_unload_idempotence_and_no_night_auto_unload(self):
  w,p,a,s=self.setup();w.local_return=True;w.agents['npc_a']['z']=5;w.agents['npc_a']['inventory']=1
  w.pickups=[dict(agent_id='npc_a',operation_id='pick',executed_us=1)]
  p=w.packet('npc_a',128)
  c=dict(w.context('npc_a'),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],capture_us=p['capture_us'],pose_ref=p['pose_ref'],body_revision=p['body_revision'],expires_us=p['capture_us']+500000,kind='wait',amount=0,target_ref='',reason='return_unload_attempt')
  r=w.execute(c,p);self.assertEqual(w.execute(c,p),r);self.assertEqual(len(w.returns),1);self.assertEqual(w.agents['npc_a']['inventory'],0)
 def test_return_release_keeps_goal_and_respects_budget(self):
  from tests.test_incomplete_reposition import RepositionTests
  a,p,d,s=RepositionTests().setup();old=next(iter(a.decisions.values()));old['return_reposition']=old.pop('reposition')
  d['day_cycle']['phase']='return';d['reason']='return_search_no_candidate_after_scan'
  for x in p['movement_surface']['ground']['samples']:x.update(status='sampled',height_delta=0)
  r=release(a,p,d,key='return_reposition',phase='return',reasons=(d['reason'],),landmarks=True)
  self.assertTrue(r['return_reposition']['applied']);self.assertEqual(r['day_cycle']['phase'],'return')
  s['operations']=16
  self.assertFalse(release(a,p,d,key='return_reposition',phase='return',reasons=(d['reason'],),landmarks=True)['return_reposition']['applied'])

 def test_empty_arrival_needs_body_result(self):
  w,p,a,s=self.setup();a.carried_count=lambda:0
  w.agents['npc_a']['z']=5;p=w.packet('npc_a',129);p['dock']=sample(w,p)
  self.assertIsNone(review(a,p,None,s,True,None)[1]['outcome'])
  self.assertEqual(review(a,p,None,s,True,{'status':'waited'})[1]['outcome'],'home_like_observed')
 def test_reposition_step_is_not_undone_by_homing(self):
  w,p,a,s=self.setup()
  a.observations={'old':{'observation_id':'old'}}
  a.decisions={'old':{'return_reposition':{'pending_step':True,'day':0}}}
  out=review(a,p,{'color':'ochre'},s,True,{'status':'turned'})
  self.assertEqual(out[0],['wait',0]);self.assertEqual(out[1]['diagnostic'],'reposition_continue')
 def test_night_wait_does_not_deliver_in_new_mode(self):
  w,p,a,s=self.setup();w.local_return=True;w.agents['npc_a'].update(z=5,inventory=1)
  w.pickups=[dict(agent_id='npc_a',operation_id='pick',executed_us=1)]
  p=w.packet('npc_a',224)
  c=dict(w.context('npc_a'),operation_id='op:'+p['observation_id'],source_id=p['observation_id'],capture_us=p['capture_us'],pose_ref=p['pose_ref'],body_revision=p['body_revision'],expires_us=p['capture_us']+500000,kind='wait',amount=0,target_ref='',reason='day_night')
  w.execute(c,p);self.assertEqual(w.returns,[]);self.assertEqual(w.agents['npc_a']['inventory'],1)
