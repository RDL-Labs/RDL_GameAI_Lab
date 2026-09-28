import copy
import gzip
import json
import unittest
from pathlib import Path

from integrations.luanti.tests.check_speed_probe import summarize
from integrations.luanti.tests.run_multi_resource import run
from integrations.luanti.tests.run_speed_probe import signature


class SpeedProbeTests(unittest.TestCase):
    def test_invalid_speed_rejected_before_server_or_world(self):
        for speed in (0, 17, float('nan'), float('inf')):
            with self.subTest(speed=speed), self.assertRaises(ValueError):
                run('natural_meadow', 1, 'steady', 'unused', simulation_speed=speed)

    @classmethod
    def setUpClass(cls):
        with gzip.open(Path(__file__).parent / 'fixtures/luanti_l15a_speed_probe.json.gz',
                       'rt', encoding='utf-8') as stream:
            cls.archive = json.load(stream)

    def test_failure_is_not_hidden_by_replay_pass(self):
        rows = summarize(self.archive['sweep'])
        self.assertTrue(rows[3]['replay_pass'])
        self.assertFalse(rows[3]['transport_healthy'])
        self.assertGreater(rows[3]['invalid_results']['expired'], 0)
        self.assertFalse(rows[4]['replay_pass'])
        self.assertFalse(rows[4]['complete'])
        self.assertIn('pending capacity', rows[4]['world_failure'])

    def test_behavior_and_transport_are_distinct(self):
        rows = summarize(self.archive['sweep'])
        self.assertTrue(rows[1]['same_commands_and_results'])
        self.assertTrue(rows[2]['transport_healthy'])
        self.assertFalse(rows[2]['same_commands_and_results'])

    def test_confirmation_is_read_only_and_complete(self):
        report = self.archive['confirmation']
        before = copy.deepcopy(report)
        rows = summarize(report)
        self.assertEqual(report, before)
        self.assertTrue(rows[0]['transport_healthy'])
        self.assertTrue(rows[1]['transport_healthy'])
        self.assertFalse(rows[2]['transport_healthy'])
        self.assertEqual(rows[2]['invalid_results'], {'stale': 3})
        self.assertEqual(rows[1]['speed'], 1.5)
        self.assertTrue(all(n == 1 for n in rows[1]['max_pending'].values()))

    def test_margin_repeated_with_same_actions(self):
        rows = summarize(self.archive['repeat'])
        self.assertTrue(all(r['transport_healthy'] for r in rows))
        self.assertEqual(signature(self.archive['confirmation']['runs'][1]['data']),
                         signature(self.archive['repeat']['runs'][1]['data']))
