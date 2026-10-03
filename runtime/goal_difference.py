"""Goal-scoped local hypothesis comparison; not canonical E/H/T1 admission."""
from copy import deepcopy

MODEL='home-trial-confirmation-hypothesis-v1'

def initial(goal_id,model_ref=MODEL,dimension='home_confirmed',threshold=2,parent_goal_id=None):
    if not all(isinstance(x,str) and x for x in (goal_id,model_ref,dimension)):raise ValueError('goal_contract')
    if type(threshold) is not int or threshold<1:raise ValueError('goal_threshold')
    if parent_goal_id==goal_id:raise ValueError('goal_parent')
    return dict(goal_id=goal_id,model_ref=model_ref,dimension=dimension,parent_goal_id=parent_goal_id,
                H=0,threshold=threshold,records={},trial=None)

def method(state,enabled,primary,alternative):
    """Caller supplies permitted methods; no action authority is created here."""
    return alternative if enabled and state['H']>=state['threshold'] else primary

def begin(state,trial_id,source):
    s=deepcopy(state)
    trial=dict(trial_id=trial_id,source=deepcopy(source),model_ref=s['model_ref'],
               goal_id=s['goal_id'],dimension=s['dimension'],F={s['dimension']:1})
    if s['trial'] is not None:
        if s['trial']!=trial:raise ValueError('goal_trial_active')
        return s
    if trial_id in s['records']:raise ValueError('goal_trial_closed')
    s['trial']=trial
    return s

def finish(state,trial_id,confirmed,comparable,source):
    if type(confirmed) is not bool or type(comparable) is not bool:raise ValueError('goal_evidence')
    s=deepcopy(state)
    compared_trial=state['records'].get(trial_id,{}).get('trial') or state['trial']
    if compared_trial and compared_trial.get('interrupted_by_safety') and not confirmed:comparable=False
    evidence=dict(confirmed=confirmed,comparable=comparable,source=source)
    if trial_id in s['records']:
        if s['records'][trial_id]['evidence']!=evidence:raise ValueError('goal_trial_conflict')
        return s
    trial=s['trial']
    if not trial or trial['trial_id']!=trial_id:raise ValueError('goal_trial_binding')
    E=(0 if confirmed else 1) if comparable else None
    before=s['H']
    if comparable:s['H']=0 if confirmed else before+E
    s['records'][trial_id]=dict(trial=deepcopy(trial),evidence=evidence,
        F_prime={trial["dimension"]:int(confirmed)} if comparable else None,E=E,
        H_before=before,H_after=s['H'],status='compared' if comparable else 'defer')
    s['trial']=None
    return s
