# Anticipated exposure is a bounded residual, not an unfinished-goal counter.
night_fear_state()=D("H"=>0.,"last_us"=>nothing,"next_estimate_us"=>0,"estimate"=>nothing,
    "evaluations"=>0,"requests"=>0,"food_blocks"=>0,"records"=>Any[],"last_request_us"=>nothing,
    "requested"=>false,"peak_H"=>0.,"anticipatory_evaluations"=>0)
function night_return_estimate!(s,state,home,at_home,now,day_us)
    if at_home
        state["estimate"]=nothing;state["next_estimate_us"]=now
        return D("seconds"=>0.,"margin"=>0.,"kind"=>"at_home")
    end
    if now<state["next_estimate_us"] && state["estimate"]!==nothing
        return state["estimate"]
    end
    outlook=mb_return_outlook!(s,now);frame=s["current"]
    route=frame===nothing ? nothing : mb_return_estimate(s,outlook,frame.key)
    if home!==nothing
        estimate=mb_parent_estimate!(s,D(),"home",home);kind="observed_home"
    elseif route!==nothing && !isempty(route["path"])
        estimate=mb_parent_estimate!(s,D("mb_path"=>route["path"]),"home",nothing);kind="observed_chain"
    else
        estimate=mb_parent_estimate!(s,D(),"home",nothing);kind="unconfirmed"
    end
    # Unknown search time is not zero. This allowance is a prior, not a guaranteed bound.
    margin=(kind=="unconfirmed" ? .25 : .05)*day_us/1_000_000
    state["estimate"]=D("seconds"=>Float64(estimate["upper_actions"]),"margin"=>margin,
        "kind"=>kind,"model"=>estimate["model"],"source"=>estimate["source"])
    state["next_estimate_us"]=now+64_000_000
    state["estimate"]
end
function night_fear_update!(state,estimate,at_home,hazard_view,now,day_us,night_us)
    state["last_us"]!==nothing && now<=state["last_us"] && return state["H"]
    dt=state["last_us"]===nothing ? 1. : min(60.,(now-state["last_us"])/1_000_000)
    state["last_us"]=now;local_us=mod(now,day_us)
    remaining=(night_us-local_us)/1_000_000
    scale=max(1.,.125day_us/1_000_000)
    residual=at_home ? 0. : max(0.,(estimate["seconds"]+estimate["margin"]-remaining)/scale)
    features=hazard_view===nothing ? Any[] : hazard_view["features"]
    threat=isempty(features) ? 0. : maximum(clamp((8-h["distance"])/4,0.,2.) for h in features)
    complete=hazard_view!==nothing && hazard_view["coverage"]=="complete"
    target=clamp(max(residual,threat),0.,8.)
    # Arrival without a usable safety observation is not evidence for relief.
    at_home && !complete && (target=max(target,state["H"]))
    before=state["H"];tau=target>before ? 30. : 120.
    state["H"]=target+(before-target)*exp(-dt/tau)
    state["peak_H"]=max(state["peak_H"],state["H"]);state["evaluations"]+=1
    state["anticipatory_evaluations"]+=Int(local_us<night_us && residual>0)
    if mod(state["evaluations"],64)==1
        push!(state["records"],D("us"=>now,"at_home"=>at_home,"estimate"=>copy(estimate),
            "until_night"=>remaining,"residual"=>residual,"threat"=>threat,"target"=>target,
            "H"=>state["H"],"increment"=>max(0.,state["H"]-before),"relief"=>max(0.,before-state["H"])))
        length(state["records"])>64 && popfirst!(state["records"])
    end
    state["H"]
end
function night_fear_request!(state,returning,replenishing,now,rng)
    if state["last_request_us"]==now
        return returning || state["requested"]
    end
    state["last_request_us"]=now
    state["food_blocks"]+=Int(replenishing && state["H"]>0)
    state["requested"]=!replenishing && state["H"]>0 && rand(rng)<-expm1(-1.5state["H"])
    state["requests"]+=Int(state["requested"])
    returning || state["requested"]
end
