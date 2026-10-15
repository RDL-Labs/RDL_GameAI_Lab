import copy
import hashlib
import json
from pathlib import Path
import unittest
import subprocess
from .reference import prepare,batch,nearest


class ReferenceTests(unittest.TestCase):
    def test_maintenance_preserves_original_prefix(self):
        root=Path('experiments/julia_migration/fixtures')
        for name in ('geometry_inputs.jsonl','geometry_expected.jsonl','groups.jsonl'):
            original=subprocess.check_output(['git','show',f'315f864:{root.as_posix()}/{name}'])
            self.assertTrue((root/name).read_bytes().startswith(original),name)

    def test_frozen_inputs_and_outputs(self):
        root=Path('experiments/julia_migration/fixtures')
        meta=json.loads((root/'hashes.json').read_text())
        for name,digest in meta['hashes'].items():
            self.assertEqual(hashlib.sha256((root/name).read_bytes()).hexdigest(),digest)
        rows=[json.loads(s) for s in (root/'geometry_inputs.jsonl').read_text().splitlines()]
        before=copy.deepcopy(rows);qs=[prepare(r) for r in rows];snapshot=copy.deepcopy(qs)
        expected=[json.loads(s)['value'] for s in (root/'geometry_expected.jsonl').read_text().splitlines()]
        actual=batch(qs)
        for a,b in zip(actual,expected):
            self.assertIs(type(a),type(b))
            if isinstance(b,float):self.assertLessEqual(abs(a-b),1e-12+1e-12*abs(b))
            else:self.assertEqual(a,b)
        self.assertEqual(actual,batch(qs));self.assertEqual(qs,snapshot);self.assertEqual(rows,before)
        actual[0]=123.;self.assertNotEqual(batch(qs)[0],123.)
        for s in (root/'groups.jsonl').read_text().splitlines():
            g=json.loads(s);self.assertEqual(nearest(batch([qs[i] for i in g['indices']])),g['nearest'])

    def test_invalid_wrapper_inputs(self):
        base=dict(kind='ray',start=[0.,0.],vector=[1.,0.],circle=[1.,0.,1.],margin=0.)
        for bad in (dict(start=[0.]),dict(vector=[0.,0.]),dict(circle=[1.,0.,-1.]),
                    dict(margin=-1.),dict(start=[float('nan'),0.]),dict(start=[float('inf'),0.]),
                    dict(start=[10001.,0.]),dict(kind='unknown'),dict(start=[True,False])):
            with self.subTest(bad=bad),self.assertRaises(ValueError):prepare(dict(base,**bad))


if __name__=='__main__':unittest.main()
