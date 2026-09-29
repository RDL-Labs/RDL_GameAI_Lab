import unittest
from copy import deepcopy
from tests import test_food_revisit as fixture
from runtime.directional_routes import admit,review

class DirectionalRouteTests(unittest.TestCase):
 def setup(self):
  a,p,d,old,r=fixture.FoodRevisitTests().setup()
  routes={};admit(routes,'food',[dict(color='brown',source='seen')],'receipt')
  s=dict(rule='directional-landmark-routes-v1',binding=['revisit','npc_a'],routes=routes,trip=None,day=1,at_home=True,outbound=dict(points=[],overflow=False),operations=0,cursors={},failed=[],active=None)
  a.decisions['previous']['directional_routes']=s
  return a,p,d,s,r
 def test_reverse_is_unproven_and_receipt_not_two_votes(self):
  nodes={};pts=[dict(color='brown'),dict(color='green')]
  admit(nodes,'food',pts,'one');admit(nodes,'food',pts,'one')
  food=next(n for n in nodes.values() if n['goal']=='food');home=next(n for n in nodes.values() if n['goal']=='home')
  self.assertEqual(food['support'],1);self.assertEqual(home['support'],0)
  self.assertEqual([p['color'] for p in home['points']],['green','brown'])
  admit(nodes,'home',list(reversed(pts)),'two');self.assertEqual(home['support'],1);self.assertEqual(food['support'],1)
  for i in range(20):admit(nodes,'food',pts,str(i))
  self.assertEqual(food['support'],8)
 def test_support_changes_selection_and_reversed_route_is_selectable(self):
  a,p,d,s,r=self.setup();out=review(a,p,d)
  self.assertTrue(out['directional_routes']['applied']);self.assertEqual(out['action'],['move',1])
  d['day_cycle']['phase']='return';d['reason']='return_search_no_candidate_after_scan'
  out=review(a,p,d);self.assertTrue(out['directional_routes']['applied'])
  chosen=out['directional_routes']['routes'][out['directional_routes']['active']]
  self.assertEqual(chosen['goal'],'home');self.assertEqual(chosen['support'],0)
 def test_visible_tower_beats_strong_route_but_blocked_allows_detour(self):
  a,p,d,s,r=self.setup();d['day_cycle'].update(phase='return',home_memory={'color':'ochre'});d['reason']='return_dock_approach'
  p['skyline'].update(coverage='complete',features=[dict(color='ochre',azimuth=[-5,5])])
  for n in s['routes'].values():n['support']=8
  out=review(a,p,d);self.assertFalse(out['directional_routes']['applied']);self.assertEqual(out['action'],d['action'])
  d['reason']='return_approach_blocked';self.assertTrue(review(a,p,d)['directional_routes']['applied'])
 def test_unload_credits_actual_paths_not_shortcut_candidate(self):
  a,p,d,s,r=self.setup();s['trip']=dict(pickup='pick',outbound=dict(points=[dict(color='green')],overflow=False),inbound=dict(points=[dict(color='red')],overflow=False))
  a.unload_receipts={'op:previous':dict(executed_us=r['executed_us'],pickups=['pick'])}
  out=review(a,p,d)['directional_routes'];self.assertIsNone(out['trip'])
  self.assertEqual(len(out['admissions']),4)
  oldbrown=next(n for n in out['routes'].values() if n['goal']=='food' and n['points'][0]['color']=='brown');self.assertEqual(oldbrown['support'],1)
 def test_ambiguous_unknown_and_physical_block_do_not_force_move(self):
  a,p,d,s,r=self.setup();p['landmarks']['coverage']='partial'
  self.assertFalse(review(a,p,d)['directional_routes']['applied'])
  p['landmarks']['coverage']='complete'
  for x in p['movement_surface']['ground']['samples']:x['status']='unavailable'
  self.assertFalse(review(a,p,d)['directional_routes']['applied'])
 def test_budget_and_local_failure_once(self):
  a,p,d,s,r=self.setup();key=next(k for k,n in s['routes'].items() if n['goal']=='food');s.update(active=key,operations=48,trial_complete=True)
  out=review(a,p,d);self.assertEqual(out['directional_routes']['routes'][key]['H'],1)
  a.decisions['previous']['directional_routes']=out['directional_routes']
  self.assertEqual(review(a,p,d)['directional_routes']['routes'][key]['H'],1)
 def test_day_preserves_support_and_input_purity(self):
  a,p,d,s,r=self.setup();s['day']=0;before=deepcopy(s)
  out=review(a,p,d);self.assertEqual(out['directional_routes']['routes'],s['routes']);self.assertEqual(s,before)
  s['binding'][1]='npc_b'
  with self.assertRaises(ValueError):review(a,p,d)

 def test_stronger_success_changes_relative_candidate_score(self):
  a,p,d,s,r=self.setup();admit(s['routes'],'food',[dict(color='green')],'green-one')
  p['landmarks']['features'].append(dict(ref='g',color='green',azimuth=[25,35],range_band='mid'))
  for i in range(3):admit(s['routes'],'food',[dict(color='green')],'g'+str(i))
  out=review(a,p,d);chosen=out['directional_routes']['routes'][out['directional_routes']['active']]
  self.assertEqual(chosen['points'][0]['color'],'green');self.assertEqual(out['action'],['turn',30])
 def test_no_delivery_no_support_and_memory_not_an_action_tape(self):
  a,p,d,s,r=self.setup();r['acquired']=True;s['active']=next(k for k,n in s['routes'].items() if n['goal']=='food')
  out=review(a,p,d)['directional_routes'];self.assertEqual(out['routes'],s['routes']);self.assertIsNotNone(out['trip']);self.assertIsNone(out['active'])
  p['landmarks']['features']=[];r['acquired']=False
  self.assertFalse(review(a,p,d)['directional_routes']['applied'])

 def test_runtime_retry_keeps_route_state(self):
  from unittest.mock import patch
  from integrations.lightweight.timed_harvest import HarvestAgent
  from integrations.lightweight.world import World
  from integrations.lightweight.timed_harvest import HarvestCampaign
  from runtime.initial_orientation import sample
  from runtime.local_return import sample as dock
  w=World('route-retry');loop=HarvestCampaign(w.run_id,1,harvest_state=True,mb_field_mode='enabled');aid='npc_a'
  a=loop.agents[aid];a.directional_route_mode='enabled';a.orientation_mode='enabled';a.return_completion_mode='enabled'
  loop.configure(dict(w.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode='enabled',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
  for slot in range(24):
   p=w.packet(aid,slot);p['orientation']=sample(p,w.agents[aid]['yaw']);p['dock']=dock(w,p)
   response=loop.observe(p);before=deepcopy(a.decisions[p['observation_id']]['directional_routes'])
   self.assertEqual(loop.observe(deepcopy(p))['command'],response['command'])
   self.assertEqual(a.decisions[p['observation_id']]['directional_routes'],before)
   loop.result(w.execute(response['command'],p))

if __name__=='__main__':unittest.main()
