include("../parameters.jl")

# Compare current rest with tolerating predicted walking effort until the goal.
# Inputs are observed distance / owner-side stage estimates, never world coordinates.
# This is an initial bodily forecast, not a new goal-success reward or parent H.
function fatigue_forecast(body,load,seconds,relief;resistance=1.)
    rules=FATIGUE_FORECAST_RULES
    walked,status,_,_=step(body,"walk",load,resistance)
    rested,_,_,_=step(body,"rest",load)
    duration=max(1.,Float64(seconds))
    strain_rate=max(0.,walked.strain-body.strain)
    reserve_rate=max(0.,body.reserve-metabolize(walked,1.).reserve)
    predicted_strain=body.strain+strain_rate*duration
    predicted_reserve=body.reserve-reserve_rate*duration
    pressure=(max(0.,body.strain-rules.onset)/rules.scale)^2
    rest_gain=max(0.,body.strain-rested.strain)*min(duration,rules.delay_seconds)/rules.scale
    risk=rules.risk_gain*(max(0.,predicted_strain-1)/rules.scale+max(0.,-predicted_reserve)/HUNGER_FORECAST_RULES.scale)
    benefit=clamp(relief,0.,1.)/(1+duration/rules.delay_seconds)
    continue_score=rules.continue_prior+benefit-pressure-risk
    rest_score=pressure+rest_gain
    probability=status=="performed" ? 1/(1+exp(clamp(rest_score-continue_score,-700.,700.))) : 0.
    D("seconds"=>duration,"predicted_strain"=>predicted_strain,"predicted_reserve"=>predicted_reserve,
        "continue_score"=>continue_score,"rest_score"=>rest_score,"continue_probability"=>probability,
        "walk_status"=>status,"relief"=>relief)
end

function fatigue_navigation_continue!(map,body,load,target,returning,loop,now)
    rules=FATIGUE_FORECAST_RULES
    # Below onset there is no fatigue intervention and no additional random draw.
    body.strain<rules.onset && body.reserve>0 && return true
    state=get!(() -> D("records"=>Any[],"continued"=>0,"rested"=>0),map,"fatigue_forecast")
    family=returning ? "home" : "food"
    target_key=(family,target===nothing ? nothing : get(target,"ref",family))
    if get(state,"target_key",nothing)==target_key && now<get(state,"next_us",0) &&
            body.strain<1 && body.reserve>0 && get(state,"choice",false)
        return true
    end
    seconds=target===nothing ? rules.unknown_seconds : mb_travel_seconds(target["distance"])
    source=target===nothing ? "unknown" : "observed_goal"
    if target===nothing && returning && haskey(map,"daily_plan")
        estimate=mb_daily_estimate(map["daily_plan"],"return",seconds)
        seconds=estimate["seconds"];source=estimate["source"]
    end
    relief=returning ? get(get(map,"embedded_rest",D()),"place_value",0.) : 0.
    forecast=fatigue_forecast(body,load,seconds,relief)
    candidates=[D("method"=>"continue","priority"=>forecast["continue_score"]),
        D("method"=>"rest","priority"=>forecast["rest_score"])]
    forecast["walk_status"]=="performed" && (forecast["continue_probability"]=method_distribution(loop,candidates)[1])
    chosen=forecast["continue_probability"]>0 && rand(loop.rng)<forecast["continue_probability"]
    record=merge(forecast,D("us"=>now,"source"=>source,"family"=>returning ? "home" : "food",
        "strain"=>body.strain,"reserve"=>body.reserve,"continued"=>chosen))
    state["choice"]=chosen;state["target_key"]=target_key
    state["next_us"]=now+round(Int,min(seconds,rules.delay_seconds)*1e6)
    state[chosen ? "continued" : "rested"]+=1
    push!(state["records"],record);length(state["records"])>rules.record_limit && popfirst!(state["records"])
    chosen
end
