"""Finite visible-food/body experiment. No change to exploration's sensors/policy."""
from copy import deepcopy
import json
from math import hypot, sqrt
from pathlib import Path

from runtime.layered_body import capabilities
from .body_fixture import BodyWorld
from .world import segment_hit


def sight_blocked(start, end, obstacle):
    """Eye at 1m, food at .2m; intersect sight segment with vertical cylinder."""
    dx, dz = end[0]-start[0], end[1]-start[1]
    length2 = dx*dx+dz*dz
    if not length2:
        return False
    ox, oz = start[0]-obstacle['x'], start[1]-obstacle['z']
    b = 2*(ox*dx+oz*dz)
    c = ox*ox+oz*oz-obstacle['radius']**2
    disc = b*b-4*length2*c
    if disc < 0:
        return False
    lo = max(0., (-b-sqrt(disc))/(2*length2))
    hi = min(1., (-b+sqrt(disc))/(2*length2))
    return lo <= hi and obstacle['height'] >= 1.-.8*hi


class FoodBarrierWorld(BodyWorld):
    """One target, forward-only experiment; pickup has its own atomic receipt."""
    def __init__(self, height=.4, burst=10., reserve=100.):
        super().__init__()
        self.world.agents['npc_a'].update(x=0., z=0., yaw=0.)
        self.world.objects = [dict(x=0., z=.5, radius=.1, height=height, solid=True)]
        self.world.resources = [dict(x=0., z=1.8, stock=1)]
        self.states['npc_a'].update(burst=burst, reserve=reserve)

    def observe(self):
        a = self.world.agents['npc_a']; food = self.world.resources[0]
        start = (a['x'], a['z']); end = (food['x'], food['z'])
        seen = food['stock'] > 0 and not any(sight_blocked(start, end, o) for o in self.world.objects)
        # Explicit fixture sensor: relative range + coarse height, no target coordinates.
        barriers = [o for o in self.world.objects if segment_hit(start, end, o)]
        return dict(capture_us=self.clock['npc_a'], food_visible=seen,
                    food_distance=hypot(end[0]-start[0], end[1]-start[1]) if seen else None,
                    barrier_height_upper=max((round(o['height']+.049999, 1) for o in barriers), default=0.),
                    body=capabilities(self.states['npc_a']))

    def pickup(self, operation_id):
        with self.lock:
            key = ('npc_a', operation_id)
            request = ('pickup',)
            if key in self.receipts:
                old, receipt = self.receipts[key]
                if old != request:
                    raise ValueError('body_operation_conflict')
                return deepcopy(receipt)
            a = self.world.agents['npc_a']; food = self.world.resources[0]
            obs = self.observe()
            clear = not any(o['solid'] and segment_hit((a['x'], a['z']), (food['x'], food['z']), o)
                            for o in self.world.objects)
            success = obs['food_visible'] and obs['food_distance'] <= 1.25 and clear
            if success:
                food['stock'] -= 1; a['inventory'] += 1; a['revision'] += 1
            start = self.clock['npc_a']; self.clock['npc_a'] += 1_000_000
            receipt = dict(operation_id=operation_id, start_us=start, end_us=self.clock['npc_a'],
                           result=dict(action='pickup', status='picked_up' if success else 'inaccessible'))
            self.receipts[key] = (request, deepcopy(receipt))
            return receipt


def choose(obs, blocked):
    """Fixed initial ability, NOT a learned climbing policy. No World truth inputs."""
    if not obs['food_visible']:
        return 'defer'
    if obs['food_distance'] <= 1.25 and not obs['barrier_height_upper']:
        return 'pickup'
    if not obs['body']['can_walk']:
        return 'rest'
    if not blocked:
        return 'walk'
    if obs['barrier_height_upper'] > obs['body']['climb_height']:
        return 'defer'
    return 'climb' if obs['body']['can_climb'] else 'rest'


def run_case(**settings):
    w = FoodBarrierWorld(**settings); records = []; blocked = False
    outcome = 'time_limit'
    for i in range(8):
        obs = w.observe(); action = choose(obs, blocked)
        if action == 'defer':
            records.append(dict(observation=obs, action=action)); outcome='deferred'; break
        op = 'food-barrier:'+str(i)
        receipt = w.pickup(op) if action == 'pickup' else w.execute('npc_a', op, action, w.clock['npc_a'])
        records.append(dict(observation=obs, action=action, receipt=receipt))
        if receipt['result']['status'] == 'picked_up':
            outcome='harvested'; break
        if action in ('walk', 'climb'):
            blocked = receipt['result']['status'] == 'blocked'
    return dict(settings=settings, outcome=outcome, records=records,
                world_audit=dict(stock=w.world.resources[0]['stock'], inventory=w.world.agents['npc_a']['inventory']))


def experiment():
    return dict(rule='visible-food-obstacle-v1', cases={
        'low_ready':run_case(), 'low_recover':run_case(burst=0.),
        'visible_too_high':run_case(height=.7), 'occluded':run_case(height=2.),
        'no_reserve':run_case(burst=0., reserve=0.)})


if __name__ == '__main__':
    report = experiment()
    Path('tests/fixtures/visible_food_obstacle.json').write_text(json.dumps(report, indent=2)+'\n', encoding='utf8')
    print({k:(v['outcome'], [r['action'] for r in v['records']]) for k,v in report['cases'].items()})
