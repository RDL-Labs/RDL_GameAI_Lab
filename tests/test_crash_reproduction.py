import tempfile
import unittest
from pathlib import Path
from integrations.lightweight.crash_reproduction import tail_time


class CrashLogTests(unittest.TestCase):
    def test_partial_final_line_keeps_last_complete_time(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'run.jsonl'
            path.write_bytes(b'{"capture_us":10}\n{"result":{"executed_us":20}}\n{"packet":')
            self.assertEqual(tail_time(path),20)

    def test_summary_time_and_missing_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'run.jsonl'
            self.assertIsNone(tail_time(path))
            path.write_text('{"packet":{"capture_us":15}}\n{"ended_us":30}\n')
            self.assertEqual(tail_time(path),30)


if __name__=='__main__':unittest.main()
