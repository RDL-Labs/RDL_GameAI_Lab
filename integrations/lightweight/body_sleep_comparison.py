"""Three agents, three days; bodily exploration, unload and existing night Sleep."""
from collections import Counter
import gzip
import json
from pathlib import Path

from .timed_harvest import run


def audit(path):
    kinds=Counter();statuses=Counter();body_sources=Counter(); reviews=[];effects=set();duplicates=0
    clocks={};last_states={}; continuity=True;bias_applied=0;selection_changed=0
    for line in Path(path).read_text(encoding='utf8').splitlines():
        row=json.loads(line)
        if row['type']=='completed':
            c,r=row['command'],row['result'];aid=c['agent_id'];op=c['operation_id']
            duplicates+=op in effects;effects.add(op)
            kinds[c['kind']]+=1;statuses[r['status']]+=1
            assert r['executed_us']==c['capture_us']+1_000_000
            assert c['capture_us']>=clocks.get(aid,0)
            clocks[aid]=r['executed_us']
            b=row['layered_body']
            if aid in last_states:continuity &= last_states[aid]==b['before']
            last_states[aid]=b['after']
        elif row['type']=='decision':
            trace=(row.get('continuous_selection') or {}).get('sleep_model') or {}
            bias_applied+=trace.get('status')=='applied'
            selection_changed+=bool(trace.get('changed'))
        elif row['type']=='summary':
            for aid,state in row['agents'].items():
                sleep=state['sleep']
                if sleep:
                    for cycle in sleep['completed']+[sleep['cycle']]:
                        if not cycle:continue
                        review=cycle.get('relation_review')
                        reviews.append(dict(agent=aid,day=cycle['day'],status=cycle['status'],rest_us=cycle['rest_us']))
                        if review:
                            for r in review['records']:
                                assert r['agent_id']==aid
                                if 'body_observation' in r:body_sources[r['action']]+=1
    return dict(actions=dict(kinds),statuses=dict(statuses),duplicate_effects=duplicates,
                body_continuity=continuity,night_cycles=reviews,body_sleep_sources=dict(body_sources),
                sleep_bias_applied=bias_applied,sleep_selection_changed=selection_changed)


def main():
    reports={};root=Path('outputs/body_sleep');root.mkdir(parents=True,exist_ok=True)
    fixtures=Path('tests/fixtures/body_sleep');fixtures.mkdir(parents=True,exist_ok=True)
    for scene in ('natural','food_barrier'):
        for enabled in (False,True):
            name=f'{scene}-{enabled}';path=root/(name+'.jsonl')
            options=dict(days=3,stop_after_returns=None,seed=20261002,skyline_subrays=True,
                orientation_mode='enabled',return_completion_mode='enabled',selection_mode='continuous',
                body_mode='enabled',body_scene=scene,sleep_learning=enabled,sleep_auto_adopt=enabled)
            if scene=='natural':
                options.update(goal_difference_mode='enabled',food_goal_mode='enabled',lateral_side='left',
                    reposition_mode='enabled',nested_model_mode='enabled',directional_route_mode='enabled',
                    relation_field_mode='enabled',hazard_mode='enabled',hazard_scenario='territorial',
                    warning_review_mode='enabled',territory_resource_layout='three_inside',dynamic_hazard=True,regrowth_days=3)
            summary=run(path,**options); summary.pop('elapsed_seconds',None)
            reports[name]=dict(options=options,summary=summary,audit=audit(path))
            with gzip.GzipFile(filename=str(fixtures/(name+'.jsonl.gz')),mode='wb',mtime=0) as out:
                out.write(path.read_bytes())
            print(name,summary['pickups'],len(summary['returns']),reports[name]['audit']['body_sleep_sources'],flush=True)
    (fixtures/'comparison.json').write_text(json.dumps(reports,indent=2)+'\n',encoding='utf8')
    return reports


if __name__=='__main__':main()
