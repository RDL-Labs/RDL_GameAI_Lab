"""Portable numeric diagnostics must not weaken evidence or action checks."""
import math
import unittest
from integrations.luanti.tests.check_multi_resource import first_difference


class ReplayPortabilityTests(unittest.TestCase):
    def test_linux_windows_last_bit_is_allowed_only_for_derived_motion(self):
        path='$/agents/npc_c/decisions/obs/rest/recurrence/local_motion/forward'
        self.assertIsNone(first_difference(2.380139954330329,2.3801399543303297,path))
        self.assertIsNotNone(first_difference(2.380139,2.38014,path))

    def test_nested_containers_accept_only_allowed_leaf_differences(self):
        def tree(value):
            decision=dict(rest=dict(recurrence=dict(local_motion=dict(forward=value))))
            return dict(agents=dict(npc_c=dict(decisions=dict(obs=decision))))
        self.assertIsNone(first_difference(tree(2.380139954330329),tree(2.3801399543303297)))
        self.assertIsNotNone(first_difference(tree(2.38),tree(2.39)))
        p='$/agents/npc_a/decisions/obs/movement_terrain/directional_samples'
        self.assertIsNone(first_difference([{'total':1.}],[{'total':math.nextafter(1.,2.)}],p))

    def test_terrain_numeric_roundoff_is_allowed(self):
        path='$/agents/npc_a/decisions/obs/movement_terrain/directional_samples/0/source_contributions/obstacles/0/value'
        self.assertIsNone(first_difference(1.,math.nextafter(1.,2.),path))
        self.assertIsNotNone(first_difference(1.,1.00001,path))

    def test_raw_evidence_commands_and_discrete_decisions_stay_exact(self):
        paths=['$/agents/npc_a/observations/obs/food/visible/0/distance',
            '$/agents/npc_a/commands/obs/amount',
            '$/agents/npc_a/decisions/obs/movement_terrain/evidence/food/items/0/forward',
            '$/agents/npc_a/decisions/obs/movement_terrain/directional_samples/0/source_contributions/ground/height_delta',
            '$/agents/npc_a/decisions/obs/action/1',
            '$/agents/npc_a/decisions/obs/rest/state/fatigue']
        for path in paths:
            self.assertIsNotNone(first_difference(1.,math.nextafter(1.,2.),path),path)
        self.assertIsNotNone(first_difference([0],[45],'$/agents/npc_a/decisions/obs/movement_terrain/minimum_directions'))

    def test_structure_nonfinite_and_error_path(self):
        path='$/agents/npc_a/decisions/obs/rest/recurrence/local_motion/forward'
        self.assertIsNotNone(first_difference(float('nan'),1.,path))
        self.assertIsNotNone(first_difference(float('inf'),1.,path))
        self.assertIsNotNone(first_difference({'a':1},{'a':1,'b':2}))
        self.assertIsNotNone(first_difference([1],[1,2]))
        self.assertIn('$/a/0',first_difference({'a':[1]},{'a':[2]}))

    def test_offline_world_projection_is_numeric_but_status_is_exact(self):
        self.assertIsNone(first_difference(1.,math.nextafter(1.,2.),'$history/0/windows/npc_a/0/world_audit/right'))
        self.assertIsNotNone(first_difference('unknown','translated','$history/0/windows/npc_a/0/status'))


if __name__=='__main__':unittest.main()
