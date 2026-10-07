import unittest
from copy import deepcopy
from tests import test_ground_appearance as appearance_tests
from runtime.ground_pattern import recognize
class PatternTests(unittest.TestCase):
 def packet(self):return appearance_tests.AppearanceTests().world().packet('npc_a',8)
 def test_band_and_disconnected_and_occlusion(self):
  p=self.packet()
  for i in (6,7,8):p['ground_appearance']['cells'][i]['appearance']='bare_ground'
  before=deepcopy(p);r=recognize(p);self.assertEqual(p,before)
  b=next(g for g in r['groups'] if g['appearance']=='bare_ground')
  self.assertEqual(b['shape'],'sampled_band_candidate');self.assertEqual(b['sample_indices'],[6,7,8])
  self.assertEqual(recognize(p),r)
  c=p['ground_appearance']['cells'][7];c.update(status='occluded',appearance=None);p['ground_appearance']['coverage']='partial'
  r=recognize(p);bs=[g for g in r['groups'] if g['appearance']=='bare_ground']
  self.assertEqual(len(bs),2);self.assertTrue(all(g['shape']=='insufficient_shape' for g in bs))
  self.assertTrue(all(7 in g['unknown_neighbor_indices'] for g in bs))
 def test_all_unknown_and_large_patch(self):
  p=self.packet();self.assertEqual(recognize(p)['groups'][0]['shape'],'sampled_patch')
  for c in p['ground_appearance']['cells']:c.update(status='occluded',appearance=None)
  p['ground_appearance']['coverage']='partial';r=recognize(p)
  self.assertEqual(r['status'],'unavailable');self.assertEqual(r['groups'],[])
 def test_source_binding_and_group_isolation(self):
  p=self.packet();r=recognize(p);r['source']['agent_id']='bad';self.assertEqual(p['agent_id'],'npc_a')
  p['agent_id']='npc_b'
  with self.assertRaises(ValueError):recognize(p)
if __name__=='__main__':unittest.main()
