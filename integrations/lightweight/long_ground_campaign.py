"""Supervised long human-scale campaign with observer-only daily ground maps."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import time


def save(path,data):
    temp=path.with_suffix('.tmp')
    temp.write_text(json.dumps(data,indent=2),encoding='utf8');temp.replace(path)


def worker(args):
    from runtime.lw_time import DAY_US,metadata
    from .timed_harvest import run
    from .integrated_social_campaign import audit,compact_report
    from .base_landscape import install,render
    from .energy_exploration import EnergyWorld
    root=args.output
    preview=EnergyWorld('map',seed=20261005);install(preview);render(preview,root/'base.html')
    base=(root/'base.html').read_text(encoding='utf8')
    counts={};usage={};last_hour=-1
    def ground(day,snapshot):
        save(root/f'ground-day-{day:02d}.json',snapshot)
        cells=snapshot['cells'];rects=[]
        for key,cell in cells.items():
            if cell['wear']<=0:continue
            x,z=map(int,key.split(','));opacity=min(1,cell['wear']/10)
            rects.append(f'<rect x="{32+(x+64)*5}" y="{48+(70-z-1)*5}" width="5" height="5" fill="#7c4c21" opacity="{opacity:.3f}"><title>wear {cell["wear"]:.3f}</title></rect>')
        html=base.replace('</svg>',''.join(rects)+'</svg>')+f'<p>Day {day}: ground wear overlay, not agent knowledge.</p>'
        (root/f'ground-day-{day:02d}.html').write_text(html,encoding='utf8')
        save(root/f'day-{day:02d}.json',dict(day=day,actions=counts,ground_candidate_selections=usage,
            worn_cells=sum(c['wear']>0 for c in cells.values()),road_cells=sum(c['wear']>=10 for c in cells.values()),
            max_wear=max((c['wear'] for c in cells.values()),default=0)))
    def observe(row):
        nonlocal last_hour
        kind=row['type']
        if kind=='completed':
            a=row['command']['agent_id'];c=counts.setdefault(a,{})
            status=row['result']['status'];c[status]=c.get(status,0)+1
        elif kind=='decision':
            selected=(row.get('continuous_selection') or {}).get('selected','') or ''
            if selected.startswith('food/ground_'):
                a=row['command']['agent_id'];usage[a]=usage.get(a,0)+1
        elif kind=='ground_day':ground(row['day'],row['ground_wear'])
        elif kind=='summary':
            if row['ended_us'] % DAY_US == 0:ground(row['ended_us']//DAY_US,row['ground_wear'])
            else:save(root/'ground-partial.json',row['ground_wear'])
            save(root/'summary.json',row)
        t=row.get('capture_us',row.get('packet',{}).get('capture_us',0))
        hour=t//720_000_000
        if hour>last_hour:
            last_hour=hour
            save(root/'progress.json',dict(sim_us=t,day_fraction=t/DAY_US,planned_days=args.days,
                actions=counts,ground_candidate_selections=usage))
    source=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text(encoding='utf8'))
    options=dict(source['runs']['inherited']['options'],days=args.days,body_scene='social_base',
        run_id='lw-scaled-base',ground_continuity_enabled=True,exploration_horizon_enabled=True,
        observation_interval_us=args.observation_us,movement_inertia=args.movement_inertia)
    if args.seconds:options['run_duration_us']=args.seconds*1_000_000
    save(root/'options.json',dict(options,time_profile=metadata()))
    run(root/'run.jsonl',log_observer=observe,**options)
    save(root/'report.json',compact_report({'long':dict(options=options,
        audit=audit(root/'run.jsonl',days=args.days,duration_us=args.seconds*1_000_000 if args.seconds else None))}))


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True)
    p.add_argument('--days',type=int,default=30);p.add_argument('--seconds',type=int)
    p.add_argument('--observation-us',type=int,choices=(250000,1000000,5000000),default=250000)
    p.add_argument('--movement-inertia',action='store_true')
    p.add_argument('--worker',action='store_true');args=p.parse_args()
    if args.worker:worker(args);return
    args.output.mkdir(parents=True,exist_ok=False)
    command=[sys.executable,'-X','faulthandler','-m',__spec__.name,'--worker','--days',str(args.days),'--output',str(args.output),
        '--observation-us',str(args.observation_us)]
    if args.movement_inertia:command+=['--movement-inertia']
    if args.seconds:command+=['--seconds',str(args.seconds)]
    env=dict(os.environ,RDL_LW_TIME_PROFILE='human_scale_v1',PYTHONHASHSEED='0')
    start=time.time()
    with (args.output/'stdout.log').open('wb') as out,(args.output/'stderr.log').open('wb') as err:
        process=subprocess.Popen(command,env=env,stdout=out,stderr=err)
        save(args.output/'status.json',dict(state='running',pid=process.pid,started_unix=start,
            commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),command=command))
        code=process.wait()
    save(args.output/'status.json',dict(state='completed' if code==0 else 'failed',returncode=code,
        exit_hex=hex(code&0xffffffff),started_unix=start,elapsed_seconds=time.time()-start))
    raise SystemExit(code)


if __name__=='__main__':main()
