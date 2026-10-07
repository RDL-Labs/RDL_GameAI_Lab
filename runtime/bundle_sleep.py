"""Completed-Sleep-only dormancy; usage is not causal correctness."""
from copy import deepcopy
from .experience_bundle import context


def review(state,agent,p,cycle,formation_us,phase='night'):
    s=deepcopy(state)
    if s['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('bundle_sleep_binding')
    s.setdefault('dormant',[]);s.setdefault('usage',{});s.setdefault('sleep_cycles',[])
    previous=next(reversed(agent.observations.values()),None)
    if previous and s.get('usage_cursor')!=previous['observation_id']:
        ident=previous['observation_id'];decision=agent.decisions[ident]
        cs=decision.get('continuous_selection') or {};trace=cs.get('experience_bundle') or {}
        command=agent.commands.get(ident);result=agent.results.get(command['operation_id']) if command else None
        chosen=next((c for c in cs.get('candidates',[]) if c['model']==cs.get('selected')),None)
        used=bool(trace.get('changed') and command and chosen and result
            and result['status'] not in ('stale','expired') and result['executed_us']<p['capture_us']
            and [command['kind'],command['amount']]==chosen['action'])
        contributors={ref for c in trace.get('contributions',[]) for ref in c['model_refs']}
        for ref in trace.get('matched_refs',[]):
            u=s['usage'].setdefault(ref,dict(opportunities=0,uses=0,idle_sleeps=0))
            u['opportunities']+=1
            if used and ref in contributors:u['uses']+=1
        s['usage_cursor']=ident
    if cycle and cycle['status']=='completed' and cycle['day'] not in s['sleep_cycles']:
        decisions=[];active=[]
        for b in s['bundles']:
            ref=b['model_ref'];u=s['usage'].setdefault(ref,dict(opportunities=0,uses=0,idle_sleeps=0))
            if b['formed_us']>=formation_us:
                active.append(b);continue
            if u['uses']:
                reason='used';u['idle_sleeps']=0
            else:
                u['idle_sleeps']+=1
                reason='matched_without_executed_change' if u['opportunities'] else 'no_opportunity'
            # Rare-context memories get longer retention and are never deleted.
            dormant=not u['uses'] and u['idle_sleeps']>=(2 if u['opportunities'] else 3)
            decisions.append(dict(model_ref=ref,reason=reason,opportunities=u['opportunities'],
                uses=u['uses'],idle_sleeps=u['idle_sleeps'],dormant=dormant))
            (s['dormant'] if dormant else active).append(b)
            u['opportunities']=0;u['uses']=0
        s['bundles']=active;s['sleep_cycles'].append(cycle['day'])
        s.setdefault('sleep_reviews',[]).append(dict(day=cycle['day'],source=cycle['source'],decisions=decisions))
    # Restore matching dormant material only when an active slot exists.
    current=context(p);remaining=[];woken=[]
    for b in s['dormant']:
        if phase in ('exploration','return') and len(s['bundles'])<32 and any(
                x['context']==current and x['phase']==phase for x in b['sources']):
            s['bundles'].append(b);s['usage'][b['model_ref']]['idle_sleeps']=0;woken.append(b['model_ref'])
        else:remaining.append(b)
    s['dormant']=remaining;s['woken']=woken
    return s
