import unittest
from runtime.goal_difference import initial,begin,finish
class GoalDifferenceTests(unittest.TestCase):
 def test_residual_retry_defer_resolution(self):
  s=begin(initial('a:home'),'one',{'capture_us':0});before=s.copy()
  a=finish(s,'one',False,True,'end1');self.assertEqual(a['H'],1);self.assertEqual(s,before)
  self.assertEqual(finish(a,'one',False,True,'end1'),a)
  with self.assertRaises(ValueError):finish(a,'one',True,True,'end1')
  b=finish(begin(a,'two',{}),'two',False,False,'end2');self.assertEqual(b['H'],1);self.assertIsNone(b['records']['two']['E'])
  c=finish(begin(b,'three',{}),'three',False,True,'end3');self.assertEqual(c['H'],2)
  d=finish(begin(c,'four',{}),'four',True,True,'end4');self.assertEqual(d['H'],0);self.assertEqual(len(d['records']),4)
 def test_goal_isolation_and_trial_binding(self):
  a=initial('a:home');b=initial('b:home')
  a=finish(begin(a,'one',{}),'one',False,True,'end');self.assertEqual(b['H'],0)
  with self.assertRaises(ValueError):finish(b,'one',False,True,'end')

 def test_multiple_goal_contracts_and_method_authority(self):
  from runtime.goal_difference import method
  home=initial('a:home',parent_goal_id='a:security')
  food=initial('a:food','food-model-v1','food_acquired',1,'a:security')
  source={'observation_id':'o'}
  food=begin(food,'f1',source);source['observation_id']='changed'
  self.assertEqual(food['trial']['source']['observation_id'],'o')
  self.assertEqual(food['trial']['F'],{'food_acquired':1})
  food=finish(food,'f1',False,True,'later')
  self.assertEqual(food['records']['f1']['F_prime'],{'food_acquired':0})
  self.assertEqual(food['H'],1);self.assertEqual(home['H'],0)
  self.assertEqual(method(food,True,'normal','rescan'),'rescan')
  self.assertEqual(method(food,False,'normal','rescan'),'normal')
  self.assertEqual(food['parent_goal_id'],home['parent_goal_id'])
 def test_trial_cannot_be_overwritten_or_reopened(self):
  s=begin(initial('a'),'one',{'o':1})
  self.assertEqual(begin(s,'one',{'o':1}),s)
  with self.assertRaises(ValueError):begin(s,'two',{'o':2})
  done=finish(s,'one',False,True,'end')
  with self.assertRaises(ValueError):begin(done,'one',{'o':1})
  with self.assertRaises(ValueError):finish(s,'one',0,True,'end')
  with self.assertRaises(ValueError):initial('a',threshold=0)
  with self.assertRaises(ValueError):initial('a',parent_goal_id='a')
