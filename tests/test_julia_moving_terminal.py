"""Terminal snapshots remain owned and participate in cross-language comparison."""
import unittest
from copy import deepcopy
from runtime.lw_time import SCALED

# Do not load the historical Git blob when this entire fixture is out of scope.
if SCALED:
    from experiments.julia_migration.moving_social.reference import SPECS,scenario
    from experiments.julia_migration.moving_social.measure import compare,audit


@unittest.skipUnless(SCALED,'A2 requires human_scale_v1; exercised by julia-moving-social workflow')
class TerminalSnapshotTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.value=scenario(SPECS[0])

    def test_night_and_final_mismatches_are_detected(self):
        audit(self.value,SPECS[0])
        for endpoint in ('night','final'):
            for field,key in (('body','reserve'),('position','x'),('inventory',None)):
                with self.subTest(endpoint=endpoint,field=field):
                    altered=deepcopy(self.value)
                    actor=(altered['nights'][-1] if endpoint=='night' else altered['final_agents'])['npc_a']
                    if key is None:actor[field]+=1
                    else:actor[field][key]+=1
                    with self.assertRaises(AssertionError):compare(self.value,altered)

    def test_snapshots_do_not_alias_other_endpoints(self):
        altered=deepcopy(self.value)
        altered['final_agents']['npc_a']['body']['reserve']=-1
        altered['final_agents']['npc_a']['position']['x']=-999
        self.assertEqual(altered['nights'],self.value['nights'])
        altered['nights'][-1]['npc_a']['body']['reserve']=-2
        self.assertEqual(altered['nights'][:-1],self.value['nights'][:-1])
        self.assertEqual(altered['rows'],self.value['rows'])


if __name__=='__main__':unittest.main()
