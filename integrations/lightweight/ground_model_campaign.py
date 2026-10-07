"""LW integrated exploration: observed-ground models on/off, same inherited World."""
import json
from pathlib import Path
from collections import Counter
from .timed_harvest import run
from .integrated_social_campaign import audit,compact_report
from .render_ground_wear import render


def main(days=30):
    root=Path('outputs/ground_model' if days==30 else f'outputs/ground_model_{days}d');root.mkdir(parents=True,exist_ok=True)
    source=json.loads(Path('docs/experiment-evidence/LW_cohort_paths.json').read_text(encoding='utf8'))
    reports={};actions={}
    for name in ('disabled','enabled'):
        opts=dict(source['runs']['inherited']['options'],days=days,ground_continuity_enabled=name=='enabled')
        path=root/(name+'.jsonl');run(path,**opts,world_checkpoint=source['checkpoint'])
        checked=audit(path,days=days);report=compact_report({name:dict(options=opts,audit=checked)})[name]
        report['ground_wear']=checked['summary']['ground_wear']
        counts=Counter();identities=set();commands={};increases=set();selected_ops=set();executed=0
        for line in path.open(encoding='utf8'):
            row=json.loads(line)
            if row['type']=='completed':
                executed+=int(row['command']['operation_id'] in selected_ops)
            if row['type']!='decision':continue
            p=row['packet'];c=row['command'];s=row.get('continuous_selection') or {}
            commands[(p['agent_id'],p['capture_us'])]=(c['kind'],c['amount'])
            g=row.get('ground_continuity') or {}
            for m in g.get('models',[]):
                identities.add((p['agent_id'],m['model_ref']))
                counts['linked_model_observations']+=int(bool(m['links']))
                counts['changed_context']+=int(m['status']=='observed_context_changed')
            counts['decisions_with_candidate']+=any('/ground_' in x['model'] for x in s.get('candidates',[]))
            selected='/ground_' in (s.get('selected') or '')
            counts['selected']+=selected
            if selected and c['reason'].startswith('continuous_food/ground_'):selected_ops.add(c['operation_id'])
            for event in s.get('events',[]):
                if '/ground_' in event['model'] and event['H_after']>event['H_before']:
                    increases.add((p['agent_id'],event['source'],event['result_source']))
        report['ground_models']=dict(counts,distinct_models=len(identities),H_increases=len(increases),executed_selected=executed)
        reports[name]=report;actions[name]=commands
        (root/(name+'.json')).write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
        render(root/(name+'.json'),root/(name+'.svg'))
        print(name,json.dumps(dict(summary=report['audit']['summary'],models=report['ground_models'])),flush=True)
    assert actions['disabled'].keys()==actions['enabled'].keys()
    difference=sum(v!=actions['enabled'][k] for k,v in actions['disabled'].items())
    output=dict(rule='LW-integrated-ground-model-comparison-v1',runs=reports,
        compared_decisions=len(actions['disabled']),changed_kind_amount=difference)
    (root/'report.json').write_text(json.dumps(output,indent=2)+'\n',encoding='utf8')
    print('changed_kind_amount',difference,flush=True)
    from .audit_ground_model import main as replay
    replay(root)
    from .summarize_ground_model import main as periods
    periods(root)

if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--days',type=int,choices=(30,90),default=30)
    main(parser.parse_args().days)
