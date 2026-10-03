"""Initial, bounded safety policy. No learned threat ontology or canonical H."""
from copy import deepcopy

RULE='finite-moving-hazard-safety-v1'
MULTI_RULE='finite-two-hazard-safety-v1'
KEYS=('run_id','agent_id','observation_id','capture_us','pose_ref','body_revision')


def validate(p):
    h=p['hazard']
    if h.get('rule') not in (RULE,MULTI_RULE) or h.get('source')!={k:p[k] for k in KEYS}:raise ValueError('hazard_binding')
    if h.get('coverage') not in ('complete','partial') or len(h.get('features',[]))>(2 if h['rule']==MULTI_RULE else 1):raise ValueError('hazard_coverage')
    for x in h['features']:
        if set(x)!= {'appearance','azimuth','range_band'} or x['appearance'] not in ('violet_hazard','violet_warning'):raise ValueError('hazard_feature')
        if x['range_band'] not in ('near','watch','far'):raise ValueError('hazard_range')
        a=x['azimuth']
        if len(a)!=2 or not -90<=a[0]<=a[1]<=90:raise ValueError('hazard_angle')


def review(p,old=None,result=None,*,continuous=False):
    validate(p);h=p['hazard'];now=p['capture_us'];features=h['features']
    visible=min(features,key=lambda x:({'near':0,'watch':1,'far':2}[x['range_band']],tuple(x['azimuth']),x['appearance'])) if features else None
    s=deepcopy(old) if old else dict(mode='normal',generation=0,operations=0,clear_yaw=0,far_count=0)
    s.update(rule=RULE,source=p['observation_id'],override=False,action=['wait',0],reason='normal')
    linked=bool(result and result['after_pose_ref']==p['pose_ref'] and result['after_revision']==p['body_revision'] and result['executed_us']<now and result['status'] not in ('stale','expired'))
    pending=s.pop('pending_step',False)
    if s['mode']=='normal':
        if not visible or visible['range_band']=='far':return s
        s.update(mode='safety_active',generation=s['generation']+1,started_us=now,operations=0,clear_yaw=0,far_count=0)
    s['override']=True
    complete=h['coverage']=='complete'
    if complete and visible and visible['range_band']=='far':s['far_count']+=1
    else:s['far_count']=0
    if complete and not visible and linked and old and (old.get('reason')=='safety_scan' or old.get('clearance_scan')) and result['status']=='turned' and abs(abs(result['yaw'])-90)<.01:
        s['clear_yaw']+=result['yaw']
    elif visible or not complete or not linked or result['status'] in ('moved','turned'):s['clear_yaw']=0
    if s['far_count']>=2 or abs(s['clear_yaw'])>=360:
        s.update(mode='normal',override=False,reason='limited_clearance',clear_yaw=0,far_count=0)
        return s
    if not continuous and (now-s['started_us']>=16000000 or s['operations']>=32):
        s.update(mode='safety_unresolved',reason='safety_budget');return s
    if not linked:
        s.update(mode='safety_uncertain',reason='safety_body_unlinked');return s
    if not complete and not visible:
        s.update(mode='safety_uncertain',reason='safety_scan',action=['turn',90],operations=s['operations']+1)
        return s
    ground=p['movement_surface']['ground']
    safe={x['direction_deg'] for x in ground['samples'] if x['status']=='sampled' and x['height_delta'] is not None and abs(x['height_delta'])<=.5} if ground['coverage']=='complete' and not ground['output_limited'] else set()
    if not continuous and s['operations']>=16:
        s.update(mode='safety_review',action=['turn',90],reason='safety_scan')
    elif pending and old.get('reason')=='safety_turn' and result['status']=='turned' and abs(result['yaw']-old['action'][1])<.01 and 0 in safe:
        s.update(mode='safety_active',action=['move',1],reason='safety_step')
    elif visible and visible['range_band']=='near':
        angle=sum(visible['azimuth'])/2;away=-90 if angle>=0 else 90
        if away in safe:s.update(mode='safety_active',action=['turn',away],reason='safety_turn',pending_step=True)
        else:s.update(mode='safety_active',reason='safety_no_safe_step')
    elif visible:
        s.update(mode='safety_review',reason='safety_wait_crossing')
    else:
        s.update(mode='safety_uncertain',action=['turn',90],reason='safety_scan')
    if s['action'][0]!='wait':s['operations']+=1
    return s
