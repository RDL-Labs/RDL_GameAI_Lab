"""Summarize the completed reposition trial against its saved control."""
import json
from pathlib import Path
from collections import Counter
from .audit_threshold_sweep import audit

def main():
    reports=[]
    for name in ('orientation_30d_enabled','reposition_30d_enabled'):
        path=Path('integrations/lightweight/output')/(name+'.jsonl')
        r=audit(path);counts={a:Counter() for a in r['agents']};reasons={a:Counter() for a in r['agents']}
        for line in path.open(encoding='utf-8'):
            row=json.loads(line)
            if row['type']!='decision':continue
            a=row['command']['agent_id'];reasons[a][row['command']['reason']]+=1
            t=row.get('reposition')
            if t:
                assert t['operations']<=16
                counts[a][t['reason']]+=1
                if t['applied']:
                    assert row['activity_phase']=='exploration'
                    assert t['baseline_reason']=='acquisition_incomplete'
                    assert (0 if row['command']['kind']=='move' else row['command']['amount']) in t['eligible']
        r['reposition_counts']={a:dict(c) for a,c in counts.items()}
        r['decision_reasons']={a:dict(c) for a,c in reasons.items()};reports.append(r)
    assert {k:v for k,v in reports[0]['manifest'].items() if k!='reposition_mode'}=={k:v for k,v in reports[1]['manifest'].items() if k!='reposition_mode'}
    Path('tests/fixtures/lightweight_reposition_30d_comparison.json').write_text(json.dumps(dict(runs=reports,baseline_note='prior orientation-enabled run reused; absent reposition_mode means disabled'),indent=2),encoding='utf-8')
    print('completed paired runs and intervention gates verified')
if __name__=='__main__':main()
