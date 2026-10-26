# One censored/completed observation per parent attempt, not one sample per tick.
function mb_parent_learn!(s,goal,a,completed,reason)
    a["actions"]>0 || return
    model=s["parent_mb"]["models"][a["estimate"]["model"]]
    observations=model["observations"];id=string(a["started_us"])*":"*goal
    index=findfirst(x->x["id"]==id,observations)
    sample=D("id"=>id,"actions"=>a["actions"],"energy"=>a["energy"],"completed"=>completed,"reason"=>reason,
        "baseline"=>get(a["estimate"],"baseline_actions",a["estimate"]["expected_actions"]))
    if index===nothing
        push!(observations,sample);length(observations)>128 && popfirst!(observations)
    else
        old=observations[index]
        old["completed"] && return
        old["actions"]==sample["actions"] && old["energy"]==sample["energy"] && old["completed"]==completed && return
        observations[index]=sample
    end
    model["censored_updates"]+=Int(!completed)
    model["energy_rate"]=(.01+sum(x["energy"] for x in observations))/(1+sum(x["actions"] for x in observations))
    model["forecast"]=nothing
    a["learned_actions"]=a["actions"]
end
# Kaplan-Meier survival with one bootstrap pseudo-observation; nonparametric tail is unresolved.
function mb_parent_survival!(model,mode)
    cached=model["forecast"];cached!==nothing && return cached
    observations=model["observations"];isempty(observations) && return nothing
    prior=mode=="search" ? 128. : 1.
    pairs=Any[(time=prior,event=true)]
    append!(pairs,[(time=mode=="search" ? Float64(x["actions"]) : x["actions"]/max(1.,x["baseline"]),event=x["completed"]) for x in observations])
    times=sort(unique([x.time for x in pairs]));risk=Float64(length(pairs));survival=1.;area=0.;previous=0.;q80=nothing
    for t in times
        area+=survival*(t-previous)
        events=count(x->x.time==t && x.event,pairs);censored=count(x->x.time==t && !x.event,pairs)
        survival*=1-events/risk
        survival<=.2 && q80===nothing && (q80=t)
        risk-=events+censored;previous=t
    end
    # area is a restricted mean (lower bound if a tail remains), never a fabricated completion.
    cached=D("restricted_mean"=>area,"tail_mass"=>survival,"last_observed"=>last(times),"q80"=>q80,
        "prior_weight"=>1/length(pairs),"evidence_count"=>length(observations))
    model["forecast"]=cached
    cached
end
