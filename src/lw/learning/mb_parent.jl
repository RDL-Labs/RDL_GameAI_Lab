# Sensitivity is independent of rho; actor-specific fixed gains, not learned yet.
function mb_sensitivity(values=D())
    out=D(k=>1. for k in ("delay","stagnation","energy","contradiction"))
    for (k,v) in pairs(values)
        check(haskey(out,k) && v isa Real && !(v isa Bool) && isfinite(v) && 0<v<=16,"mb_sensitivity")
        out[k]=Float64(v)
    end
    out
end
mb_response(s,key,residual)=s["sensitivity"][key]*max(0.,Float64(residual))

# Parent MB estimates: bounded learned episodes, bootstrapped only when experience is absent.
mb_parent_state()=D("models"=>D(),"active"=>D(),"records"=>Any[],"evaluated"=>0,"within_estimate"=>0,"H_requested"=>0,"successes"=>0,"last_goal"=>nothing)
# A parent retains its purpose, but changes the question and frozen forecast.
# Save the parent's pressure; the local question returns only a Boolean outcome.
function mb_parent_arrival_sync!(s,loop,goal,now)
    arrival=s["goal_arrival"][goal];parent=s["parent_mb"]
    modes=get!(parent,"modes",D())
    m=get!(modes,goal,D("mode"=>"search","entry"=>0,"completed"=>0,"saved_H"=>0.,"suspended"=>nothing,"events"=>Any[]))
    completed=get(arrival,"completed",0)
    finished=completed>m["completed"]
    m["completed"]=completed
    if m["mode"]=="approach" && (finished || arrival["mode"]!="approach" || arrival["entries"]!=m["entry"])
        active=pop!(parent["active"],goal,nothing)
        active!==nothing && mb_parent_learn!(s,goal,active,false,"arrival_mode_end")
        before=loop.H
        loop.H=goal_result_H(m["saved_H"],finished)
        if !finished
            m["suspended"]!==nothing && (parent["active"][goal]=m["suspended"])
        elseif m["suspended"]!==nothing
            # Finding a location is not evidence of completing the old full journey.
            mb_parent_learn!(s,goal,m["suspended"],false,"location_confirmed")
        end
        push!(m["events"],D("us"=>now,"kind"=>finished ? "arrival_confirmed" : "search_restored",
            "success"=>finished,"local_H"=>before,"saved_parent_H"=>m["saved_H"],"H_after"=>loop.H))
        m["mode"]="search";m["suspended"]=nothing;m["saved_H"]=0.
    end
    if m["mode"]=="search" && arrival["mode"]=="approach"
        active=pop!(parent["active"],goal,nothing)
        before=loop.H
        m["saved_H"]=before;loop.H=0.
        m["mode"]="approach";m["entry"]=arrival["entries"];m["suspended"]=active
        push!(m["events"],D("us"=>now,"kind"=>"arrival_question","saved_parent_H"=>before,"H_after"=>loop.H))
    end
    while length(m["events"])>64;popfirst!(m["events"]);end
end
function mb_parent_model!(s,goal,mode)
    key=goal*":"*mode
    get!(s["parent_mb"]["models"],key) do
        D("id"=>key,"samples"=>0,"actions_mean"=>mode=="search" ? 128. : 16.,"actions_m2"=>0.,
          "energy_rate"=>.01,"completed"=>0,"observations"=>Any[],"censored_updates"=>0,"forecast"=>nothing)
    end
