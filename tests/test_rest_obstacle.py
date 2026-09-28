"""Acceptance of actual contact records, including an observed-context removal veto."""
from copy import deepcopy
import gzip
import json
from pathlib import Path
import unittest
from runtime.rest_reactivation import appearance_key, evaluate, project_reactivation
from integrations.luanti.tests.check_rest_obstacle import check, compare, slot


class RestObstacleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path=Path(__file__).parent/'fixtures/luanti_l15a_rest_obstacle.json.gz'
        with gzip.open(path,'rt',encoding='utf-8') as f:cls.matrix=json.load(f)

    def test_actual_world_complete_replay(self):
        self.assertEqual(len(self.matrix['runs']),4)
        for run in self.matrix['runs']:
            self.assertEqual(check(run['data']),run['obstacle_summary'])
        self.assertEqual(compare(self.matrix['runs']),self.matrix['comparison'])

    def test_applicable_memory_does_not_override_exhausted_goal(self):
        for run in self.matrix['runs'][1::2]:
            a=run['data']['runtime']['exploration']['agents']['npc_a']
            d=a['decisions'][slot(a,28)];m=d['reactivation']
            self.assertEqual(m['evaluation']['forward_penalty'],.5 if run['obstacle_summary']['obstacle']=='persistent' else 0.)
            self.assertEqual(d['action'],['wait',0])
            self.assertEqual(d['reason'],'landmark_goal_budget')
            self.assertEqual(m['projection']['reason'],'current_priority_or_geometry')
            self.assertFalse(m['projection']['applied'])
        for c in self.matrix['comparison']:
            self.assertTrue(all(c['actions_equal'].values()))

    def test_observed_removal_invalidates_context_without_oracle(self):
        summaries=[]
        for run in self.matrix['runs'][1::2]:
            a=run['data']['runtime']['exploration']['agents']['npc_a']
            p=a['observations'][slot(a,28)];d=a['decisions'][slot(a,28)]
            self.assertEqual(appearance_key(p)==appearance_key(a['observations'][slot(a,23)]),
                             run['obstacle_summary']['obstacle']=='persistent')
            self.assertEqual(evaluate(d['reactivation']['bundle'],p,None),d['reactivation']['evaluation'])
            self.assertNotIn('obstacle_probe',p)
            summaries.append(run['obstacle_summary'])
        self.assertFalse(summaries[0]['world_traversable'])
        self.assertTrue(summaries[1]['world_traversable'])
        self.assertTrue(summaries[0]['record_applicable'])
        self.assertFalse(summaries[1]['record_applicable'])

    def test_current_geometry_still_excludes_forward(self):
        run=self.matrix['runs'][1];a=run['data']['runtime']['exploration']['agents']['npc_a']
        d=a['decisions'][slot(a,28)]
        # Synthetic geometry intervention on genuine evidence; not another World run.
        terrain=dict(status='complete',directional_samples=[dict(direction_deg=0,status='blocked'),
            dict(direction_deg=45,status='scored',total=0)])
        original=deepcopy(terrain)
        out=project_reactivation(terrain,['turn',45],d['reactivation']['evaluation'])
        self.assertEqual(out['reason'],'direction_not_scored')
        self.assertFalse(out['applied']);self.assertEqual(terrain,original)


if __name__=='__main__':unittest.main()
