import unittest
from copy import deepcopy
from integrations.lightweight.world import distant_patches, World

class DistantPatchTests(unittest.TestCase):
    def feature(self,lo,hi,color='green',band='mid'):
        return dict(ref=f'ray:{lo}',azimuth=[lo,hi],color=color,range_band=band)

    def test_adjacent_only_and_no_input_mutation(self):
        fs=[self.feature(-30,-15),self.feature(-15,0),self.feature(15,30),self.feature(30,45,'brown'),self.feature(45,60,'brown','far')]
        original=deepcopy(fs);out=distant_patches(fs,'patches')
        self.assertEqual(len(out),4);self.assertEqual(out[0]['azimuth'],[-30,0]);self.assertEqual(fs,original)
        self.assertEqual(distant_patches(fs,'rays'),fs)

    def test_overflow_and_projection_scope(self):
        raw=World();grouped=World(distant_mode='patches')
        p,q=raw.packet('npc_a',0),grouped.packet('npc_a',0)
        self.assertEqual({k:v for k,v in p.items() if k!='distant'},{k:v for k,v in q.items() if k!='distant'})
        # Distinct nonadjacent observations cannot be suppressed to achieve completeness.
        for w in (raw,grouped):
            w.cast=lambda aid,angle,limit,elevation=0: (10,dict(color='green')) if angle in (-90,-60,-30,0,30,60,90) else None
        q=grouped.packet('npc_a',0)
        self.assertEqual(q['distant']['coverage'],'PARTIAL');self.assertTrue(q['distant']['output_limited'])
        self.assertEqual(len(q['distant']['payload']['features']),4)

    def test_same_bands_are_not_object_identity(self):
        fs=[self.feature(0,15),self.feature(15,30)]
        fs[0]['ref']='different-object-a';fs[1]['ref']='different-object-b'
        self.assertEqual(len(distant_patches(fs,'patches')),1)
        with self.assertRaises(ValueError):World(distant_mode='invalid')
