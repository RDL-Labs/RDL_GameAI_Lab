"""Matched stochastic selection with/without refusal weight in continuous life."""
from collections import Counter
import gzip
import json
from pathlib import Path
from .timed_harvest import run
from .social_life_comparison import OPTIONS,audit


def main():
    root=Path('tests/fixtures/refusal_life');root.mkdir(parents=True,exist_ok=True)
    outputs=Path('outputs/refusal_life');outputs.mkdir(parents=True,exist_ok=True);report={}
    for seed in (20261004,20261005,20261006):
        for mode in ('shadow','enabled'):
            name=f'{seed}-{mode}';path=outputs/(name+'.jsonl')
            options=dict(OPTIONS,body_scene='social_camp',social_pressure=True,seed=seed,refusal_field_mode=mode)
            summary=run(path,**options);checked=audit(path)
            assert checked['conserved'] and not checked['body_overlap']
            choices=[]
            for line in path.read_text(encoding='utf8').splitlines():
                row=json.loads(line)
                if row['type']=='decision' and row.get('refusal_choice'):
                    trace=row['refusal_choice']
                    choices.append(dict(agent=row['packet']['agent_id'],observation=row['packet']['observation_id'],
                                        time=row['packet']['capture_us'],trace=trace,actual_action=row['command']['kind']))
            report[name]=dict(options=options,audit=checked,choices=choices,
                summary={k:summary[k] for k in ('pickups','social_stock','social_consumed','physical_inventory')})
            with gzip.GzipFile(filename=str(root/(name+'.jsonl.gz')),mode='wb',mtime=0) as f:f.write(path.read_bytes())
            print(name,checked['actions'],Counter(c['trace']['question'] for c in choices if c['trace']['weight']>0),flush=True)
    (root/'comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report


if __name__=='__main__':main()
