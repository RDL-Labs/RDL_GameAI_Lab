from copy import deepcopy
from math import sin,cos,radians,hypot
from runtime.layered_body import step
from runtime.energy_field import evaluate
from runtime import aid_method_pressure as aid,social_sleep as social
from integrations.lightweight.minimal_communication import CommunicationWorld,respond
from experiments.julia_migration.python.reference import segment_hit
from experiments.julia_migration.social_loop.reference import IDS,sleeper,receipt,DAY_US
from experiments.julia_migration.all_loop.reference import ANGLES


def make_world(spec):
    w=CommunicationWorld(capacity=4096);w.contact_distance=1.25
    w.objects=deepcopy(spec['obstacles']);w.resources=deepcopy(spec['food'])
    for i,a in enumerate(IDS):
        w.agents[a].update(x=spec['positions'][i][0],z=spec['positions'][i][1],yaw=0.,inventory=0 if i==0 else 12)
        w.bodies[a]['reserve']=50. if i==0 else 100.
    w.hearing['npc_b']=spec['hearing']
    return w


def movement_observation(w,actor):
    a=w.agents[actor];origin=(a['x'],a['z']);s,c=sin(radians(a['yaw'])),cos(radians(a['yaw']))
    visible=[]
    for j,f in enumerate(w.resources):
        dx,dz=f['x']-a['x'],f['z']-a['z'];forward,right=dx*s+dz*c,dx*c-dz*s
        distance=hypot(forward,right)
        if f['stock']>0 and distance<=12 and forward>=0 and not any(segment_hit(origin,(f['x'],f['z']),o) for o in w.objects):
            visible.append(dict(ref=j,forward=forward,right=right,distance=distance))
    visible.sort(key=lambda v:(v['distance'],v['ref']));visible=visible[:5]
    target=visible[0] if visible else None;samples=[]
    for j,angle in enumerate(ANGLES):
        theta=radians(a['yaw']+angle);end=(a['x']+sin(theta),a['z']+cos(theta))
        clear=not any(segment_hit(origin,end,o,.2) for o in w.objects)
        cost=1.+abs(angle)/90 if target is None else min(10.,hypot(target['forward']-cos(radians(angle)),target['right']-sin(radians(angle))))
        samples.append(dict(ref=str(j),action='walk',clear=clear,resistance=1.5,goal_cost=cost))
    return dict(visible=visible,energy=evaluate(w.bodies[actor],a['inventory'],samples))


