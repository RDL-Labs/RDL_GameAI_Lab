"""Isolated launcher: pin the time profile before any runtime imports."""
import os
import sys
import subprocess

def main():
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--window-seconds',type=int,default=180)
    p.add_argument('--full-day',action='store_true');p.add_argument('--worker',action='store_true',help=argparse.SUPPRESS)
    args=p.parse_args()
    if not args.worker:
        env=dict(os.environ,RDL_LW_TIME_PROFILE='human_scale_v1')
        raise SystemExit(subprocess.call([sys.executable,'-m',__spec__.name,*sys.argv[1:],'--worker'],env=env))
    from pathlib import Path
    import json
    from runtime.lw_time import DAY_US,metadata
    from .timed_harvest import run
    from .integrated_social_campaign import audit,compact_report
    duration=DAY_US if args.full_day else args.window_seconds*1_000_000
    root=Path(f'outputs/scaled_base_{duration}us');root.mkdir(parents=True,exist_ok=True)
    source=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text(encoding='utf8'))
    options=dict(source['runs']['inherited']['options'],days=1,body_scene='social_base',run_id='lw-scaled-base',
        ground_continuity_enabled=True,exploration_horizon_enabled=True,run_duration_us=duration)
    run(root/'run.jsonl',**options)
    report=compact_report({'scaled':dict(options=options,audit=audit(root/'run.jsonl',days=1,duration_us=duration))})
    report['time_profile']=metadata()
    (root/'report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report['scaled']['audit']['summary'],indent=2))

if __name__=='__main__':main()
