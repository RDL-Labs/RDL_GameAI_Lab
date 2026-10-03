"""Audit fixed territorial behavior, observation isolation, and campaign interaction."""
import json
from pathlib import Path
from collections import Counter
from math import hypot
from .audit_moving_hazard import audit,ROOT


def inspect(path):
    base,commands=audit(path);counts=Counter();transitions=[];old=None;config=None
    for line in path.open(encoding='utf8'):
        r=json.loads(line)
        if r['type']=='territory_config':config=r
        if r['type']=='territory_world':
            counts[r['mode']]+=1;counts['blocked']+=int(r['blocked'])
            b=r['position'];assert hypot(b['x']-config['home'][0],b['z']-config['home'][1])<=config['leash']+1e-8
            if old:
                dt=(r['capture_us']-old['capture_us'])/1e6
                assert hypot(b['x']-old['position']['x'],b['z']-old['position']['z'])<=config['speed']*dt+1e-8
            if old is None or (r['mode'],r['target'])!=(old['mode'],old['target']):transitions.append(r)
            old=r
        if r['type'] in ('decision','working_capture') and 'hazard' in r['packet']:
            h=r['packet']['hazard']
            assert set(h)=={'rule','source','coverage','features'}
            for f in h['features']:
                assert set(f)=={'appearance','azimuth','range_band'}
                counts['warning_observations']+=int(f['appearance']=='violet_warning')
    base.update(territory_config=config,territory_counts=dict(counts),territory_transitions=transitions)
    return base,commands


if __name__=='__main__':
    results={};baseline=None
    for mode in ('disabled','shadow','enabled'):
        r,c=inspect(ROOT/f'territory_{mode}.jsonl');results[mode]=r
        if mode=='disabled':baseline=c
        if mode=='shadow':assert c==baseline
        print(mode,r['summary']['pickups'],r['territory_counts'],r['final_modes'])
    Path('tests/fixtures/lightweight_territorial_hazard.json').write_text(json.dumps(results,indent=2),encoding='utf8')