def scenario(spec):
    w=make_world(spec);states={a:dict(records={},pending=None,model={},cycles=[]) for a in IDS}
    pressures={a:aid.update(None,{},a,threshold=3) for a in IDS};results={a:{} for a in IDS}
    answered={a:set() for a in IDS};rows=[];nights=[];effects={};request_counts={a:0 for a in IDS}
    def integrate(actor,now,obs):
        p=dict(agent_id=actor,capture_us=now,observation_id=f'ob:{now}:{actor}',social=obs)
        states[actor]=social.ingest(states[actor],p,results[actor])
        pressures[actor]=aid.update(pressures[actor],states[actor]['records'],actor,threshold=3)
    def execute(actor,op,plan,move):
        if op in effects:
            old,r=effects[op]
            if old!=plan:raise ValueError('a2_operation_conflict')
            return deepcopy(r)
        action=plan['action'];a=w.agents[actor]
        if action in ('request','give','refuse','warn','withdraw','eat','wait'):
            r=w.communicate(actor,op,action,plan.get('target'),plan.get('reply_to'))
        elif action=='pickup':
            f=w.resources[plan['food_ref']]
            legal=f['stock']>0 and hypot(f['x']-a['x'],f['z']-a['z'])<=1.25 and not any(segment_hit((a['x'],a['z']),(f['x'],f['z']),o) for o in w.objects)
            if legal:f['stock']-=1;a['inventory']+=1
            r=dict(status='picked_up' if legal else 'not_found')
        elif action=='walk':
            a['yaw']=(a['yaw']+ANGLES[plan['direction']]+180)%360-180
            dx,dz=sin(radians(a['yaw'])),cos(radians(a['yaw']))
            end=(a['x']+dx*.5*(1-w.bodies[actor]['damage']),a['z']+dz*.5*(1-w.bodies[actor]['damage']))
            clear=not any(segment_hit((a['x'],a['z']),end,o,.2) for o in w.objects)
            w.bodies[actor],result=step(w.bodies[actor],'walk',load=a['inventory'],resistance=1.5,unobstructed=clear)
            a['x']+=dx*result['distance'];a['z']+=dz*result['distance']
            r=dict(status=result['status'],distance=result['distance'])
        else:
            w.bodies[actor],r=step(w.bodies[actor],'rest',load=a['inventory'])
            r=dict(status=r['status'])
        effects[op]=(deepcopy(plan),deepcopy(r));return r
    for day in range(3):
        w.bodies['npc_a']['reserve']=max(0.,w.bodies['npc_a']['reserve']-20)
        for tick in range(spec['ticks']):
            now=day*DAY_US+tick*1_000_000;w.seconds=now/1e6
            observations={a:w.observe_communication(a) for a in IDS}
            moves={a:movement_observation(w,a) for a in IDS};plans={};selections={}
            for actor in IDS:
                obs=observations[actor];integrate(actor,now,obs);s=states[actor]
                message=next((m for m in reversed(obs['messages']) if m['id'] not in answered[actor] and m['kind'] in ('request','warn','reach')),None)
                plan=None
                if message:
                    plan=respond(dict(obs,messages=[message]),share=actor!='npc_b');answered[actor].add(message['id'])
                elif obs['inventory'] and obs['body']['reserve']<80:plan=dict(action='eat')
                elif s['pending']:plan=dict(action='rest')
                elif obs['body']['reserve']<80:
                    targets=[o['ref'] for o in obs['others'] if o['holding_food']]
                    target,selections[actor]=aid.select(targets,s['model'],pressures[actor])
                    if target is not None:
                        plan=dict(action='request',target=target);op=f'op:{now}:{actor}'
                        s['pending']=dict(message_id=actor+':'+op,target=target,deadline=now+5_000_000,
                            request_observation_id=f'ob:{now}:{actor}',operation_id=op)
                        request_counts[actor]+=1
                if plan is None:
                    visible=moves[actor]['visible'];chosen=moves[actor]['energy']['selected']
                    if visible and visible[0]['distance']<=1.25:plan=dict(action='pickup',food_ref=visible[0]['ref'])
                    elif obs['inventory'] or chosen is None:plan=dict(action='rest')
                    else:plan=dict(action='walk',direction=int(chosen))
                plans[actor]=plan
            w.seconds=(now+1_000_000)/1e6
            for actor in IDS:
                op=f'op:{now}:{actor}';r=execute(actor,op,plans[actor],moves[actor])
                saved=(deepcopy(w.agents),deepcopy(w.bodies),deepcopy(w.resources),w.consumed)
                assert execute(actor,op,plans[actor],moves[actor])==r
                assert saved==(w.agents,w.bodies,w.resources,w.consumed)
                results[actor][op]=r
                rows.append(dict(day=day,tick=tick,actor=actor,observation=observations[actor],movement=moves[actor],
                    plan=plans[actor],selection=selections.get(actor),result=r,
                    position={k:w.agents[actor][k] for k in ('x','z','yaw')},body=deepcopy(w.bodies[actor]),
                    inventory={a:w.agents[a]['inventory'] for a in IDS},stock=[f['stock'] for f in w.resources],
                    social=deepcopy(states[actor]),pressure=deepcopy(pressures[actor])))
            assert sum(f['stock'] for f in w.resources)+sum(a['inventory'] for a in w.agents.values())+w.consumed==60
        start=day*DAY_US+14_400_000_000;w.seconds=start/1e6;night={}
        for actor in IDS:
            integrate(actor,start,w.observe_communication(actor));a=sleeper(day,start)
            for sec in range(2880):
                phase='safety' if spec['interrupt'] and sec==100 else 'night'
                w.bodies[actor],_=step(w.bodies[actor],'rest',load=w.agents[actor]['inventory'])
                receipt(a,start+sec*1_000_000,phase)
            cycle=a.learning['sleep']['cycle']
            if spec['adopt']:states[actor]=social.consolidate(states[actor],dict(cycle,formation_us=start),actor)
            night[actor]=dict(sleep=a.learning['sleep'],social=deepcopy(states[actor]))
        nights.append(night)
    return dict(rows=rows,nights=nights,request_counts=request_counts,consumed=w.consumed,
                stock=[f['stock'] for f in w.resources],inventory={a:w.agents[a]['inventory'] for a in IDS})


def contact_boundaries():
    w=make_world(SPECS[0]);w.agents['npc_a'].update(x=0.,z=0.);w.agents['npc_b'].update(x=0.,z=1.)
    out={'near':w.contact('npc_a','npc_b')}
    w.agents['npc_b']['z']=2.;out['far']=w.contact('npc_a','npc_b')
    w.agents['npc_b']['z']=1.;w.objects=[dict(x=0.,z=.5,radius=.1,solid=True)]
    out['occluded']=w.contact('npc_a','npc_b');w.objects=[]
    request=w.communicate('npc_a','request','request','npc_b');w.seconds=1
    w.agents['npc_b']['z']=2.
    response=w.communicate('npc_b','response','give','npc_a','npc_a:request')
    out['departed_response']=response;out['departed_inventory']={a:w.agents[a]['inventory'] for a in IDS}
    w.agents['npc_b']['z']=1.;out['returned_contact']=w.contact('npc_a','npc_b')
    out['old_response']=w.communicate('npc_b','response','give','npc_a','npc_a:request')
    out['new_response']=w.communicate('npc_b','response2','give','npc_a','npc_a:request')
    out['final_inventory']={a:w.agents[a]['inventory'] for a in IDS}
    try:w.communicate('npc_b','response2','refuse','npc_a','npc_a:request')
    except ValueError as e:out['conflict']=str(e)
    return out


SPECS=[]
for name in ('enabled','shadow','unheard','obstacle','separated','interrupt'):
    SPECS.append(dict(name=name,ticks=90,adopt=name!='shadow',hearing=name!='unheard',interrupt=name=='interrupt',
        positions=[[0.,0.],[-.4,4.],[.4,4.]] if name!='separated' else [[0.,0.],[-.4,12.],[.4,12.]],
        food=[dict(x=float(x),z=5.,stock=12) for x in (-2,0,2)],
        obstacles=[dict(x=0.,z=2.,radius=.65,solid=True)] if name=='obstacle' else []))
