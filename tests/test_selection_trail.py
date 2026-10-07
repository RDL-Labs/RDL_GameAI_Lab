import unittest
from types import SimpleNamespace
from copy import deepcopy
from tests.test_experience_bundle import packet
from runtime.selection_trail import apply,review
class TrailTests(unittest.TestCase):
 def case(self):
  old=packet(0,'old');p=packet(10000000,'now');c=dict(model='food/wait',action=['wait',0],score=1,last_selected=0)
  a=SimpleNamespace(learning={},observations={'old':old},decisions={'old':dict(hunger={'H':6},day_cycle={'phase':'exploration'},continuous_selection=dict(selected=c['model'],candidates=[c],selection_trail={'status':'eligible'}))},commands={'old':dict(kind='wait',amount=0,operation_id='op')},results={'op':dict(status='waited',executed_us=1000000)})
  return a,p,c
 def test_use_then_late_success_and_replay(self):
  a,p,c=self.case();s=review(None,a,p,{})
  self.assertEqual(len(s['completed']),0);self.assertEqual(next(iter(s['edges'].values()))['uses'],1)
  self.assertEqual(review(s,a,p,{}),s)
  p['capture_us']=100000000;p['social']['body']['reserve']=90
  r=review(s,a,p,{});self.assertEqual(len(r['completed']),1);self.assertEqual(r['completed'][0]['credit'],7)
  self.assertEqual(review(r,a,p,{}),r);self.assertIsNotNone(s['episode'])
 def test_override_and_foreign(self):
  a,p,c=self.case();a.commands['old']['kind']='turn';self.assertFalse(review(None,a,p,{})['edges'])
  s=review(None,a,p,{});p['agent_id']='other'
  with self.assertRaises(ValueError):review(s,a,p,{})
 def test_use_changes_choice_without_success(self):
  a,p,c=self.case();s=review(None,a,p,{})
  a.learning={'selection_trail':s};other=dict(model='food/turn',action=['turn',90],score=1.01,last_selected=0)
  sel=dict(gate='method_reselection',candidates=[deepcopy(c),other]);t=apply(a,p,sel,'exploration');self.assertTrue(t['changed'])
  before=deepcopy(sel);self.assertEqual(apply(a,p,sel,'night')['status'],'protected');self.assertEqual(sel,before)
 def test_repeated_use_is_one_episode_success(self):
  a,p,c=self.case();s=review(None,a,p,{})
  a.observations={'new':dict(a.observations['old'],observation_id='new')};a.decisions['new']=a.decisions['old'];a.commands['new']=dict(a.commands['old'],operation_id='op2');a.results['op2']=a.results['op']
  s=review(s,a,p,{});p['social']['body']['reserve']=90;r=review(s,a,p,{})
  e=next(iter(r['edges'].values()));self.assertEqual(e['uses'],2);self.assertEqual(e['successes'],1)
if __name__=='__main__':unittest.main()
