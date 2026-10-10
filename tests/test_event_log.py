import json
from pathlib import Path
import tempfile
import unittest
from integrations.lightweight.timed_harvest import run
from integrations.lightweight.integrated_social_campaign import audit


class EventLogTests(unittest.TestCase):
    def test_metabolic_intervals_split_at_rate_jump_and_hunger_boundary(self):
        from integrations.lightweight.event_log import EventLog
        rows=[];log=EventLog(rows.append)
        def feed(start,before,after):
            log.emit(dict(type='metabolism',start_us=start,end_us=start+1,
                before={'a':before},after={'a':after}))
        feed(0,84,83);feed(1,83,82)
        feed(2,82,81);feed(3,81,80)
        feed(4,90,89);feed(5,89,87)
        log.flush_metabolism()
        self.assertEqual([r['count'] for r in rows],[3,1,1,1])
        self.assertIn('boundary_crossing',rows[1])
        self.assertEqual(rows[2]['before'],{'a':90})
        for r in rows:
            self.assertAlmostEqual(r['before']['a']+r['rate_per_us']['a']*(r['end_us']-r['start_us']),r['after']['a'])

    def test_zero_saturation_and_summary_flush(self):
        from integrations.lightweight.event_log import EventLog
        rows=[];log=EventLog(rows.append)
        for t,b,a in [(0,1,0),(1,0,0),(2,0,0)]:
            log.emit(dict(type='metabolism',start_us=t,end_us=t+1,before={'a':b},after={'a':a}))
        log.emit(dict(type='summary'))
        self.assertEqual([r.get('count') for r in rows],[1,2,None])

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
