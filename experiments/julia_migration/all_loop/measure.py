"""External supervisor only: no Python in Julia's simulation loop."""
import hashlib
import json
import math
import platform
import statistics
import subprocess
import sys
import time
from pathlib import Path
from .reference import generate


def compare(a,b,path='root'):
    if isinstance(a,dict):
        assert isinstance(b,dict) and a.keys()==b.keys(),path
        for k in a:compare(a[k],b[k],path+'.'+k)
    elif isinstance(a,list):
        assert isinstance(b,list) and len(a)==len(b),path
        for i,(x,y) in enumerate(zip(a,b)):compare(x,y,f'{path}[{i}]')
    elif type(a) in (int,float) and path.rsplit('.',1)[-1] in {
            'x','z','yaw','burst','strain','reserve','damage','forward','right',
            'distance','resistance','goal_cost','cost'}:
        assert type(b) in (float,int) and math.isclose(a,b,rel_tol=1e-12,abs_tol=1e-12),(path,a,b)
    else:assert type(a)==type(b) and a==b,(path,a,b)


def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
    inputs=out/'scenes.json';generate(inputs)
    commands={'python':[sys.executable,'-m','experiments.julia_migration.all_loop.reference'],
              'julia':['julia','--startup-file=no','--project=experiments/julia_migration/julia',
                       'experiments/julia_migration/all_loop/loop.jl']}
    timings=[]
    def invoke(backend,mode,name):
        target=out/(name+'.json');start=time.perf_counter()
        with (out/(name+'.stdout')).open('w') as stdout, (out/(name+'.stderr')).open('w') as stderr:
            subprocess.run(['/usr/bin/time','-v','-o',str(out/(name+'.resource.txt')),
                            *commands[backend],mode,str(inputs),str(target)],
                           check=True,stdout=stdout,stderr=stderr,timeout=300)
        timings.append(dict(name=name,wall_seconds=time.perf_counter()-start))
        return json.loads(target.read_text())
    p=invoke('python','trace','python-trace');j=invoke('julia','trace','julia-trace');compare(p,j)
    compare(p,invoke('python','trace','python-replay'));compare(j,invoke('julia','trace','julia-replay'))
    assert p['open']['counts']['pickup']>0
    assert p['open']['counts']['eat']>0
    assert p['obstacle']['counts']['blocked_samples']>0
    assert p['enclosed']['counts']['rest']==1800
    assert p['low_reserve']['counts']['body_limited_samples']>0
    assert p['shared']['counts']['pickup']==2
    all_results={b:[] for b in commands}
    for series in range(5):
        for backend in (('python','julia') if series%2==0 else ('julia','python')):
            r=invoke(backend,'bench',f'{backend}-{series}')
            for scene in p:compare(p[scene]['counts'],r[scene]['counts'])
            all_results[backend].append(r)
    report=dict(scope='A0 minimal standalone loop, not LW integrated parity',
                platform=platform.platform(),python=sys.version,
                input_sha256=hashlib.sha256(inputs.read_bytes()).hexdigest(),
                compared_steps=sum(len(r['trace']) for r in p.values()),
                counts={s:r['counts'] for s,r in p.items()},processes=timings,scenes={})
    for scene in p:
        med={b:statistics.median(statistics.median(r[scene]['seconds']) for r in results)
             for b,results in all_results.items()}
        report['scenes'][scene]=dict(seconds=med,speedup=med['python']/med['julia'])
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
