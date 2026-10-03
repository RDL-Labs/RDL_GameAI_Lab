"""Read-only day-to-day appraisal from agent observations and receipts.

Never reads experimenter body positions, resource stocks or hazard truth.
No retrospective attribution of a day's result to every used model.
"""
import json
from math import sqrt

DAY_US = 64_000_000


def analyze(path, days):
    agents = {}
    seen_results, seen_unloads = set(), set()
    def entry(aid, day):
        if not 0 <= day < days:
            raise ValueError('daily_review_time')
        if aid not in agents:
            agents[aid] = [dict(day=i+1, pickups=0, unloaded=0, movement=0.,
                rotation=0., waits=0, blocked=0, safety_observations=0,
                home_like_observed=False, model_refs=[], direct_selection_changes=0,
                observations=0,result_sources=[], unload_sources=[]) for i in range(days)]
        return agents[aid][day]
    with path.open(encoding='utf8') as stream:
        for line in stream:
            x = json.loads(line)
            if x['type'] == 'completed':
                r = x['result'];aid=x['packet']['agent_id'];key=(aid,r['operation_id'])
                if key in seen_results:
                    continue
                seen_results.add(key);d=entry(aid,r['executed_us']//DAY_US)
                d['result_sources'].append(r['operation_id'])
                d['pickups'] += int(r['acquired'])
                d['movement'] += sqrt(r['forward']**2+r['right']**2+r['up']**2)
                d['rotation'] += abs(r['yaw'])
                d['waits'] += int(r['status']=='waited')
                d['blocked'] += int(r['status']=='blocked')
            elif x['type'] == 'unload_receipt':
                r=x['receipt'];key=(x['agent_id'],r['operation_id'])
                if key in seen_unloads:
                    continue
                seen_unloads.add(key);d=entry(x['agent_id'],r['executed_us']//DAY_US)
                d['unloaded'] += len(r['pickups']);d['unload_sources'].append(r['operation_id'])
            elif x['type'] == 'decision':
                p=x['packet'];d=entry(p['agent_id'],p['capture_us']//DAY_US)
                d['observations']+=1
                d['safety_observations'] += int(x['activity_phase']=='safety')
                d['home_like_observed'] |= x['return_state'].get('outcome')=='home_like_observed'
                model=(x.get('continuous_selection') or {}).get('sleep_model',{})
                d['direct_selection_changes'] += int(model.get('changed',False))
                for ref in (x.get('model_ref'),model.get('model_ref')):
                    if ref and ref not in d['model_refs']:d['model_refs'].append(ref)
    for rows in agents.values():
        previous=None
        for d in rows:
            d['coverage']='records_available' if d['observations'] or d['result_sources'] or d['unload_sources'] else 'no_records'
            d['body_load_proxy']=d['movement']+d['rotation']/360
            d['return_evidence']='delivered' if d['unloaded'] else 'home_like' if d['home_like_observed'] else 'unconfirmed'
            comparable=previous is not None and previous['coverage']!='no_records' and d['coverage']!='no_records'
            d['delta_from_previous']=None if not comparable else {
                k:d[k]-previous[k] for k in ('pickups','unloaded','body_load_proxy','blocked','safety_observations')}
            d['comparison']='first_day' if previous is None else 'componentwise_only' if comparable else 'insufficient_records'
            previous=d
    return dict(rule='daily-agent-receipt-review-v1',days=days,agents=agents,
        authority='read-only appraisal; no H update or causal credit assignment',
        note='load is executed movement/rotation, not physiological fatigue; unconfirmed return is not proven absence')
