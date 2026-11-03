# A scenario-supplied daily objective, with learned stages and probabilistic policy.
# 局所観測用の固定設定: food/home, daily deadline, stage labels and bootstrap/cadence
# values are experimental scaffolding, not universal MB rules. Generic extraction
# is incomplete; see docs/design/LW_Daily_Provision_Plan.md.
# Uses observed food / remembered routes only; no hidden food coordinates or stocks.
mb_daily_plan_state(actor,seed)=D("active"=>nothing,"models"=>D(),"records"=>Any[],
    "decisions"=>Any[],"rng"=>BasicLoop("$actor:daily-provisions";probabilistic=true,seed=seed).rng)
function mb_daily_log!(rows,row)
    push!(rows,row);length(rows)>128 && popfirst!(rows);nothing
end
function mb_daily_learn!(state,key,seconds,energy,success,reason)
    model=get!(() -> Any[],state["models"],key)
    mb_daily_log!(model,D("seconds"=>max(0.,seconds),"energy"=>max(0.,energy),"completed"=>success,"reason"=>reason))
end
function mb_daily_estimate(state,key,baseline)
    rows=filter(x->x["completed"],get(state["models"],key,Any[]))
    # Unknown attempts remain evidence of uncertainty, not fictitious completion times.
    isempty(rows) && return D("seconds"=>max(1.,baseline),"energy"=>.001max(1.,baseline),"source"=>"bootstrap")
    D("seconds"=>max(1.,sum(x["seconds"] for x in rows)/length(rows)),
      "energy"=>sum(x["energy"] for x in rows)/length(rows),"source"=>"completed_stage")
end
function mb_daily_stage!(state,stage,now;completed=false,reason="replan")
    a=state["active"];a["stage"]==stage && return
    mb_daily_learn!(state,a["stage"],(now-a["stage_us"])/1e6,a["energy"]-a["stage_energy"],completed,reason)
    a["stage"]=stage;a["stage_us"]=now;a["stage_energy"]=a["energy"]
end
function mb_daily_close!(state,now,returned,reason)
    a=state["active"];a["closed"] && return
    mb_daily_learn!(state,a["stage"],(now-a["stage_us"])/1e6,a["energy"]-a["stage_energy"],returned && a["stage"]=="return",reason)
    # Acquisition and return outcomes are separate; an empty return is not a delivery.
    mb_daily_learn!(state,"roundtrip:"*a["initial_mode"],(now-a["started_us"])/1e6,a["energy"],returned && a["delivered"]>0,reason)
    a["closed"]=true
    mb_daily_log!(state["records"],D("started_us"=>a["started_us"],"ended_us"=>now,"deadline_us"=>a["deadline_us"],
        "initial_mode"=>a["initial_mode"],"acquired"=>a["acquired"],"delivered"=>a["delivered"],
        "returned"=>returned,"food_success"=>a["delivered"]>0,"on_time"=>now<=a["deadline_us"],
        "operations"=>a["operations"],"energy"=>a["energy"],"reason"=>reason))
end
function mb_daily_evidence(s,move,reserve,strain,now)
    visible=get(move,"visible",Any[])
    !isempty(visible) && return D("mode"=>"known_food","source"=>"visible","confidence"=>1.,
        "seconds"=>max(1.,first(visible)["distance"]/.5+1),"candidate"=>nothing)
    arrival=get(get(s,"goal_arrival",D()),"food",nothing)
    if arrival!==nothing && arrival["mode"]=="approach"
        e=arrival["estimate"]
        return D("mode"=>"known_food","source"=>"provisional_location","confidence"=>arrival["confidence"],
            "seconds"=>max(1.,hypot(e["forward"],e["right"])/.5+1),"candidate"=>nothing)
    end
    # Reuse the same uncertain chunk correspondence as ordinary navigation.
    options=mb_chunk_candidates!(s,move,"food",reserve,strain,now;H=0)
    isempty(options) && return D("mode"=>"unknown_food","source"=>"no_usable_memory","confidence"=>0.,"seconds"=>128.,"candidate"=>nothing)
    p=first(options)
    D("mode"=>"known_food","source"=>"remembered_route","confidence"=>get(p,"mb_recognition_confidence",.5),
      "seconds"=>Float64(get(p,"mb_depth",128)),"candidate"=>p)
