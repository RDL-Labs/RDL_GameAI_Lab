"""Cross-action nightly relation inspection, with no goal relevance filter.

Reported regularities are not causal constraints or adopted knowledge. Reuse
the existing Sleep window and structural comparator without fabricating an
approach Experience for the legacy approach-only Deep compiler.
"""
from itertools import combinations, islice
from copy import deepcopy
import json

from .sleep_window import SleepExperienceWindowStore
from .structural.relations import build_reported_relation
from .structural.similarity import compare_relation_profiles
from .exploration_series import digest

RULE = 'cross-action-sleep-review-v1'


def prepare(agent, p):
    selected, seen = [], set()
    # At most 64 recent observations, six distinct action/result/phase strata.
    for source in islice(reversed(agent.observations.values()), 64):
        oid = source['observation_id']
        c, r = agent.commands.get(oid), agent.results.get('op:'+oid)
        if not c or not r or source['agent_id'] != agent.agent_id:
            continue
        mode = agent.decisions[oid].get('day_cycle', {}).get('phase', 'unspecified')
        # Body mode reserves the same six slots across action/result, rather
        # than letting each phase repeat the same walk/turn/wait strata.
        key = (c['kind'], r['status']) if 'locomotor' in p else (c['kind'], r['status'], mode)
        if key in seen:
            continue
        seen.add(key)
        selected.append(dict(record_id='op:'+oid, agent_id=agent.agent_id,
            tick=r['executed_us'], decision_tick=source['capture_us'],
            source_observation_id=oid, action=c['kind'], amount=c.get('amount', 0), outcome=r['status'],
            phase=mode, target=c.get('target_ref') or None,
            food_coverage=source.get('food', {}).get('coverage'),
            food_seen=bool(source.get('food', {}).get('visible')),
            hazard_coverage=source.get('hazard', {}).get('coverage'),
            hazard_seen=bool(source.get('hazard', {}).get('features'))))
        if 'locomotor' in source:
            selected[-1]['body_observation']=deepcopy(source['locomotor'])
        if len(selected) == 6:
            break
    history = dict(authority='read-only-history', records=selected)
    window = SleepExperienceWindowStore().form_window(history, agent_id=agent.agent_id,
        sleep_cycle=f'{agent.run_id}:{agent.agent_id}:relations:{p["capture_us"]//64000000}',
        formation_tick=p['capture_us'], enabled=True)
    by_id = {r['record_id']: r for r in selected}
    return dict(rule=RULE, window=window,
        records=[by_id[i] for i in window['source_experience_ids']],
        selection=('latest per action/outcome, within last 64 observations; maximum six; body mode'
                   if 'locomotor' in p else 'latest per action/outcome/phase, within last 64 observations; maximum six'),
        authority='reported local records; not new independent Experience')


def inspect(prepared):
    profiles = []
    for r in prepared['records']:
        source = r['record_id']
        values = [('actor', 'actor', r['agent_id']), ('action', 'performed', r['action']),
                  ('outcome', 'reported_result', r['outcome'])]
        if r['target']:
            values.append(('target', 'observed_target_ref', r['target']))
        # Missing coverage remains missing, never a negative observation.
        if r['food_coverage'] == 'complete' and r['hazard_coverage'] == 'complete':
            values.append(('context', 'observed_food_and_hazard',
                           json.dumps([r['food_seen'], r['hazard_seen']])))
        relations = [build_reported_relation(source_experience_id=source,
            kind=k, subject='experience:'+source, predicate=predicate, object_value=value)
            for k, predicate, value in values]
        profiles.append(dict(profile_id=digest([RULE, source, relations]),
            source_experience_id=source, relations=relations))
    pairs = [compare_relation_profiles(a, b, purpose=RULE) for a, b in combinations(profiles, 2)]
    return dict(rule=RULE, status='compared' if pairs else 'insufficient_records',
        window=prepared['window'], records=prepared['records'], profiles=profiles,
        pair_results=pairs, candidate_admission='none',
        authority='matches/differences/missing only; no causal inference, support amplification or M_B update')
