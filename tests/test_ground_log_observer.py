import tempfile
import unittest
from pathlib import Path
from integrations.lightweight.timed_harvest import run


class GroundObserverTests(unittest.TestCase):
    def test_observer_preserves_world_and_records_initial_ground(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);rows=[]
            options=dict(days=1,run_duration_us=1000000,stop_after_returns=None,ground_wear_enabled=True,
                body_mode='enabled',energy_mode='enabled',selection_mode='continuous')
            before=run(root/'before.jsonl',**options)
            after=run(root/'after.jsonl',log_observer=lambda r: rows.append(r['type']),**options)
            before.pop('elapsed_seconds');after.pop('elapsed_seconds')
            self.assertEqual(before,after)
            self.assertEqual(rows.count('ground_day'),1)
            self.assertEqual(rows[-1],'summary')

if __name__=='__main__':unittest.main()
