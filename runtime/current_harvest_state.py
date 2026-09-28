"""Current finite food availability, independent of historical harvest success."""
from copy import deepcopy


def assess(packet, appearance, records):
    # This predicate uses the Food acquisition's coverage, not unrelated visual
    # channels. A far visible item is not a currently reachable pickup.
    complete = packet['food']['coverage'] == 'complete'
    visible = [x for x in packet['food']['visible'] if x['appearance'] == appearance]
    reachable = [x for x in visible if x['distance'] <= 1.25]
    status = ('unknown' if not complete else 'reachable_observed' if reachable
              else 'visible_out_of_reach' if visible else 'none_observed')
    successes = [r for r in records if r['acquired']]
    return dict(schema='l15a-current-harvest-state-v1',
        source={k:deepcopy(packet[k]) for k in ('run_id','agent_id','observation_id','capture_us','pose_ref')},
        scope='current Food acquisition only; no persistent place identity',
        appearance=appearance, coverage=packet['food']['coverage'],status=status,
        visible_refs=[x['ref'] for x in visible],reachable_refs=[x['ref'] for x in reachable],
        historical_success=dict(count=len(successes),
            last_operation=successes[-1]['operation_id'] if successes else None,
            authority='episodic acquisition evidence; not a new adopted relation'),
        absence_authority='current observation only; not permanent depletion or regrowth prediction')
