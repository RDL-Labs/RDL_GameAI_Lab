import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from integrations.lightweight.daily_review import analyze


class DailyReviewTests(unittest.TestCase):
    def test_receipts_differences_replay_and_no_world_truth(self):
        def result(day,op,acquired,move):
            return dict(type='completed',packet=dict(agent_id='a'),body={'secret':'unused'},stock=[999],
                result=dict(executed_us=day*64000000,operation_id=op,acquired=acquired,
                    forward=move,right=0,up=0,yaw=0,status='picked_up' if acquired else 'moved'))
        first=result(0,'x',True,1);second=result(1,'y',False,3)
        unload=dict(type='unload_receipt',agent_id='a',receipt=dict(executed_us=64000000,operation_id='u',pickups=['x']))
        with TemporaryDirectory() as folder:
            p=Path(folder)/'run.jsonl'
            p.write_text('\n'.join(json.dumps(r) for r in [first,first,second,unload,unload]))
            a,b=analyze(p,2)['agents']['a']
        self.assertIsNone(a['delta_from_previous'])
        self.assertEqual(b['delta_from_previous']['pickups'],-1)
        self.assertEqual(b['delta_from_previous']['unloaded'],1)
        self.assertEqual(b['delta_from_previous']['body_load_proxy'],2)
        self.assertEqual(a['return_evidence'],'unconfirmed')
        self.assertEqual(b['return_evidence'],'delivered')
        self.assertEqual(a['pickups'],1)

    def test_missing_day_is_not_zero_performance(self):
        x=dict(type='unload_receipt',agent_id='a',receipt=dict(
            executed_us=0,operation_id='u',pickups=['x']))
        with TemporaryDirectory() as folder:
            p=Path(folder)/'run.jsonl';p.write_text(json.dumps(x))
            day=analyze(p,2)['agents']['a'][1]
        self.assertEqual(day['coverage'],'no_records')
        self.assertEqual(day['comparison'],'insufficient_records')
        self.assertIsNone(day['delta_from_previous'])

    def test_saved_thirty_days_reconcile_with_receipts(self):
        import gzip
        path=Path('tests/fixtures/lightweight_sleep_auto_comparison_30d.json.gz')
        with gzip.open(path,'rt',encoding='utf8') as stream:reports=json.load(stream)
        for report in reports.values():
            daily=report['daily_review']['agents']
            self.assertEqual(sum(d['pickups'] for rows in daily.values() for d in rows),report['pickups'])
            for aid,rows in daily.items():
                self.assertEqual(len(rows),30)
                self.assertTrue(all(d['coverage']=='records_available' for d in rows))
                self.assertEqual(sum(d['unloaded'] for d in rows),report['agents'][aid]['unloaded'])
                self.assertIsNone(rows[0]['delta_from_previous'])
                for old,new in zip(rows,rows[1:]):
                    self.assertEqual(new['delta_from_previous']['pickups'],new['pickups']-old['pickups'])


if __name__=='__main__':unittest.main()
