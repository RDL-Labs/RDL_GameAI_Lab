"""Read-only audit of native saved campaigns; never supplies agent input."""
import argparse
import hashlib
import json
import math
from pathlib import Path


def require(value, name):
    if not value:
        raise ValueError(name)


def audit_result(r, spec):
    days = spec['config']['days']
    day_us = spec['clock']['day_us']
    require(r['ended_us'] == days * day_us, 'duration')
    require(len(r['daily']) == days, 'daily_count')
    require(len(r['day_starts']) == days, 'start_count')
    scene = spec['scene']
    history = scene.get('world_history')
    ground = sum(history['stock']) if history else sum(x['stock'] for x in scene['food'])
    shared = history.get('shared_stock', 0) if history else scene.get('initial_shared_stock', 0)
    require(r['initial_food'] == ground + shared + sum(scene['initial_inventory']) +
            sum(scene.get('initial_personal_stock', [])), 'initial_food')
    actors = set(r['final_agents'])
    require(actors == set(r['counts']), 'actors')
    for i, d in enumerate(r['daily'], 1):
        require(set(d['physical']) == actors, 'daily_actors')
        quantities = [d['ground'], d.get('shared_stock', 0), d['consumed'], d['replenished_food']]
        quantities += [v for a in d['physical'].values() for v in (a['inventory'], a['personal_stock'])]
        require(all(type(v) is int and v >= 0 for v in quantities), 'nonnegative_food')
        held = sum(a['inventory'] + a['personal_stock'] for a in d['physical'].values())
        require(r['initial_food'] + d['replenished_food'] ==
                d['ground'] + d.get('shared_stock', 0) + d['consumed'] + held, 'daily_food')
        for a in actors:
            require(sum(d['counts'][a].values()) == i * day_us // 1_000_000, 'daily_operations')
    held = sum(a['inventory'] + a['personal_stock'] for a in r['final_agents'].values())
    require(r['initial_food'] + r['replenished_food'] ==
            r['ground'] + r.get('shared_stock', 0) + r['consumed'] + held, 'final_food')
    for a, state in r['final_agents'].items():
        for key in ('position', 'body', 'inventory', 'personal_stock'):
            require(state[key] == r['daily'][-1]['physical'][a][key], 'terminal_' + key)
        require(all(math.isfinite(state['body'][k]) for k in ('burst', 'strain', 'reserve', 'damage')), 'finite_body')
        purpose = state['return_purpose']
        require(purpose['completed'] <= purpose['entries'], 'purpose_completion')
    return {
        'days': days, 'actors': sorted(actors),
        'operations': sum(sum(x.values()) for x in r['counts'].values()),
        'food': {'initial': r['initial_food'], 'added': r['replenished_food'],
                 'ground': r['ground'], 'shared': r.get('shared_stock', 0),
                 'held': held, 'consumed': r['consumed']},
        'sleep_models': {a: {'records': len(s['records']), 'applications': s['applications'],
             'selection_changes': s['selection_changes'],
             'woken': s.get('maintenance', {}).get('woken', 0),
             'dormant': sum(u['dormant'] for u in s.get('maintenance', {}).get('usage', {}).values())}
             for a, s in (r.get('sleep_action_models') or {}).items()},
        'bundles': {a: {k: len(s[k]) if k in ('active', 'dormant') else s[k]
                       for k in ('active', 'dormant', 'woken', 'changes')}
                    for a, s in (r.get('experience_bundles') or {}).items()},
    }


def audit_directory(root):
    root = Path(root)
    first = root / 'first'
    spec = json.loads((first / 'spec.json').read_text())
    manifest = json.loads((first / 'manifest.json').read_text())
    require(hashlib.sha256((first / 'spec.json').read_bytes()).hexdigest() ==
            manifest['spec_sha256'], 'spec_hash')
    require((first / 'result.json').read_bytes() ==
            (root / 'replay' / 'result.json').read_bytes(), 'replay')
    result = audit_result(json.loads((first / 'result.json').read_text()), spec)
    result['measurement'] = json.loads((first / 'summary.json').read_text())['measurement']
    result['config'] = spec['config']
    result['frozen_replay'] = True
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('directory')
    args = parser.parse_args()
    print(json.dumps(audit_directory(args.directory), indent=2))
