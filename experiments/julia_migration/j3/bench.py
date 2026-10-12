import hashlib
import json
from pathlib import Path
import statistics
import sys
import time
from experiments.julia_migration.python.reference import batch
from .bridge import Bridge,decode_queries,decode,difference,encode_results


def rss(pid,field='VmRSS:'):
    try:return int(next(s.split()[1] for s in Path(f'/proc/{pid}/status').read_text().splitlines() if s.startswith(field)))
    except (FileNotFoundError,StopIteration):return None


def main(mode,source,out):
    import os
    out.mkdir(parents=True,exist_ok=False)
    started=time.perf_counter()
    meta=json.loads((source/'manifest.json').read_text())
    samples=[]
    for s in meta['snapshots']:
        raw=(source/(s['key']+'.queries.bin')).read_bytes()
        expected=(source/(s['key']+'.expected.bin')).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==s['input_sha256']
        assert hashlib.sha256(expected).hexdigest()==s['expected_sha256']
        samples.append((s,decode_queries(raw),decode(expected)))
    input_seconds=time.perf_counter()-started
    bridge=None;stderr=(out/'julia.stderr.txt').open('w')
    measurements=[];memory=[];first_difference=None;bit_differences=0
    try:
        start=time.perf_counter()
        if mode=='julia':bridge=Bridge(stderr)
        def run(q):
            if bridge:return bridge.call(q)
            t=time.perf_counter_ns();values=batch(q)
            return values,dict(total_ns=time.perf_counter_ns()-t)
        first,timing=run(samples[0][1])
        startup_first_seconds=time.perf_counter()-start
        assert difference(samples[0][2],first) is None
        for s,queries,expected in samples:
            actual,_=run(queries) # warm-up; full comparison not in timing
            mismatch=difference(expected,actual)
            if mismatch:
                first_difference=dict(snapshot=s['key'],**mismatch)
                (out/'first_difference.json').write_text(json.dumps(first_difference,indent=2))
                raise AssertionError(first_difference)
            for a,b in zip(expected,actual):
                bit_differences+=encode_results([a])!=encode_results([b])
            rows=[]
            for _ in range(30):
                actual,timing=run(queries);rows.append(timing)
            assert difference(expected,actual) is None
            memory.append(dict(snapshot=s['key'],parent_rss_kib=rss(os.getpid()),
                server_rss_kib=rss(bridge.process.pid) if bridge else None))
            measurements.append(dict(snapshot=s['key'],query_count=len(queries),samples=rows,
                median_ns=statistics.median(t['total_ns'] for t in rows)))
        report=dict(mode=mode,input_seconds=input_seconds,startup_first_seconds=startup_first_seconds,
            first_difference=first_difference,bit_differences=bit_differences,memory_samples=memory,
            measurements=measurements,server_pid=bridge.process.pid if bridge else None,
            request_count=bridge.sequence if bridge else None,
            parent_peak_rss_kib=rss(os.getpid(),'VmHWM:'),
            server_peak_rss_kib=rss(bridge.process.pid,'VmHWM:') if bridge else None)
        (out/'result.json').write_text(json.dumps(report,indent=2))
    finally:
        if bridge:bridge.close()
        stderr.close()


if __name__=='__main__':main(sys.argv[1],Path(sys.argv[2]),Path(sys.argv[3]))
