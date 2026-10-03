"""Successful observed landmark sequences as finite food-revisit hypotheses.

No coordinates, resource identity, or motor tape. Not canonical model adoption.
"""
from copy import deepcopy
from .landmark_day_cycle import DAY_US, clusters

RULE = 'successful-landmark-food-revisit-v1'
MAX_ANCHORS = 8
MAX_OPERATIONS = 48


def wrap(angle):
    return (angle + 180) % 360 - 180


def anchor(packet, feature):
    cue = packet.get('orientation', {})
    if cue.get('status') != 'available':
        return None
    return dict(color=feature['color'], bearing=wrap(sum(feature['azimuth']) / 2 - cue['relative_center']),
                source=packet['observation_id'], capture_us=packet['capture_us'], pose_ref=packet['pose_ref'])


def matches(packet, waypoint):
    """Merge adjacent sampled rays; ambiguity remains explicit."""
    cue = packet.get('orientation', {})
    if cue.get('status') != 'available' or packet['landmarks']['coverage'] != 'complete':
        return None
    features = [f for f in packet['landmarks']['features'] if f['color'] == waypoint['color']
                and abs(wrap(sum(f['azimuth']) / 2 - cue['relative_center'] - waypoint['bearing'])) <= 45]
    return [dict(angle=(lo + hi) / 2, near=any(f['range_band'] == 'near' and lo <= sum(f['azimuth']) / 2 <= hi for f in features))
            for lo, hi in clusters(features)]


