"""Parent-goal success credit for a bounded, executed child contribution."""
from copy import deepcopy


def review(state,agent,p,hunger):
    s=deepcopy(state)
    if s['binding']!=[p['run_id'],p['agent_id']]:raise ValueError('credit_binding')
    goal=hunger['goal']
    if goal['goal_id']!=p['agent_id']+':food-sufficiency':raise ValueError('credit_parent')
    credit=s.setdefault('parent_credit',dict(strength={},pending={},records={},cursor=None))
    previous=next(reversed(agent.observations.values()),None)
    if previous and credit['cursor']!=previous['observation_id']:
        ident=previous['observation_id'];cs=agent.decisions[ident].get('continuous_selection') or {}
        trace=cs.get('experience_bundle') or {};use=trace.get('parent_use') or {}
        command=agent.commands.get(ident);result=agent.results.get(command['operation_id']) if command else None
        chosen=next((c for c in cs.get('candidates',[]) if c['model']==trace.get('selected')),None)
        trial=use.get('trial_id')
        if (trace.get('changed') and trial and trial not in credit['pending'] and trial not in credit['records']
                and command and result and chosen and result['executed_us']<p['capture_us']
                and result['status'] not in ('stale','expired')
                and [command['kind'],command['amount']]==chosen['action']):
            if use['goal_id']!=goal['goal_id'] or use['model_ref']!=goal['model_ref']:raise ValueError('credit_parent')
            known={b['model_ref'] for b in s['bundles']+s.get('dormant',[])}
            refs=sorted({ref for c in trace['contributions'] for ref in c['model_refs']})
            if not refs or not set(refs)<=known:raise ValueError('credit_sources')
            credit['pending'][trial]=dict(parent=deepcopy(use),refs=refs,operation=command['operation_id'],
                observation=ident,action=chosen['action'],result=result['status'])
        credit['cursor']=ident
    for trial,use in list(credit['pending'].items()):
        comparison=goal['records'].get(trial)
        if comparison is None:continue
        success=comparison['evidence']['comparable'] and comparison['evidence']['confirmed']
        # One finite credit budget per parent trial, shared across contributors.
        total=min(8.,use['parent']['H']) if success else 0.
        for ref in use['refs']:
            credit['strength'][ref]=min(8.,credit['strength'].get(ref,0.)+total/len(use['refs']))
        credit['records'][trial]=dict(use=use,comparison=deepcopy(comparison),credit=total,
            status='reinforced' if total else 'not_reinforced')
        del credit['pending'][trial]
    return s
