import unittest
from types import SimpleNamespace
from copy import deepcopy
from runtime.bundle_credit import review
from runtime.experience_bundle import apply,context
from tests.test_experience_bundle import packet

class CreditTests(unittest.TestCase):
 def case(self,success=True,H=6):
  p=packet(6000000,'now');b=dict(model_ref='b',formed_us=0,sources=[dict(context=context(p),phase='exploration',action='turn',operation='source')])
  s=dict(binding=['r','a'],bundles=[b])
  use=dict(goal_id='a:food-sufficiency',model_ref='parent',H=H,trial_id='trial')
  cs=dict(selected='move',candidates=[dict(model='move',action=['move',.5])],experience_bundle=dict(changed=True,selected='move',parent_use=use,contributions=[dict(model_refs=['b'])]))
  a=SimpleNamespace(observations={'old':dict(observation_id='old')},decisions={'old':dict(continuous_selection=cs)},commands={'old':dict(operation_id='op',kind='move',amount=.5)},results={'op':dict(executed_us=1000000,status='moved')})
  h=dict(goal=dict(goal_id='a:food-sufficiency',model_ref='parent',records={'trial':dict(evidence=dict(comparable=True,confirmed=success))}))
  return s,a,p,h
 def test_success_snapshot_and_replay(self):
  s,a,p,h=self.case();before=deepcopy(s);r=review(s,a,p,h)
  self.assertEqual(r['parent_credit']['strength']['b'],6)
  self.assertEqual(review(r,a,p,h),r);self.assertEqual(s,before)
 def test_failure_and_override_do_not_reinforce(self):
  s,a,p,h=self.case(False);self.assertEqual(review(s,a,p,h)['parent_credit']['strength']['b'],0)
  a.commands['old']['kind']='wait';self.assertFalse(review(s,a,p,h)['parent_credit']['records'])
 def test_pending_and_cap(self):
  s,a,p,h=self.case(H=30);record=h['goal']['records'].pop('trial');r=review(s,a,p,h)
  self.assertTrue(r['parent_credit']['pending']);h['goal']['records']['trial']=record
  r=review(r,a,p,h);self.assertEqual(r['parent_credit']['strength']['b'],8)
 def test_strength_changes_later_choice_and_shadow_is_unchanged(self):
  s,a,p,h=self.case();s=review(s,a,p,h)
  a.learning={'experience_bundles':s};a.bundle_credit_enabled=True;a.experience_bundle_mode='enabled'
  def choice():return dict(gate='method_reselection',candidates=[dict(model='turn',action=['turn',90],score=2,last_selected=0),dict(model='move',action=['move',.5],score=1,last_selected=0)])
  t=apply(a,p,choice(),'exploration');self.assertTrue(t['changed'])
  a.bundle_credit_enabled=False;self.assertFalse(apply(a,p,choice(),'exploration')['changed'])
  a.bundle_credit_enabled=True;a.experience_bundle_mode='shadow';c=choice();before=deepcopy(c);apply(a,p,c,'exploration');self.assertEqual(c,before)
 def test_shared_budget_and_incomparable(self):
  s,a,p,h=self.case();second=deepcopy(s['bundles'][0]);second['model_ref']='b2';s['bundles'].append(second)
  a.decisions['old']['continuous_selection']['experience_bundle']['contributions'][0]['model_refs'].append('b2')
  r=review(s,a,p,h);self.assertEqual(r['parent_credit']['strength'],{'b':3,'b2':3})
  h['goal']['records']['trial']['evidence']['comparable']=False
  self.assertEqual(sum(review(s,a,p,h)['parent_credit']['strength'].values()),0)
 def test_binding(self):
  s,a,p,h=self.case();p['agent_id']='other'
  with self.assertRaises(ValueError):review(s,a,p,h)

if __name__=='__main__':unittest.main()
