"""Opt-in timed harvest: fixed work duration, independent agents, result-time stock."""
from copy import deepcopy
from runtime.landmark_day_cycle import DAY_US, BOUNDARIES, phase
from runtime.landmark_return_campaign import ReturnCampaign
from runtime.relational_movement import RULE as RELATION_FIELD_RULE
from .world import World, ApproachAgent

WORK_US=500_000

class HarvestAgent(ApproachAgent):
    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs)
        self.unloaded=set()
        self.unload_receipts={}

    def carried_count(self):
        return sum(r['acquired'] for op,r in self.results.items() if op not in self.unloaded)

    def snapshot(self):
        with self.lock:
            state=super().snapshot()
            state['inventory']=[item for item in state['inventory'] if item['operation_id'] not in self.unloaded]
            state['unload_receipts']=deepcopy(self.unload_receipts)
            return state

    def admit_unload(self,receipt):
        # Explicit body-side delivery receipt; no coordinates or resource truth.
        with self.lock:
            op=receipt['operation_id']
            if op in self.unload_receipts:
                if self.unload_receipts[op]!=receipt:raise ValueError('unload_conflict')
                return False
            result=self.results.get(op)
            if not result or result['status']!='waited' or result['executed_us']!=receipt['executed_us']:
                raise ValueError('unload_result')
            ids=receipt['pickups']
            if not ids or len(ids)!=len(set(ids)):raise ValueError('unload_items')
            for item in ids:
                r=self.results.get(item)
                if not r or not r['acquired'] or r['executed_us']>=result['executed_us'] or item in self.unloaded:
                    raise ValueError('unload_items')
            self.unloaded.update(ids)
            self.unload_receipts[op]=deepcopy(receipt)
            return True

    hazard_mode='disabled'
    warning_review_mode='disabled'
    continuous_selection=False

    goal_difference_mode='disabled'
    food_goal_mode='disabled'
    goal_switch_threshold=2

    def _activity_phase(self,p,state,old):
        from runtime.goal_difference import initial,begin,finish,method
        parent=self.agent_id+':food-security'
        state.setdefault('goal_difference',initial(self.agent_id+':home',threshold=self.goal_switch_threshold,parent_goal_id=parent))
        state.setdefault('food_goal',initial(self.agent_id+':food','food-trial-acquisition-hypothesis-v1',
            'food_acquired',threshold=self.goal_switch_threshold,parent_goal_id=parent))
        state.setdefault('food_review_scans',0)
        g=state['goal_difference']
        new_day=old is not None and p['capture_us']//DAY_US!=old['day']
        food=state['food_goal']
        if new_day:
            state['food_review_scans']=0
            if food['trial'] is not None:
                start=food['trial']['source']['capture_us']
                records=[r for r in self.results.values() if start<=r['executed_us']<(old['day']*DAY_US+32000000)]
                packets=[q for q in self.observations.values() if start<=q['capture_us']<(old['day']*DAY_US+32000000)]
                confirmed=any(r['acquired'] for r in records)
                comparable=confirmed or (bool(records) and bool(packets) and
                    all(q['food']['coverage']=='complete' for q in packets) and
                    all(r['status'] not in ('stale','expired') for r in records))
                food=finish(food,food['trial']['trial_id'],confirmed,comparable,p['observation_id'])
                state['food_goal']=food
        if new_day and g['trial'] is not None:
            delivered=any(r['executed_us']//DAY_US==old['day'] for r in self.unload_receipts.values())
            confirmed=delivered or (old['return_state']['outcome']=='home_like_observed' and self.carried_count()==0)
            trial_packets=[q for q in self.observations.values() if q['capture_us']>=g['trial']['source']['capture_us']]
            comparable=confirmed or (bool(trial_packets) and all(q['skyline']['coverage']=='complete' for q in trial_packets)
                and old['home_memory'] is not None and old['return_state']['outcome'] not in ('body_correspondence_unavailable','acquisition_incomplete'))
            g=finish(g,g['trial']['trial_id'],confirmed,comparable,p['observation_id'])
            state['goal_difference']=g
        scheduled=phase(p['capture_us'])
        if old is None:
            state['home_pending']=False
        elif old['day']!=state['day'] or p['capture_us']//DAY_US!=old['day']:
            # A home-like appearance is insufficient to discharge carried cargo.
            delivered=any(r['executed_us']//DAY_US==old['day'] for r in self.unload_receipts.values())
            state['home_pending']=((not delivered and old['return_state']['outcome']!='home_like_observed') or self.carried_count()>0)
        effective='return' if state.get('home_pending') and scheduled=='exploration' else scheduled
        if effective=='return' and g['trial'] is None:
            state['goal_difference']=begin(g,self.agent_id+':home:'+str(p['capture_us']//DAY_US),
                dict(observation_id=p['observation_id'],capture_us=p['capture_us']))
        if effective=='exploration' and food['trial'] is None:
            state['food_goal']=begin(food,self.agent_id+':food:'+str(p['capture_us']//DAY_US),
                dict(observation_id=p['observation_id'],capture_us=p['capture_us']))
        state['food_method']=method(state['food_goal'],self.food_goal_mode=='enabled','existing_exploration','bounded_rescan')
        state['return_state']['method']=method(state['goal_difference'],self.goal_difference_mode=='enabled','home_first','landmark_first')
        if getattr(self,'_safety_current',{}).get('override'):
            for name in ('food_goal','goal_difference'):
                if state[name]['trial'] is not None:state[name]['trial']['interrupted_by_safety']=True
            return 'safety'
        return effective

    orientation_mode='disabled'
    return_completion_mode='disabled'

    def _packet(self,p):
        if self.hazard_mode!='disabled':
            from runtime.moving_hazard_safety import validate
            validate(p)
        if 'orientation' in p:
            from runtime.initial_orientation import validate
            validate(p)
        if self.orientation_mode=='enabled' and 'orientation' not in p:
            raise ValueError('orientation_required')
        if self.return_completion_mode=='enabled':
            from runtime.local_return import validate
            validate(p)
        return super()._packet({k:v for k,v in p.items() if k not in ('orientation','dock','hazard')})

    lateral_side=None

    def _calculate_current_terrain(self,observed,packet):
        terrain=super()._calculate_current_terrain(observed,packet)
        if self.lateral_side is not None:
            from runtime.composed_lateral_bias import apply
            terrain=apply(terrain,self.lateral_side)
        return terrain

    def _return_review(self,p,memory,state,linked,result):
        if self.return_completion_mode=='enabled':
            from runtime.local_return import review
        else:
            from runtime.home_search import review
        return review(self,p,memory,state,linked,result)

    def expiry(self,capture):
        start=capture//DAY_US*DAY_US
        boundary=next(start+b for b in BOUNDARIES if start+b>capture)
        return min(capture+WORK_US+1,boundary)

    reposition_mode='disabled'
    nested_model_mode='disabled'
    food_revisit_mode='disabled'
    directional_route_mode='disabled'
    relation_field_mode='disabled'

    def _decision(self,p):
        d=self._proposed_decision(p)
        if self.continuous_selection:
            from runtime.continuous_selection import review
            d=review(self,p,d)
        if self.sleep_learning:
            from runtime.harvest_sleep import review as sleep_review
            d=sleep_review(self,p,d)
        return d

    def _proposed_decision(self,p):
        if self.hazard_mode!='disabled':
            from runtime.safety_mode_review import evaluate
            previous=next(reversed(self.decisions.values())) if self.decisions else {}
            packet=next(reversed(self.observations.values())) if self.observations else None
            result=self.results.get('op:'+packet['observation_id']) if packet else None
            safety=evaluate(p,previous.get('safety'),result,self.warning_review_mode,continuous=self.continuous_selection)
            self._safety_current=safety if self.hazard_mode=='enabled' else {}
            d=self._normal_decision(p)
            d['safety']=safety
            if self.hazard_mode=='enabled' and safety['override']:
                d.update(action=safety['action'],target='',reason=safety['reason'],terrain_gate='safety')
                if d.get('mb_field'):
                    d['mb_field'].update(final_action=safety['action'],final_reason=safety['reason'])
            return d
        return self._normal_decision(p)

    def _normal_decision(self,p):
        d=self._base_decision(p)
        if self.relation_field_mode=='enabled':
            from runtime.directional_routes import review as routes
            from runtime.relational_movement import review as field
            d=field(self,p,routes(self,p,d,propose_only=True))
            if d['relation_field']['applied']:
                if self.nested_model_mode=='enabled':
                    from runtime.nested_local_models import review as nested
                    d=nested(self,p,d)
                return d
        elif self.directional_route_mode=='enabled':
            from runtime.directional_routes import review
            d=review(self,p,d)
        elif self.food_revisit_mode=='enabled':
            from runtime.food_revisit import review
            d=review(self,p,d)
        if self.reposition_mode=='enabled':
            from runtime.incomplete_reposition import review
            d=review(self,p,d)
        if self.return_completion_mode=='enabled':
            from runtime.incomplete_reposition import review
            d=review(self,p,d,key='return_reposition',phase='return',landmarks=True,
                reasons=('return_reposition_continue','return_search_no_candidate_after_scan','return_search_acquisition_incomplete',
                    'return_approach_blocked','return_approach_budget','return_search_goal_budget',
                    'return_search_operation_budget','return_search_ambiguous','return_search_blocked'))
        if self.nested_model_mode=='enabled':
            from runtime.nested_local_models import review
            d=review(self,p,d)
        return d

    def _base_decision(self,p):
        d=super()._decision(p)
        state=d['day_cycle']
        if (state['phase']=='exploration' and state['food_method']=='bounded_rescan'
                and d['action'][0]=='wait' and d['reason'] in ('landmark_no_candidate_after_scan','landmark_goal_budget','landmark_operation_budget')
                and state['food_review_scans']<4):
            state['food_review_scans']+=1
            angle=90
            if self.orientation_mode=='enabled':
                from runtime.initial_orientation import scan
                angle,d['orientation_review']=scan(p,self.observations.values())
            d.update(action=['turn',angle],target='',reason='food_goal_rescan',terrain_gate='goal_review')
        if d['action'][0]=='pickup' and p['capture_us']+WORK_US>=self.expiry(p['capture_us']):
            d.update(action=['wait',0],target='',reason='harvest_work_deadline')
        # Only bypass the combined appearance gate, never a body/life/variation gate.
        if phase(p['capture_us'])!='exploration' or d['reason']!='acquisition_incomplete':return d
        previous=next(reversed(self.observations.values())) if self.observations else None
        r=self.results.get('op:'+previous['observation_id']) if previous else None
        linked=previous is None or (r and r['after_pose_ref']==p['pose_ref'] and r['after_revision']==p['body_revision'] and r['executed_us']<p['capture_us'])
        food=[i for i in p['food']['visible'] if i['appearance']==self.teaching['appearance'] and i['distance']<=1.25]
        if linked and p['food']['coverage']=='complete' and food and p['capture_us']+WORK_US<self.expiry(p['capture_us']):
            d.update(action=['pickup',0],target=food[0]['ref'],reason='reachable_food_work',terrain_gate='pickup_work')
        return d

class HarvestCampaign(ReturnCampaign):
    agent_type=HarvestAgent

class WorkScheduler:
    def __init__(self,world):self.world=world;self.pending={};self.completed={}
    def start(self,c,p):
        aid=c['agent_id'];op=c['operation_id']
        if op in self.completed:
            old,r=self.completed[op]
            if old!=c:raise ValueError('operation_conflict')
            return False
        if aid in self.pending:
            old,q,due=self.pending[aid]
            if old!=c or q!=p:raise ValueError('body_busy')
            return False
        if c['kind']!='pickup' or c['capture_us']+WORK_US>=c['expires_us']:raise ValueError('work_deadline')
        if c['pose_ref']!=self.world.pose(aid) or c['body_revision']!=self.world.agents[aid]['revision']:raise ValueError('stale_start')
        if p['food']['coverage']!='complete' or not any(i['ref']==c['target_ref'] and i['distance']<=1.25 for i in p['food']['visible']):raise ValueError('work_target')
        self.pending[aid]=(deepcopy(c),deepcopy(p),c['capture_us']+WORK_US)
        return True
    def advance(self,now):
        out=[]
        for aid,(c,p,due) in sorted(list(self.pending.items()),key=lambda x:(x[1][2],x[0])):
            if due>now:continue
            r=self.world.execute(c,p,executed_us=due)
            self.completed[c['operation_id']]=(c,deepcopy(r));del self.pending[aid]
            out.append((p,c,r))
        return out


def run(path,days=30,skyline_subrays=False,inexhaustible=False,stop_after_returns=3,mb_field_mode="enabled",inexhaustible_after_model=False,goal_difference_mode="disabled",food_goal_mode="disabled",seed=20260928,goal_switch_threshold=2,lateral_side=None,orientation_mode="disabled",reposition_mode="disabled",return_completion_mode="disabled",nested_model_mode="disabled",food_revisit_mode="disabled",directional_route_mode="disabled",relation_field_mode="disabled",hazard_mode="disabled",hazard_scenario="crossing",warning_review_mode="disabled",territory_resource_layout="original",selection_mode="legacy",dynamic_hazard=False,regrowth_days=None,sleep_learning=False,sleep_auto_adopt=False,body_mode="disabled",body_scene="natural",energy_mode="disabled",social_mode="disabled",social_adopt=True,social_pressure=True,refusal_field_mode="disabled",personal_food=False,hunger_enabled=False,body_method_field=False,food_retention=False,experience_bundle_mode="disabled",bundle_sleep_enabled=False,bundle_credit_enabled=False,trail_enabled=False):
    import json,time
    if trail_enabled and (not hunger_enabled or bundle_credit_enabled):raise ValueError('trail_dependencies')
    if bundle_credit_enabled and (experience_bundle_mode!='enabled' or not hunger_enabled):raise ValueError('bundle_credit_dependencies')
    if bundle_sleep_enabled and (experience_bundle_mode=="disabled" or not sleep_learning):raise ValueError("bundle_sleep_dependencies")
    if experience_bundle_mode not in ("disabled","shadow","enabled") or (experience_bundle_mode!="disabled" and not hunger_enabled):raise ValueError("bundle_dependencies")
    if food_retention and (not hunger_enabled or refusal_field_mode=="disabled"):raise ValueError("retention_dependencies")
    if body_method_field and (not hunger_enabled or selection_mode!="continuous"):raise ValueError("body_field_dependencies")
    if hunger_enabled and not personal_food:raise ValueError("hunger_requires_personal_food")
    if personal_food and social_mode!="enabled":raise ValueError("personal_food_requires_social")
    if refusal_field_mode not in ("disabled","shadow","enabled") or (refusal_field_mode!="disabled" and (social_mode!="enabled" or not social_pressure)):raise ValueError("refusal_field_dependencies")
    if social_mode not in ("disabled","enabled") or (social_mode=="enabled" and (energy_mode=="disabled" or not sleep_learning)):raise ValueError("social_dependencies")
    if energy_mode not in ("disabled","shadow","enabled") or (energy_mode!="disabled" and (body_mode!="enabled" or selection_mode!="continuous")):raise ValueError("energy_dependencies")
    if body_mode not in ("disabled","enabled"):raise ValueError("body_mode")
    if body_scene not in ("natural","food_barrier","social_camp","social_shared") or (body_scene!="natural" and body_mode!="enabled"):raise ValueError("body_scene")
    if sleep_auto_adopt and (not sleep_learning or selection_mode!="continuous"):raise ValueError("sleep_auto_dependencies")
    from pathlib import Path
    if stop_after_returns is not None and (type(stop_after_returns) is not int or stop_after_returns < 1):raise ValueError('return_target')
    if type(goal_switch_threshold) is not int or not 1<=goal_switch_threshold<=30:raise ValueError('goal_switch_threshold')
    if relation_field_mode not in ('disabled','enabled'):raise ValueError('relation_field_mode')
    if relation_field_mode=='enabled' and (orientation_mode!='enabled' or return_completion_mode!='enabled'):raise ValueError('relation_field_dependencies')
    if directional_route_mode not in ('disabled','enabled'):raise ValueError('directional_route_mode')
    if directional_route_mode=='enabled' and (orientation_mode!='enabled' or return_completion_mode!='enabled'):raise ValueError('directional_route_dependencies')
    if food_revisit_mode not in ('disabled','enabled'):raise ValueError('food_revisit_mode')
    if food_revisit_mode=='enabled' and (orientation_mode!='enabled' or return_completion_mode!='enabled'):raise ValueError('food_revisit_dependencies')
    if nested_model_mode not in ('disabled','enabled'):raise ValueError('nested_model_mode')
    if return_completion_mode not in ('disabled','enabled'):raise ValueError('return_completion_mode')
    if reposition_mode not in ('disabled','enabled'):raise ValueError('reposition_mode')
    if orientation_mode not in ('disabled','enabled'):raise ValueError('orientation_mode')
    if lateral_side not in (None,'left','right'):raise ValueError('lateral_side')
    if hazard_mode not in ('disabled','shadow','enabled'):raise ValueError('hazard_mode')
    if hazard_scenario not in ('crossing','persistent','night','route_crossing','territorial'):raise ValueError('hazard_scenario')
    if warning_review_mode not in ('disabled','shadow','enabled'):raise ValueError('warning_review_mode')
    if selection_mode not in ('legacy','continuous'):raise ValueError('selection_mode')
    from .resource_regrowth import ResourceRegrowth
    if regrowth_days is not None and (inexhaustible or inexhaustible_after_model):raise ValueError('regrowth_requires_finite_stock')
    regrowth=ResourceRegrowth(regrowth_days) if regrowth_days is not None else None
    world_type,campaign_type=World,HarvestCampaign
    if body_mode=='enabled':
        from .body_exploration import ExplorationBodyWorld,BodyCampaign
        world_type,campaign_type=ExplorationBodyWorld,BodyCampaign
    if energy_mode!='disabled':
        from .energy_exploration import EnergyWorld,EnergyCampaign
        world_type,campaign_type=EnergyWorld,EnergyCampaign
    if social_mode=='enabled':
        from .social_life import SocialWorld,SocialCampaign
        world_type,campaign_type=SocialWorld,SocialCampaign
    w=world_type('lw-work',seed=seed,layout='sparse');loop=campaign_type(w.run_id,days,mb_field_mode=mb_field_mode,harvest_state=True)
    w.personal_food=personal_food
    from .territorial_hazard import TerritorialHazard,resource_layout
    if territory_resource_layout!="original" and hazard_scenario!="territorial":raise ValueError("territory_layout_scenario")
    resource_layout(w,territory_resource_layout)
    if body_scene=='food_barrier':
        # Controlled World initial layout, never a target coordinate sent to policy.
        w.objects=[dict(x=0.,z=8.,radius=1.,height=12.,solid=True,color='ochre')]
        w.resources=[]
        for i,aid in enumerate(w.agents):
            x=(i-1)*2.
            w.agents[aid].update(x=x,z=4.,yaw=0.)
            w.objects.append(dict(x=x,z=4.5,radius=.1,height=.4,solid=True,color='gray'))
            w.resources.append(dict(x=x,z=5.8,stock=12))
    if body_scene in ('social_camp','social_shared'):
        if social_mode!='enabled':raise ValueError('social_scene_requires_social')
        w.objects=[dict(x=0.,z=8.,radius=.3,height=12.,solid=True,color='ochre')]
        w.resources=[dict(x=-.4,z=6.8,stock=6),dict(x=.4,z=6.8,stock=6)]
        for i,aid in enumerate(w.agents):
            w.agents[aid].update(x=(i-1)*.25,z=5.8,yaw=0.,inventory=0 if i==0 else 2)
            w.bodies[aid]['reserve']=30. if i==0 else 90.
        loop.agents['npc_b'].share=False
        loop.agents['npc_b'].deposit_enabled=body_scene=='social_shared'
        loop.agents['npc_c'].deposit_enabled=body_scene=='social_shared'
    territory=TerritorialHazard() if hazard_scenario=='territorial' else None
    if dynamic_hazard and (not territory or selection_mode!='continuous'):raise ValueError('dynamic_hazard_requires_continuous_territory')
    from .patrol_hazard import PatrolHazard,sample_pair
    patrol=PatrolHazard() if dynamic_hazard else None
    for agent in loop.agents.values():
        agent.sleep_model_capacity=192 if days<=30 else 576
        agent.trail_enabled=trail_enabled
        agent.bundle_sleep_enabled=bundle_sleep_enabled
        agent.bundle_credit_enabled=bundle_credit_enabled
        agent.experience_bundle_mode=experience_bundle_mode
        agent.food_retention=food_retention
        agent.body_method_field=body_method_field
        agent.hunger_enabled=hunger_enabled
        agent.personal_food=personal_food
        agent.refusal_field_mode=refusal_field_mode
        agent.refusal_seed=seed
        agent.social_pressure=social_pressure
        agent.social_adopt=social_adopt
        agent.energy_apply=energy_mode=="enabled"
        agent.sleep_auto_adopt=sleep_auto_adopt
        agent.sleep_learning=sleep_learning
        agent.continuous_selection=selection_mode=="continuous"
        agent.hazard_mode=hazard_mode
        agent.warning_review_mode=warning_review_mode
        agent.goal_difference_mode=goal_difference_mode
        agent.food_goal_mode=food_goal_mode
        agent.goal_switch_threshold=goal_switch_threshold
        agent.lateral_side=lateral_side
        agent.orientation_mode=orientation_mode
        agent.reposition_mode=reposition_mode
        agent.return_completion_mode=return_completion_mode
        agent.nested_model_mode=nested_model_mode
        agent.food_revisit_mode=food_revisit_mode
        agent.directional_route_mode=directional_route_mode
        agent.relation_field_mode=relation_field_mode
    w.local_return=return_completion_mode=="enabled"
    w.skyline_subrays=skyline_subrays
    w.inexhaustible=inexhaustible
    scheduler=WorkScheduler(w)
    if body_mode=='enabled':
        from .body_exploration import BodyScheduler
        scheduler=BodyScheduler(w)
    start=time.perf_counter();captures=0
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('w',encoding='utf8') as f:
        def emit(x):f.write(json.dumps(x,separators=(',',':'))+'\n');f.flush()
        if territory:
            emit(dict(type='territory_config',rule='fixed-territorial-response-v1',center=territory.center,home=territory.home,radius=territory.radius,leash=territory.leash,speed=2,warning_distance=3,detector='world-radius',authority='experimenter-only'))
        emit(dict(type='manifest',version='lw-timed-harvest-v1',trail_enabled=trail_enabled,sleep_model_capacity=192 if days<=30 else 576,bundle_credit_enabled=bundle_credit_enabled,bundle_sleep_enabled=bundle_sleep_enabled,experience_bundle_mode=experience_bundle_mode,food_retention=food_retention,body_method_field=body_method_field,hunger_enabled=hunger_enabled,personal_food=personal_food,social_mode=social_mode,social_adopt=social_adopt,social_pressure=social_pressure,refusal_field_mode=refusal_field_mode,body_mode=body_mode,body_scene=body_scene,energy_mode=energy_mode,regrowth_days=regrowth_days,dynamic_hazard=dynamic_hazard,selection_mode=selection_mode,territory_resource_layout=territory_resource_layout,warning_review_mode=warning_review_mode,hazard_mode=hazard_mode,hazard_scenario=hazard_scenario,relation_field_rule=RELATION_FIELD_RULE if relation_field_mode=='enabled' else None,relation_field_mode=relation_field_mode,directional_route_mode=directional_route_mode,food_revisit_mode=food_revisit_mode,nested_model_mode=nested_model_mode,resource_access=w.resource_access,return_completion_mode=return_completion_mode,reposition_mode=reposition_mode,orientation_mode=orientation_mode,days=days,stop_after_returns=stop_after_returns,lateral_side=lateral_side,goal_switch_threshold=goal_switch_threshold,controller_seed=20260928,food_goal_mode=food_goal_mode,goal_difference_mode=goal_difference_mode,return_mode='overnight-home-purpose-v1',inventory_mode='confirmed-unloads-v1',mb_field_mode=mb_field_mode,inexhaustible_after_model=inexhaustible_after_model,stock_mode='inexhaustible' if inexhaustible else 'finite',work_us=1_000_000 if body_mode=='enabled' else WORK_US,skyline_subrays=skyline_subrays,objects=w.objects,resources=w.resources,agents=w.agents,seed=w.seed))
        for aid in w.agents:
            loop.configure(dict(w.context(aid),schema=loop.schema,clock_id='world-sim-v1',selection_profile='steady',mb_field_mode=mb_field_mode,teaching=dict(statement_id=aid+':teaching',source='god_statue',sample_observation=aid+':sample',appearance='brown_capped_ovoid',predicate='food_after_known_processing')))
        def complete(p,c,r):
            loop.result(r)
            if social_mode=='enabled' and c['operation_id'] in w.social_log:
                emit(dict(type='social_effect',**w.social_log[c['operation_id']]))
            for returned in w.returns:
                if returned['agent_id']==c['agent_id'] and returned['executed_us']==r['executed_us']:
                    receipt=dict(operation_id=c['operation_id'],executed_us=r['executed_us'],pickups=returned['pickups'])
                    loop.agents[c['agent_id']].admit_unload(receipt)
                    emit(dict(type='unload_receipt',agent_id=c['agent_id'],receipt=receipt))
            emit(dict(type='completed',food_ledger=getattr(w,'food_ledger',{}).get(c['operation_id']),packet=p,command=c,result=r,body=w.agents[c['agent_id']],layered_body=getattr(w,'body_log',{}).get(c['operation_id']),stock=[x['stock'] for x in w.resources]))
        for slot in range(days*256):
            now=slot*250000
            if social_mode=="enabled":
                w.advance_metabolism(now)
                if w.metabolic_log and w.metabolic_log[-1]["end_us"]==now:emit(dict(type="metabolism",**w.metabolic_log[-1]))
            finished=set()
            for p,c,r in scheduler.advance(now):complete(p,c,r);finished.add(c['agent_id'])
            if regrowth:
                replenished=regrowth.advance(now,w.resources)
                if replenished:emit(replenished)
            territory_state=territory.advance(now,w.agents,w.objects) if territory and hazard_mode!='disabled' else None
            if territory_state:emit(dict(type='territory_world',**territory_state))
            patrol_state=patrol.advance(now,w.objects) if patrol and hazard_mode!='disabled' else None
            if patrol_state:emit(dict(type='patrol_world',**patrol_state))
            packets={aid:w.packet(aid,slot) for aid in w.agents}
            if orientation_mode=='enabled':
                from runtime.initial_orientation import sample
                for aid,p in packets.items():p['orientation']=sample(p,w.agents[aid]['yaw'])
            if w.local_return:
                from runtime.local_return import sample
                for aid,p in packets.items():p['dock']=sample(w,p)
            if hazard_mode!='disabled':
                from .moving_hazard import sample,position
                obj=territory_state['position'] if territory_state else position(now,hazard_scenario)
                for aid,p in packets.items():
                    p['hazard']=sample_pair(w,p,[obj,patrol_state['position']]) if patrol_state else sample(w,p,hazard_scenario,object_state=obj)
                from math import hypot
                emit(dict(type='hazard_world',capture_us=now,position=obj,distances={aid:hypot(body['x']-obj['x'],body['z']-obj['z']) for aid,body in w.agents.items()} if obj else {}))
            for aid,p in packets.items():
                captures+=1
                if aid in scheduler.pending or aid in finished:
                    emit(dict(type='working_capture',packet=p,reason='body_busy' if aid in scheduler.pending else 'completion_boundary'))
                    continue
                if body_mode=='enabled' and now+1_000_000>=days*64000000:
                    emit(dict(type='working_capture',packet=p,reason='campaign_completion_boundary'));continue
                c=loop.observe(p)['command'];d=loop.agents[aid].decisions[p['observation_id']]
                emit(dict(type='decision',bundle_sleep=d.get('bundle_sleep'),bundle_formation=d.get('bundle_formation'),hunger_selection=d.get('hunger_selection'),hunger=d.get('hunger'),personal_food=d.get('personal_food'),refusal_choice=d.get('refusal_choice'),aid_method_selection=d.get('aid_method_selection'),social_relations=d.get('social_relations'),social_intent=d.get('social_intent'),body_bridge=d.get('body_bridge'),sleep_learning=d.get('sleep_learning'),packet=p,command=c,continuous_selection=d.get('continuous_selection'),safety=d.get('safety'),relation_field=d.get('relation_field'),directional_routes=d.get('directional_routes'),food_revisit=d.get('food_revisit'),model_ref=d['model_ref'],records=len(loop.agents[aid].learning['records']),lateral=(d.get('movement_terrain') or {}).get('lateral'),mb_field=d.get('mb_field'),nested_models=d.get('nested_models'),return_reposition=d.get('return_reposition'),reposition=d.get('reposition'),orientation_review=d.get('orientation_review'),return_state=d['day_cycle']['return_state'],home_pending=d['day_cycle'].get('home_pending',False),activity_phase=d['day_cycle']['phase'],goal_difference=d['day_cycle']['goal_difference'],food_goal=d['day_cycle']['food_goal'],food_method=d['day_cycle']['food_method'],food_review_scans=d['day_cycle']['food_review_scans']))
                if inexhaustible_after_model and not w.inexhaustible and loop.agents[aid].model is not None:
                    w.inexhaustible=True
                    emit(dict(type='stock_mode_transition',capture_us=now,agent_id=aid,mode='inexhaustible',model=loop.agents[aid].model.to_json(),admission=loop.agents[aid].learning['admission'],stock=[x['stock'] for x in w.resources]))
                if body_mode=='enabled' or c['kind']=='pickup':
                    scheduler.start(c,p);emit(dict(type='work_started',agent_id=aid,operation_id=c['operation_id'],start_us=now,due_us=now+(1_000_000 if body_mode=='enabled' else WORK_US)))
                else:complete(p,c,w.execute(c,p))
            if stop_after_returns is not None and len(w.returns)>=stop_after_returns and not scheduler.pending:break
        assert not scheduler.pending
        ended=(slot+1)*250000;reason='return_target_reached' if stop_after_returns is not None and len(w.returns)>=stop_after_returns else 'time_limit'
        for aid in w.agents:loop.finish(dict(w.context(aid),ended_us=ended,reason=reason))
        summary=dict(type='summary',reason=reason,captures=captures,ended_us=ended,pickups=len(w.pickups),returns=w.returns,elapsed_seconds=time.perf_counter()-start,stock=[x['stock'] for x in w.resources],
            social_mode=social_mode,social_stock=getattr(w,'stock',None),social_consumed=getattr(getattr(w,'communication',None),'consumed',None),physical_inventory={aid:b['inventory'] for aid,b in w.agents.items()},
            sleep_learning=sleep_learning,energy_mode=energy_mode,body_mode=body_mode,layered_bodies=getattr(w,'bodies',None),
            agents={aid:dict(observations=len(a.observations),carried=a.carried_count(),unloaded=len(a.unloaded),records=len(a.learning['records']),model_ref=a.model.model_ref if a.model else None,
                selection_trail=a.learning.get('selection_trail'),experience_bundles=a.learning.get('experience_bundles'),social_relations=a.learning.get('social_relations'),sleep=a.learning.get('sleep'),sleep_auto_model=a.learning.get('sleep_auto_model')) for aid,a in loop.agents.items()})
        emit(summary)
    return summary

if __name__=='__main__':
    import argparse,json
    p=argparse.ArgumentParser();p.add_argument('--output',required=True);p.add_argument('--days',type=int,default=30);p.add_argument('--skyline-subrays',action='store_true');p.add_argument('--inexhaustible',action='store_true');p.add_argument('--no-return-target',action='store_true');p.add_argument('--mb-field-mode',choices=['enabled','disabled'],default='enabled');p.add_argument('--inexhaustible-after-model',action='store_true');p.add_argument('--goal-difference-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--food-goal-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--seed',type=int,default=20260928);p.add_argument('--goal-switch-threshold',type=int,default=2);p.add_argument('--lateral-side',choices=['left','right']);p.add_argument('--orientation-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--reposition-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--return-completion-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--nested-model-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--food-revisit-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--directional-route-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--relation-field-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--hazard-mode',choices=['disabled','shadow','enabled'],default='disabled');p.add_argument('--hazard-scenario',choices=['crossing','persistent','night','route_crossing','territorial'],default='crossing');p.add_argument('--warning-review-mode',choices=['disabled','shadow','enabled'],default='disabled');p.add_argument('--territory-resource-layout',choices=['original','three_inside'],default='original');p.add_argument('--regrowth-days',type=int);p.add_argument('--dynamic-hazard',action='store_true');p.add_argument('--selection-mode',choices=['legacy','continuous'],default='continuous');p.add_argument('--sleep-learning',action='store_true');p.add_argument('--sleep-auto-adopt',action='store_true');p.add_argument('--body-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--body-scene',choices=['natural','food_barrier','social_camp','social_shared'],default='natural');p.add_argument('--energy-mode',choices=['disabled','shadow','enabled'],default='disabled');p.add_argument('--social-mode',choices=['disabled','enabled'],default='disabled');p.add_argument('--no-social-adopt',action='store_true');p.add_argument('--refusal-field-mode',choices=['disabled','shadow','enabled'],default='disabled');p.add_argument('--personal-food',action='store_true');p.add_argument('--hunger-enabled',action='store_true');p.add_argument('--body-method-field',action='store_true');a=p.parse_args()
    print(json.dumps(run(a.output,a.days,a.skyline_subrays,a.inexhaustible,None if a.no_return_target else 3,a.mb_field_mode,a.inexhaustible_after_model,a.goal_difference_mode,a.food_goal_mode,a.seed,a.goal_switch_threshold,a.lateral_side,a.orientation_mode,a.reposition_mode,a.return_completion_mode,a.nested_model_mode,a.food_revisit_mode,a.directional_route_mode,a.relation_field_mode,a.hazard_mode,a.hazard_scenario,a.warning_review_mode,a.territory_resource_layout,a.selection_mode,a.dynamic_hazard,a.regrowth_days,a.sleep_learning,a.sleep_auto_adopt,a.body_mode,a.body_scene,a.energy_mode,a.social_mode,not a.no_social_adopt,True,a.refusal_field_mode,a.personal_food,a.hunger_enabled,a.body_method_field),indent=2))
