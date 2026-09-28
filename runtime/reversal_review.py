"""One stationary, next-observation review; no new route or learned authority."""
from copy import deepcopy


def review(agent, p, d):
    previous = next(reversed(agent.decisions.values())) if agent.decisions else None
    old = previous.get('reversal_review') if previous and previous['period'] == d['period'] else None
    state = deepcopy(old['state']) if old else dict(used=False, pending=None)
    meta = dict(mode=agent.reversal_review_mode, state=state, status='inactive',
                source=None, candidate_action=list(d['action']), candidate_reason=d['reason'])
    d['reversal_review'] = meta
    if agent.reversal_review_mode != 'enabled':
        return d
    pending = state['pending']
    if pending:
        state['pending'] = None
        meta['source'] = pending['source']
        result = agent.results.get('op:' + pending['source'])
        same_body = (result is not None and result['status'] == 'waited'
                     and result['after_pose_ref'] == p['pose_ref'] == pending['pose_ref']
                     and result['after_revision'] == p['body_revision'] == pending['body_revision']
                     and result['executed_us'] < p['capture_us'])
        fresh = (p['sample_seq'] == pending['sample_seq'] + 1
                 and pending['capture_us'] < p['capture_us'] <= pending['capture_us'] + 500000)
        if same_body and fresh and 'steering' in d:
            # Waiting is not a successful translation and must not erase turn count.
            d['steering']['turns_without_move'] = pending['turns_without_move']
        target = pending['approach']['ref']
        same_target = d['approach'] is not None and d['approach']['ref'] == target
        terrain = d['movement_terrain']
        complete = terrain is not None and terrain['status'] == 'complete'
        reverse = d['action'][0] == 'turn' and d['action'][1] * pending['turn_amount'] < 0
        if not same_body or not fresh:
            status = 'correspondence_unavailable'
        elif not same_target:
            status = 'target_or_priority_changed'
        elif d['action'][0] == 'pickup':
            meta['status'] = 'pickup_priority'
            return d
        elif not complete:
            status = 'acquisition_unresolved'
        elif reverse:
            status = 'same_reversal_deferred'
        elif d['action'][0] not in ('move', 'turn'):
            status = 'selection_unresolved'
        else:
            meta['status'] = 'released_to_existing_control'
            return d
        meta['status'] = status
        if target not in d['blocked_targets']:
            d['blocked_targets'].append(target)
        if same_target:
            d['approach'] = None
            d.update(action=['wait', 0], target='', reason='reversal_review_deferred')
        return d
    approach = d['steering'].get('stopped_approach')
    if (not state['used'] and approach is not None
            and d['reason'] == 'observed_material_terrain_reversal_stopped'):
        command = agent.commands[next(reversed(agent.observations))]
        state['used'] = True
        state['pending'] = dict(source=p['observation_id'], capture_us=p['capture_us'],
                                sample_seq=p['sample_seq'], pose_ref=p['pose_ref'],
                                body_revision=p['body_revision'], approach=deepcopy(approach),
                                turns_without_move=d['steering']['turns_without_move'],
                                turn_amount=command['amount'])
        d['blocked_targets'].remove(approach['ref'])
        d['steering']['stopped_targets'] = []
        d['approach'] = deepcopy(approach)
        d.update(action=['wait', 0], target='', reason='reversal_review_wait')
        meta.update(status='awaiting_next_observation', source=p['observation_id'])
    return d
