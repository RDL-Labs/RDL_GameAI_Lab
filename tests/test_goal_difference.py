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
