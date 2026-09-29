"""LW-1: deterministic planar World; existing campaign owns every decision."""
from copy import deepcopy
from math import sin, cos, radians, sqrt, hypot, tan
from random import Random
from hashlib import sha256

from runtime.exploration import CELLS, SLOT_US
from runtime.landmark_return_campaign import ReturnCampaign, CampaignAgent
from runtime.landmark_day_cycle import DAY_US


def segment_hit(start, end, obj, margin=0):
    dx, dz = end[0]-start[0], end[1]-start[1]
    length = dx*dx+dz*dz
    t = max(0, min(1, ((obj['x']-start[0])*dx+(obj['z']-start[1])*dz)/length)) if length else 0
    return hypot(start[0]+t*dx-obj['x'], start[1]+t*dz-obj['z']) <= obj['radius']+margin


def ray_hit(start, direction, obj):
    dx, dz = obj['x']-start[0], obj['z']-start[1]
    along = dx*direction[0]+dz*direction[1]
    disc = obj['radius']**2-(dx*dx+dz*dz-along*along)
    if disc < 0: return None
    far = along+sqrt(disc)
    return max(0, along-sqrt(disc)) if far >= 0 else None


def distant_patches(features, mode):
    """Compress contiguous identical observed bands; never consult object identity."""
    if mode not in ('rays', 'patches'): raise ValueError('distant_mode')
    out=[]
    for feature in features:
        f=deepcopy(feature)
        if (mode=='patches' and out and out[-1]['color']==f['color']
                and out[-1]['range_band']==f['range_band']
                and out[-1]['azimuth'][1]==f['azimuth'][0]):
            out[-1]['azimuth'][1]=f['azimuth'][1]
        else:out.append(f)
    return out


