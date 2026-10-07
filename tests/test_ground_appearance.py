import unittest
from copy import deepcopy
from integrations.lightweight.energy_exploration import EnergyWorld,EnergyCampaign
from integrations.lightweight.ground_appearance import validate
class AppearanceTests(unittest.TestCase):
 def world(self):
  w=EnergyWorld('r');w.objects=[];w.ground_appearance_enabled=True;w.agents['npc_a'].update(x=0.,z=0.,yaw=0.)
  return w
 def test_visibility_regrowth_and_binding(self):
  w=self.world();w.ground_wear.walk('op','npc_b',(.1,1.1),(.9,1.1))
  p=w.packet('npc_a',8);v=p['ground_appearance'];validate(v,p)
  cell=next(c for c in v['cells'] if c['angle']==0 and c['distance']==1)
  self.assertEqual(cell['appearance'],'trampled_grass')
  w.ground_wear.recovery_enabled=True;w.ground_wear.advance(128000000)
  self.assertEqual(next(c for c in w.packet('npc_a',9)['ground_appearance']['cells'] if c['angle']==0 and c['distance']==1)['appearance'],'grass')
  self.assertEqual(cell['appearance'],'trampled_grass')
  bad=deepcopy(p);bad['agent_id']='npc_b'
  with self.assertRaises(ValueError):validate(v,bad)
  w.objects=[dict(x=0,z=.5,radius=.2,height=2,solid=True,color='gray')]
  q=w.packet('npc_a',10);validate(q['ground_appearance'],q)
  c=next(c for c in q['ground_appearance']['cells'] if c['angle']==0 and c['distance']==1)
  self.assertEqual((c['status'],c['appearance']),('occluded',None))
 def test_observed_bare_ground_no_hidden_data(self):
  w=self.world()
  for i in range(20):w.ground_wear.walk(str(i),'npc_b',(.1,1.1),(.9,1.1))
  p=w.packet('npc_a',8);v=p['ground_appearance'];self.assertIn('bare_ground',[c['appearance'] for c in v['cells']])
  for c in v['cells']:self.assertEqual(set(c),{'angle','distance','status','appearance'})
  v['cells'].append(v['cells'][0])
  with self.assertRaises(ValueError):validate(v,p)
 def test_runtime_stores_but_does_not_change_command(self):
  commands=[]
  for enabled in (False,True):
   w=self.world();w.ground_appearance_enabled=enabled;l=EnergyCampaign('r',1)
   l.configure(dict(w.context('npc_a'),schema=l.schema,clock_id='world-sim-v1',selection_profile='steady',teaching=dict(statement_id='t',source='god_statue',sample_observation='s',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
   p=w.packet('npc_a',8);commands.append(l.observe(p)['command'])
   self.assertEqual('ground_appearance' in l.agents['npc_a'].observations[p['observation_id']],enabled)
   self.assertEqual(l.observe(p)['command'],commands[-1])
  self.assertEqual(commands[0],commands[1])
if __name__=='__main__':unittest.main()
