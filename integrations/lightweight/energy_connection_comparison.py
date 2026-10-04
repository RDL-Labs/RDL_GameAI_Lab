"""Same loaded/resistive physics; energy candidate ranking off versus on."""
import gzip
import json
from pathlib import Path
from .timed_harvest import run
from .body_sleep_comparison import audit


def main():
    root=Path('tests/fixtures/energy_connection');root.mkdir(parents=True,exist_ok=True)
    out=Path('outputs/energy_connection');out.mkdir(parents=True,exist_ok=True)
    report={}
    for scene in ('natural','food_barrier'):
        for mode in ('shadow','enabled'):
            name=scene+'-'+mode;path=out/(name+'.jsonl')
            options=dict(days=3,seed=20261002,stop_after_returns=None,body_mode='enabled',body_scene=scene,
                energy_mode=mode,selection_mode='continuous',sleep_learning=True,sleep_auto_adopt=True,
                orientation_mode='enabled',return_completion_mode='enabled',skyline_subrays=True,
                hazard_mode='enabled' if scene=='natural' else 'shadow')
            if scene=='natural':options.update(hazard_scenario='territorial',warning_review_mode='enabled',
                territory_resource_layout='three_inside',dynamic_hazard=True)
            summary=run(path,**options);summary.pop('elapsed_seconds',None)
            fields=changed=0;max_load=0.
            for line in path.read_text(encoding='utf8').splitlines():
                row=json.loads(line)
                if row['type']=='decision':
                    e=(row.get('continuous_selection') or {}).get('energy_field')
                    if e:fields+=1;changed+=int(e['changed'])
                    max_load=max(max_load,row['packet']['locomotor']['energy']['load'])
            report[name]=dict(options=options,summary=summary,audit=audit(path),
                              energy_fields=fields,energy_changed=changed,max_load=max_load)
            with gzip.GzipFile(filename=str(root/(name+'.jsonl.gz')),mode='wb',mtime=0) as f:f.write(path.read_bytes())
            print(name,summary['pickups'],sum(len(r['pickups']) for r in summary['returns']),fields,changed,max_load,flush=True)
    (root/'comparison.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    return report


if __name__=='__main__':main()
