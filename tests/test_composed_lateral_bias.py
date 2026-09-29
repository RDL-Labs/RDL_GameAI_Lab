import unittest
from copy import deepcopy
from runtime.composed_lateral_bias import apply

def terrain():
 return dict(status='complete',minimum_directions=[-45,45],minimum_height=1.,model_field={'source':'adopted'},approach_field={'applied':True},directional_samples=[dict(direction_deg=a,status='scored',physical=1.,food=.2,obstacle=.1,model_field_cost=-.3,total=1. if abs(a)==45 else 2.) for a in (-90,-45,0,45,90)])

class LateralTests(unittest.TestCase):
 def test_mirror_and_existing_model_preserved(self):
  t=terrain();old=deepcopy(t)
  for side,direction in [('left',-45),('right',45)]:
   r=apply(t,side);self.assertEqual(r['minimum_directions'],[direction]);self.assertTrue(r['lateral']['applied'])
   self.assertEqual(r['model_field'],t['model_field']);self.assertEqual(r['approach_field'],t['approach_field'])
   self.assertTrue(all(row['model_field_cost']==-.3 for row in r['directional_samples']))
  self.assertEqual(t,old)
 def test_forward_unknown_blocked_and_difference_not_overridden(self):
  for change in ('forward','partial','blocked','difference','model'):
   t=terrain()
   if change=='forward':t['minimum_directions']=[0]
   elif change=='partial':t['status']='partial'
   elif change=='blocked':t['directional_samples'][1]['status']='blocked'
   elif change=='difference':t['directional_samples'][1]['physical']=2.
   else:t['directional_samples'][1]['model_field_cost']=-.8
   self.assertFalse(apply(t,'left')['lateral']['applied'])
 def test_neutral_is_not_individual_profile(self):
  with self.assertRaises(ValueError):apply(terrain(),'neutral')