def review(agent, packet, decision):
    d = deepcopy(decision)
    previous = next(reversed(agent.observations.values())) if agent.observations else None
    last = agent.decisions.get(previous['observation_id'], {}) if previous else {}
    old = last.get('food_revisit')
    s = deepcopy(old) if old else dict(rule=RULE, binding=[packet['run_id'], packet['agent_id']],
        memory=None, H=0, threshold=2, trail=[], trail_ids=[], trail_overflow=False, day=-1)
    if s['binding'] != [packet['run_id'], packet['agent_id']]:
        raise ValueError('food_revisit_binding')
    day = packet['capture_us'] // DAY_US
    command = agent.commands.get(previous['observation_id']) if previous else None
    result = agent.results.get(command['operation_id']) if command else None
    linked = bool(result and result['after_pose_ref'] == packet['pose_ref']
                  and result['after_revision'] == packet['body_revision'] and result['executed_us'] < packet['capture_us'])
    s.update(applied=False, reason='priority', comparison=None)

    # Only a linked actual pickup certifies success; seeing Food is insufficient.
    if linked and result.get('acquired') and previous['capture_us'] // DAY_US == s['day']:
        if s.get('attempt') and not s.get('closed'):
            s['H'] = 0
            s['comparison'] = dict(E=0, source=result['operation_id'], question='revisit_yields_food')
            s['closed'] = True
        elif s.get('origin') and s['trail'] and not s['trail_overflow']:
            s['memory'] = dict(parent='food-security', hypothesis='observed_route_may_yield_food',
                origin=s['origin'], anchors=deepcopy(s['trail']), success=result['operation_id'],
                success_observation=previous['observation_id'], day=s['day'])
            s['H'] = 0

    # A bounded failed trial changes its own residual once, not once per wait.
    def fail(reason, comparable=True):
        if not s.get('closed'):
            if comparable:
                s['H'] = min(32, s['H'] + 1)
            s['comparison'] = dict(E=1 if comparable else None, source=packet['observation_id'],
                question='revisit_yields_food', reason=reason)
        s.update(closed=True, reason=reason)

    if s['day'] != day:
        if s.get('attempt') and not s.get('closed'):
            fail('day_ended_without_acquisition', s.get('food_complete', False))
        dc = last.get('day_cycle', {})
        at_home = bool(dc.get('return_state', {}).get('outcome') == 'home_like_observed'
                       or any(r['executed_us'] // DAY_US == day - 1 for r in agent.unload_receipts.values()))
        origin = (dict(source=packet['observation_id'], kind='prior_return_confirmed') if at_home else None)
        if old is None and d['day_cycle'].get('home_memory'):
            origin = dict(source=d['day_cycle']['home_memory']['source'], kind='initial_home_observation')
        s.update(day=day, trail=[], trail_ids=[], trail_overflow=False, origin=origin,
                 attempt=False, closed=False, cursor=0, operations=0, scans=0, selected=False, food_complete=True)

    phase = d['day_cycle']['phase']
    if phase == 'return' and s.get('attempt') and not s.get('closed'):
        fail('acquisition_window_ended', s.get('food_complete', False))

    # Record chosen, actually approached, observed landmarks from this outing.
    if linked and result['status'] == 'moved' and s['origin'] and previous['capture_us'] // DAY_US == day:
        goal = last.get('landmark', {}).get('goal')
        if goal and abs(sum(goal['current_feature']['azimuth']) / 2) <= 45 and last.get('day_cycle', {}).get('phase') == 'exploration' and not last.get('food_revisit', {}).get('applied'):
            gid = goal['goal_id']
            if gid not in s['trail_ids']:
                item = anchor(previous, goal['current_feature'])
                if item:
                    if len(s['trail']) >= MAX_ANCHORS:
                        s['trail_overflow'] = True
                    else:
                        item['approach_result'] = result['operation_id']
                        s['trail'].append(item); s['trail_ids'].append(gid)

    d['food_revisit'] = s
    if phase != 'exploration':
        return d
    if not s['selected']:
        s['selected'] = True
        s['attempt'] = bool(s['memory'] and s['origin'] and s['H'] < s['threshold'])
        s['reason'] = 'revisit_selected' if s['attempt'] else 'exploration_selected'
    if s['attempt'] and not s['closed']:
        s['food_complete'] = s.get('food_complete', True) and packet['food']['coverage'] == 'complete'
    if not s['attempt'] or s['closed']:
        return d
    if not linked:
        fail('body_correspondence_unavailable', False)
        return d
    if result['status'] in ('stale', 'expired'):
        fail('body_result_unavailable', False)
        return d
    if last.get('food_revisit', {}).get('applied') and result['status'] == 'blocked':
        fail('approach_blocked')
        return d
    # Current food, work, body and return gates retain authority.
    if packet['food']['visible'] or d['action'][0] == 'pickup':
        s['reason'] = 'current_food_priority'
        return d
    if not (d['reason'].startswith(('landmark_', 'neighborhood_')) or d['reason'] in ('food_goal_rescan', 'acquisition_incomplete')):
        s['reason'] = 'existing_priority'
        return d
    if not getattr(agent,'continuous_selection',False) and s['operations'] >= MAX_OPERATIONS:
        fail('revisit_operation_budget')
        return d
    points = s['memory']['anchors']
    while s['cursor'] < len(points):
        found = matches(packet, points[s['cursor']])
        if found is None:
            fail('acquisition_or_orientation_unavailable', False)
            return d
        if len(found) > 1:
            fail('landmark_ambiguous', False)
            return d
        if not found:
            if s['scans'] >= 4:
                fail('landmark_not_reacquired')
                return d
            s['scans'] += 1
            action = ['turn', 90]
            break
        target = found[0]
        if target['near']:
            s['cursor'] += 1
            continue
        angle = target['angle']
        if abs(angle) > 7.5:
            action = ['turn', max(-45, min(45, round(angle / 5) * 5))]
        else:
            surface = packet['movement_surface']['ground']
            safe = not surface['output_limited'] and any(x['direction_deg'] == 0 and x['status'] == 'sampled'
                    and abs(x['height_delta']) <= .5 for x in surface['samples'])
            if not safe:
                fail('current_step_unavailable', False)
                return d
            action = ['move', 1]
        break
    else:
        fail('route_end_without_food', packet['food']['coverage'] == 'complete')
        return d
    s.update(applied=True, reason='observed_landmark_revisit', operations=s['operations'] + 1)
    d.update(action=action, target='', reason='food_revisit', terrain_gate='observed_landmark_revisit')
    return d
