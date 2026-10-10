import json
from pathlib import Path
import tempfile
import unittest
from integrations.lightweight.timed_harvest import run
from integrations.lightweight.integrated_social_campaign import audit


class EventLogTests(unittest.TestCase):
    def test_logging_does_not_change_state_and_preserves_audit(self):
        source=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text())
        options=dict(source['runs']['inherited']['options'],days=1,body_scene='social_base',
            run_duration_us=20_000_000,stop_after_returns=None)
        summaries=[];sizes=[];audits=[]
        with tempfile.TemporaryDirectory() as directory:
            for mode in ('full','events'):
                path=Path(directory)/mode
                summary=run(path,log_mode=mode,**options)
                summary.pop('elapsed_seconds');summaries.append(summary)
                sizes.append(path.stat().st_size)
                audits.append(audit(path,days=1,duration_us=20_000_000))
            self.assertEqual(summaries[0],summaries[1])
            self.assertLess(sizes[1],sizes[0])
            for key in ('completed','commands','daily','food_conserved','no_duplicate_or_overlapping_effects'):
                self.assertEqual(audits[0][key],audits[1][key])
            self.assertIsNone(audits[1]['safety_decisions'])
            rows=[json.loads(x) for x in path.read_text().splitlines()]
            self.assertFalse(any(x['type'] in ('decision','working_capture','hazard_world') for x in rows))
            self.assertTrue(any(x['type']=='selection_change' for x in rows))


if __name__=='__main__':unittest.main()
