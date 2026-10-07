"""Opt-in social actions inside the existing one-body-action exploration scheduler."""
from copy import deepcopy
import json
from math import hypot
from runtime.exploration import require
from runtime.social_sleep import ingest,consolidate
from .energy_exploration import EnergyWorld,EnergyAgent,EnergyCampaign
from .minimal_communication import CommunicationWorld


class SocialWorld(EnergyWorld):
    personal_food=False
    def __init__(self,*args,**kwargs):
        super().__init__(*args,**kwargs)
        self.communication=CommunicationWorld(capacity=1024)
        # Same local reach as lightweight pickup/unload; old fixtures retain 0.6.
        self.communication.contact_distance=1.25
        self.communication.agents=self.agents;self.communication.bodies=self.bodies
        self.stock=0;self.social_log={};self.metabolic_us=0;self.metabolic_log=[];self.food_ledger={}

    def record_food(self,op):
        if op not in self.food_ledger:
            self.food_ledger[op]=dict(ground=sum(r['stock'] for r in self.resources),shared=self.stock,
                carried={a:b['inventory'] for a,b in self.agents.items()},consumed=self.communication.consumed)

    def advance_metabolism(self,now):
        require(now>=self.metabolic_us,'metabolic_clock')
        if now==self.metabolic_us:return
        cost=(now-self.metabolic_us)/1e6*.25
        before={a:b['reserve'] for a,b in self.bodies.items()}
        for body in self.bodies.values():body['reserve']=max(0.,body['reserve']-cost)
        self.metabolic_log.append(dict(start_us=self.metabolic_us,end_us=now,before=before,
                                       after={a:b['reserve'] for a,b in self.bodies.items()}))
        self.metabolic_us=now

    def at_base(self,aid):
        a=self.agents[aid]
        return hypot(a['x'],a['z']-6)<=1.25 and self.visible(aid,dict(x=0.,z=6.))

    def packet(self,aid,slot):
        p=super().packet(aid,slot);self.communication.seconds=p['capture_us']/1e6
        self.communication.objects=self.objects
        s=self.communication.observe_communication(aid)
        s.update(source={k:p[k] for k in ('run_id','agent_id','observation_id','capture_us','pose_ref')},
                 at_base=self.at_base(aid),stock=self.stock if self.at_base(aid) else None)
        p['social']=s
        if self.personal_food:
            from runtime.personal_food import observe
            s['food_band']=observe(s['inventory'])
        return p

    def execute(self,c,p,executed_us=None):
        aid=c['agent_id'];op=c['operation_id']
        if c['kind']!='social':
            r=super().execute(c,p,executed_us);self.record_food(op);return r
        if op in self.effects:
            old,r=self.effects[op];require(old==c,'operation_conflict');return deepcopy(r)
        now=c['capture_us']+1_000_000 if executed_us is None else executed_us
        require(all(c.get(k)==v for k,v in self.context(aid).items()),'context')
        require(c['source_id']==p['observation_id'] and op=='op:'+p['observation_id'] and p['agent_id']==aid,'source_binding')
        require(all(c[k]==p[k] for k in ('capture_us','pose_ref','body_revision')),'capture_binding')
        require(now==c['capture_us']+1_000_000 and c['capture_us']>=self.ready_us[aid],'body_schedule')
        a=self.agents[aid];body=deepcopy(self.bodies[aid]);before=self.pose(aid);revision=a['revision']
        intent=json.loads(c['target_ref']);status='unavailable'
        if before!=c['pose_ref'] or revision!=c['body_revision']:status='stale'
        elif now>=c['expires_us']:status='expired'
        elif intent['action'] in ('deposit','take'):
            if self.at_base(aid) and not self.personal_food:
                if intent['action']=='deposit' and a['inventory']:
                    self.stock+=a['inventory'];a['inventory']=0;status='deposited'
                elif intent['action']=='take' and self.stock:
                    self.stock-=1;a['inventory']+=1;status='taken'
        else:
            self.communication.seconds=now/1e6;self.communication.objects=self.objects
            status=self.communication.communicate(aid,op,**intent)['status']
        r=dict(self.context(aid),operation_id=op,source_id=c['source_id'],executed_us=now,
            before_pose_ref=before,after_pose_ref=self.pose(aid),before_revision=revision,after_revision=a['revision'],
            status=status,forward=0,right=0,up=0,yaw=0,acquired=False)
        self.effects[op]=(deepcopy(c),deepcopy(r));self.ready_us[aid]=now
        self.body_log[op]=dict(before=body,after=deepcopy(self.bodies[aid]))
        self.social_log[op]=dict(intent=intent,result=deepcopy(r),inventory={k:v['inventory'] for k,v in self.agents.items()},
                                 stock=self.stock,consumed=self.communication.consumed)
        self.record_food(op)
        return r


