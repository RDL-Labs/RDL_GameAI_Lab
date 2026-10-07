"""LW integrated exploration in an expanded landscape; no inherited omniscient map."""
import json
from pathlib import Path
from .timed_harvest import run
from .integrated_social_campaign import audit,compact_report
from .expanded_world import render_layout
from .render_ground_wear import render


def main(days=3):
    root=Path(f'outputs/expanded_world_{days}d');root.mkdir(parents=True,exist_ok=True)
    source=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text(encoding='utf8'))
    options=dict(source['runs']['inherited']['options'],days=days,body_scene='social_expanded',
                 run_id='lw-expanded',ground_continuity_enabled=True)
    path=root/'run.jsonl';summary=run(path,**options)
    checked=audit(path,days=days)
    report=compact_report({'expanded':dict(options=options,audit=checked)})['expanded']
    report['ground_wear']=summary['ground_wear']
    with path.open(encoding='utf8') as f:
        manifest=next(r for line in f if (r:=json.loads(line))['type']=='manifest')
    report['layout']=dict(objects=manifest['objects'],resources=manifest['resources'])
    (root/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    render_layout(manifest,root/'layout.svg');render(root/'report.json',root/'ground.svg')
    print(json.dumps(report['audit']['summary'],indent=2))

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--days',type=int,choices=(3,30,90),default=3)
    main(p.parse_args().days)
