# Native adaptation of incomplete_reposition.py: retained response opens only
# acquired, currently executable steps. The existing method loop owns selection.
reposition_state(actor)=D("actor"=>actor,"purpose"=>nothing,"last_us"=>nothing,"residual"=>0.,"offered"=>0,"selected"=>0,"records"=>Any[])
function reposition_candidates!(s,actor,movement,now;linked=false,purpose="food",home_unresolved=false)
    check(s["actor"]==actor,"reposition_actor")
    previous=s["last_us"]
    previous!==nothing && now<=previous && return Any[]
    if s["purpose"]!=purpose
        s["residual"]=0.;s["purpose"]=purpose
    end
    dt=previous===nothing ? 0. : (now-previous)/1e6
    s["last_us"]=now;s["residual"]=max(0.,s["residual"]-.5dt)
    eligible=(purpose=="food" && movement["food_coverage"]=="partial") || (purpose=="home" && home_unresolved)
    eligible && linked || return Any[]
    s["residual"]=min(8.,s["residual"]+1.)
    ground=movement["movement_surface"]["ground"]
    ground["output_limited"] && return Any[]
    s["residual"]>=2 || return Any[]
    allowed=[i for (i,v) in enumerate(ground["samples"]) if v["status"]=="sampled" &&
        v["height_delta"]!==nothing && abs(v["height_delta"])<=.5 && movement["energy"]["rows"][i]["cost"]!==nothing]
    near=[i for i in allowed if abs(ground["samples"][i]["direction_deg"])<=45]
    s["residual"]<4 && !isempty(near) && (allowed=near)
    candidates=[D("method"=>"reposition_$(ground["samples"][i]["direction_deg"])",
        "action"=>"walk","direction"=>i-1,"priority"=>3.5,"question"=>"target_observed") for i in allowed]
    if !isempty(candidates)
        s["offered"]+=1
        push!(s["records"],D("source"=>"ob:$now:$actor","residual"=>s["residual"],"purpose"=>purpose,
            "directions"=>[c["direction"] for c in candidates]))
        length(s["records"])>32 && popfirst!(s["records"])
    end
    candidates
end

# Movement is a means of acquiring evidence, not completion of the search.
function search_review_result!(state, family, method, found, performed)
    if get(state,"review_family",nothing)!=family
        state["review_H"]=0;state["review_family"]=family
    end
    if found || (method=="survey" && performed)
        state["review_H"]=0
    elseif startswith(method,"reposition_") && performed
        state["review_H"]=min(32,get(state,"review_H",0)+1)
    end
end
function project_search_review!(state,candidates,loop,target,family)
    target===nothing && get(state,"review_family",nothing)==family || return
    h=get(state,"review_H",0)
    h>=loop.threshold || return
    for c in candidates
        c["method"]=="survey" || continue
        # Keep a choice, but unresolved relocation increases the value of looking.
        c["priority"]+=min(4.,h/loop.threshold)
    end
end
