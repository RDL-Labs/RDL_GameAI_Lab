# Adapter only: predicts progress from current observations and the final selected
# direction. It never reads world positions, hidden targets or obstacle truth.
function navigation_forecast(plan,move,target,family)
    get(plan,"action",nothing) in ("walk","run") || return nothing
    target===nothing && return nothing
    get(target,"distance_estimated",false) && return nothing
    all(k->haskey(target,k),("forward","right","distance")) || return nothing
    rows=plan["action"]=="run" ? move["run_rows"] : move["energy"]["rows"]
    direction=get(plan,"direction",nothing)
    direction===nothing && return nothing
    index=direction+1
    1<=index<=length(rows) || return nothing
    row=rows[index]
    get(row,"status",nothing)=="performed" || return nothing
    distance=min(get(row,"distance",0.),get(plan,"approach_span",Inf))
    distance>0 || return nothing
    angle=get(plan,"approach_angle",ANGLES[index])
    predicted_remaining=hypot(target["forward"]-cosd(angle)*distance,
        target["right"]-sind(angle)*distance)
    D("family"=>family,"ref"=>get(target,"ref",nothing),"action"=>plan["action"],
      "before"=>target["distance"],"scale"=>distance,
      "expected"=>(target["distance"]-predicted_remaining)/distance)
end

function navigation_forecast_result(forecast,home,visible;sensitivity=1.)
    forecast===nothing && return nothing
    target=if forecast["family"]=="home"
        home
    else
        index=findfirst(v->get(v,"ref",nothing)==forecast["ref"],visible)
        index===nothing ? nothing : visible[index]
    end
    (target===nothing || get(target,"distance_estimated",false)) && return nothing
    observed=(forecast["before"]-target["distance"])/forecast["scale"]
    (sensitivity*forecast["expected"],sensitivity*observed)
end

function navigation_forecast_record!(map,forecast,evidence)
    forecast===nothing && return
    stats=get!(() -> D("evaluated"=>0,"unobserved"=>0,"below_forecast"=>0,
        "expected_sum"=>0.,"observed_sum"=>0.),map,"navigation_forecast_stats")
    if evidence===nothing
        stats["unobserved"]+=1
    else
        expected,observed=evidence
        stats["evaluated"]+=1;stats["below_forecast"]+=observed<expected
        stats["expected_sum"]+=expected;stats["observed_sum"]+=observed
    end
end
