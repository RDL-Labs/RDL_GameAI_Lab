"""Mode transitions, evidence bounds and complete World replay."""
from collections import Counter
from runtime.rest_reactivation import ReactivatingExploration
from .check_movement_rest import check as check_rest


def check(data):
    summary=check_rest(data,ReactivatingExploration)
    for aid,a in data["runtime"]["exploration"]["agents"].items():
        phases=Counter();models=Counter();retrievals=reviews=applied=changes=0;records=0
        for oid,d in a["decisions"].items():
            m=d["reactivation"];phases[m["phase"]]+=1
            assert m["body_resting"]==(d["rest"]["state"]["active"] is not None)
            assert m["observation_source"]==oid
            if m["phase"]=="internal_reactivation":
                assert d["reason"]=="finite_rest" and d["action"]==["wait",0]
            if m["bundle"]:
                assert len(m["bundle"]["records"])<=3 and m["bundle"]["scanned"]<=16
                assert m["bundle"]["binding"]["agent_id"]==aid
                if m["trigger"]=="started":
                    retrievals+=1;records+=len(m["bundle"]["records"])
                for r in m["bundle"]["records"]:
                    assert r["operation_id"] in a["results"] and r["source"] in a["observations"]
            if m["evaluation"]:models[m["evaluation"]["model"]["status"]]+=1
            if m["projection"]:
                reviews+=1;applied+=m["projection"]["applied"];changes+=m["projection"]["changed"]
                assert m["phase"]=="resume_review"
                if m["projection"]["changed"]:assert d["reason"]=="rest_reactivation"
        if a["reactivation_mode"]=="disabled":assert retrievals==reviews==changes==0
        summary["agents"][aid]["reactivation"]=dict(mode=a["reactivation_mode"],phases=dict(phases),
            retrievals=retrievals,retrieved_records=records,reviews=reviews,applied=applied,changes=changes,model_results=dict(models))
    return summary
