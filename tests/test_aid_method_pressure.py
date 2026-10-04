import unittest
import json
import gzip
from pathlib import Path
from runtime.aid_method_pressure import update,select


def record(outcome,target='b'):
    return dict(agent_id='a',target=target,outcome=outcome,request_observation_id='start',source_observation_id='end')


class AidPressureTests(unittest.TestCase):
    def test_threshold_switch_without_sleep_or_forbidden_retry(self):
        records={'one':record('refuse')};s=update(None,records,'a')
        self.assertEqual(s['parent']['H'],1)
        self.assertEqual(select(['b','c'],{},s)[0],'b')
        records['two']=record('no_response_observed');s=update(s,records,'a')
        self.assertEqual(s['methods']['b']['H'],2)
        self.assertEqual(select(['b','c'],{},s)[0],'c')
        target,trace=select(['b'],{},s)
        self.assertIsNone(target)
        self.assertIn('b',[c['target'] for c in trace['candidates']])
        self.assertEqual(update(s,records,'a'),s)

    def test_failed_execution_defer_and_success_scoped_reset(self):
        records={'one':record('refuse')};s=update(None,records,'a')
        records['two']=record('request_not_executed');s=update(s,records,'a')
        self.assertEqual(s['parent']['H'],1)
        self.assertIsNone(s['parent']['records']['two']['E'])
        records['three']=record('given','c');s=update(s,records,'a')
        self.assertEqual(s['parent']['H'],0)
        self.assertEqual(s['methods']['b']['H'],1)
        self.assertEqual(s['methods']['c']['H'],0)

    def test_agent_binding(self):
        with self.assertRaises(ValueError):update(None,{'one':record('refuse')},'other')
        with self.assertRaises(ValueError):update(update(None,{},'a'),{},'other')

    def test_world_switches_same_day_after_two_refusals(self):
        root=Path('tests/fixtures/aid_pressure')
        report=json.loads((root/'comparison.json').read_text(encoding='utf8'))
        requests=report['enabled']['audit']['requests']
        self.assertEqual([r['target'] for r in requests[:3]],['npc_b','npc_b','npc_c'])
        self.assertEqual([r['day'] for r in requests[:3]],[1,1,1])
        with gzip.open(root/'enabled.jsonl.gz','rt',encoding='utf8') as f:
            row=next(json.loads(line) for line in f if '"type":"decision"' in line and
                     json.loads(line)['packet']['observation_id']==requests[2]['observation'])
        pressure=row['social_relations']['pressure']
        self.assertEqual(pressure['parent']['H'],2)
        self.assertEqual(pressure['methods']['npc_b']['H'],2)
        self.assertEqual(row['social_relations']['model'],{})
        for entry in report.values():
            self.assertTrue(entry['audit']['conserved']);self.assertFalse(entry['audit']['body_overlap'])
