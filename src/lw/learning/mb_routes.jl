# A selected path is one attempt, shared by chunks, sleep and waking search.
mb_route_state()=D("active"=>nothing,"stats"=>D(),"events"=>Any[],"started"=>0,"outcomes"=>D(),"uncertainty"=>D(),"controls"=>D(),"decisions"=>Any[],"local_repairs"=>0,"local_rejoins"=>0,"repair_records"=>Any[],"forecast"=>D("evaluated"=>0,"within_estimate"=>0,"H_requested"=>0,"records"=>Any[]))
function mb_route_finish!(s,outcome,now;reward=0.)
    r=s["routes"];a=r["active"];a===nothing && return
    st=get(r["stats"],a["id"],nothing)
    if st!==nothing
        st[outcome]=get(st,outcome,0)+1;st["reward"]+=reward
    end
    r["outcomes"][outcome]=get(r["outcomes"],outcome,0)+1
    push!(r["events"],D("id"=>a["id"],"kind"=>a["kind"],"goal"=>a["goal"],"started_us"=>a["started_us"],"ended_us"=>now,
        "steps"=>a["cursor"]-1,"length"=>length(a["path"]),"verified_steps"=>a["verified"],"outcome"=>outcome,"reward"=>reward,"H"=>get(a,"H",nothing),"reason"=>get(a,"reason",outcome),"estimate"=>get(a,"estimate",nothing),"effort"=>get(a,"effort",nothing),"local_repairs"=>get(a,"repairs",0)))
    length(r["events"])>64 && popfirst!(r["events"])
    r["active"]=nothing
end
function mb_route_attach!(p,s,path,goal,kind;chunk=nothing,sleep=nothing)
    id=goal*":"*bytes2hex(sha256(join(path,"|")))[1:16]
    merge!(p,D("mb_path"=>copy(path),"mb_route"=>id,"mb_route_kind"=>kind,"mb_route_index"=>1,"mb_route_goal"=>goal))
    st=get(s["routes"]["stats"],id,nothing)
    if st!==nothing
        failures=sum(get(st,k,0) for k in ("unresolved","blocked","mismatch","lost","abandoned"))
        p["priority"]+=log1p(get(st,"success",0))-log1p(failures)
    end
    p
end
function mb_route_record!(s,p,status,now;energy=0.)
    r=s["routes"];a=r["active"];id=get(p,"mb_route",nothing)
    if a!==nothing
        a["H"]=get(p,"mb_control_H",get(a,"H",0))
        control=get(p,"mb_control",nothing)
        if control!==nothing
            r["controls"][control]=get(r["controls"],control,0)+1
        end
        if get(p,"mb_abandon",nothing)==a["id"]
            a["reason"]="H_abandon";mb_route_finish!(s,"abandoned",now);return
        end
        same_goal=get(p,"purpose_family",a["goal"])==a["goal"]
        if id===nothing && same_goal && get(p,"mb_control",nothing)!="change" &&
            (get(p,"mb_local_repair",nothing)==a["id"] || p["action"] in ("walk","run","scan","climb","pickup","recover","deposit")) && !haskey(p,"mb_recheck")
            mb_route_repair_record!(s,p,status,energy,now);return
        end
        if get(p,"mb_recheck",nothing)==a["id"]
            a["last_us"]=now;mb_route_effort!(a,energy);return
        end
    end
    if id===nothing
        # Endpoint acquisition may resolve the parent on the following tick.
        if a!==nothing && a["cursor"]>length(a["path"]) && status in ("picked_up","recovered")
            a["last_us"]=now;mb_route_effort!(a,energy);return
        end
        if a!==nothing
            if get(p,"purpose_family",a["goal"])==a["goal"] && p["action"] in ("rest","eat","request") && !haskey(p,"mb_control")
                a["reason"]="body_or_schedule_pause";return
            end
            a["reason"]=get(p,"mb_control",nothing)=="change" ? "H_choice" : "purpose_or_safety_override"
            mb_route_finish!(s,a["cursor"]>length(a["path"]) ? "unresolved" : "interrupted",now)
        end
        return
    end
    if a===nothing || a["id"]!=id
        if a!==nothing
            a["reason"]="H_route_change";mb_route_finish!(s,"interrupted",now)
        end
        path=p["mb_path"]
        get(p,"mb_route_index",1)==1 || return
        if !haskey(r["stats"],id) && length(r["stats"])<256
            r["stats"][id]=D("starts"=>0,"reward"=>0.)
        end
        haskey(r["stats"],id) && (r["stats"][id]["starts"]+=1)
        a=D("id"=>id,"path"=>copy(path),"goal"=>p["mb_route_goal"],"kind"=>p["mb_route_kind"],
            "chunk"=>get(p,"mb_chunk",nothing),"sleep"=>get(p,"mb_sleep",nothing),"cursor"=>1,"verified"=>0,
            "started_us"=>now,"last_us"=>now,"priority"=>p["priority"],"uncertain"=>false,"pending_edge"=>nothing,"H"=>get(p,"mb_control_H",0))
        a["estimate"]=mb_route_estimate(s,path,a["goal"])
        a["effort"]=D("actions"=>0,"energy"=>0.,"contradictions"=>0,"charged"=>0,"last_evaluated"=>nothing)
        r["active"]=a;r["started"]+=1
    end
    a["last_us"]=now;mb_route_effort!(a,energy)
    status=="performed" || mb_route_uncertain!(s,"execution_blocked")
