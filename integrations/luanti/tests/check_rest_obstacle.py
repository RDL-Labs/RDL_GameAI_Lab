"""Audit measured contact, retrieved evidence and the non-intervention boundary."""
from runtime.rest_reactivation import appearance_key
from .check_rest_reactivation import check as check_reactivation


def slot(a,n):
    return next(k for k,p in a['observations'].items() if p['sample_seq']==n)


def check(data):
    check_reactivation(data)  # Complete wire replay, sensor/body/stock/rest audits.
    w=data['world'];probe=w['obstacle_probe'];mode=probe['mode']
    assert mode in ('persistent','removed')
    assert [(e['kind'],e['slot']) for e in probe['events']]==(
        [('insert',23)] if mode=='persistent' else [('insert',23),('remove',27)])
    a=data['runtime']['exploration']['agents']['npc_a']
    before,review=slot(a,23),slot(a,28)
    result=a['results']['op:'+before]
    assert a['commands'][before]['kind']=='move' and result['status']=='blocked'
    assert result['before_pose_ref']==result['after_pose_ref']==a['observations'][review]['pose_ref']
    assert result['before_revision']==result['after_revision']==a['observations'][review]['body_revision']
    for n in range(24,28):
        oid=slot(a,n)
        assert a['commands'][oid]['reason']=='finite_rest'
        assert a['results']['op:'+oid]['status']=='waited'
    d=a['decisions'][review];m=d['reactivation']
    assert d['rest']['transition']=='resumed'
    assert probe['review']['traversable']==(mode=='removed')
    assert all(n['name']==('air' if mode=='removed' else 'rdl_bridge:exploration_rock_gray')
               for n in probe['review']['nodes'])
    same_view=appearance_key(a['observations'][before])==appearance_key(a['observations'][review])
    applied=changed=False;eligible=False;penalty=0.;reason=None
    if a['reactivation_mode']=='enabled':
        assert m['phase']=='resume_review'
        record=next(r for r in m['evaluation']['records'] if r['operation_id']==result['operation_id'])
        eligible=record['applicable'];penalty=m['evaluation']['forward_penalty']
        assert eligible==same_view
        assert penalty==(.5 if same_view else 0.)
        if not same_view:assert 'observed_context_changed' in record['reasons']
        projection=m['projection'];applied=projection['applied'];changed=projection['changed'];reason=projection['reason']
    else:
        assert m['phase']=='external_observation' and m['bundle'] is None
    # Report the measured outcome, without requiring a favorable action change.
    return dict(obstacle=mode,reactivation=a['reactivation_mode'],blocked=True,
        review_action=d['action'],review_reason=d['reason'],record_applicable=eligible,
        potential_penalty=penalty,applied=applied,changed=changed,projection_reason=reason,
        world_traversable=probe['review']['traversable'],same_coarse_view=same_view)


def compare(runs):
    assert len(runs)==4
    comparisons=[]
    for i in (0,2):
        left,right=[r['data']['runtime']['exploration']['agents'] for r in runs[i:i+2]]
        def actions(a):
            return [(c['kind'],c['amount'],c['reason']) for c in a['commands'].values()]
        equal={aid:actions(left[aid])==actions(right[aid]) for aid in left}
        comparisons.append(dict(obstacle=runs[i]['obstacle_summary']['obstacle'],actions_equal=equal))
    return comparisons
