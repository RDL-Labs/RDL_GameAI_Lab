# Observer-local hypotheses from visible owned supplies. No expiry ledger or
# hidden store is read. A changed pile is evidence, not an item-identity proof.
food_condition_state()=D("views"=>D(),"pending"=>Any[],"conditions"=>D(),"storage"=>D(),"records"=>Any[],"next_us"=>0,"day"=>-1)
# Initial sensory prior, isolated game assumption, not forced refusal or toxicity.
const FOOD_APPEARANCE_AVERSION=Dict("grey_flesh"=>8.0)
function food_condition_aversion(map,kind)
    appearance=RDLBody.FOOD_APPEARANCE[kind]
    prior=get(FOOD_APPEARANCE_AVERSION,appearance,0.)
    s=map===nothing ? nothing : get(map,"food_conditions",nothing)
    e=s===nothing ? nothing : get(s["conditions"],appearance,nothing)
    e===nothing && return prior
    # Confirmed rejection adds evidence; successful inspections weaken the prior.
    n=e["samples"];bad=n-e["usable"]
    (prior+max(4.,2prior)*bad)/(1+n)
end
function food_condition_observe!(map,inventory,stores,at_home,now,day_us;foods=nothing,actor=nothing,shared_stores=false)
    map["food_clock"]=(now=now,day_us=day_us)
    s=get!(food_condition_state,map,"food_conditions");day=div(now,day_us)
    now<s["next_us"] && day==s["day"] && return
    s["next_us"]=now+64_000_000;s["day"]=day
    held=[count(==(k),inventory) for k in RDLBody.FOOD_KIND_IDS]
    for (scope,counts) in (("held",held),("stored",at_home ? stores : nothing))
        counts===nothing && continue
        for kind in RDLBody.FOOD_KIND_IDS
        kind==RDLBody.SPOILED_FOOD && continue
        key=scope*":"*string(kind)
        old=get(s["views"],key,nothing)
        fresh=counts[kind];bad=counts[RDLBody.SPOILED_FOOD]
        since=old!==nothing && old["fresh"]>0 ? old["since_day"] : day
        if old!==nothing && day>old["day"] && old["fresh"]>fresh && bad>old["changed"]
            push!(s["pending"],D("source_kind"=>kind,"appearance"=>RDLBody.FOOD_APPEARANCE[RDLBody.SPOILED_FOOD],
                "scope"=>scope,"observed_condition"=>get(get(get(s,"visual_conditions",D()),string(kind),D()),"condition",nothing),"observed_after_days"=>day-since,"us"=>now,"confirmed"=>false))
            # Visible change is evidence for loss of the former state, even if
            # the actor disposes of the result instead of testing edibility.
            food_storage_failure!(s,last(s["pending"]))
            length(s["pending"])>16 && popfirst!(s["pending"])
        end
        s["views"][key]=D("fresh"=>fresh,"changed"=>bad,"day"=>day,"since_day"=>since)
        end
    end
    if foods!==nothing && foods.game.age.enabled
        rows=food_condition_visuals(foods,actor,at_home;shared_stores)
        senses=get!(()->D(),s,"visual_conditions")
        for kind in RDLBody.FOOD_KIND_IDS
            seen=filter(v->v["kind"]==kind,rows)
            isempty(seen) && continue
            n=sum(v["count"] for v in seen)
            senses[string(kind)]=D("condition"=>sum(v["condition"]*v["count"] for v in seen)/n,"samples"=>n,"us"=>now)
        end
        s["visible_batches"]=rows
    end
end
function food_storage_failure!(s,p)
    get(p,"storage_learned",false) && return
    model=get!(() -> D("unusable_episodes"=>0,"shortest_observed_days"=>typemax(Int)),s["storage"],string(p["source_kind"]))
    model["unusable_episodes"]+=1
    model["shortest_observed_days"]=min(model["shortest_observed_days"],max(1,p["observed_after_days"]))
    cue=get(p,"observed_condition",nothing)
    if cue!==nothing
        cues=get!(()->D(),model,"cue_failures");key=string(round(Int,cue))
        cues[key]=get(cues,key,0)+1
    end
    p["storage_learned"]=true
