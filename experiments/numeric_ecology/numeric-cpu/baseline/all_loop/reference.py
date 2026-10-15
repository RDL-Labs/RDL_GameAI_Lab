"""A0 minimal policy; existing Python geometry/body/energy are the reference."""
import copy
import json
import math
import sys
import time
from pathlib import Path
from runtime.layered_body import initial, step
from runtime.energy_field import evaluate
from runtime.lw_time import SCALED
from experiments.julia_migration.python.reference import segment_hit

ANGLES = (-90, -45, 0, 45, 90)


def run(scene, trace=False):
    assert SCALED
    agents = [dict(x=p[0], z=p[1], yaw=0., inventory=0,
                   body=dict(initial(), reserve=scene['reserve'])) for p in scene['agents']]
    food = copy.deepcopy(scene['food'])
    obstacles = scene['obstacles']
    rows = []
    counts = dict(walk=0, rest=0, eat=0, pickup=0, blocked_samples=0, body_limited_samples=0)
    for tick in range(scene['ticks']):
        for index, a in enumerate(agents):
            origin = (a['x'], a['z'])
            yaw = math.radians(a['yaw']); s, c = math.sin(yaw), math.cos(yaw)
            visible = []
            for j, f in enumerate(food):
                dx, dz = f['x']-a['x'], f['z']-a['z']
                forward, right = dx*s+dz*c, dx*c-dz*s
                distance = math.hypot(forward, right)
                if f['stock'] > 0 and distance <= 12 and forward >= 0 and not any(
                        segment_hit(origin, (f['x'], f['z']), o) for o in obstacles):
                    visible.append(dict(ref=j, forward=forward, right=right, distance=distance))
            visible.sort(key=lambda v: (v['distance'], v['ref']))
            visible = visible[:5]
            target = visible[0] if visible else None
            samples = []
            for j, angle in enumerate(ANGLES):
                theta = math.radians(a['yaw']+angle)
                endpoint = (a['x']+math.sin(theta), a['z']+math.cos(theta))
                clear = not any(segment_hit(origin, endpoint, o, .2) for o in obstacles)
                goal = 1.+abs(angle)/90 if target is None else min(10., math.hypot(
                    target['forward']-math.cos(math.radians(angle)),
                    target['right']-math.sin(math.radians(angle))))
                samples.append(dict(ref=str(j), action='walk', clear=clear,
                                    resistance=scene['resistance'], goal_cost=goal))
            evaluated = evaluate(a['body'], a['inventory'], samples)
            counts['blocked_samples'] += sum(r['status']=='blocked' for r in evaluated['rows'])
            counts['body_limited_samples'] += sum(r['status']=='body_limited' for r in evaluated['rows'])
            chosen = -1
            if a['inventory'] and a['body']['reserve'] < 80:
                action = 'eat'
                a['body'], result = step(a['body'], 'eat', food_available=True, load=a['inventory'])
                a['inventory'] -= result['food_consumed']
            elif target is not None and target['distance'] <= 1.25:
                action = 'pickup'; result = dict(status='picked_up')
                food[target['ref']]['stock'] -= 1; a['inventory'] += 1
            elif evaluated['selected'] is None:
                action = 'rest'; a['body'], result = step(a['body'], 'rest', load=a['inventory'])
            else:
                action = 'walk'; chosen = int(evaluated['selected'])
                # Atomic orientation + walk is an A0 fixture operation, not LW steering.
                a['yaw'] = (a['yaw']+ANGLES[chosen]+180)%360-180
                a['body'], result = step(a['body'], 'walk', load=a['inventory'], resistance=scene['resistance'])
                theta = math.radians(a['yaw'])
                a['x'] += math.sin(theta)*result['distance']; a['z'] += math.cos(theta)*result['distance']
            counts[action] += 1
            if trace:
                rows.append(dict(tick=tick, agent=index, visible=visible, candidates=evaluated['rows'],
                                 action=action, chosen=chosen, status=result['status'],
                                 state=copy.deepcopy(a), stock=[f['stock'] for f in food]))
    assert sum(f['stock'] for f in food)+sum(a['inventory'] for a in agents)+counts['eat']==sum(f['stock'] for f in scene['food'])
    return dict(agents=agents, stock=[f['stock'] for f in food], counts=counts, trace=rows)


def generate(path):
    base = dict(ticks=600, agents=[[-2.,0.],[0.,0.],[2.,0.]], reserve=100., resistance=1.5,
                food=[dict(x=float(x),z=5.,stock=12) for x in (-2,0,2)], obstacles=[])
    scenes=[]
    for name in ('open','obstacle','enclosed','low_reserve','shared'):
        s=copy.deepcopy(base);s['name']=name
        if name=='open':s['reserve']=79.
        if name=='obstacle':s['obstacles']=[dict(x=float(x),z=2.,radius=.65) for x in (-2,0,2)]
        if name=='enclosed':s['obstacles']=[dict(x=float(x),z=0.,radius=.3) for x in (-2,0,2)]
        if name=='low_reserve':s['reserve']=.0001
        if name=='shared':s['agents']=[[-.2,0.],[0.,0.],[.2,0.]];s['food']=[dict(x=0.,z=1.,stock=2)]
        scenes.append(s)
    Path(path).write_text(json.dumps(scenes,indent=2)+'\n',encoding='utf8')


if __name__=='__main__':
    if sys.argv[1]=='generate':generate(sys.argv[2]);sys.exit()
    scenes=json.loads(Path(sys.argv[2]).read_text());mode=sys.argv[1]
    result={}
    for scene in scenes:
        if mode=='trace':result[scene['name']]=run(scene,True)
        else:
            run(scene)
            values=[]
            for _ in range(3):
                start=time.perf_counter();r=run(scene);values.append(time.perf_counter()-start)
            result[scene['name']]=dict(seconds=values,counts=r['counts'])
    Path(sys.argv[3]).write_text(json.dumps(result)+'\n',encoding='utf8')
