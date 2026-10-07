"""Run the riparian scene with existing LW integrated settings."""
import json
from pathlib import Path
from .timed_harvest import run
from .integrated_social_campaign import audit,compact_report
from .base_landscape import install,render
from .energy_exploration import EnergyWorld

def main(days=3,seed=20261005,exploration_horizon=False):
    root=Path(f'outputs/base_landscape_{seed}_{days}d'+('_horizon' if exploration_horizon else ''));root.mkdir(parents=True,exist_ok=True)
    src=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text(encoding='utf8'))
    options=dict(src['runs']['inherited']['options'],days=days,seed=seed,body_scene='social_base',run_id='lw-base',ground_continuity_enabled=True,exploration_horizon_enabled=exploration_horizon)
    run(root/'run.jsonl',**options)
    report=compact_report({'base':dict(options=options,audit=audit(root/'run.jsonl',days=days))})
    (root/'report.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    w=EnergyWorld('preview',seed=seed);install(w);render(w,root/'map.html')
    print(json.dumps(report['base']['audit']['summary'],indent=2))

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--days',type=int,choices=(3,30,90),default=3);p.add_argument('--seed',type=int,default=20261005)
    p.add_argument('--exploration-horizon',action='store_true')
    a=p.parse_args();main(a.days,a.seed,a.exploration_horizon)