end
function food_condition_result!(map,kind,usable,now)
    s=get!(food_condition_state,map,"food_conditions");appearance=RDLBody.FOOD_APPEARANCE[kind]
    e=get!(() -> D("samples"=>0,"usable"=>0),s["conditions"],appearance)
    e["samples"]+=1;e["usable"]+=Int(usable)
    # At most one storage episode per observed scope/day, not one failure per fish.
    if !usable
        for p in s["pending"]
            p["confirmed"] || p["appearance"]!=appearance || begin
                p["confirmed"]=true
                food_storage_failure!(s,p)
            end
        end
    end
    push!(s["records"],D("us"=>now,"appearance"=>appearance,"usable"=>usable,"samples"=>e["samples"]))
    length(s["records"])>64 && popfirst!(s["records"])
end
function food_condition_usable(map,kind)
    s=get(map,"food_conditions",nothing);s===nothing && return .5
    e=get(s["conditions"],RDLBody.FOOD_APPEARANCE[kind],nothing)
    e===nothing ? .5 : e["usable"]/e["samples"]
end
function food_storage_survival(map,kind,days_ahead)
    days_ahead<=0 && return 1.
    # Subjective bootstrap by recognizable appearance, not the world's expiry ledger.
    prior=get(FOOD_RETENTION_PRIOR,RDLBody.FOOD_APPEARANCE[kind],1.)^days_ahead
    s=map===nothing ? nothing : get(map,"food_conditions",nothing)
    cue=s===nothing ? nothing : get(get(s,"visual_conditions",D()),string(kind),nothing)
    cue!==nothing && (prior*=max(.05,1-.5cue["condition"]))
    e=s===nothing ? nothing : get(s["storage"],string(kind),nothing)
    failures=e===nothing ? 0 : e["unusable_episodes"]
    if e!==nothing && cue!==nothing
        specific=get(get(e,"cue_failures",D()),string(round(Int,cue["condition"])),0)
        # Specific visual experience refines the general retention hypothesis.
        failures=.5failures+.5specific
    end
    e===nothing || days_ahead<e["shortest_observed_days"] ? prior : prior/(1+failures)
end
const FOOD_RETENTION_PRIOR=Dict("red_round_fruit"=>.9,"red_flesh"=>.7,"brown_capped_ovoid"=>.99,"brown_meal"=>.97,"silver_fish"=>.5,"roasted_fish"=>.5,"salt_grilled_fish"=>.5)

# One shared meal budget for all foods, rather than one whole budget per kind.
function food_expiry_forecast(map,body,gut;now=nothing,day_us=nothing,delay_seconds=0.)
    clock=map===nothing ? (now=0,day_us=17_280_000_000) : get(map,"food_clock",(now=0,day_us=17_280_000_000))
    now=now===nothing ? clock.now : now;day_us=day_us===nothing ? clock.day_us : day_us
    remaining=max(0.,(day_us-mod(now,day_us))/1e6-delay_seconds)
    security=map===nothing ? nothing : get(map,"food_security",nothing)
    rate=security===nothing ? nothing : get(security,"rate",nothing)
    rate=rate===nothing ? RDLBody.MEAL_ENERGY/(day_us/1e6) : rate
    capacity=max(0.,(100-body.reserve+remaining*rate)/RDLBody.MEAL_ENERGY-(gut===nothing ? 0. : gut.gut))
    D("capacity"=>capacity,"risk"=>[1-food_storage_survival(map,k,1) for k in RDLBody.FOOD_KIND_IDS],
      "remaining_seconds"=>remaining,"urgency"=>1-remaining/(day_us/1e6),"us"=>now)
end
function food_expected_waste(counts,forecast;units=nothing)
    counts===nothing && return 0.
    risk=forecast["risk"];budget=forecast["capacity"];loss=0.
    # Optimistic allocation: spend the shared budget on the least durable foods.
    for k in sortperm(risk;rev=true)
        k>length(counts) && continue
        risk[k]>0 || continue
        n=max(0.,counts[k]);used=min(n,budget);budget-=used
        loss+=risk[k]*(n-used)*(units===nothing ? 1. : units[k])
    end
    loss
end
