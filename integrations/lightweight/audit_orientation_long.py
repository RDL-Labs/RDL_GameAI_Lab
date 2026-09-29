"""Audit paired completed 30-day initial-orientation runs."""
import json
from collections import Counter
from pathlib import Path
from .audit_threshold_sweep import audit


def summarize(path):
    report=audit(path)
    counts={aid:Counter() for aid in report['agents']}
    days={}
    for line in Path(path).open(encoding='utf8'):
        row=json.loads(line)
        if row['type']!='decision':continue
        c=row['command'];aid=c['agent_id'];day=str(c['capture_us']//64000000+1)
        counts[aid][c['reason']]+=1
        d=days.setdefault(day,{}).setdefault(aid,dict(reviews=0,left_rescans=0,moves=0))
        d['reviews']+=int(bool(row.get('orientation_review')))
        d['left_rescans']+=int(c['reason']=='food_goal_rescan' and c['amount']==-90)
        d['moves']+=int(c['kind']=='move')
    report['decision_reasons']={aid:dict(c) for aid,c in counts.items()}
    report['days']=days
    return report


def main():
    reports=[summarize('integrations/lightweight/output/orientation_30d_'+mode+'.jsonl') for mode in ('disabled','enabled')]
    assert {k:v for k,v in reports[0]['manifest'].items() if k!='orientation_mode'}=={k:v for k,v in reports[1]['manifest'].items() if k!='orientation_mode'}
    dest=Path('tests/fixtures/lightweight_orientation_30d_comparison.json')
    dest.write_text(json.dumps(dict(runs=reports),indent=2),encoding='utf8')
    for r in reports:
        print(r['manifest']['orientation_mode'],json.dumps(r['agents']))
        print('reviews',sum(a['reviews'] for d in r['days'].values() for a in d.values()),'left',sum(a['left_rescans'] for d in r['days'].values() for a in d.values()))
        print(json.dumps(r['decision_reasons']))

if __name__=='__main__':main()