end
function mb_daily_request!(s,move,home,at_home,inventory,reserve,strain,now,day_us;replenishing=false,return_hint=false)
    state=s["daily_plan"];a=state["active"]
    if a===nothing || (a["closed"] && now>=a["deadline_us"])
        evidence=mb_daily_evidence(s,move,reserve,strain,now)
        a=D("started_us"=>now,"deadline_us"=>(fld(now,day_us)+1)*day_us,"initial_mode"=>evidence["mode"],
            "stage"=>evidence["mode"],"stage_us"=>now,"stage_energy"=>0.,"energy"=>0.,"operations"=>0,
            "acquired"=>0,"acquired_sources"=>Set{String}(),"delivered"=>0,"departed"=>!at_home,"closed"=>false,"choice"=>"food","forecast"=>nothing,
            "evidence"=>evidence,"next_us"=>now,"last_visible"=>!isempty(get(move,"visible",Any[])))
        state["active"]=a
    end
    a["closed"] && return configured_daily_plan_stay(replenishing)
    a["departed"] |= !at_home
    if at_home && a["departed"] && a["choice"]=="home" && inventory==0
        mb_daily_close!(state,now,true,"empty_return");return configured_daily_plan_stay(replenishing)
    end
    visible=!isempty(get(move,"visible",Any[]))
    if now<a["next_us"] && visible==a["last_visible"]
        return a["choice"]=="home"
    end
    a["next_us"]=now+64_000_000;a["last_visible"]=visible
    evidence=mb_daily_evidence(s,move,reserve,strain,now);a["evidence"]=evidence
    mode=evidence["mode"]
    food=mb_daily_estimate(state,mode,evidence["seconds"])
    mode=="known_food" && (food["seconds"]=max(food["seconds"],evidence["seconds"]))
    # Recognized home distance or an observed directed return chain; unknown is explicit.
    frame=s["current"];chain=frame===nothing ? nothing : mb_return_estimate(s,mb_return_outlook!(s,now),frame.key)
    base=home!==nothing ? home["distance"]/.5 : chain===nothing ? 128. : Float64(length(chain["path"]))
    back=mb_daily_estimate(state,"return",max(1.,base))
    (home!==nothing || chain!==nothing) && (back["seconds"]=max(back["seconds"],base))
    resources=get(s["parent_mb"],"resources",D("metabolic_rate"=>0.))
    remaining=max(1.,(a["deadline_us"]-now)/1e6);rate=resources["metabolic_rate"]
    budget_penalty(t,e)=2log1p(max(0.,t/remaining-1))+2log1p(max(0.,(e+t*rate)/max(.01,reserve)-1))
    # Reserving the whole return is part of evaluating further acquisition.
    t=food["seconds"]+back["seconds"];e=food["energy"]+back["energy"]
    if a["forecast"]===nothing
        a["forecast"]=mb_daily_estimate(state,"roundtrip:"*a["initial_mode"],t)
    end
    forecast=a["forecast"];elapsed=(now-a["started_us"])/1e6
    t=max(t,forecast["seconds"]-elapsed);e=max(e,forecast["energy"]-a["energy"])
    continue_score,return_score=configured_daily_plan_scores(evidence["confidence"],inventory,reserve,
        replenishing,budget_penalty(t,e),budget_penalty(back["seconds"],back["energy"]),return_hint)
    loop=BasicLoop("daily-provisions";probabilistic=true)
    loop.rng=state["rng"]
    delay=mb_response(s,"delay",(elapsed-forecast["seconds"])/max(1.,.25forecast["seconds"]))
    loop.H=min(32.,max(delay,budget_penalty(t,e)))
    candidates=[D("method"=>"continue_food","priority"=>continue_score),D("method"=>"return_home","priority"=>return_score)]
    probabilities=method_distribution(loop,candidates)
    choice=rand(loop.rng)<probabilities[1] ? "food" : "home"
    # Rest/processing at camp must not fabricate completion of an outing.
    stage=choice=="home" ? "return" : mode
    prior=a["stage"]
    mb_daily_stage!(state,stage,now;completed=prior=="unknown_food" && mode=="known_food",reason="plan_revision")
    a["choice"]=choice
    a["remaining_estimate"]=D("food_seconds"=>food["seconds"],"return_seconds"=>back["seconds"],
        "available_seconds"=>remaining,"food_source"=>evidence["source"],"return_known"=>home!==nothing || chain!==nothing)
    mb_daily_log!(state["decisions"],D("us"=>now,"stage"=>stage,"confidence"=>evidence["confidence"],
        "return_probability"=>probabilities[2],"H"=>loop.H,"forecast_seconds"=>forecast["seconds"],"estimate"=>copy(a["remaining_estimate"])))
    choice=="home"
end
function mb_daily_result!(s,plan,status,now,energy,amount;acquired_source=nothing,delivered_sources=String[])
    state=s["daily_plan"];a=state["active"]
    (a===nothing || a["closed"]) && return
    a["operations"]+=1;a["energy"]+=max(0.,energy)
    if status in ("picked_up","recovered")
        source=acquired_source===nothing ? "op:$now:$(s["actor"])" : acquired_source
        if !(source in a["acquired_sources"])
            a["acquired"]+=1;push!(a["acquired_sources"],source)
        end
        mb_daily_stage!(state,"return",now+1_000_000;completed=true,reason="acquired")
        a["next_us"]=now+1_000_000
    elseif plan["action"]=="deposit" && status=="performed"
        a["delivered"]+=min(amount,count(id->id in a["acquired_sources"],unique(delivered_sources)))
        if a["departed"] || a["delivered"]>0
            mb_daily_close!(state,now+1_000_000,true,a["delivered"]>0 ? "delivered" : "initial_cargo_return")
        end
        a["next_us"]=now+1_000_000
    elseif status=="not_found"
        a["evidence"]=D("mode"=>"unknown_food","candidate"=>nothing)
        mb_daily_stage!(state,"unknown_food",now+1_000_000;reason="food_not_found")
        a["next_us"]=now+1_000_000
    end
end