end
function mb_route_uncertain!(s,reason;pending=nothing)
    a=s["routes"]["active"];a===nothing && return
    a["uncertain"]=true;a["reason"]=reason
    pending!==nothing && (a["pending_edge"]=pending)
    r=s["routes"]["uncertainty"];r[reason]=get(r,reason,0)+1
end
function mb_route_observe!(s,receipt,frame,now)
    a=s["routes"]["active"];a===nothing && return
    receipt===nothing && return # Pauses do not erase the route.
    if get(receipt,"local_repair",nothing)==a["id"] && receipt["status"]=="performed" && now==receipt["now"]+1_000_000
        mb_route_rejoin!(s,frame,now);return
    end
    get(receipt,"route",nothing)==a["id"] || return
    i=a["cursor"]
    (i<=length(a["path"]) && receipt["predicted"]==a["path"][i]) || return
    outcome=mb_prediction_outcome(s,receipt,frame,now)
    if outcome=="execution_failure"
        mb_route_uncertain!(s,"execution_blocked");return
    end
    if outcome=="mismatch"
        a["effort"]["contradictions"]+=1
        mb_route_uncertain!(s,"recognition_mismatch";pending=receipt["predicted"]);return
    end
    if frame===nothing || now!=receipt["now"]+1_000_000
        mb_route_uncertain!(s,frame===nothing ? "no_observation" : "observation_gap";pending=receipt["predicted"]);return
    end
    a["cursor"]+=1;a["verified"]+=Int(outcome=="match")
    a["uncertain"]=false;a["pending_edge"]=nothing
end
function mb_route_goal!(s,goal,source,resolved,H_before,H_after,now)
    a=s["routes"]["active"];a===nothing && return
    a["goal"]==goal && source=="op:$(a["last_us"]):$(s["actor"])" || return
    if resolved===true && H_after==0
        mb_route_finish!(s,"success",now;reward=Float64(max(0,H_before-H_after)))

    end
end
function mb_route_candidates!(s,move,goal,reserve,strain,now;H=0)
    a=s["routes"]["active"];a===nothing && return Any[]
    a["H"]=H
    if a["goal"]!=goal
        a["reason"]="parent_purpose_changed";mb_route_finish!(s,"interrupted",now);return Any[]
    end
    (reserve<=20 || strain>=.8) && return Any[]
    mb_route_rejoin!(s,s["current"],now)
    get(a,"repair_pending",false) && return Any[]
    mb_route_reacquire!(s,now)
    i=a["cursor"]
    if i>length(a["path"])
        mb_route_uncertain!(s,"endpoint_unresolved");return Any[]
    end
    all(k->haskey(s["edges"],k),a["path"]) || (mb_route_uncertain!(s,"missing_edge");return Any[])
    a["pending_edge"]!==nothing && return Any[]
    edge=a["path"][i];e=s["edges"][edge]
    matches=mb_correspondences(s,[e["from"]],now;scope="route")
    isempty(matches) && (mb_route_uncertain!(s,"no_correspondence");return Any[])
    match=first(matches);p=mb_first_action(e,(anchor=match["anchor"],),move)
    p===nothing && (mb_route_uncertain!(s,"infeasible_action");return Any[])
    a["uncertain"]=false
    merge!(p,D("method"=>"mb_route:"*a["id"],"priority"=>a["priority"],"question"=>"target_observed",
        "mb_edge"=>edge,"mb_expected"=>e["to"],"mb_depth"=>length(a["path"])-i+1,
        "mb_path"=>a["path"],"mb_route"=>a["id"],"mb_route_kind"=>a["kind"],"mb_route_index"=>i,"mb_route_goal"=>goal))
    a["chunk"]!==nothing && merge!(p,D("mb_chunk"=>a["chunk"],"mb_chunk_index"=>i))
    a["sleep"]!==nothing && (p["mb_sleep"]=a["sleep"])
    mb_attach_correspondence!(p,s,match)
    Any[p]
end

# Re-observe the expected endpoint of an executed step; never execute it twice blindly.
function mb_route_reacquire!(s,now)
    a=s["routes"]["active"];key=a["pending_edge"];key===nothing && return
    frame=s["current"];(frame===nothing || s["current_us"]!=now) && return
    edge=get(s["edges"],key,nothing);edge===nothing && return
    node=get(s["nodes"],edge["to"],nothing);node===nothing && return
    fit=mb_similarity(frame,node)
    (fit===nothing || fit.agreement<.65) && return
    a["cursor"]+=1;a["pending_edge"]=nothing;a["uncertain"]=false
    # Recovery after a gap is tentative, not a verified transition or purpose success.
    r=s["routes"]["uncertainty"];r["reacquired"]=get(r,"reacquired",0)+1
