"""Goal-scoped local hypothesis comparison; not canonical E/H/T1 admission."""
from copy import deepcopy

MODEL='home-trial-confirmation-hypothesis-v1'

def initial(goal_id):
    return dict(goal_id=goal_id,model_ref=MODEL,H=0,threshold=2,records={},trial=None)

def begin(state,trial_id,source):
    s=deepcopy(state)
    s['trial']=dict(trial_id=trial_id,source=source,model_ref=MODEL,F=dict(home_confirmed=1))
    return s

def finish(state,trial_id,confirmed,comparable,source):
    s=deepcopy(state)
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
        F_prime=dict(home_confirmed=int(confirmed)) if comparable else None,E=E,
        H_before=before,H_after=s['H'],status='compared' if comparable else 'defer')
    s['trial']=None
    return s
