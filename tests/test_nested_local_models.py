import unittest
from copy import deepcopy
from types import SimpleNamespace
from integrations.lightweight.world import World
from runtime.nested_local_models import update,review

class NestedModelTests(unittest.TestCase):
 def setup(self):
  w=World('nested');old=w.packet('npc_c',4);p=w.packet('npc_c',5)
  r=dict(operation_id='op:'+old['observation_id'],status='waited',acquired=False,after_pose_ref=p['pose_ref'],after_revision=p['body_revision'],executed_us=1000001)
  state=dict(rule='nested-local-mb-selection-v1',binding=['nested','npc_c'],nodes={'food/survey':dict(H=2,threshold=2,parent='food')},events=[],trial=dict(model='food/survey',question='view_changed',source=old['observation_id'],F=1))
  return old,p,r,state
 def test_residual_is_local_and_input_unchanged(self):
  old,p,r,s=self.setup();before=deepcopy(s)
  out=update(s,p,old,r,{})
  self.assertEqual(out['nodes']['food/survey']['H'],3);self.assertEqual(out['events'][-1]['E'],1);self.assertEqual(s,before)
  self.assertEqual(out,update(s,p,old,r,{}))
 def test_missing_body_defers_and_foreign_binding_rejects(self):
  old,p,r,s=self.setup();out=update(s,p,old,None,{})
  self.assertEqual(out['nodes']['food/survey']['H'],2);self.assertIsNone(out['events'][-1]['E'])
  p['agent_id']='npc_a'
  with self.assertRaises(ValueError):update(s,p,old,r,{})
 def test_changed_view_resolves_only_its_node(self):
  old,p,r,s=self.setup();s['nodes']['home/survey']=dict(H=7,threshold=2,parent='home')
  p['landmarks']['features']=[];old['landmarks']['features']=[dict(color='red',azimuth=[0,5],range_band='far')]
  out=update(s,p,old,r,{})
  self.assertEqual(out['nodes']['food/survey']['H'],0);self.assertEqual(out['nodes']['home/survey']['H'],7)
 def test_candidate_exhaustion_opens_release_without_new_budget(self):
  old,p,r,s=self.setup()
  a=SimpleNamespace(observations={'old':old},results={r['operation_id']:r},commands={old['observation_id']:{'operation_id':r['operation_id'],'kind':'wait','amount':0}},unload_receipts={},decisions={old['observation_id']:{'nested_models':s,'reposition':dict(day=0,capture_us=1000000,residual=3,operations=0)} })
  d=dict(action=['wait',0],reason='landmark_no_candidate_after_scan',day_cycle=dict(phase='exploration',food_goal=dict(goal_id='food',H=9,threshold=2)))
  out=review(a,p,d);self.assertTrue(out['nested_models']['selection']['applied']);self.assertIn(out['action'][0],('move','turn'))
  self.assertEqual(out['day_cycle'],d['day_cycle'])
  a.decisions[old['observation_id']]['reposition']['operations']=16
  self.assertFalse(review(a,p,d)['nested_models']['selection']['applied'])
 def test_priority_retains_pickup_and_night(self):
  old,p,r,s=self.setup();a=SimpleNamespace(observations={},results={},commands={},unload_receipts={},decisions={})
  for phase,reason,action in [('night','day_night',['wait',0]),('exploration','reachable_food_work',['pickup',0])]:
   d=dict(action=action,reason=reason,day_cycle=dict(phase=phase,food_goal=dict(goal_id='food',H=30,threshold=2)))
   out=review(a,p,d);self.assertEqual(out['action'],action);self.assertFalse(out['nested_models']['selection']['applied'])
 def test_trace_is_bounded(self):
  old,p,r,s=self.setup();s['events']=[{}]*32
  self.assertEqual(len(update(s,p,old,r,{})['events']),32)

 def test_arrival_does_not_substitute_for_unload(self):
  old,p,r,s=self.setup();s['trial']['question']='unloaded';r['status']='waited'
  p['dock']={'in_reach':True}
  out=update(s,p,old,r,{})
  self.assertEqual(out['events'][-1]['E'],1)
  out=update(s,p,old,r,{r['operation_id']:{}})
  self.assertEqual(out['events'][-1]['E'],0)
 def test_recovery_failure_is_a_separate_selection_cost(self):
  old,p,r,s=self.setup();s['nodes']['food/reposition']=dict(H=32,threshold=2,parent='food')
  a=SimpleNamespace(observations={'old':old},results={r['operation_id']:r},commands={old['observation_id']:{'operation_id':r['operation_id'],'kind':'wait'}},unload_receipts={},decisions={old['observation_id']:{'nested_models':s}})
  d=dict(action=['wait',0],reason='landmark_no_candidate_after_scan',day_cycle=dict(phase='exploration',food_goal=dict(goal_id='food',H=9,threshold=2)))
  out=review(a,p,d)
  self.assertFalse(out['nested_models']['selection']['applied']);self.assertEqual(out['nested_models']['selection']['contributions']['recovery_H'],16)

 def test_runtime_retry_does_not_add_comparisons(self):
  from integrations.lightweight.timed_harvest import HarvestCampaign
  w=World('nested-runtime');loop=HarvestCampaign(w.run_id,1,harvest_state=True,mb_field_mode='enabled');aid='npc_a'
  loop.agents[aid].nested_model_mode='enabled'
  loop.configure(dict(w.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
  for slot in range(16):
   p=w.packet(aid,slot);first=loop.observe(p);before=deepcopy(loop.agents[aid].decisions[p['observation_id']]['nested_models'])
   self.assertEqual(loop.observe(deepcopy(p))['command'],first['command'])
   self.assertEqual(loop.agents[aid].decisions[p['observation_id']]['nested_models'],before)
   loop.result(w.execute(first['command'],p))
