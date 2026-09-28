import copy
import gzip
import json
import unittest
from pathlib import Path

from integrations.luanti.tests.diagnose_goal_followup import diagnose


class GoalFollowupTests(unittest.TestCase):
    def test_actual_followup_and_agent_only_nonmutation(self):
        path = Path(__file__).parent / 'fixtures/luanti_l15a_goal_reassessment.json.gz'
        with gzip.open(path, 'rt', encoding='utf-8') as stream:
            archive = json.load(stream)
        # Remove all World/summary/provenance information: only accepted agent state is used.
        reduced = {'runs': [{'data': {'runtime': r['data']['runtime']}} for r in archive['runs']]}
        before = copy.deepcopy(reduced)
        report = diagnose(reduced)
        self.assertEqual(reduced, before)
        self.assertEqual(report, diagnose(archive))
        agents = [a for r in report['runs'] for a in r['agents'].values()]
        self.assertEqual(sum(a['observations'] for a in agents), 1536)
        self.assertEqual(sum(len(a['reviews']) for a in agents), 8)
        self.assertTrue(all(a['learning_records'] == a['acquired_count'] == 0 for a in agents))
        for i in (2, 3):
            b = report['runs'][i]['agents']['npc_b']['reviews'][0]['rows']
            self.assertEqual(b[7]['result'], 'blocked')  # slot36
            self.assertEqual(b[8]['reason'], 'landmark_goal_budget')
        for i in (6, 7):
            a = report['runs'][i]['agents']['npc_a']['reviews'][0]['rows']
            self.assertEqual(a[8]['landmark_outcome'], 'ambiguous')  # slot36
            b = report['runs'][i]['agents']['npc_b']['reviews'][0]['rows']
            self.assertEqual(b[-1]['approach']['operations'], 20)
            self.assertEqual(b[-1]['result'], 'turned')
            self.assertNotIn('blocked', [r['result'] for r in b])
