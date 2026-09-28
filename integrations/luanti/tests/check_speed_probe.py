"""Separate replay validity, transport health, and behavioral equivalence."""
from collections import Counter
from .run_speed_probe import signature


def summarize(report):
    baseline = next((signature(r['data']) for r in report['runs']
                     if r['speed'] == 1 and r['accepted']), None)
    rows = []
    for run in report['runs']:
        data = run.get('data')
        row = dict(speed=run['speed'], replay_pass=run['accepted'])
        if data is None:
            row.update(transport_healthy=False, error=run.get('error'))
            rows.append(row)
            continue
        current = signature(data)
        statuses = Counter(item[3] for items in current.values() for item in items)
        complete = all(len(items) == report['periods'] * 64 for items in current.values()) and len(current) == 3
        bad = {str(k): v for k, v in statuses.items() if k not in ('turned', 'moved', 'waited', 'blocked', 'picked_up', 'not_found')}
        timing = data['world']['timing']
        row.update(transport_healthy=run['accepted'] and complete and not bad,
                   complete=complete, invalid_results=bad,
                   same_commands_and_results=baseline == current if baseline else None,
                   differences={aid: sum(a != b for a, b in zip(items, baseline[aid]))
                                + abs(len(items) - len(baseline[aid]))
                                for aid, items in current.items()} if baseline else None,
                   world_failure=data['world'].get('failure'), timing=timing,
                   achieved_speed=data['world']['finished_us'] / timing['wall_elapsed_us'],
                   max_pending={aid: a['max_pending'] for aid, a in data['world']['agents'].items()})
        rows.append(row)
    return rows
