import gc
import json
from pathlib import Path
import sys
import time
import tracemalloc
from .reference import prepare, batch


def main(output):
    start=time.perf_counter()
    rows=[json.loads(s) for s in Path('experiments/julia_migration/fixtures/geometry_inputs.jsonl').read_text().splitlines()]
    parse=time.perf_counter()-start
    start=time.perf_counter();queries=[prepare(r) for r in rows];conversion=time.perf_counter()-start
    start=time.perf_counter();first=batch(queries);first_time=time.perf_counter()-start
    if output=='cold':
        print(json.dumps(dict(valid=len(first)==len(queries),python=sys.version)));return
    measurements=[]
    for n in (23,100,1024):
        qs=([q for q,r in zip(queries,rows) if r['label']=='observed-world-cast'] if n==100 else queries[:n]);times=[]
        assert len(qs)==n
        batch(qs)
        before=gc.get_stats()
        for _ in range(200):
            start=time.perf_counter_ns();result=batch(qs);times.append(time.perf_counter_ns()-start)
        after=gc.get_stats()
        # Memory instrumentation is separate from timing.
        tracemalloc.start();result=batch(qs);current,peak=tracemalloc.get_traced_memory();tracemalloc.stop()
        measurements.append(dict(n=n,times_ns=times,tracemalloc_peak_bytes=peak,
            gc_collections=[a['collections']-b['collections'] for a,b in zip(after,before)],
            gc_seconds=None,gc_reason='Python collection counts only, no GC timing instrumentation in benchmark'))
    Path(output).write_text(json.dumps(dict(python=sys.version,parse_seconds=parse,
        conversion_seconds=conversion,first_batch_seconds=first_time,measurements=measurements),indent=2))


if __name__=='__main__':main(sys.argv[1])
