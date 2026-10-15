import copy
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest
from .bridge import Bridge,encode,decode_queries,decode,encode_results,difference,shadow,MAX_QUERIES,RESPONSE
from experiments.julia_migration.python.reference import prepare,batch


class CodecTests(unittest.TestCase):
    def test_wrong_response_binding_is_terminal(self):
        bridge=object.__new__(Bridge)
        bridge.timeout=1;bridge.sequence=0;bridge.failed=False
        bridge._write=lambda data,deadline:None
        bridge._read=lambda size,deadline:RESPONSE.pack(b'RDR3',99,0,0,0,0,0)
        with self.assertRaisesRegex(ValueError,'response_binding'):bridge.call([])
        self.assertTrue(bridge.failed)
        with self.assertRaisesRegex(RuntimeError,'bridge_failed'):bridge.call([])

    def test_roundtrip_and_discrete_boundaries(self):
        rows=[json.loads(s) for s in Path('experiments/julia_migration/fixtures/geometry_inputs.jsonl').read_text().splitlines()]
        qs=[prepare(r) for r in rows];before=copy.deepcopy(qs)
        self.assertEqual(decode_queries(encode(qs)),qs)
        self.assertIsNone(difference(batch(qs),decode(encode_results(batch(qs)))))
        self.assertEqual(qs,before)
        self.assertIsNotNone(difference([None],[0.]))
        self.assertIsNotNone(difference([False],[0.]))
        self.assertIsNotNone(difference([1.],[True]))
        self.assertIsNotNone(difference([1.],[1.001]))
        with self.assertRaises(ValueError):encode([None]*(MAX_QUERIES+1))
        with self.assertRaises(ValueError):decode(b'\x04'+b'\x00'*8)


@unittest.skipUnless(os.environ.get('J3_INTEGRATION')=='1','explicit Julia integration only')
class BridgeTests(unittest.TestCase):
    def test_fixture_shadow_and_failure(self):
        rows=[json.loads(s) for s in Path('experiments/julia_migration/fixtures/geometry_inputs.jsonl').read_text().splitlines()]
        qs=[prepare(r) for r in rows];before=copy.deepcopy(qs)
        with tempfile.TemporaryFile(mode='w+') as err:
            bridge=Bridge(err)
            try:
                pid=bridge.process.pid
                self.assertEqual(bridge.call([])[0],[])
                expected=batch(qs)
                returned,timing=shadow(qs,bridge)
                self.assertEqual(returned,expected)
                returned[0]=123.
                self.assertEqual(shadow(qs,bridge)[0],expected)
                self.assertEqual(bridge.process.pid,pid)
                self.assertEqual(qs,before)
                bridge.process.kill();bridge.process.wait()
                with self.assertRaises((RuntimeError,BrokenPipeError)):bridge.call(qs)
                with self.assertRaisesRegex(RuntimeError,'bridge_failed'):bridge.call(qs)
            finally:bridge.close()

    def test_start_failure_and_invalid_server_input(self):
        with tempfile.TemporaryFile(mode='w+') as err:
            with self.assertRaises(FileNotFoundError):Bridge(err,executable='/not-a-julia-executable')
            bridge=Bridge(err)
            try:
                q=('segment',(0.,0.),(1.,0.),dict(x=0.,z=0.,radius=-1.),0.)
                with self.assertRaises(RuntimeError):bridge.call([q])
                self.assertTrue(bridge.failed)
            finally:bridge.close()

    def test_owned_snapshot_replay(self):
        source=Path(os.environ['J3_SNAPSHOTS'])
        meta=json.loads((source/'manifest.json').read_text())
        results=[]
        with tempfile.TemporaryFile(mode='w+') as err:
            bridge=Bridge(err)
            try:
                for s in meta['snapshots']:
                    path=source/(s['key']+'.queries.bin');raw=path.read_bytes()
                    self.assertEqual(hashlib.sha256(raw).hexdigest(),s['input_sha256'])
                    qs=decode_queries(raw);before=encode(qs)
                    expected=decode((source/(s['key']+'.expected.bin')).read_bytes())
                    actual,timing=bridge.call(qs)
                    mismatch=difference(expected,actual)
                    if mismatch:
                        (source/'first_difference.json').write_text(json.dumps(dict(snapshot=s['key'],**mismatch)))
                    self.assertIsNone(mismatch)
                    self.assertEqual(bridge.call(qs)[0],actual)
                    actual[0]=123.
                    self.assertIsNone(difference(expected,bridge.call(qs)[0]))
                    returned,_=shadow(qs,bridge)
                    self.assertEqual(returned,batch(qs))
                    self.assertEqual(encode(qs),before)
                    self.assertEqual(path.read_bytes(),raw)
                    results.append(dict(snapshot=s['key'],query_count=len(qs),mismatch=None))
            finally:bridge.close()
        (source/'shadow_correctness.json').write_text(json.dumps(results,indent=2))


if __name__=='__main__':unittest.main()
