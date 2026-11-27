# Human physiology has no independent reserve. Material pools are authoritative.
struct HumanBody <: AbstractBody
    burst::Float64
    strain::Float64
    damage::Float64
    nutrients::Macronutrients.MacroBody
    hours_per_second::Float64
    activity::Float64
    activity_capacity::Union{Nothing,ActivityCapacity.State}
    capacity_action::Symbol
end
HumanBody(burst,strain,damage,nutrients,hours_per_second,activity)=HumanBody(burst,strain,damage,nutrients,hours_per_second,activity,nothing,:observe)
HumanBody(nutrients,hours_per_second)=HumanBody(10.,0.,0.,nutrients,hours_per_second,0.)
body_alive(b::Body)=b.reserve>0
body_alive(b::HumanBody)=b.nutrients.alive
body_energy(b::Body)=b.reserve
function body_energy(b::HumanBody)
    n=b.nutrients
    max(0.,n.sugar+n.fat+n.amino+max(0.,n.tissue-MACRO_PARAMETERS.tissue_minimum)-
        MACRO_PARAMETERS.activity_rate*b.activity*b.hours_per_second)
end
body_mobility(b::Body)=body_alive(b) ? 1. : 0.
body_mobility(b::HumanBody)=Macronutrients.body_signals(b.nutrients,MACRO_PARAMETERS).ability*(b.activity_capacity===nothing ? 1. : ActivityWear.ability(b.activity_capacity.physical))
body_demand(b::Body)=clamp((80-b.reserve)/80,0.,1.)
body_demand(b::HumanBody)=Macronutrients.body_signals(b.nutrients,MACRO_PARAMETERS).body_demand
body_food_gap(b::Body)=max(0.,80-b.reserve)
body_food_gap(b::HumanBody)=max(0.,MACRO_PARAMETERS.sugar_reference-b.nutrients.sugar)+
    max(0.,MACRO_PARAMETERS.fat_reference-b.nutrients.fat)+max(0.,MACRO_PARAMETERS.tissue_target-b.nutrients.tissue)
# Protected tissue is already excluded from body_energy. No second scalar floor.
body_spendable(b::Body,floor)=max(0.,body_energy(b)-floor)
body_spendable(b::HumanBody,floor)=body_energy(b)
body_energy_delta(d)=get(d,"energy",get(d,"reserve",0.))
body_observed_energy(d)=get(d,"energy",get(d,"reserve",0.))
body_observed_demand(d)=get(d,"body_demand",clamp((80-body_observed_energy(d))/80,0.,1.))

function step(b::HumanBody,action,load,resistance=1.,clear=true)
    burst,strain=b.burst,b.strain
    distance=0.;activity=0.;status="body_limited"
    effort=(1+BODY_ACTION.load_effort*load)*resistance
    ability=body_mobility(b)*(1-b.damage)
    if !body_alive(b)
        status="dead"
    elseif ability<=0 && action!="rest"
        status="incapacitated"
    elseif action in ("walk","run","climb")
        burst_cost=action=="run" ? BODY_ACTION.run_burst*effort : action=="climb" ? BODY_ACTION.climb_burst*effort : 0.
        strain_limit=action=="walk" ? 1. : action=="run" ? BODY_ACTION.run_max_strain : BODY_ACTION.climb_max_strain
        if strain<strain_limit && burst>=burst_cost && ability>0
            activity=clamp(MACRO_WALK_INTENSITY*effort*(action=="walk" ? 1. : 2.),0.,1.)
            if clear
                status="performed"
                distance=(action=="run" ? BODY_ACTION.run_distance : action=="walk" ? BODY_ACTION.walk_distance : 1.)*ability
                burst-=burst_cost
                strain=min(1.,strain+(action=="run" ? BODY_ACTION.run_strain : action=="climb" ? BODY_ACTION.climb_strain : BODY_ACTION.walk_strain)*effort*SS)
            else
                status="blocked";activity*=BODY_ACTION.blocked_reserve/BODY_ACTION.walk_reserve
            end
        end
    elseif action in ("fish","process_food")
        if strain<1 && ability>0
            status="worked"
            activity=clamp(MACRO_WALK_INTENSITY*(action=="fish" ? BODY_ACTION.fish_reserve : BODY_ACTION.work_reserve)/BODY_ACTION.walk_reserve,0.,1.)
            strain=action=="fish" ? max(0.,strain-BODY_ACTION.fish_strain_recovery*ability*SS) : min(1.,strain+BODY_ACTION.work_strain*SS)
        end
    elseif action=="eat"
        status="ate" # ingestion/digestion transfers material; no instant credit
    elseif action=="rest"
        status="rested"
        burst=min(BODY_ACTION.burst_capacity,burst+BODY_ACTION.rest_burst*ability)
        strain=max(0.,strain-BODY_ACTION.rest_strain*ability*SS)
    else
        error("action")
    end
    # Enabled cumulative-capacity mode replaces the legacy short strain accumulator.
    capacity_action=status in ("performed","worked","rested","ate","blocked") ? Symbol(action=="process_food" ? "work" : action=="climb" ? "run" : action) : :observe
    out=HumanBody(burst,b.activity_capacity===nothing ? strain : 0.,b.damage,b.nutrients,b.hours_per_second,activity,b.activity_capacity,capacity_action)
    delta=Dict("burst"=>burst-b.burst,"strain"=>out.strain-b.strain,
        "energy"=>body_energy(out)-body_energy(b),"damage"=>0.)
    out,status,distance,delta
end

# Forecast only: never mutate the body shared with digestion or the live world.
function metabolize(b::HumanBody,seconds)
    physical=deepcopy(b.nutrients)
    Macronutrients.advance!(physical,MACRO_PARAMETERS,seconds*b.hours_per_second;intensity=b.activity)
    HumanBody(b.burst,b.strain,b.damage,physical,b.hours_per_second,0.,b.activity_capacity===nothing ? nothing : deepcopy(b.activity_capacity),:observe)
end
