import json
from pathlib import Path
import statistics
import subprocess
import sys
import time


def main(source,root):
    root.mkdir(parents=True,exist_ok=False)
    processes=[]
    for series in range(5):
        for mode in (('python','julia') if series%2==0 else ('julia','python')):
            dest=root/f'{mode}-{series}'
            command=[sys.executable,'-m','experiments.julia_migration.j3.bench',mode,str(source),str(dest)]
            start=time.perf_counter()
            result=subprocess.run(['/usr/bin/time','-v','-o',str(root/f'{mode}-{series}.resource.txt'),*command],
                capture_output=True,text=True)
            elapsed=time.perf_counter()-start
            (root/f'{mode}-{series}.stdout.txt').write_text(result.stdout)
            (root/f'{mode}-{series}.stderr.txt').write_text(result.stderr)
            result.check_returncode()
            processes.append(dict(mode=mode,series=series,command=command,wall_seconds=elapsed))
            (root/'processes.json').write_text(json.dumps(processes,indent=2))
    reports={mode:[json.loads((root/f'{mode}-{i}/result.json').read_text()) for i in range(5)] for mode in ('python','julia')}
    comparison=[]
    for i,s in enumerate(json.loads((source/'manifest.json').read_text())['snapshots']):
        times={mode:[r['measurements'][i]['median_ns'] for r in reports[mode]] for mode in reports}
        comparison.append(dict(snapshot=s['key'],query_count=s['query_count'],series_median_ns=times,
            speedup=statistics.median(times['python'])/statistics.median(times['julia'])))
    summary=dict(snapshots=comparison,correctness='all compared; see raw bit_differences and shadow_correctness',
        limitation='Python-selected World geometry traces; no Julia observation/action authority; not World speedup')
    (root/'comparison.json').write_text(json.dumps(summary,indent=2))
    print(json.dumps(summary,indent=2))


if __name__=='__main__':main(Path(sys.argv[1]),Path(sys.argv[2]))
