# Forecasts describe required effort; available resources do not grow with them.
function mb_plan_context!(s,now,day_us,reserve,metabolic_loss)
    s["parent_mb"]["resources"]=D("now"=>now,"deadline_us"=>(fld(now,day_us)+1)*day_us,
        "reserve"=>max(0.,Float64(reserve)),"metabolic_rate"=>now>0 ? max(0.,metabolic_loss/(now/1e6)) : 0.)
end
function mb_plan_budget(s,e,goal)
    ctx=get(s["parent_mb"],"resources",nothing);ctx===nothing && return nothing
    deadline=ctx["deadline_us"]
    daily=get(s,"daily_plan",nothing)
    if daily!==nothing && daily["active"]!==nothing && !daily["active"]["closed"]
        deadline=min(deadline,daily["active"]["deadline_us"])
    end
    # Neither replacing a method nor entering approach buys a new deadline.
    parent=s["parent_mb"]
    mode=get(get(parent,"modes",D()),goal,nothing)
    suspended=mode===nothing ? nothing : get(mode,"suspended",nothing)
    for trial in (get(parent["active"],goal,nothing),suspended)
        trial===nothing && continue
        old=get(trial["estimate"],"planning",nothing)
        old!==nothing && (deadline=min(deadline,old["deadline_us"]))
    end
    seconds=max(1.,(deadline-ctx["now"])/1e6)
    energy=e["expected_energy"]+e["expected_actions"]*ctx["metabolic_rate"]
    time_gap=max(0.,e["expected_actions"]/seconds-1)
    energy_gap=max(0.,energy/max(.01,ctx["reserve"])-1)
    D("deadline_us"=>deadline,"available_seconds"=>seconds,"available_energy"=>ctx["reserve"],
      "predicted_energy_with_metabolism"=>energy,"metabolic_rate"=>ctx["metabolic_rate"],
      "time_gap"=>time_gap,"energy_gap"=>energy_gap,"penalty"=>2log1p(time_gap)+2log1p(energy_gap))
end
function mb_plan_pressure(s,a,now)
    e=a["estimate"];budget=get(e,"planning",nothing)
    ctx=get(s["parent_mb"],"resources",nothing)
    (budget===nothing || ctx===nothing) && return 0.
    remaining=max(0.,e["expected_actions"]-a["actions"])
    available=max(1.,(budget["deadline_us"]-now)/1e6)
    # Passing the deadline is not erased when predicted remaining effort reaches zero.
    late=max(0.,(now-budget["deadline_us"])/1e6)/max(1.,budget["available_seconds"])
    time_gap=log1p(max(0.,remaining/available-1))+late
    energy=max(0.,e["expected_energy"]-a["energy"])+remaining*ctx["metabolic_rate"]
    energy_gap=log1p(max(0.,energy/max(.01,ctx["reserve"])-1))
    max(mb_response(s,"delay",time_gap),mb_response(s,"energy",energy_gap))
end