class World:
    version = 'lw-planar-world-v1'

    def __init__(self, run_id='lw-demo', seed=20260928, distant_mode='rays', layout='dense'):
        distant_patches([],distant_mode)
        self.inexhaustible=False
        self.skyline_subrays=False
        self.distant_mode=distant_mode
        if layout not in ('dense','sparse'):raise ValueError('layout')
        self.layout=layout
        self.run_id, self.seed = run_id, seed
        rng = Random(seed)
        self.objects = [dict(x=0., z=8., radius=1., height=12., color='ochre', solid=True)]
        for i in range(22):
            angle = rng.uniform(-180, 180); distance = rng.uniform(14, 43)
            self.objects.append(dict(x=sin(radians(angle))*distance, z=cos(radians(angle))*distance,
                radius=rng.uniform(.6, 1.5), height=rng.choice([2., 5., 8.]),
                color=rng.choice(['brown', 'green', 'gray']), solid=True))
        self.resources = []
        # Patches are distinct from visual trunks; association is not taught.
        for obj in self.objects[1:9]:
            self.resources.append(dict(x=obj['x']+obj['radius']+1., z=obj['z'], stock=12))
        # Keep food positions/stock identical: vary only visible solid objects.
        if layout=='sparse':
            self.objects=[self.objects[i] for i in (0,1,4,7,10,14)]
        self.agents = {f'npc_{c}':dict(x=float(i*2-2), z=4., yaw=0., revision=0, inventory=0)
                       for i,c in enumerate('abc')}
        self.effects, self.tokens = {}, {a:{} for a in self.agents}
        self.returns, self.counted = [], set()
        self.pickups = []

    def context(self, aid):
        return dict(run_id=self.run_id, world_epoch=1, agent_id=aid)

    def pose(self, aid):
        return f'{self.run_id}:{aid}:pose:{self.agents[aid]["revision"]}'

    def direction(self, aid, angle=0):
        theta = radians(self.agents[aid]['yaw']+angle)
        return sin(theta), cos(theta)

    def relative(self, aid, obj):
        a=self.agents[aid]; dx,dz=obj['x']-a['x'],obj['z']-a['z']
        s,c=self.direction(aid)
        return dx*s+dz*c, dx*c-dz*s

    def cast(self, aid, angle, limit, elevation=0):
        a=self.agents[aid]; origin=(a['x'],a['z']); direction=self.direction(aid,angle)
        hits=[]
        for obj in self.objects:
            d=ray_hit(origin,direction,obj)
            if d is not None and d<=limit and 1.+d*tan(radians(elevation))<=obj['height']:
                hits.append((d,obj))
        return min(hits,key=lambda x:x[0]) if hits else None

    def visible(self, aid, obj):
        a=self.agents[aid]
        return not any(segment_hit((a['x'],a['z']),(obj['x'],obj['z']),o) for o in self.objects)

    def traversable(self, aid, angle=0):
        a=self.agents[aid];dx,dz=self.direction(aid,angle)
        return not any(segment_hit((a['x'],a['z']),(a['x']+dx,a['z']+dz),o,.2) for o in self.objects if o['solid'])

    def packet(self, aid, slot):
        a=self.agents[aid]; now=slot*SLOT_US; ident=f'{self.run_id}:{aid}:obs:{slot}'
        p=dict(self.context(aid),clock_id='world-sim-v1',observation_id=ident,capture_us=now,
               sample_seq=slot,pose_ref=self.pose(aid),body_revision=a['revision'])
        food=[]
        for index,obj in enumerate(self.resources):
            f,r=self.relative(aid,obj);d=hypot(f,r)
            if obj['stock'] and d<=12 and f>=0 and self.visible(aid,obj):
                token='seen:'+sha256(f'{self.run_id}:{aid}:{index}'.encode()).hexdigest()[:24]
                self.tokens[aid][token]=index
                food.append(dict(ref=token,distance=d,forward=f,right=r,up=0,appearance='brown_capped_ovoid'))
        food.sort(key=lambda x:(x['distance'],x['ref']))
        p['food']=dict(coverage='partial' if len(food)>5 else 'complete',visible=food[:5])
        cells=[]
        offsets=((0,0),(0,1),(0,2),(90,1),(90,2),(-90,1),(-90,2),(180,1),(180,2))
        for key,(angle,distance) in zip(CELLS,offsets):
            dx,dz=self.direction(aid,angle)
            hit=any(segment_hit((a['x'],a['z']),(a['x']+dx*distance,a['z']+dz*distance),o) for o in self.objects)
            cells.append(dict(cell_id=key,color='unknown' if hit else 'green',status='occluded' if hit else 'sampled'))
        p['ground']=dict(model='l13t-local-surface-rays-v1',profile='l13t-natural-fixed-v1',
                        coverage='partial' if any(c['status']!='sampled' for c in cells) else 'complete',cells=cells)
        features=[];sky=[]
        for elevation in (0,15,30):
            for j,angle in enumerate(range(-90,91,15)):
                hit=self.cast(aid,angle,48,elevation)
                bounds=[max(-90,angle-7.5),min(90,angle+7.5)]
                if hit and elevation==0 and hit[1]['color']!='ochre':
                    d,obj=hit
                    features.append(dict(ref=f'ray:{elevation}:{j}',color=obj['color'],azimuth=bounds,
                        range_band='near' if d<=8 else 'mid' if d<=24 else 'far'))
                skyhit=hit
                if self.skyline_subrays:
                    hits=[h for delta in (-5,0,5) if -90<=angle+delta<=90
                          if (h:=self.cast(aid,angle+delta,48,elevation))]
                    skyhit=min(hits,key=lambda h:h[0]) if hits else None
                if skyhit:
                    d,obj=skyhit
                    sky.append(dict(ref=f'ray:{elevation}:{j}',color=obj['color'],azimuth=bounds,
                        range_band='near' if d<=8 else 'mid' if d<=24 else 'far',elevation=elevation))
        p['landmarks']=dict(model='l13u-horizontal-surface-fan-v1',profile='l13u-landmark-fixed-v1',
                            coverage='complete',output_limited=False,features=features)
        p['skyline']=dict(model='finite-elevated-fan-v1',source={k:p[k] for k in ('agent_id','observation_id','capture_us','pose_ref')},coverage='complete',features=sky)
        # Finite surface rays, same wire vocabulary; new sensor implementation is declared in the run manifest.
        distant=[]
        patches=distant_patches(features,self.distant_mode)
        for j,f in enumerate(patches[:4]):
            distant.append(dict(feature_id=f'f{j}',color_band={'green':'unknown','brown':'unknown','gray':'dark_gray','blue':'unknown','red':'muted_red'}[f['color']],
                azimuth_interval_deg=f['azimuth'],elevation_interval_deg=[0,5],angular_width_band='unknown',angular_height_band='unknown'))
        p['distant']=dict(frame_id=f'{self.run_id}:{aid}:distant:{slot}',agent_id=aid,sensor_id='eye',channel='vision_distant',
            profile_id='fixture-distant-enabled',profile_revision=1,sensor_model_revision='sampled-surface-v0.2',
            sample_seq=slot,clock_id='world-sim-v1',sampled_world_tick=slot,observer_frame_ref=p['pose_ref'],
            capture_window=dict(kind='instant',start_us=now,end_us=now),status='SAMPLED',
            coverage='PARTIAL' if len(patches)>4 else 'COMPLETE_WITHIN_PLAN',output_limited=len(patches)>4,payload=dict(features=distant))
        context={k:p[k] for k in ('run_id','world_epoch','agent_id','observation_id','clock_id','capture_us','pose_ref','body_revision')}
        samples=[dict(direction_deg=angle,status='sampled' if self.traversable(aid,angle) else 'blocked',
                      height_delta=0 if self.traversable(aid,angle) else None) for angle in (-90,-45,0,45,90)]
        obstacles=[]
        for j,angle in enumerate(range(-90,91,30)):
            hit=self.cast(aid,angle,12)
            if hit:
                d,_=hit;obstacles.append(dict(ref=ident+f':ray:{j}',forward=max(0,d*cos(radians(angle))),right=d*sin(radians(angle))))
        p['movement_surface']=dict(schema='l15a-current-surface-rays-v1',
            ground=dict(source=dict(context,frame_id=ident+':ground'),coverage='complete',output_limited=False,samples=samples),
            obstacles=dict(source=dict(context,frame_id=ident+':obstacles'),coverage='complete',output_limited=False,items=obstacles))
        return p

    def execute(self, command, packet, executed_us=None):
        c=command;aid=c['agent_id'];op=c['operation_id']
        if any(c.get(k)!=v for k,v in self.context(aid).items()):raise ValueError('context')
        if op!='op:'+packet['observation_id']:raise ValueError('operation_binding')
        if op in self.effects:
            old,result=self.effects[op]
            if old!=c:raise ValueError('operation_conflict')
            return deepcopy(result)
        if c['source_id']!=packet['observation_id'] or packet['agent_id']!=aid:raise ValueError('source_binding')
        a=self.agents[aid];before=self.pose(aid);revision=a['revision'];now=c['capture_us']+1 if executed_us is None else executed_us
        if now<c['capture_us']:raise ValueError('execution_time')
        status={'move':'blocked','turn':'turned','wait':'waited','pickup':'not_found'}[c['kind']]
        if c['pose_ref']!=before or c['body_revision']!=revision:status='stale'
        elif now>=c['expires_us']:status='expired'
        elif c['kind']=='move' and self.traversable(aid):
            dx,dz=self.direction(aid);a['x']+=dx;a['z']+=dz;status='moved'
        elif c['kind']=='turn':a['yaw']=(a['yaw']+c['amount']+180)%360-180
        elif c['kind']=='pickup':
            visible={i['ref'] for i in packet['food']['visible']}
            index=self.tokens[aid].get(c['target_ref'])
            if index is not None and c['target_ref'] in visible:
                obj=self.resources[index]
                if obj['stock']>0 and hypot(obj['x']-a['x'],obj['z']-a['z'])<=1.25 and self.visible(aid,obj):
                    if not self.inexhaustible:obj['stock']-=1
                    a['inventory']+=1;status='picked_up'
                    self.pickups.append(dict(agent_id=aid,operation_id=op,executed_us=now))
        if status in ('moved','turned','picked_up'):a['revision']+=1
        r=dict(self.context(aid),operation_id=op,source_id=c['source_id'],executed_us=now,
            before_pose_ref=before,after_pose_ref=self.pose(aid),before_revision=revision,after_revision=a['revision'],
            status=status,forward=1 if status=='moved' else 0,right=0,up=0,yaw=c['amount'] if status=='turned' else 0,acquired=status=='picked_up')
        self.effects[op]=(deepcopy(c),deepcopy(r))
        if c['capture_us']%DAY_US>=56000000 and status=='waited' and hypot(a['x'],a['z']-6)<=10:
            fresh=[e['operation_id'] for e in self.pickups if e['agent_id']==aid and e['operation_id'] not in self.counted]
            if fresh:
                self.counted.update(fresh);self.returns.append(dict(agent_id=aid,day=c['capture_us']//DAY_US+1,pickups=fresh,executed_us=now))
                a['inventory']-=len(fresh)
        return r


class ApproachAgent(CampaignAgent):
    def _calculate_current_terrain(self, observed, packet):
        from runtime.approach_movement_field import approach_field
        return approach_field(super()._calculate_current_terrain(observed,packet),packet)


class ApproachCampaign(ReturnCampaign):
    agent_type=ApproachAgent


def run(path, days=3, seed=20260928, mode='enabled', run_id='lw-demo', distant_mode='rays', layout='dense', approach_mode='disabled'):
    """Append complete JSON lines; an interrupted file retains its valid prefix."""
    import json, time
    from pathlib import Path
    if approach_mode not in ('disabled','enabled'):raise ValueError('approach_mode')
    campaign=ApproachCampaign if approach_mode=='enabled' else ReturnCampaign
    world=World(run_id,seed,distant_mode,layout);loop=campaign(run_id,days,seed,mb_field_mode=mode,harvest_state=True)
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    started=time.perf_counter();slots=0
    with path.open('w',encoding='utf8') as stream:
        def emit(value):
            stream.write(json.dumps(value,separators=(',',':'),allow_nan=False)+'\n');stream.flush()
        emit(dict(type='manifest',version=world.version,run_id=run_id,seed=seed,days=days,model_field=mode,
                  approach_mode=approach_mode,layout=layout,objects=world.objects,resources=world.resources,agents=world.agents,authority='experimenter-only World truth',
                  clock='virtual integer microseconds',body_model='instant discrete one-unit step, no agent collisions',sensor='lw-planar-rays-v1' if distant_mode=='rays' else 'lw-planar-patches-v1'))
        for aid in world.agents:
            config=dict(world.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode=mode,
                teaching=dict(statement_id=f'{run_id}:{aid}:teaching',source='god_statue',sample_observation=f'{run_id}:{aid}:sample',
                              appearance='brown_capped_ovoid',predicate='food_after_known_processing'))
            loop.configure(config)
        for slot in range(days*256):
            packets={aid:world.packet(aid,slot) for aid in world.agents}
            commands={aid:loop.observe(p)['command'] for aid,p in packets.items()}
            for aid,c in commands.items():
                result=world.execute(c,packets[aid]);loop.result(result)
                decision=loop.agents[aid].decisions[packets[aid]['observation_id']]
                emit(dict(type='step',packet=packets[aid],command=c,result=result,body=world.agents[aid],
                    model_ref=decision['model_ref'],model_field=decision.get('mb_field'),
                    learning_count=len(loop.agents[aid].learning['records']),returns=len(world.returns),
                    approach_field=(decision.get('movement_terrain') or {}).get('approach_field')))
            slots=slot+1
            if slots%256==0:emit(dict(type='day',day=slots//256,returns=world.returns,stock=[r['stock'] for r in world.resources]))
            if len(world.returns)>=3:break
        reason='return_target_reached' if len(world.returns)>=3 else 'time_limit'
        ended=(slots-1)*SLOT_US+1 if reason=='return_target_reached' else days*DAY_US
        for aid in world.agents:loop.finish(dict(world.context(aid),ended_us=ended,reason=reason))
        summary=dict(type='summary',reason=reason,slots=slots,days_completed=slots//256,returns=world.returns,
            pickups=len(world.pickups),stock=[r['stock'] for r in world.resources],elapsed_seconds=time.perf_counter()-started,
            agents={aid:dict(records=len(a.learning['records']),model_ref=a.model.model_ref if a.model else None,
                observations=len(a.observations),body=world.agents[aid]) for aid,a in loop.agents.items()})
        emit(summary)
    return summary


if __name__=='__main__':
    import argparse,json
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--days',type=int,default=3)
    p.add_argument('--seed',type=int,default=20260928);p.add_argument('--mode',choices=['enabled','disabled'],default='enabled')
    p.add_argument('--distant-mode',choices=['rays','patches'],default='rays')
    p.add_argument('--layout',choices=['dense','sparse'],default='dense')
    p.add_argument('--approach-mode',choices=['disabled','enabled'],default='disabled')
    args=p.parse_args();print(json.dumps(run(args.output,args.days,args.seed,args.mode,distant_mode=args.distant_mode,layout=args.layout,approach_mode=args.approach_mode),indent=2))

