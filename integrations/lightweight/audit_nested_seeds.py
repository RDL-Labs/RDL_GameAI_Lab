"""Multi-layout movement continuity audit; performance is not an acceptance gate."""
import json
from pathlib import Path
from .audit_nested_models import summarize

RUNS={20260928:'nested_seed_20260928',20260929:'nested_seed_20260929',20260930:'nested_models_30d_final'}

def continuity(report):
    out={}
    for aid in report['agents']:
        active=[];longest=0;streak=0
        for day in range(1,31):
            moved=report['days'].get(str(day),{}).get(aid,{}).get('moved',0)
            if moved:active.append(day);streak=0
            else:streak+=1;longest=max(longest,streak)
        out[aid]=dict(days_with_translation=active,late_days_with_translation=sum(d>=12 for d in active),
            max_consecutive_days_without_translation=longest)
    return out

def main():
    reports=[];common=None
    for seed,name in RUNS.items():
        report=summarize(Path('integrations/lightweight/output')/(name+'.jsonl'))
        assert report['manifest']['seed']==seed
        fixed={k:v for k,v in report['manifest'].items() if k not in ('seed','objects','resources')}
        if common is None:common=fixed
        assert fixed==common,'non-layout configuration changed'
        report['continuity']=continuity(report);reports.append(report)
        print(seed,json.dumps(dict(agents=report['agents'],continuity=report['continuity'])),flush=True)
    Path('tests/fixtures/lightweight_nested_seed_comparison.json').write_text(json.dumps(dict(runs=reports,scope='World layout seeds vary; controller seed and profiles fixed; 20260930 reused'),indent=2),encoding='utf8')
if __name__=='__main__':main()
