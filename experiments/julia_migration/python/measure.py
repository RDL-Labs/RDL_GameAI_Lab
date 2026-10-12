import json
from pathlib import Path
import statistics
import subprocess
import sys
import time


def main(root):
    root.mkdir(parents=True,exist_ok=True)
    project='experiments/julia_migration/julia'
    commands=dict(python=[sys.executable,'-m','experiments.julia_migration.python.geometry_bench'],
        julia=['julia','--startup-file=no','--threads=1',f'--project={project}',f'{project}/bench/geometry.jl'])
    records=[]
    for series in range(3):
        for lang in (('python','julia') if series%2==0 else ('julia','python')):
            for stage in ('cold','warm'):
                dest=root/f'{lang}-{series}-{stage}'
                command=[*commands[lang],'cold' if stage=='cold' else str(dest.with_suffix('.json'))]
                start=time.perf_counter()
                result=subprocess.run(['/usr/bin/time','-v','-o',str(dest.with_suffix('.resource.txt')),*command],
                    capture_output=True,text=True)
                wall=time.perf_counter()-start
                dest.with_suffix('.stdout.txt').write_text(result.stdout)
                dest.with_suffix('.stderr.txt').write_text(result.stderr)
                result.check_returncode()
                if stage=='cold':assert json.loads(result.stdout)['valid']
                records.append(dict(series=series,language=lang,stage=stage,wall_seconds=wall,command=command))
                (root/'process_timings.json').write_text(json.dumps(records,indent=2))
    medians={}
    for lang in commands:
        for n in (23,100,1024):
            vals=[]
            for series in range(3):
                data=json.loads((root/f'{lang}-{series}-warm.json').read_text())
                vals.append(statistics.median(next(m['times_ns'] for m in data['measurements'] if m['n']==n)))
            medians[f'{lang}_{n}']=vals
    comparison=dict(series_medians_ns=medians,speedup={str(n):statistics.median(medians[f'python_{n}'])/statistics.median(medians[f'julia_{n}']) for n in (23,100,1024)},
        limitation='kernel only; no Python-Julia bridge; process wall includes imports of benchmark tools; no production speedup claim')
    (root/'timing_comparison.json').write_text(json.dumps(comparison,indent=2))
    print(json.dumps(comparison,indent=2))


if __name__=='__main__':main(Path(sys.argv[1]))
