import json
from pathlib import Path
import tempfile
import unittest
from integrations.lightweight.timed_harvest import run
from integrations.lightweight.integrated_social_campaign import audit


class ObservationCadenceTests(unittest.TestCase):
    def test_coarse_observation_keeps_world_clock_and_body_audit(self):
        source=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text(encoding='utf8'))
        options=dict(source['runs']['inherited']['options'],days=1,body_scene='social_base',
            run_duration_us=8000000,stop_after_returns=None)
        records={}
        with tempfile.TemporaryDirectory() as directory:
            for interval in (250000,1000000):
                p=Path(directory)/str(interval)
                summary=run(p,observation_interval_us=interval,**options)
                rows=[json.loads(x) for x in p.read_text(encoding='utf8').splitlines()]
                packets=[r['packet'] for r in rows if r['type'] in ('decision','working_capture')]
                self.assertTrue(all(x['capture_us'] % interval == 0 for x in packets))
                self.assertEqual(len(packets),summary['captures'])
                self.assertEqual(summary['ended_us'],8000000)
                report=audit(p,days=1,duration_us=8000000)
                self.assertTrue(report['food_conserved'])
                self.assertTrue(report['no_duplicate_or_overlapping_effects'])
                records[interval]=(summary['captures'],sum(r['type']=='metabolism' for r in rows))
            self.assertEqual(records[250000][0],records[1000000][0]*4)
            self.assertEqual(records[250000][1],records[1000000][1])

if __name__=='__main__':unittest.main()
