include(joinpath(@__DIR__, "../../body/load.jl"))
include("../parameters.jl")
hunger_pressure(reserve)=(max(0.,HUNGER_FORECAST_RULES.onset-reserve)/HUNGER_FORECAST_RULES.scale)^HUNGER_FORECAST_RULES.power
function hunger_forecast_update!(h,now,reserve)
    h["intensity"]=hunger_pressure(reserve);h["last_us"]=now;h["due"]=nothing
    forecast=get(h,"forecast",nothing)
    if h["intensity"]==0
        h["H"]=0.;h["forecast"]=nothing
    elseif forecast!==nothing
        elapsed=max(0.,(now-forecast["started_us"])/1e6)
        expected=forecast["reserve"]-forecast["cost"]*min(1.,elapsed/forecast["seconds"])
        energy=max(0.,expected-reserve)/HUNGER_FORECAST_RULES.scale
        delay=max(0.,elapsed-forecast["seconds"])/max(HUNGER_FORECAST_RULES.delay_scale,forecast["seconds"])
        # Current unresolved residual, not repeated failures for merely being hungry.
        h["H"]=max(energy,delay,get(forecast,"contradiction",0.))
    end
    h
end
function hunger_expect!(h,family,now,reserve,seconds,cost)
    old=get(h,"forecast",nothing)
    h["intensity"]>0 || return
    old!==nothing && old["family"]==family && return # Do not slide the deadline.
    h["forecast"]=D("family"=>family,"started_us"=>now,"reserve"=>reserve,
        "seconds"=>max(1.,seconds),"cost"=>max(0.,cost))
    h["H"]=0.
end
function hunger_home_observe!(h,stock,now)
    h["home_stock"]=stock;h["home_observed_us"]=now
    f=get(h,"forecast",nothing)
    if stock<=0 && f!==nothing && f["family"]=="home"
        f["contradiction"]=1.;h["H"]=max(h["H"],1.)
    end
end
function hunger_relief_score(h,reserve,seconds,cost,availability)
    future=hunger_pressure(max(0.,reserve-cost))
    relief=h["intensity"]*clamp(availability,0.,1.)/(1+max(0.,seconds)/HUNGER_FORECAST_RULES.delay_scale)
    relief-max(0.,future-h["intensity"])
end
# Ports social_life.advance_metabolism, hunger_review and food_retention.
food_band(n)=n==0 ? "none" : n<=2 ? "low" : n<=5 ? "some" : "many"
hunger_state(actor)=D("actor"=>actor,"H"=>0,"threshold"=>2,"last_us"=>-1,"due"=>nothing,"intensity"=>0.,"comparisons"=>0,"records"=>Any[])
function hunger_update!(h,actor,now,reserve;continuous=false)
    h["actor"]==actor && now>=h["last_us"] && 0<=reserve<=100 || error("hunger_binding")
    if continuous
        if !get(h,"continuous",false)
            h["continuous"]=true;h["H"]=0.;h["forecast"]=nothing
        end
        return hunger_forecast_update!(h,now,reserve)
    end
    if h["due"]!==nothing && now>=h["due"]
        before=h["H"];h["H"]=reserve>80 ? 0 : before+1;h["comparisons"]+=1
        push!(h["records"],D("trial_due_us"=>h["due"],"source"=>"ob:$now:$actor","reserve"=>reserve,"E"=>Int(reserve<=80),"H_before"=>before,"H_after"=>h["H"]))
        length(h["records"])>32 && popfirst!(h["records"]);h["due"]=nothing
    end
    h["due"]===nothing && reserve<=80 && (h["due"]=now+5_000_000)
    h["last_us"]=now;h["intensity"]=reserve>80 ? 0. : .05+.95*(80-reserve)/80
    h
end
hunger_select(h)=get(h,"continuous",false) ? h["intensity"]>0 : h["intensity"]>0 && .2+h["intensity"]+min(1.,h["H"]/h["threshold"])>.5
function retention_cost(obs,h)
    obs["self_id"]==h["actor"] || error("retention_owner")
    scarcity=Dict("none"=>0.,"low"=>1.,"some"=>.4,"many"=>0.)[food_band(obs["inventory"])]
    reserve=obs["body"]["reserve"]
    scarcity*(1+2*max(0.,(80-reserve)/80)+(reserve<=80 ? min(1.,h["H"]/h["threshold"]) : 0.))
end

# Existing feasible methods only. Reserve depletion is not resolved by rest.
function project_body_methods!(candidates,h,body,phase)
    phase in ("exploration","return") || return false
    urgency=h["intensity"]*(1+min(1.,h["H"]/h["threshold"]))
    fatigue=body.strain;recoverable=min(1.,body.reserve/20);applied=false
    for c in candidates
        get(c,"record_trial",true) || continue
        action=c["action"]
        delta=action=="rest" ? fatigue*recoverable-.5*urgency : action in ("walk","scan") ? .5*urgency-.5*fatigue : nothing
        delta===nothing && continue
        c["priority"]+=delta;applied|=delta!=0
    end
    applied
end
