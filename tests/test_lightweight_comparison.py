import json
import tempfile
import unittest
from pathlib import Path
from integrations.lightweight.compare import audit, compare, rows

FIXTURE=Path('tests/fixtures/lightweight_world_three_days.jsonl.gz')

class LightweightComparisonTests(unittest.TestCase):
    def test_audit_counts_recorded_operations(self):
        result=audit(FIXTURE)
        self.assertEqual(result['summary']['slots'],768)
        self.assertEqual(sum(a['observations'] for a in result['agents'].values()),2304)
        self.assertEqual(result['summary']['pickups'],0)
        self.assertTrue(all(a['field_applied']==0 for a in result['agents'].values()))

    def test_missing_summary_and_duplicate_operation_rejected(self):
        data=list(rows(FIXTURE))
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'bad.jsonl'
            p.write_text('\n'.join(json.dumps(x) for x in data[:-1]))
            with self.assertRaisesRegex(AssertionError,'incomplete'):audit(p)
            data.insert(2,data[1]);p.write_text('\n'.join(json.dumps(x) for x in data))
            with self.assertRaises(AssertionError):audit(p)

    def test_paired_change_and_initial_world_mismatch(self):
        data=list(rows(FIXTURE))
        with tempfile.TemporaryDirectory() as tmp:
            a,b=Path(tmp)/'a.jsonl',Path(tmp)/'b.jsonl'
            a.write_text('\n'.join(json.dumps(x) for x in data))
            data[1]['command']['reason']='audit-change'
            b.write_text('\n'.join(json.dumps(x) for x in data))
            r=compare(a,b);self.assertEqual(r['differences'],{'command':1})
            data[0]['seed']+=1;b.write_text('\n'.join(json.dumps(x) for x in data))
            with self.assertRaises(AssertionError):compare(a,b)
