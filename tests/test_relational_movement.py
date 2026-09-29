import unittest
from copy import deepcopy
from tests import test_directional_routes as fixtures
from runtime.relational_movement import relation,compose,review
from runtime.directional_routes import admit


def terrain():
 return dict(status='complete',directional_samples=[dict(direction_deg=x,status='scored',total=0.) for x in (-90,-45,0,45,90)])

def scene_packet(p):
 p['landmarks'].update(coverage='complete',output_limited=False,features=[dict(ref='a',color='brown',azimuth=[-35,-25],range_band='mid'),dict(ref='b',color='green',azimuth=[25,35],range_band='mid')])
 return p

def target():return dict(color='brown',scene=[dict(color='brown',angle=-50,range_band='mid'),dict(color='green',angle=50,range_band='mid')])

class RelationFieldTests(unittest.TestCase):
 def setup(self):
  a,p,d,s,r=fixtures.DirectionalRouteTests().setup();scene_packet(p)
  for n in s['routes'].values():n['points']=[target()]
  d['directional_routes']=s
  a.teaching={'appearance':'brown_capped_ovoid'};a._calculate_current_terrain=lambda observed,packet:terrain()
  return a,p,d,s,r
 def test_multiple_landmarks_induce_direction_not_single_target(self):
  a,p,d,s,r=self.setup();out=compose(p,target(),terrain())
  self.assertEqual(min(out['samples'],key=lambda x:x['total'])['direction'],0)
  self.assertLess(out['samples'][2]['relation'],0)
  p['landmarks']['features']=p['landmarks']['features'][:1]
  self.assertEqual(relation(p,target())['status'],'insufficient_landmarks')
 def test_pair_relation_is_invariant_to_common_yaw_shift(self):
  a,p,d,s,r=self.setup();before=relation(p,target())['pairs'][0]['error']
  for f in p['landmarks']['features']:f['azimuth']=[x+15 for x in f['azimuth']]
  self.assertEqual(relation(p,target())['pairs'][0]['error'],before)
 def test_unknown_and_ambiguous_not_promoted(self):
  a,p,d,s,r=self.setup();p['landmarks']['coverage']='partial'
  self.assertEqual(relation(p,target())['status'],'unavailable')
  p['landmarks']['coverage']='complete';p['landmarks']['features'].append(dict(ref='c',color='brown',azimuth=[70,80],range_band='mid'))
  self.assertEqual(relation(p,target())['status'],'insufficient_landmarks')
 def test_hard_exclusion_and_sum_provenance(self):
  a,p,d,s,r=self.setup();t=terrain();t['directional_samples'][2]['status']='blocked';before=deepcopy(t)
  out=compose(p,target(),t,goal_angle=40)
  self.assertNotIn('total',out['samples'][2]);self.assertEqual(t,before)
  for row in out['samples']:
   if row['status']=='scored':self.assertAlmostEqual(row['total'],row['base']+row['relation']+row['goal'])
 def test_owner_retained_against_stronger_alternative(self):
  a,p,d,s,r=self.setup();first=next(k for k,n in s['routes'].items() if n['goal']=='food')
  s['routes']['other']=deepcopy(s['routes'][first]);s['routes']['other']['support']=8
  a.decisions['previous']['relation_field']=dict(day=1,phase='exploration',owner=first,operations=0)
  out=review(a,p,d);self.assertEqual(out['relation_field']['owner'],first);self.assertTrue(out['relation_field']['applied'])
 def test_confirmed_turn_step_survives_relation_leaving_view(self):
  a,p,d,s,r=self.setup();p['landmarks']['features']=[]
  a.commands['previous'].update(kind='turn',amount=45);r.update(status='turned',yaw=45)
  a.decisions['previous']['relation_field']=dict(day=1,phase='exploration',owner=None,operations=1,pending_step=True)
  out=review(a,p,d);self.assertEqual(out['action'],['move',1]);self.assertEqual(out['relation_field']['reason'],'confirmed_turn_step')
 def test_priority_and_recovery_handoff(self):
  a,p,d,s,r=self.setup();d['action']=['pickup',0]
  self.assertFalse(review(a,p,d)['relation_field']['applied'])
  d['action']=['wait',0];a.decisions['previous']['reposition']=dict(day=1,pending_step=True)
  self.assertEqual(review(a,p,d)['relation_field']['reason'],'recovery_handoff')
 def test_relation_signature_distinguishes_same_color_sequences(self):
  nodes={};one=target();two=deepcopy(one);two['scene'][0]['angle']=-10
  admit(nodes,'food',[one],'receipt1',relational=True);admit(nodes,'food',[two],'receipt2',relational=True)
  self.assertEqual(len(nodes),4)
 def test_budget_and_missing_surface_keep_baseline(self):
  a,p,d,s,r=self.setup();a.decisions['previous']['relation_field']=dict(day=1,phase='exploration',operations=48)
  self.assertFalse(review(a,p,d)['relation_field']['applied'])
  a.decisions['previous']['relation_field']={};a._calculate_current_terrain=lambda *args:dict(status='partial')
  self.assertFalse(review(a,p,d)['relation_field']['applied'])
 def test_runtime_retry(self):
  from unittest.mock import patch
  from integrations.lightweight.timed_harvest import HarvestAgent
  with patch.object(HarvestAgent,'relation_field_mode','enabled'):
   fixtures.DirectionalRouteTests().test_runtime_retry_keeps_route_state()

if __name__=='__main__':unittest.main()

