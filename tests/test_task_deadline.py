import copy
import gzip
import json
import unittest
from pathlib import Path

from runtime.exploration_deadline import deadline_loop
from runtime.goal_reassessment import ReassessingExploration
from integrations.luanti.tests.run_speed_probe import signature


class TaskDeadlineTests(unittest.TestCase):
    def test_duration_is_instance_isolated_and_expiry_does_not_reset_at_16(self):
        old = ReassessingExploration('old', 1)
        short = deadline_loop(16)('short')
        long = deadline_loop(64)('long')
        self.assertEqual(old.agents['npc_a'].capacity, 64)
        self.assertEqual(short.agents['npc_a'].capacity, 64)
        a = long.agents['npc_a']
        self.assertEqual(a.capacity, 256)
        self.assertEqual(a.expiry(15_990_000), 16_490_000)
        self.assertEqual(a.expiry(63_990_000), 64_000_000)
        self.assertEqual(old.agents['npc_a'].expiry(15_990_000), 16_000_000)
        for seconds in (0, 17, 65, 16.0, True):
            with self.assertRaises(ValueError):
                deadline_loop(seconds)
        with self.assertRaises(ValueError):
            deadline_loop(32)('invalid', periods=2)

    def test_configuration_conflict_does_not_mutate(self):
        with gzip.open(Path(__file__).parent / 'fixtures/luanti_l15a_goal_reassessment.json.gz', 'rt', encoding='utf-8') as f:
            data = json.load(f)['runs'][6]['data']
        request = copy.deepcopy(next(d['request'] for d in data['world']['deliveries'] if d['kind'] == 'configure'))
        loop = deadline_loop(32)(request['run_id'])
        request.update(schema=loop.schema, task_seconds=32)
        response = loop.configure(request)
        self.assertEqual(loop.configure(request), response)
        before = loop.snapshot()
        request['task_seconds'] = 64
        with self.assertRaises(ValueError):
            loop.configure(request)
        self.assertEqual(loop.snapshot(), before)

    def test_actual_world_one_period_and_no_budget_refresh(self):
        with gzip.open(Path(__file__).parent / 'fixtures/luanti_l15a_task_deadline.json.gz', 'rt', encoding='utf-8') as f:
            report = json.load(f)
        self.assertEqual(len(report['runs']), 3)
        baseline = signature(report['runs'][0]['data'])
        for case, run in zip(report['predeclared'], report['runs']):
            seconds = case['task_seconds']
            data = run['data']
            self.assertEqual(len(data['world']['periods']), 1)
            self.assertFalse(data['world'].get('failure'))
            current = signature(data)
            self.assertEqual({aid: rows[:64] for aid, rows in current.items()}, baseline)
            if seconds > 16:
                self.assertEqual(current['npc_b'][64][2], 'observed_material_terrain_reversal_stopped')
                self.assertTrue(all(row[0] == 'wait' for row in current['npc_b'][64:]))
            for agent in data['runtime']['exploration']['agents'].values():
                self.assertEqual(len(agent['observations']), seconds * 4)
                decisions = list(agent['decisions'].values())
                self.assertEqual({d['period'] for d in decisions}, {0})
                self.assertTrue(all('period_boundary' not in d['rest']['recurrence']['reasons'] for d in decisions))
                self.assertLessEqual(max(d['landmark']['selected_count'] for d in decisions), 8)
                self.assertLessEqual(sum(d['goal_reassessment']['triggered'] for d in decisions), 1)
                self.assertLessEqual(sum(d['rest']['transition'] == 'started' for d in decisions), 4)
                self.assertTrue(all(r['status'] not in ('stale', 'expired', 'stopped') for r in agent['results'].values()))
