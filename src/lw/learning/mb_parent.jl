# Parent MB estimates: bounded learned episodes, bootstrapped only when experience is absent.
mb_parent_state()=D("models"=>D(),"active"=>D(),"records"=>Any[],"evaluated"=>0,"within_estimate"=>0,"H_requested"=>0,"successes"=>0)
function mb_parent_model!(s,goal,mode)
    key=goal*":"*mode
    get!(s["parent_mb"]["models"],key) do
        D("id"=>key,"samples"=>0,"actions_mean"=>mode=="search" ? 128. : 16.,"actions_m2"=>0.,
          "energy_rate"=>.01,"completed"=>0)
    end
end
function mb_parent_estimate!(s,p,goal,target)
    mode=haskey(p,"mb_path") ? "route" : target===nothing ? "search" : "approach"
    model=mb_parent_model!(s,goal,mode);n=model["samples"]
    # Child route and current observed distance are evidence, not hidden world coordinates.
    center=mode=="route" ? Float64(length(p["mb_path"])+(goal=="food" ? 1 : 0)) :
        mode=="approach" ? max(1.,ceil(max(0.,target["distance"]-1.)/.5)+1.) : model["actions_mean"]
    n>0 && mode=="search" && (center=model["actions_mean"])
    spread=n<2 ? max(mode=="search" ? 128. : 4.,center) : max(4.,sqrt(model["actions_m2"]/(n-1)))
    upper=clamp(ceil(Int,center+spread),2,4096)
    rate=max(.0001,model["energy_rate"])
    D("model"=>model["id"],"mode"=>mode,"source"=>n==0 ? "bootstrap" : "experience",
      "samples"=>n,"expected_result"=>goal=="food" ? "acquired_food" : "confirmed_home",
      "expected_actions"=>center,"upper_actions"=>upper,"active_seconds"=>upper,
      "energy"=>upper*rate,"energy_quantum"=>max(.01,upper*rate),
      "progress_window"=>max(8,cld(upper,4)),"expected_new_scenes"=>mode=="search" ? 1 : 0)
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
    if !haskey(state["active"],goal)
        frame=s["current"]
        state["active"][goal]=D("estimate"=>deepcopy(estimate),"started_us"=>now,"last_us"=>now,
            "actions"=>0,"energy"=>0.,"scenes"=>frame===nothing ? String[] : [frame.key],
            "child_debt"=>0,"charged"=>0,"last_source"=>nothing,"last_increment"=>0)
    end
end
function mb_parent_record!(s,p,energy,now)
    goal=get(p,"mb_parent_goal",nothing);goal===nothing && return
    a=get(s["parent_mb"]["active"],goal,nothing);a===nothing && return
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
    delay=max(0,cld(a["actions"]-e["upper_actions"],window))
    stagnation=e["expected_new_scenes"]>0 && length(a["scenes"])<2 ? max(0,fld(a["actions"],window)-1) : 0
    excess=max(0,floor(Int,(a["energy"]-e["energy"])/e["energy_quantum"]))
    a["child_debt"]+=max(0,child_increment)
    debt=max(delay,stagnation,excess,a["child_debt"])
    increment=resolved===true ? 0 : max(0,debt-a["charged"])
    a["charged"]=max(a["charged"],debt);a["last_increment"]=increment
    state["evaluated"]+=1;state["within_estimate"]+=Int(debt==0 && resolved!==true);state["H_requested"]+=increment
    record=D("source"=>source,"goal"=>goal,"estimate"=>copy(e),"actions"=>a["actions"],"energy"=>a["energy"],
        "scenes"=>length(a["scenes"]),"delay"=>delay,"stagnation"=>stagnation,"energy_excess"=>excess,
        "child_debt"=>a["child_debt"],"increment"=>increment,"resolved"=>resolved)
    push!(state["records"],record);length(state["records"])>64 && popfirst!(state["records"])
    if resolved===true
        model=state["models"][e["model"]];model["completed"]+=1
        # Learn only completed episodes; unresolved episodes are not fictitious arrival times.
        model["samples"]+=1;n=model["samples"];delta=a["actions"]-model["actions_mean"]
        model["actions_mean"]+=delta/n;model["actions_m2"]+=delta*(a["actions"]-model["actions_mean"])
        rate=a["energy"]/max(1,a["actions"]);model["energy_rate"]+=(rate-model["energy_rate"])/n
        state["successes"]+=1;delete!(state["active"],goal)
    end
    increment
end
