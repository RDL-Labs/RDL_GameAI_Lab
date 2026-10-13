# Continuous local method H, adapted from continuous_selection safety family.
threat_band(features)=isempty(features) ? 3 : minimum(h["distance"]<=4 ? 0 : h["distance"]<=8 ? 1 : 2 for h in features)
# Observed clearance is limited evidence, not a World-wide safety assertion.
# Matches moving_hazard_safety.review: signed scans accumulate only from
# accepted body results; alternating turns do not constitute a full survey.
function limited_clearance!(state,ob)
 fs=ob["features"];complete=ob["coverage"]=="complete"
 state["far_count"]=complete && !isempty(fs) && threat_band(fs)==2 ? get(state,"far_count",0)+1 : 0
 result=get(state,"body_result",nothing)
 linked=get(state,"accepted",false) && result!==nothing
 if complete && isempty(fs) && linked && result.action=="scan" && result.status=="performed" && abs(abs(result.yaw)-90)<.01
    state["clear_yaw"]=get(state,"clear_yaw",0.)+result.yaw
 elseif !isempty(fs) || !complete || !linked || result.action in ("walk","run","scan")
    state["clear_yaw"]=0.
 end
 if state["far_count"]>=2 || abs(get(state,"clear_yaw",0.))>=360
    state["active"]=false;state["releases"]+=1
    state["limited_releases"]=get(state,"limited_releases",0)+1
    state["release_reason"]="limited_clearance"
    state["clear_yaw"]=0.;state["far_count"]=0
    return true
 end
 false
end
function safety_methods!(state,loop,ob,movement,source;running=false)
 fs=ob["features"];band=threat_band(fs)
 if loop.trial!==nothing
    prior=state["trial_band"]
    comparable=get(state,"accepted",false)
    value=comparable ? ((!isempty(fs) && band>prior) || (isempty(fs) && ob["coverage"]=="complete")) : nothing
    resolve_method!(loop,loop.trial.source,value,value)
 end
 # Existing one-second basis H is separate from each method's clearance question.
 # Far-only evidence does not start a fresh warning mode.
 if !state["active"] && band>=2
    return nothing
 end
 if state["active"]
    limited_clearance!(state,ob) && return nothing
 else
    state["clear_yaw"]=0.;state["far_count"]=0
 end
 if !isempty(fs)
    !state["active"] && (state["entries"]+=1)
    state["active"]=true;state["H"]=0
 else
    get(state,"accepted",false) && (state["H"]=min(8,state["H"]+(ob["coverage"]=="complete" ? 2 : 1)))
    if state["H"]>=8
        state["active"]=false;state["releases"]+=1;state["release_reason"]="provisional_mode_release";return nothing
    end
 end
 candidates=Any[D("method"=>"wait","action"=>"rest","priority"=>isempty(fs) ? 1. : 2.,"question"=>"clearance_evidence"),
    D("method"=>"survey_left","action"=>"scan","scan_angle"=>-90,"priority"=>1.5,"question"=>"clearance_evidence"),
    D("method"=>"survey_right","action"=>"scan","scan_angle"=>90,"priority"=>1.5,"question"=>"clearance_evidence")]
 rows=copy(movement["energy"]["rows"])
 running && append!(rows,movement["run_rows"])
 for row in rows
    row["cost"]===nothing && continue
    i=parse(Int,row["ref"]);angle=deg2rad(ANGLES[i+1])
    i==2 && any(h->h["distance"]<=4 && abs(rad2deg(atan(h["right"],h["forward"])))<30,fs) && continue
    # Worst observed directional pressure, never sum opposing threats to zero.
    pressure=isempty(fs) ? 0. : maximum(cos(angle-atan(h["right"],h["forward"])) for h in fs)
    action=get(row,"action","walk")
    effort=get(row,"resistance",1.5)*(1+.1*get(row,"load",0))
    score=2-1.5*pressure-.05*effort*(action=="run" ? 5 : 1)
    push!(candidates,D("method"=>action*"_$(ANGLES[i+1])","action"=>action,"direction"=>i,"priority"=>score,"question"=>"clearance_evidence"))
 end
 plan=choose_method!(loop,candidates,source);plan["safety"]=true
 state["trial_band"]=band;state["accepted"]=false;state["overrides"]+=1
 plan
end
