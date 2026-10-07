import json
from pathlib import Path
import tempfile
import unittest
from integrations.lightweight.rotation_diagnostic import analyze


class RotationDiagnosticTests(unittest.TestCase):
    def run_rows(self, turns):
        rows=[];x=0
        for t,angle in enumerate(turns):
            moved=angle=='move'
            if moved:x+=1
            status='moved' if moved else 'waited' if angle is None else 'turned'
            rows.append(dict(type='completed',command=dict(agent_id='a',operation_id=str(t),reason='test'),
                result=dict(executed_us=t,status=status,yaw=0 if moved or angle is None else angle,forward=int(moved)),body=dict(x=x,z=0)))
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'log';p.write_text('\n'.join(json.dumps(r) for r in rows))
            return analyze(p,100)['a']

    def test_wait_does_not_hide_stationary_alternation(self):
        s=self.run_rows([45,None,-45,45,-45])
        self.assertEqual(s['max_alternating']['turns'],4)
        self.assertEqual(s['stationary_reversals'],3)
        self.assertEqual(s['alternating_episodes_ge4'],1)
        self.assertEqual(s['max_alternating']['max_position_displacement'],0)

    def test_movement_breaks_chain(self):
        s=self.run_rows([45,-45,'move',45,-45])
        self.assertEqual(s['max_alternating']['turns'],2)
        self.assertEqual(s['turn_followed_by_move'],1)

    def test_one_direction_is_not_alternation(self):
        s=self.run_rows([90,90,90,90])
        self.assertEqual(s['max_stationary']['turns'],4)
        self.assertEqual(s['max_alternating']['turns'],1)
        self.assertEqual(s['stationary_reversals'],0)

if __name__=='__main__':unittest.main()
