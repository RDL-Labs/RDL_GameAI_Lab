"""Observer-only replay audit: discovery, subsequent harvest and unload cycles."""
import hashlib
import json
from collections import Counter
from math import hypot
from pathlib import Path

ROOT = Path('integrations/lightweight/output')


def audit(path):
    agents = {}; digest = hashlib.sha256(); seen = set()
    def cycle(start):
        return dict(start_us=start, first_pickup_us=None, sites=[], pickup_ids=[], movement=0,
                    movement_before_pickup=0, turns=0, reasons=Counter(), route_segments=[],
                    phase=None, previous_owner=None, owner_switches=0)
    for line in path.open('rb'):
        digest.update(line); r = json.loads(line)
        if r['type'] == 'manifest':
            manifest = r
            agents = {a:dict(current=cycle(0), cycles=[], discovered=[], daily={}) for a in r['agents']}
        if r['type'] == 'summary': summary = r
        if r['type'] in ('decision', 'completed'):
            p = r['packet']; a = agents[p['agent_id']]; c = a['current']
            day = str(p['capture_us']//64000000+1)
            daily = a['daily'].setdefault(day, dict(movement=0, sites=[], first_pickup_us=None))
            if r['type'] == 'decision':
                f = r.get('relation_field') or {}; phase = r['activity_phase']
                owner = f.get('owner') if f.get('applied') else None
                c['reasons'][f.get('reason', 'legacy')] += 1
                if owner and owner != c['previous_owner']:
                    if c['previous_owner'] and c['phase'] == phase: c['owner_switches'] += 1
                    node = r['directional_routes']['routes'][owner]
                    c['route_segments'].append(dict(at_us=p['capture_us'], phase=phase, route=owner,
                        colors=[x['color'] for x in node['points']], support=node['support'], H=node['H']))
                c['previous_owner'] = owner; c['phase'] = phase
            else:
                result = r['result']; op = result['operation_id']
                assert op not in seen; seen.add(op)
                c['movement'] += result['forward']; daily['movement'] += result['forward']
                c['turns'] += int(result['status'] == 'turned')
                if c['first_pickup_us'] is None: c['movement_before_pickup'] += result['forward']
                if result['acquired']:
                    body = r['body']
                    sites = [i for i, x in enumerate(manifest['resources']) if hypot(x['x']-body['x'], x['z']-body['z']) <= 1.25+1e-9]
                    assert len(sites) == 1, 'Ambiguous observer-side site attribution'
                    site = sites[0]; c['pickup_ids'].append(op)
                    if site not in c['sites']: c['sites'].append(site)
                    if site not in daily['sites']: daily['sites'].append(site)
                    if site not in a['discovered']: a['discovered'].append(site)
                    if c['first_pickup_us'] is None: c['first_pickup_us'] = result['executed_us']
                    if daily['first_pickup_us'] is None: daily['first_pickup_us'] = result['executed_us']
        elif r['type'] == 'unload_receipt':
            a = agents[r['agent_id']]; c = a['current']; receipt = r['receipt']
            assert set(c['pickup_ids']) == set(receipt['pickups']) and c['pickup_ids']
            c['end_us'] = receipt['executed_us']; c['completed'] = True
            c['seconds_to_pickup'] = (c['first_pickup_us']-c['start_us'])/1e6
            c['seconds_to_delivery'] = (c['end_us']-c['start_us'])/1e6
            a['cycles'].append(c); a['current'] = cycle(c['end_us'])
    assert summary['ended_us'] == 1920000000
    for aid, a in agents.items():
        cycles = a['cycles']; known = set(); repeats = []; same_previous = 0
        for i,c in enumerate(cycles):
            c['all_sites_previously_harvested'] = bool(c['sites']) and set(c['sites']) <= known
            if i:
                repeats.append(c)
                same_previous += int(c['sites'] == cycles[i-1]['sites'])
            known.update(c['sites'])
        first_day = next((int(d) for d,x in a['daily'].items() if x['sites']), None)
        after = [x for d,x in a['daily'].items() if first_day is not None and int(d)>first_day]
        a['metrics'] = dict(first_harvest_day=first_day, distinct_sites=len(known), completed_cycles=len(cycles),
            post_first_delivery_cycles=len(repeats), same_sites_as_previous_cycle=same_previous,
            known_site_cycles=sum(c['all_sites_previously_harvested'] for c in repeats),
            post_discovery_days=len(after), post_discovery_harvest_days=sum(bool(x['sites']) for x in after),
            post_discovery_moving_without_harvest_days=sum(x['movement']>0 and not x['sites'] for x in after),
            reacquisition_seconds=[c['seconds_to_pickup'] for c in repeats],
            reacquisition_movement=[c['movement_before_pickup'] for c in repeats])
        a['current'].update(end_us=summary['ended_us'], completed=False)
    assert sum(len(c['pickup_ids']) for a in agents.values() for c in a['cycles']+[a['current']]) == summary['pickups']
    return dict(source=str(path), sha256=digest.hexdigest(), agents=agents,
        scope='Observer-only; cycles start at prior confirmed unload, including night and return delays. Final interval is censored. Site identity is not supplied to agents.')


if __name__ == '__main__':
    reports = {name:audit(ROOT/file) for name,file in [('legacy','directional_enabled_30d.jsonl'),('relation','relation_field_30d.jsonl')]}
    expected = json.loads(Path('tests/fixtures/lightweight_relation_field_30d.json').read_text())
    assert reports['relation']['sha256'] == expected['sha256']
    assert reports['legacy']['sha256'] == expected['baseline_sha256']
    Path('tests/fixtures/lightweight_route_stability.json').write_text(json.dumps(reports,indent=2),encoding='utf8')
    for mode,r in reports.items():
        for aid,a in r['agents'].items(): print(mode,aid,json.dumps(a['metrics']),flush=True)
