"""Compare identical newcomer inputs with inherited vs reset wear."""
import json
from pathlib import Path


def extract(path):
    decisions={};completed={};manifest=None
    for line in path.open(encoding='utf8'):
        r=json.loads(line)
        if r['type']=='manifest':manifest=r
        if r['type']=='decision':
            c=r['command'];decisions[(c['agent_id'],c['capture_us'])]=(c['kind'],c['amount'])
        if r['type']=='completed':
            c=r['command'];completed[(c['agent_id'],c['capture_us'])]=r['result']['status']
    return manifest,decisions,completed


def main():
    root=Path('outputs/cohort_paths')
    ma,a,ar=extract(root/'inherited.jsonl');mb,b,br=extract(root/'reset.jsonl')
    assert ma.pop('reset_inherited_wear') is False
    assert mb.pop('reset_inherited_wear') is True
    assert ma==mb,'newcomer_initial_conditions_differ'
    keys=a.keys() & b.keys();different=sorted((k for k in keys if a[k]!=b[k]),key=lambda k:(k[1],k[0]))
    common_results=ar.keys() & br.keys()
    report=json.loads((root/'report.json').read_text(encoding='utf8'))
    state=json.loads((root/'checkpoint.json').read_text(encoding='utf8'))
    summary=dict(initial_conditions_equal=True,common_decisions=len(keys),
        changed_actions=len(different),unpaired_decisions=len(a.keys() ^ b.keys()),
        changed_results=sum(ar[k]!=br[k] for k in common_results),
        first_action_difference=([different[0],a[different[0]],b[different[0]]] if different else None),
        formation_road_cells=sum(c['wear']>=10 for c in state['ground']['cells'].values()),
        cases={})
    for name,r in report.items():
        s=r['audit']['summary'];cells=r['ground_wear']['cells']
        summary['cases'][name]=dict(pickups=s['pickups'],eaten=s['social_consumed'],
            reserves={a:b['reserve'] for a,b in s['layered_bodies'].items()},
            first_pickup_day=r['first_pickup_day'],road_cells=sum(c['wear']>=10 for c in cells.values()),
            historical_cells=len(cells),patterns=r['patterns'],
            food_conserved=r['audit']['food_conserved'],
            body_effects_unique=r['audit']['no_duplicate_or_overlapping_effects'])
    (root/'comparison.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf8')
    print(json.dumps(summary,indent=2))

if __name__=='__main__':main()
