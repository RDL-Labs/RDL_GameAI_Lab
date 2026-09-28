"""Exact World replay plus finite reassessment authority audits."""
from runtime.goal_reassessment import ReassessingExploration
from .check_rest_reactivation import check as base_check


def check(data):
    summary=base_check(data,ReassessingExploration)
    for aid,a in data['runtime']['exploration']['agents'].items():
        counts={};selected=0;triggered=0
        for oid,d in a['decisions'].items():
            m=d['goal_reassessment']
            if not m['triggered']:continue
            triggered+=1;counts[d['period']]=counts.get(d['period'],0)+1
            assert m['mode']=='enabled' and m['state']['used']
            assert m['baseline_reason']=='landmark_goal_budget' and d['rest']['transition']=='resumed'
            assert d['landmark']['selected_count']==8
            assert len(m['candidates'])<=13
            if m['status']=='selected':
                selected+=1;f=m['state']['selected']
                assert f in a['observations'][oid]['landmarks']['features']
                assert f['color']!=m['state']['held']['current_feature']['color']
                assert d['reason']=='goal_reassessment_selected'
        assert all(n<=1 for n in counts.values())
        summary['agents'][aid]['reassessment']=dict(triggered=triggered,selected=selected)
    return summary
