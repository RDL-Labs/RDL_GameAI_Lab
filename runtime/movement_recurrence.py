"""Finite acquired-history recurrence; no World lookup or action authority."""
from .lw_time import DAY_US
from math import cos, sin, radians, sqrt
from .learned_exploration import observation_key
from .resource_exploration import PERIOD_US

WINDOW_OPERATIONS = 8
WINDOW_US = 2250000
RETURN_DISTANCE = .25
RETURN_YAW = 5.
SCHEMA = "l15a-movement-history-diagnostic-v1"


def wrap(value):
    return (value+180)%360-180


def view_key(p):
    key=observation_key(p)
    s=p["movement_surface"]
    if (key is None or any(s[k]["coverage"]!="complete" or s[k]["output_limited"] for k in ("ground","obstacles"))
            or any(r["status"]=="unavailable" for r in s["ground"]["samples"])):
        return None
    # Existing coarse visual key, plus rounded current Food appearance/range.
    # References, exact World identity and absolute coordinates are not keys.
    key["food_appearance_range"]=sorted((x["appearance"],round(x["distance"])) for x in p["food"]["visible"])
    return key


def diagnose_window(records, *, purpose_scoped=True, period_us=PERIOD_US):
    """At most nine acquired views, linked by eight already received results."""
    if type(period_us) is not int or period_us not in (16_000_000,32_000_000,64_000_000,DAY_US):
        raise ValueError("history_period")
    if not 1<=len(records)<=WINDOW_OPERATIONS+1:
        raise ValueError("history_budget")
    views=[r["observation"] for r in records]
    end=views[-1]
    if len({(p["run_id"],p["agent_id"],p["world_epoch"],p["clock_id"]) for p in views})!=1:
        raise ValueError("history_binding")
    if len({p["observation_id"] for p in views})!=len(views):
        raise ValueError("duplicate_observation")
    out=dict(source_id=end["observation_id"],capture_us=end["capture_us"],
        sources=[p["observation_id"] for p in views],operations=[],
        status="insufficient_history",reasons=[],local_motion=None,same_coarse_view=None,
        purpose_gate="unresolved",repetition_eligible=False)
    if len(records)<3:
        return out
    reasons=[]
    if end["capture_us"]-views[0]["capture_us"]>WINDOW_US:reasons.append("history_expired")
    if views[0]["capture_us"]//period_us!=end["capture_us"]//period_us:reasons.append("period_boundary")
    keys=[view_key(p) for p in views]
    if any(k is None for k in keys):reasons.append("acquisition_incomplete")
    results=[]
    for record,later in zip(records,views[1:]):
        p,c,r=record["observation"],record["command"],record["result"]
        if later["sample_seq"]!=p["sample_seq"]+1 or later["capture_us"]<=p["capture_us"]:
            reasons.append("observation_gap")
        if r is None:
            reasons.append("result_unavailable_at_decision");continue
        out["operations"].append(r["operation_id"])
        identity=all(r[k]==p[k] for k in ("run_id","agent_id","world_epoch"))
        bound=(c is not None and c["source_id"]==p["observation_id"] and c["operation_id"]==r["operation_id"]
            and r["source_id"]==p["observation_id"] and identity
            and r["before_pose_ref"]==p["pose_ref"] and r["before_revision"]==p["body_revision"]
            and r["after_pose_ref"]==later["pose_ref"] and r["after_revision"]==later["body_revision"]
            and p["capture_us"]<=r["executed_us"]<later["capture_us"])
        if not bound:reasons.append("body_chain_unavailable")
        if r["status"] in ("expired","stale","stopped"):reasons.append("unexecuted_operation")
        results.append(r)
    if reasons:
        out.update(status="unknown",reasons=sorted(set(reasons)))
        return out
    x=z=up=yaw=path=0.
    reversals=0;last_turn=None
    for r in results:
        theta=radians(yaw)
        x+=r["forward"]*sin(theta)+r["right"]*cos(theta)
        z+=r["forward"]*cos(theta)-r["right"]*sin(theta)
        up+=r["up"]
        path+=sqrt(r["forward"]**2+r["right"]**2+r["up"]**2)
        yaw=wrap(yaw+r["yaw"])
        if r["status"]=="turned":
            reversals+=int(last_turn is not None and last_turn*r["yaw"]<0)
            last_turn=r["yaw"]
        else:last_turn=None
    net=sqrt(x*x+z*z+up*up)
    same=keys[0]==keys[-1]
    returned=net<=RETURN_DISTANCE and abs(yaw)<=RETURN_YAW
    acquired=sum(r["acquired"] for r in results)
    if acquired and purpose_scoped:status="acquisition_progress"
    elif returned and same and path>=2:status="movement_return_candidate"
    elif returned and same and reversals and path<.001:status="stationary_reversal_candidate"
    elif path<.001:status="stationary_other"
    else:status="translated_or_view_changed"
    out.update(status=status,same_coarse_view=same,local_motion=dict(right=x,forward=z,up=up,
        net_distance=net,path_distance=path,yaw=yaw,consecutive_reversals=reversals,acquisitions=acquired))
    if not purpose_scoped:
        # No normal/abnormal, purpose, reward or planned-survey admission gate.
        out["purpose_gate"]="not_used"
        out["repetition_eligible"]=status in ("stationary_reversal_candidate","movement_return_candidate")
        return out
    decisions=[r.get("decision") for r in records]
    reasons=[r["command"]["reason"] for r in records[:-1]]
    approaches=[d.get("approach") if d else None for d in decisions]
    if acquired:gate="acquisition_progress"
    elif "neighborhood_survey" in reasons:gate="planned_survey"
    elif (not all(x.startswith("observed_material_") for x in reasons)
          or not all(approaches) or len({a["ref"] for a in approaches if a})!=1):
        gate="purpose_not_stable_food_approach"
    else:
        target=approaches[0]["ref"]
        endpoints=[[x for x in p["food"]["visible"] if x["ref"]==target] for p in (views[0],end)]
        if any(len(x)!=1 for x in endpoints):gate="target_range_unavailable"
        elif endpoints[0][0]["distance"]-endpoints[1][0]["distance"]>.25:gate="observed_range_progress"
        else:gate="stable_food_approach"
    out["purpose_gate"]=gate
    out["repetition_eligible"]=gate=="stable_food_approach" and status in (
        "stationary_reversal_candidate","movement_return_candidate")
    return out