class SocialAgent(EnergyAgent):
    hunger_enabled=False
    personal_food=False
    share=True
    social_adopt=True
    social_pressure=True
    refusal_field_mode='disabled'
    refusal_seed=0
    deposit_enabled=True

    def carried_count(self):
        return getattr(self,'_social_inventory',0)

    def _packet(self,p):
        s=p['social']
        require(set(s)=={'source','self_id','body','inventory','others','messages','at_base','stock'} | ({'food_band'} if self.personal_food else set()),'social_fields')
        if self.personal_food:
            from runtime.personal_food import observe
            require(s['food_band']==observe(s['inventory']),'food_band')
        require(s['source']=={k:p[k] for k in ('run_id','agent_id','observation_id','capture_us','pose_ref')},'social_binding')
        require(s['self_id']==p['agent_id'] and type(s['inventory']) is int and s['inventory']>=0,'social_inventory')
        require(s['body']==p['locomotor']['state'] and s['inventory']==p['locomotor']['energy']['load'],'social_body')
        require(type(s['at_base']) is bool and ((type(s['stock']) is int and s['stock']>=0)
                if s['at_base'] else s['stock'] is None),'social_stock')
        require(isinstance(s['others'],list) and len(s['others'])<=5,'social_contacts')
        seen=set()
        for other in s['others']:
            require(set(other)=={'ref','holding_food'} and other['ref'] in self.allowed_agent_ids
                    and other['ref']!=self.agent_id and other['ref'] not in seen
                    and type(other['holding_food']) is bool,'social_contact')
            seen.add(other['ref'])
        require(isinstance(s['messages'],list) and len(s['messages'])<=32,'social_messages')
        seen=set()
        for message in s['messages']:
            require(set(message)=={'id','sender','kind','reply_to','time'} and isinstance(message['id'],str)
                    and message['id'] not in seen and message['sender'] in self.allowed_agent_ids
                    and message['sender']!=self.agent_id and message['kind'] in ('request','given','refuse','reach','warn')
                    and type(message['time']) in (int,float) and 0<=p['capture_us']/1e6-message['time']<3,'social_message')
            seen.add(message['id'])
        return super()._packet({k:v for k,v in p.items() if k!='social'})

    def result_contract(self,c):
        allowed,distance=super().result_contract(c)
        allowed['social']={'unavailable','expressed','transferred','ate','no_food','withdraw','wait','deposited','taken'}
        return allowed,distance

    def _decision(self,p):
        self._social_inventory=p['social']['inventory']
        d=super()._decision(p)
        learning,model=self._prospective
        if self.hunger_enabled:
            from runtime.hunger_review import update
            learning['hunger']=update(learning.get('hunger'),self.agent_id,p['capture_us'],
                                     p['social']['body']['reserve'],p['observation_id'])
            h=learning['hunger']
            d['hunger']=dict(intensity=h['intensity'],H=h['goal']['H'],threshold=h['goal']['threshold'],
                             due=h['due'],comparisons=len(h['goal']['records']))
        s=ingest(learning.get('social_relations'),p,self.results)
        if self.social_pressure:
            from runtime.aid_method_pressure import update
            s['pressure']=update(s.get('pressure'),s['records'],self.agent_id)
        if self.refusal_field_mode!='disabled':
            from runtime.refusal_relation_field import compile_field
            s['refusal_field']=compile_field(s['records'],s['pressure'],self.agent_id)
        cycle=(learning.get('sleep') or {}).get('cycle')
        if cycle:
            formation=self.observations.get(cycle['source'],p)['capture_us']
            if self.social_adopt:s=consolidate(s,dict(cycle,formation_us=formation),self.agent_id)
        intent=None;obs=p['social'];phase=d['day_cycle']['phase'];time=p['capture_us']%64_000_000
        provision=None
        if self.personal_food:
            from runtime.personal_food import assess
            provision=assess(obs['food_band'],obs['body']['reserve'])
            if self.hunger_enabled and obs['body']['reserve']==80 and obs['food_band']!='none':
                provision['choice']='eat'
            d['personal_food']=provision
        # Existing safety and in-flight body/deadline gates retain authority.
        previous=next(reversed(self.observations.values())) if self.observations else None
        result=self.results.get('op:'+previous['observation_id']) if previous else None
        linked=previous is None or (result is not None and result['after_pose_ref']==p['pose_ref']
            and result['after_revision']==p['body_revision'] and result['executed_us']<p['capture_us'])
        available=(linked and phase not in ('safety','orientation') and p['capture_us']+1_000_000<self.expiry(p['capture_us']))
        # Final four night seconds are reserved for confirmed ordinary rest/Sleep.
        if available and not (phase=='night' and time>=60_000_000):
            answered=set()
            for prior in self.decisions.values():
                if prior.get('social_intent',{}).get('reply_to'):answered.add(prior['social_intent']['reply_to'])
            message=next((m for m in reversed(obs['messages']) if m['id'] not in answered and m['kind'] in ('request','warn','reach')),None)
            if message:
                action={'warn':'withdraw','reach':'warn','request':'give' if self.share and obs['inventory'] else 'refuse'}[message['kind']]
                intent=dict(action=action,target=message['sender'],reply_to=message['id'])
                if (message['kind']=='request' and self.share and self.refusal_field_mode!='disabled'
                        and message['sender'] in {o['ref'] for o in obs['others']}):
                    from runtime.refusal_relation_field import choose
                    current=dict(obs,messages=[message])
                    seed=f'{self.refusal_seed}:{self.run_id}:{self.agent_id}:{p["observation_id"]}:respond:{message["sender"]}'
                    intent,d['refusal_choice']=choose(s['refusal_field'],current,message['sender'],'respond',seed,
                                                    enabled=self.refusal_field_mode=='enabled')
            elif (provision['choice']=='eat' if provision else obs['body']['reserve']<80 and obs['inventory']):
                intent=dict(action='eat')
            elif not self.personal_food and obs['body']['reserve']<80 and obs['at_base'] and obs['stock']:
                intent=dict(action='take')
            elif obs['body']['reserve']<80 and not s['pending']:
                targets=[x['ref'] for x in obs['others'] if x['holding_food']]
                if targets:
                    if self.social_pressure:
                        from runtime.aid_method_pressure import select
                        target,d['aid_method_selection']=select(targets,s['model'],s['pressure'])
                    else:target=min(targets,key=lambda x:(-s['model'].get(x,{}).get('expectation',.5),x))
                else:target=None
                if target is not None:
                    intent=dict(action='request',target=target)
                    if self.refusal_field_mode!='disabled':
                        from runtime.refusal_relation_field import choose
                        seed=f'{self.refusal_seed}:{self.run_id}:{self.agent_id}:{p["observation_id"]}:request:{target}'
                        candidate,d['refusal_choice']=choose(s['refusal_field'],obs,target,'request_again',seed,
                                                           enabled=self.refusal_field_mode=='enabled')
                        intent=candidate if candidate['action']=='request' else None
                    if intent:
                        mid=self.agent_id+':op:'+p['observation_id']
                        s['pending']=dict(message_id=mid,target=target,deadline=p['capture_us']+5_000_000,
                                          request_observation_id=p['observation_id'],operation_id='op:'+p['observation_id'])
            if intent is None and not self.personal_food and self.deposit_enabled and obs['at_base'] and obs['inventory'] and phase in ('return','night'):
                intent=dict(action='deposit')
        if d['reason']=='return_unload_attempt' and intent is None:
            if obs['inventory'] and self.deposit_enabled and not self.personal_food:intent=dict(action='deposit')
            else:d.update(action=['wait',0],reason='social_base_wait')
        if self.hunger_enabled and intent and intent['action'] in ('eat','request'):
            from runtime.hunger_review import select
            d['hunger_selection']=select(learning['hunger'],intent['action'])
            if d['hunger_selection']['selected']=='existing_activity':
                if intent['action']=='request':s['pending']=None
                intent=None
        if self.personal_food and intent is None and d['reason']=='return_unload_attempt':
            d.update(action=['wait',0],target='',reason='social_base_wait')
        if (intent is None and provision and provision['choice']=='provisioned_rest' and available
                and phase=='exploration' and d.get('terrain_gate')!='safety'):
            d['body_bridge']['baseline_action']=list(d['action'])
            d['body_bridge']['baseline_reason']=d['reason']
            d.update(action=['wait',0],target='',reason='personal_food_sufficient')
            self._body_final(d)
        if intent:
            # Preserve the actual superseded proposal for auditing.
            d['body_bridge']['baseline_action']=list(d['action'])
            d['body_bridge']['baseline_reason']=d['reason']
            d.update(action=['social',0],target=json.dumps(intent,sort_keys=True),reason='social_'+intent['action'],social_intent=intent)
            # Superseded movement cannot receive rest or movement credit.
            self._body_final(d)
        learning['social_relations']=s;self._prospective=learning,model
        d['social_relations']=deepcopy(s)
        return d


class SocialCampaign(EnergyCampaign):
    agent_type=SocialAgent
