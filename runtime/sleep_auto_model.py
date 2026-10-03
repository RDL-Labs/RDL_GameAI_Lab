"""Opt-in unvalidated local M_B: observed context/action -> execution outcome.

Automatic empirical adoption is deliberately not canonical T1 acceptance.
Execution success is not goal success; the resulting bias may be harmful.
"""
from copy import deepcopy
from .exploration_series import digest

RULE = 'sleep-unvalidated-action-model-v1'
SUCCESS = {'moved', 'turned', 'picked_up', 'waited'}
FAILURE = {'blocked', 'not_found'}


def adopt(previous, review, run, agent, capture_us):
    state = deepcopy(previous) if previous else dict(rule=RULE, binding=[run, agent], records=[], cells=[])
    if state['binding'] != [run, agent]:
        raise ValueError('sleep_model_binding')
    known = {r['record_id']: r for r in state['records']}
    for r in review['records']:
        if r['agent_id'] != agent or r['tick'] > capture_us:
            raise ValueError('sleep_model_source')
        if r['record_id'] in known:
            if known[r['record_id']] != r:
                raise ValueError('sleep_model_source_conflict')
            continue
        known[r['record_id']] = deepcopy(r)
    # Bounded research campaign store, never silently truncate sources.
    if len(known) > 192:
        raise ValueError('sleep_model_capacity')
    state['records'] = list(known.values())
    groups = {}
    for r in state['records']:
        if r['food_coverage'] != 'complete' or r['hazard_coverage'] != 'complete':
            continue
        if r['outcome'] not in SUCCESS | FAILURE:
            continue
        key = (r['food_seen'], r['hazard_seen'], r['action'], r['amount'])
        groups.setdefault(key, []).append(r)
    cells = []
    for key, records in sorted(groups.items()):
        positive = sum(r['outcome'] in SUCCESS for r in records)
        cells.append(dict(context=list(key[:2]), action=list(key[2:]),
            execution_rate=positive/len(records), support=len(records),
            positive=positive, negative=len(records)-positive,
            sources=[r['record_id'] for r in records]))
    state.update(cells=cells, model_ref=RULE+':'+digest([run, agent, cells])[:24],
        adopted_us=capture_us, authority='automatic unvalidated local M_B; not canonical T1 or causal truth')
    return state


def apply(agent, p, candidates):
    model = agent._prospective[0].get('sleep_auto_model')
    trace = dict(rule=RULE, model_ref=model['model_ref'] if model else None,
                 contributions=[], status='no_model')
    if model is None:
        return trace
    if model['binding'] != [p['run_id'], p['agent_id']]:
        raise ValueError('sleep_model_binding')
    if model['adopted_us'] >= p['capture_us']:
        raise ValueError('sleep_model_time')
    food, hazard = p.get('food', {}), p.get('hazard', {})
    if food.get('coverage') != 'complete' or hazard.get('coverage') != 'complete':
        trace['status'] = 'context_unavailable'
        return trace
    context = [bool(food.get('visible')), bool(hazard.get('features'))]
    trace['status'] = 'no_matching_cell'
    for c in candidates:
        cells = [cell for cell in model['cells'] if cell['context'] == context and cell['action'] == c['action']]
        if not cells:
            continue
        cell = cells[0]
        bias = .75*(2*cell['execution_rate']-1)
        trace['contributions'].append(dict(candidate=c['model'], before=c['score'], bias=bias,
            predicted_execution_rate=cell['execution_rate'], sources=cell['sources']))
        c['score'] += bias
    if trace['contributions']:
        trace['status'] = 'applied'
    return trace