end
function mb_parent_estimate!(s,p,goal,target)
    arrival=get(get(s,"goal_arrival",D()),goal,nothing)
    if arrival!==nothing && arrival["mode"]=="approach"
        target=D("distance"=>hypot(arrival["estimate"]["forward"],arrival["estimate"]["right"]))
    end
    mode=haskey(p,"mb_path") ? "route" : target===nothing ? "search" : "approach"
    arrival!==nothing && arrival["mode"]=="approach" && (mode="approach")
    model=mb_parent_model!(s,goal,mode);n=model["samples"]
    # Child route and current observed distance are evidence, not hidden world coordinates.
    center=mode=="route" ? Float64(length(p["mb_path"])+(goal=="food" ? 1 : 0)) :
        mode=="approach" ? max(1.,ceil(max(0.,target["distance"]-1.)/.5)+1.) : 128.
    baseline=center
    survival=mb_parent_survival!(model,mode)
    prior_weight=1.;tail_mass=0.;evidence_count=0
    if survival===nothing
        spread=max(mode=="search" ? 128. : 4.,center)
        upper=max(2,ceil(Int,center+spread))
    else
        scale=mode=="search" ? 1. : baseline
        center=max(1.,survival["restricted_mean"]*scale)
        prior_weight=survival["prior_weight"];tail_mass=survival["tail_mass"];evidence_count=survival["evidence_count"]
        q=survival["q80"]
        # If the 80% quantile is unidentified, keep the unobserved tail explicit and plan beyond the bound.
        horizon=q===nothing ? survival["last_observed"]*scale+max(4.,.25survival["last_observed"]*scale) : q*scale
        upper=max(2,ceil(Int,max(center,horizon)))
    end
    rate=max(.0001,model["energy_rate"])
    D("model"=>model["id"],"mode"=>mode,"source"=>evidence_count==0 ? "bootstrap" : "experience",
      "samples"=>n,"evidence_count"=>evidence_count,"prior_weight"=>prior_weight,"tail_mass"=>tail_mass,
      "mean_is_lower_bound"=>tail_mass>0,"baseline_actions"=>baseline,
      "expected_result"=>goal=="food" ? "acquired_food" : "confirmed_home",
      "expected_actions"=>center,"upper_actions"=>upper,"active_seconds"=>upper,
      "expected_energy"=>center*rate,
      "energy"=>upper*rate,"energy_quantum"=>max(.01,upper*rate),
      "progress_window"=>max(8,cld(upper,4)),"expected_new_scenes"=>mode=="search" ? 1 : 0)
end

# Experimental achievement value plus bounded, signed prediction advantage.
# Evaluate the frozen episode estimate, never the model updated by this outcome.
function mb_completion_reward(e,actions,energy)
    expected_energy=get(e,"expected_energy",e["energy"]*e["expected_actions"]/e["upper_actions"])
    time_scale=max(1.,e["expected_actions"],e["upper_actions"]-e["expected_actions"])
    energy_scale=max(.01,expected_energy,e["energy"]-expected_energy)
    time_delta=(e["expected_actions"]-actions)/time_scale
    energy_delta=(expected_energy-energy)/energy_scale
    response(x)=tanh(sign(x)*max(0.,abs(x)-.1))
    advantage=.5*(response(time_delta)+response(energy_delta))
    D("value"=>1.0 + .75advantage,"achievement"=>1.,"advantage"=>advantage,
      "time_delta"=>time_delta,"energy_delta"=>energy_delta,
      "time_scale"=>time_scale,"energy_scale"=>energy_scale,"tolerance"=>.1)
end

function mb_parent_reward(s,goal,source,now)
    records=s["parent_mb"]["records"]
    isempty(records) && return nothing
    r=last(records)
    get(r,"evaluated_us",nothing)==now && r["source"]==source && r["goal"]==goal && r["resolved"]===true || return nothing
    r["completion_reward"]["value"]
end
function mb_parent_candidates!(s,candidates,goal,target)
    for p in candidates
        estimate=mb_parent_estimate!(s,p,goal,target)
        p["mb_parent_estimate"]=estimate
        # Only a small estimated effort term; learned rewards and H still govern selection.
        p["priority"]-=.1log1p(estimate["upper_actions"])
    end
    candidates
