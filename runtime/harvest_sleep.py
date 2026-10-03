"""Night checkpoint for existing harvest induction; not legacy approach Deep.

Reuse the Sleep window, then the unchanged three-formation/two-validation
harvest inspector. A night wait is a local rest receipt, not proof of safety.
"""
from copy import deepcopy

from .harvest_predictability import build_admission
from .sleep_window import SleepExperienceWindowStore
from .sleep_relation_review import prepare, inspect

RULE = 'harvest-night-consolidation-v1'
REST_US = 1_000_000


def review(agent, p, decision):
    learning, model = agent._prospective
    state = dict(learning.get('sleep', dict(rule=RULE, cycle=None, completed=[])))
    state['completed'] = list(state['completed'])
    state['cycle'] = deepcopy(state['cycle'])
    day = p['capture_us'] // 64_000_000
    previous = next(reversed(agent.observations.values())) if agent.observations else None
    prior = agent.decisions.get(previous['observation_id']) if previous else None
    result = agent.results.get('op:' + previous['observation_id']) if previous else None
    night = decision['day_cycle']['phase'] == 'night' and decision['action'][0] == 'wait'
    cycle = state['cycle']
    if cycle is not None and cycle['day'] != day:
        if cycle['status'] == 'pending':
            cycle['status'] = 'interrupted'
        state['completed'].append(cycle)
        cycle = None
    if night and cycle is None:
        # Preserve early counterexamples; never pick a successful subset.
        records = deepcopy(learning['records'][:6])
        history = dict(authority='read-only-history', records=[dict(r,
            record_id=r['operation_id'], tick=r['executed_us'],
            decision_tick=r['capture_us']) for r in records])
        window = SleepExperienceWindowStore().form_window(history, agent_id=agent.agent_id,
            sleep_cycle=f'{agent.run_id}:{agent.agent_id}:night:{day}',
            formation_tick=p['capture_us'], enabled=True)
        cycle = dict(day=day, status='pending', rest_us=0, window=window,
            records=records, source=p['observation_id'], result=None,
            relation_materials=prepare(agent, p), relation_review=None)
    if cycle is not None and cycle['status'] == 'pending':
        linked = (night and prior is not None and prior['day_cycle']['phase'] == 'night'
            and previous['capture_us'] // 64_000_000 == day
            and agent.commands[previous['observation_id']]['kind'] == 'wait'
            and result is not None and result['status'] == 'waited'
            and result['after_pose_ref'] == p['pose_ref']
            and result['after_revision'] == p['body_revision']
            and result['executed_us'] < p['capture_us'])
        cycle['rest_us'] = cycle['rest_us'] + min(250_000,
            p['capture_us'] - result['executed_us']) if linked else 0
        if cycle['rest_us'] >= REST_US:
            cycle['relation_review'] = inspect(cycle['relation_materials'])
            if model is not None:
                outcome = dict(status='MODEL_ALREADY_PRESENT')
            elif len(cycle['records']) < 5:
                outcome = dict(status='INSUFFICIENT_EVIDENCE')
            elif learning['admission'] and learning['admission']['status'] == 'REJECT':
                outcome = dict(status='PREVIOUSLY_REJECTED')
            else:
                model, outcome = build_admission(agent.run_id, agent.agent_id,
                    cycle['records'], [*agent.observations.values(), p])
                learning['admission'] = outcome
            cycle.update(status='completed', result=dict(status=outcome['status'],
                reason=outcome.get('reason'), model_ref=model.model_ref if model else None),
                completed_us=p['capture_us'])
    state['cycle'] = cycle
    learning['sleep'] = state
    agent._prospective = learning, model
    decision['sleep_learning'] = dict(rule=RULE, cycle_day=day,
        status=cycle['status'] if cycle else 'awake',
        rest_us=cycle['rest_us'] if cycle else 0,
        result=cycle['result']['status'] if cycle and cycle['result'] else None)
    decision['model_ref'] = model.model_ref if model else None
    return decision
