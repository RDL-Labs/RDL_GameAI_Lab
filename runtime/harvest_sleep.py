"""Night checkpoint for existing harvest induction; not legacy approach Deep.

Reuse the Sleep window, then the unchanged three-formation/two-validation
harvest inspector. A night wait is a local rest receipt, not proof of safety.
"""
from runtime.lw_time import DAY_US
from copy import deepcopy

from .harvest_predictability import build_admission
from .sleep_window import SleepExperienceWindowStore
from .sleep_relation_review import prepare, inspect

RULE = 'harvest-night-consolidation-v1'
from .lw_time import SLEEP_REST_US as REST_US


def consolidate(agent, learning, model, cycle, p, completed_us=None):
    completed_us=p["capture_us"] if completed_us is None else completed_us
    cycle['relation_review'] = inspect(cycle['relation_materials'])
    if getattr(agent, 'sleep_auto_adopt', False):
        from .sleep_auto_model import adopt
        learning['sleep_auto_model'] = adopt(learning.get('sleep_auto_model'),
            cycle['relation_review'], agent.run_id, agent.agent_id, completed_us,
            capacity=getattr(agent,'sleep_model_capacity',192))
        cycle['auto_model_ref'] = learning['sleep_auto_model']['model_ref']
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
        completed_us=completed_us)
    return model


def review(agent, p, decision):
    learning, model = agent._prospective
    state = dict(learning.get('sleep', dict(rule=RULE, cycle=None, completed=[])))
    state['completed'] = list(state['completed'])
    state['cycle'] = deepcopy(state['cycle'])
    day = p['capture_us'] // DAY_US
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
    if cycle is not None and cycle['status'] == 'pending' and not getattr(agent,'sleep_receipt_intake',False):
        linked = (night and prior is not None and prior['day_cycle']['phase'] == 'night'
            and previous['capture_us'] // DAY_US == day
            and agent.commands[previous['observation_id']]['kind'] == 'wait'
            and result is not None and result['status'] == 'waited'
            and result['after_pose_ref'] == p['pose_ref']
            and result['after_revision'] == p['body_revision']
            and result['executed_us'] < p['capture_us'])
        credit = (agent.sleep_rest_credit(previous, result, p)
                  if linked and hasattr(agent, 'sleep_rest_credit') else
                  min(250_000, p['capture_us'] - result['executed_us']) if linked else 0)
        cycle['rest_us'] = cycle['rest_us'] + credit if linked else 0
        if cycle['rest_us'] >= REST_US:
            model = consolidate(agent, learning, model, cycle, p)
    state['cycle'] = cycle
    learning['sleep'] = state
    agent._prospective = learning, model
    decision['sleep_learning'] = dict(rule=RULE, cycle_day=day,
        status=cycle['status'] if cycle else 'awake',
        rest_us=cycle['rest_us'] if cycle else 0,
        result=cycle['result']['status'] if cycle and cycle['result'] else None)
    decision['model_ref'] = model.model_ref if model else None
    return decision


def accept_rest_result(agent, packet, command, result):
    """Consume an already accepted body result once, before day/run closure."""
    if not getattr(agent, 'sleep_receipt_intake', False):return False
    if agent.results.get(command['operation_id']) != result:
        raise ValueError('sleep_result_not_accepted')
    current=agent.learning.get('sleep')
    if not current or not current['cycle'] or current['cycle']['status']!='pending':return False
    state=deepcopy(current)
    cycle=state['cycle'];op=command['operation_id']
    if result['executed_us']<=cycle.get('last_rest_executed_us',-1):return False
    prior=agent.decisions[packet['observation_id']]
    if cycle['day']!=packet['capture_us']//DAY_US or prior['day_cycle']['phase']!='night':return False
    valid=(command['kind']=='wait' and result['status']=='waited' and
        result['after_pose_ref']==packet['pose_ref'] and result['after_revision']==packet['body_revision'] and
        packet['capture_us'] < result['executed_us'] <= (cycle['day']+1)*DAY_US)
    cycle['last_rest_operation']=op
    cycle['last_rest_executed_us']=result['executed_us']
    cycle['rest_us']=cycle['rest_us']+agent.sleep_rest_credit(packet,result,packet) if valid else 0
    learning=deepcopy(agent.learning);model=agent.model
    if cycle['rest_us']>=REST_US:
        # Consolidation uses original accepted observation as evidence; only the
        # formation time comes from the accepted completion receipt.
        model=consolidate(agent,learning,model,cycle,packet,completed_us=result['executed_us'])
    learning['sleep']=state
    agent.learning=learning;agent.model=model
    return True