end
function mb_parent_begin!(s,p,goal,target,now)
    p["mb_parent_goal"]=goal
    estimate=get(p,"mb_parent_estimate",nothing)
    estimate===nothing && (estimate=mb_parent_estimate!(s,p,goal,target))
    state=s["parent_mb"]
    previous=state["last_goal"]
    if previous!==nothing && previous!=goal && haskey(state["active"],previous)
        mb_parent_learn!(s,previous,state["active"][previous],false,"purpose_switch")
    end
    state["last_goal"]=goal
    if !haskey(state["active"],goal)
        frame=s["current"]
        state["active"][goal]=D("estimate"=>deepcopy(estimate),"started_us"=>now,"last_us"=>now,
            "actions"=>0,"energy"=>0.,"scenes"=>frame===nothing ? String[] : [frame.key],
            "learned_actions"=>0,"paused"=>false,"child_debt"=>0,"charged"=>0,"last_source"=>nothing,"last_increment"=>0)
    end
end
function mb_parent_record!(s,p,energy,now)
    goal=get(p,"mb_parent_goal",nothing)
    if goal===nothing
        previous=s["parent_mb"]["last_goal"]
        a=previous===nothing ? nothing : get(s["parent_mb"]["active"],previous,nothing)
        if a!==nothing && !a["paused"]
            mb_parent_learn!(s,previous,a,false,"pause");a["paused"]=true
        end
        return
    end
    a=get(s["parent_mb"]["active"],goal,nothing);a===nothing && return
    a["paused"]=false
    a["actions"]+=1;a["energy"]+=max(0.,energy);a["last_us"]=now
end
function mb_parent_H_increment!(s,goal,source,resolved,now;child_increment=0)
    state=s["parent_mb"];a=get(state["active"],goal,nothing)
    (a===nothing || source!="op:$(a["last_us"]):$(s["actor"])" || now!=a["last_us"]+1_000_000) && return nothing
    a["last_source"]==source && return a["last_increment"]
    a["last_source"]=source;e=a["estimate"];frame=s["current"]
    if frame!==nothing && !(frame.key in a["scenes"]) && length(a["scenes"])<64
        push!(a["scenes"],frame.key)
    end
    window=e["progress_window"]
    delay=mb_response(s,"delay",(a["actions"]-e["upper_actions"])/window)
    stagnation=e["expected_new_scenes"]>0 && length(a["scenes"])<2 ? mb_response(s,"stagnation",a["actions"]/window-1) : 0
    excess=mb_response(s,"energy",(a["energy"]-e["energy"])/e["energy_quantum"])
    a["child_debt"]+=max(0,child_increment)
    debt=max(delay,stagnation,excess,a["child_debt"])
    increment=resolved===true ? 0 : max(0,debt-a["charged"])
    a["charged"]=max(a["charged"],debt);a["last_increment"]=increment
    state["evaluated"]+=1;state["within_estimate"]+=Int(debt==0 && resolved!==true);state["H_requested"]+=increment
    record=D("source"=>source,"goal"=>goal,"evaluated_us"=>now,"estimate"=>copy(e),"actions"=>a["actions"],"energy"=>a["energy"],
        "sensitivity"=>copy(s["sensitivity"]),"scenes"=>length(a["scenes"]),"delay"=>delay,"stagnation"=>stagnation,"energy_excess"=>excess,
        "child_debt"=>a["child_debt"],"increment"=>increment,"resolved"=>resolved)
    record["completion_reward"]=resolved===true ? mb_completion_reward(e,a["actions"],a["energy"]) : nothing
    push!(state["records"],record);length(state["records"])>64 && popfirst!(state["records"])
    if resolved!==true && a["actions"]>=max(32,2a["learned_actions"])
        mb_parent_learn!(s,goal,a,false,"unfinished")
    end
    if resolved===true
        mb_parent_learn!(s,goal,a,true,"completed")
        model=state["models"][e["model"]];model["completed"]+=1
        # Learn only completed episodes; unresolved episodes are not fictitious arrival times.
        model["samples"]+=1;n=model["samples"];delta=a["actions"]-model["actions_mean"]
        model["actions_mean"]+=delta/n;model["actions_m2"]+=delta*(a["actions"]-model["actions_mean"])
        state["successes"]+=1;delete!(state["active"],goal)
    end
    increment
end