end
# Parent H gates whole-route alternatives. Group size must not multiply change votes.
function mb_route_control!(s,candidates,loop,goal,now)
    a=s["routes"]["active"];a===nothing && return candidates
    if a["goal"]!=goal
        a["reason"]="parent_purpose_changed";mb_route_finish!(s,"interrupted",now);return candidates
    end
    a["H"]=loop.H
    out=copy(candidates)
    push!(out,D("method"=>"mb_recheck:"*a["id"],"action"=>"scan","scan_angle"=>60.,"priority"=>a["priority"],
        "question"=>"target_observed","mb_recheck"=>a["id"]))
    push!(out,D("method"=>"mb_abandon:"*a["id"],"action"=>"scan","scan_angle"=>60.,"priority"=>a["priority"],
        "question"=>"target_observed","mb_abandon"=>a["id"]))
    group(p)=get(p,"mb_recheck",nothing)==a["id"] ? "recheck" :
        get(p,"mb_route",nothing)==a["id"] ? "continue" :
        haskey(p,"mb_route") || haskey(p,"mb_abandon") ? "change" : "repair"
    counts=D();for p in out;g=group(p);counts[g]=get(counts,g,0)+1;end
    h=max(1e-6,Float64(loop.H)/loop.threshold)
    # Overall change responds to this route's residual, not pressure inherited before it began.
    route_pressure=min(Float64(loop.H),Float64(a["effort"]["charged"]))/loop.threshold
    gates=D("continue"=>1.,"recheck"=>(a["uncertain"] ? 1.0+h : h),"repair"=>1.0+h,"change"=>max(1e-6,route_pressure))
    for p in out
        g=group(p);p["mb_control"]=g;p["mb_control_H"]=loop.H
        g=="repair" && (p["mb_local_repair"]=a["id"])
        p["observation_log_prior"]=get(p,"observation_log_prior",0.)+log(gates[g]/counts[g])
    end
    probs=method_distribution(loop,out);mass=D(g=>0. for g in keys(counts))
    for (p,prob) in zip(out,probs);mass[group(p)]+=prob;end
    r=s["routes"];push!(r["decisions"],D("us"=>now,"id"=>a["id"],"H"=>loop.H,"uncertain"=>a["uncertain"],"route_pressure"=>route_pressure,"mass"=>mass))
    length(r["decisions"])>64 && popfirst!(r["decisions"])
    out
end

# Freeze estimates before execution; later graph updates cannot move this attempt's goalposts.
function mb_route_estimate(s,path,goal)
    costs=[max(0.,s["edges"][k]["energy_sum"]/max(1,s["edges"][k]["samples"])) for k in path]
    terminal=goal=="food" ? 1 : 0 # One explicit acquisition operation after reaching food.
    D("steps"=>length(path),"actions"=>length(path)+terminal,"active_seconds"=>length(path)+terminal,
      "energy_prefix"=>cumsum(costs),"energy"=>sum(costs),"action_slack"=>1,
      "energy_quantum"=>max(.01,isempty(costs) ? 0. : sum(costs)/length(costs)))
end
function mb_route_effort!(a,energy)
    e=a["effort"];e["actions"]+=1;e["energy"]+=max(0.,energy)
end
function mb_route_H_increment!(s,goal,source,resolved,now)
    a=s["routes"]["active"]
    (a===nothing || a["goal"]!=goal || source!="op:$(a["last_us"]):$(s["actor"])" || now!=a["last_us"]+1_000_000) && return nothing
    e=a["effort"];estimate=a["estimate"]
    e["last_evaluated"]==source && return e["last_increment"]
    e["last_evaluated"]=source
    progress=min(a["cursor"]-1,estimate["steps"])
    # The current attempted step and a terminal acquisition have their own allowance.
    allowed=min(estimate["actions"],progress+1)+estimate["action_slack"]
    lag=max(0,e["actions"]-allowed)
    prefix=min(estimate["steps"],progress+1)
    budget=prefix==0 ? 0. : estimate["energy_prefix"][prefix]
    excess=max(0,floor(Int,(e["energy"]-budget)/estimate["energy_quantum"])-1)
    debt=max(lag,excess,e["contradictions"])
    increment=resolved===true ? 0 : max(0,debt-e["charged"])
    e["charged"]=max(e["charged"],debt);e["last_increment"]=increment
    f=s["routes"]["forecast"];f["evaluated"]+=1;f["within_estimate"]+=Int(debt==0 && resolved!==true);f["H_requested"]+=increment
    push!(f["records"],D("source"=>source,"id"=>a["id"],"progress"=>progress,"actions"=>e["actions"],
        "lag"=>lag,"energy_excess"=>excess,"contradictions"=>e["contradictions"],"increment"=>increment,"resolved"=>resolved))
    length(f["records"])>64 && popfirst!(f["records"])
    increment
end
