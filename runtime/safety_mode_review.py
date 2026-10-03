"""Local warning-mode justification review, not a proof of safety or Core H."""
from copy import deepcopy
from .moving_hazard_safety import review,KEYS

RULE='warning-mode-justification-v1'


def evaluate(p,old=None,result=None,mode='enabled',*,continuous=False):
    if mode not in ('disabled','shadow','enabled'):raise ValueError('warning_review_mode')
    if mode=='disabled':return review(p,old,result,continuous=continuous)
    binding=[p['run_id'],p['agent_id']]
    fingerprint=dict(hazard=p['hazard'],**{k:p[k] for k in KEYS})
    previous=(old or {}).get('mode_model')
    if previous:
        if previous['binding']!=binding:raise ValueError('warning_review_binding')
        if p['capture_us']<previous['last_seen_us']:raise ValueError('warning_review_clock')
        if p['capture_us']==previous['last_seen_us']:
            if fingerprint!=previous['fingerprint']:raise ValueError('warning_review_conflict')
            return deepcopy(old)
    s=review(p,old,result,continuous=continuous);now=p['capture_us']
    node=deepcopy(previous) if previous else dict(rule=RULE,binding=binding,model='safety/maintain-warning',
        question='current_observation_renews_warning_basis',H=0,threshold=8,events=[],last_eval_us=now,generation=s['generation'])
    node.update(last_seen_us=now,fingerprint=deepcopy(fingerprint),eligible=False,applied=False)
    if node['generation']!=s['generation']:
        node.update(H=0,last_eval_us=now,generation=s['generation'])
    active=bool((old or {}).get('override') or s['override'])
    linked=bool(result and result['after_pose_ref']==p['pose_ref'] and result['after_revision']==p['body_revision']
        and result['executed_us']<now and result['status'] not in ('stale','expired'))
    features=p['hazard']['features']
    reason='inactive'
    if active and features:
        before=node['H'];node.update(H=0,last_eval_us=now)
        reason='observed_hazard_renews_basis'
        node['events']=(node['events']+[dict(source=p['observation_id'],F=1,F_prime=1,E=0,gain=0,H_before=before,H_after=0,reason=reason)])[-32:]
    elif active and not linked:
        node['last_eval_us']=now;reason='body_correspondence_unavailable'
    elif active and now-node['last_eval_us']>=1000000:
        complete=p['hazard']['coverage']=='complete';gain=2 if complete else 1
        reason='observed_no_hazard' if complete else 'basis_unrenewed_under_partial_observation'
        before=node['H'];node.update(H=min(node['threshold'],before+gain),last_eval_us=now)
        node['events']=(node['events']+[dict(source=p['observation_id'],F=1,F_prime=0,E=1,gain=gain,
            H_before=before,H_after=node['H'],reason=reason,coverage=p['hazard']['coverage'],safety_proven=False)])[-32:]
    elif active:reason='review_interval'
    node['reason']=reason
    node['eligible']=bool(s['override'] and linked and not features and node['H']>=node['threshold'])
    if mode=='enabled' and node['eligible']:
        s.update(mode='normal',override=False,action=['wait',0],reason='provisional_mode_release',pending_step=False,clear_yaw=0,far_count=0)
        node['applied']=True
    s['mode_model']=node
    return s
