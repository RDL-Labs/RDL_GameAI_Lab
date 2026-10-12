"""J0: independent baseline pairs and a separate actual-worker profile."""
import json
import os
from pathlib import Path
import platform
import pstats
import subprocess
import sys
from .reference import BASE


def save(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf8')


def main(root):
    root.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, PYTHONHASHSEED='0', RDL_LW_TIME_PROFILE='human_scale_v1')
    commit = subprocess.check_output(['git','rev-parse','HEAD'], text=True).strip()
    save(root/'manifest.json', dict(baseline=BASE, experiment_commit=commit,
        baseline_diff=subprocess.check_output(['git','diff','--stat',BASE],text=True),
        python=sys.version, platform=platform.platform(), cpu=Path('/proc/cpuinfo').read_text(),
        dependencies=subprocess.check_output([sys.executable,'-m','pip','freeze'],text=True),
        summary_exclusion_allowlist=['elapsed_seconds'], julia_version='1.13.1', threads=1))
    common=['-m','integrations.lightweight.long_ground_campaign','--days','1',
            '--seconds','180','--observation-us','1000000','--movement-inertia']
    pairs=[]
    for series in range(3):
        states={};timings={}
        for mode in (('events','off') if series%2==0 else ('off','events')):
            dest=root/f'baseline-{series}-{mode}'
            command=[sys.executable,*common,'--log-mode',mode,'--output',str(dest)]
            subprocess.run(command,env=env,check=True)
            s=json.loads((dest/'summary.json').read_text())
            timings[mode]=dict(simulation_seconds=s.pop('elapsed_seconds'),
                supervisor_seconds=json.loads((dest/'status.json').read_text())['elapsed_seconds'],command=command)
            states[mode]=s
        pairs.append(dict(series=series,timing=timings,final_state_equal=states['events']==states['off']))
        save(root/'baseline_comparison.json',pairs)
        assert pairs[-1]['final_state_equal']
    dest=root/'profile';dest.mkdir()
    command=[sys.executable,'-m','cProfile','-o',str(dest/'profile.pstats'),*common,
             '--worker','--log-mode','off','--output',str(dest)]
    subprocess.run(command,env=env,check=True)
    stats=pstats.Stats(str(dest/'profile.pstats'))
    rows=[];categories={}
    for (file,line,name),(primitive,calls,self_time,cumulative,callers) in stats.stats.items():
        category=('history_copy' if file.endswith('/copy.py') else
                  'geometry' if name in ('ray_hit','segment_hit','hypot','sqrt') else
                  'logging_observer_io' if any(s in file for s in ('event_log.py','json/','long_ground_campaign.py')) else
                  'observation' if any(s in name for s in ('capture','observe','visible','cast','packet')) else
                  'candidate_model' if any(s in file for s in ('selection','terrain','model','candidate','sleep')) else 'other')
        categories[category]=categories.get(category,0)+self_time
        rows.append(dict(file=file,line=line,function=name,calls=calls,self_seconds=self_time,cumulative_seconds=cumulative,category=category))
    save(dest/'profile.json',dict(command=command,total_seconds=stats.total_tt,
        categories_exclusive_seconds=categories,
        top_self=sorted(rows,key=lambda r:r['self_seconds'],reverse=True)[:60],
        top_cumulative=sorted(rows,key=lambda r:r['cumulative_seconds'],reverse=True)[:60],
        geometry=[r for r in rows if r['function'] in ('ray_hit','segment_hit')],
        limitation='exclusive categories are heuristic; cumulative time overlaps; not benchmark timing'))


if __name__=='__main__':main(Path(sys.argv[1]))
