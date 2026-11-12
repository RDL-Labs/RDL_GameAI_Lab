# Adapter only: selection, prediction-result learning, trial lifecycle and
# acquisition residuals call the SAME functions used by human LW actors.
include("../../lw/configured_paths/predator_cognition_parameters.jl")
include("../../lw/configured_paths/predator_rest_place.jl")
include("predator_cost_forecast.jl")
include("../../lw/configured_paths/predator_food_demand.jl")
include("../../lw/configured_paths/predator_idle_gate.jl")
include("../../lw/configured_paths/predator_food_site.jl")
include("../../lw/configured_paths/predator_crossing.jl")
mutable struct PredatorMind
    loop::LW.BasicLoop
    acquisition::Dict{String,Any}
    places::Dict{String,Any}
    estimates::Dict{String,Float64}
    selected::Any
    trial::Any
    start_food::Float64
    start_spent::Float64
    start_eaten::Float64
    start_capture::Int
    start_rival_distance::Float64
    records::Vector{Any}
    completed::Int
end
PredatorMind(i)=PredatorMind(LW.BasicLoop("predator:$i:maintain";probabilistic=true,seed=20261106+i),
    LW.D(),LW.D(),Dict{String,Float64}(),nothing,nothing,0.,0.,0.,0,Inf,Any[],0)
function predator_remember_place!(mind,p,kind,t)
    rule=PREDATOR_COGNITION;body=p.visual.body
    cell=(floor(Int,body.x/rule.place_cell),floor(Int,body.z/rule.place_cell))
    key=string(kind,":",cell)
    if !haskey(mind.places,key) && length(mind.places)>=rule.place_limit
        eviction_keys=collect(keys(mind.places))
        oldest=first(sort!(eviction_keys;by=k->(mind.places[k].seen,k)))
        delete!(mind.places,oldest)
    end
    prior=get(mind.places,key,nothing)
    mind.places[key]=(kind=kind,x=body.x,z=body.z,seen=t,successes=prior===nothing ? 1 : prior.successes+1)
end
function predator_candidates(mind,p,rival,scents,i;physiology=nothing,world=nothing)
    rule=PREDATOR_COGNITION;body=p.visual.body
    hunger=max(0.,(PREDATOR_ANIMAL_TRIAL.initial_food-p.food)/rule.food_pressure_scale)
    rest_need=physiology===nothing ? nothing : predator_recovery_need(physiology.body)
    rest_pressure=rest_need===nothing ? rule.rest_weight : PREDATOR_BODY.rest_need_weight*rest_need
    rest_forecast=physiology===nothing ? rule.episode_ticks : predator_rest_forecast(physiology.body,rule.episode_ticks)
    rest_expected=if physiology===nothing
        0.
    else
        forecast_body=predator_recover(physiology.body,rest_forecast)
        rest_need-predator_recovery_need(forecast_body)-
            (physiology.body.reserve-forecast_body.reserve+PREDATOR_ANIMAL_TRIAL.daily_food/PREDATOR_ANIMAL_TRIAL.day_ticks*rest_forecast)/rule.food_value_scale
    end
    rows=Any[LW.D("method"=>"hunt","action"=>:hunt,"question"=>"acquired_food",
        "priority"=>rule.food_weight*hunger,"forecast"=>rule.episode_ticks,"expected"=>get(mind.estimates,"hunt",rule.hunt_prior)),
        LW.D("method"=>"rest","action"=>:rest,"question"=>"rested",
        "priority"=>rest_pressure-rule.food_weight*hunger,"forecast"=>rest_forecast,
        "expected"=>rest_expected)]
    rest_need!==nothing && rest_need<=PREDATOR_BODY.need_band && filter!(c->c["action"]!=:rest,rows)
    for key in sort!(collect(keys(mind.places)))
        place=mind.places[key];distance=hypot(place.x-body.x,place.z-body.z)
        place.kind=="rest" && rest_need!==nothing && rest_need<=PREDATOR_BODY.need_band && continue
        distance>rule.arrival_radius || continue
        travel=LW.mb_travel_seconds(distance) # Shared coarse human estimate, not exact geometry planning.
        action=place.kind=="food" ? :visit_food : :visit_rest
        value=LW.acquisition_value(mind.acquisition,string(action),key,travel,0.5,hunger)
        pressure=place.kind=="food" ? rule.food_weight*hunger : rest_pressure-rule.food_weight*hunger
        site_repulsion=place.kind=="food" ? predator_food_site_repulsion(mind,key) : 0.
        push!(rows,LW.D("method"=>"visit:"*key,"action"=>action,"question"=>"reached_remembered_place",
            "priority"=>pressure+value.score+rule.place_prior-site_repulsion,"forecast"=>travel,"food_site_repulsion"=>site_repulsion,
            "expected"=>rule.place_prior,"target"=>(place.x,place.z),"site"=>key))
    end
    configured_predator_rest_candidates!(mind,rows)
    if rival.actor!==nothing
        push!(rows,LW.D("method"=>"retreat","action"=>:retreat,"question"=>"rival_farther",
            "priority"=>rule.rival_weight,"forecast"=>rule.decision_ticks,"expected"=>rule.place_prior))
        own=scents===nothing ? 0. : scents.observed[i].own
        foreign=scents===nothing ? 0. : scents.observed[i].foreign
        push!(rows,LW.D("method"=>"warn","action"=>:warn,"question"=>"rival_farther",
            "priority"=>rule.rival_weight+own-foreign,"forecast"=>PREDATOR_ANIMAL_TRIAL.warning_duration_ticks,
            "expected"=>rule.place_prior))
    end
    world!==nothing && configured_crossing_candidate!(rows,mind,p,world;physiology)
    physiology!==nothing && configured_predator_food_demand!(rows,p,mind)
    rows
end
function predator_mind_close!(mind,p,rival,t;dead=false,physiology=nothing)
    mind.trial===nothing && return
    rule=PREDATOR_COGNITION;c=mind.selected;action=c["action"]
    cost=(p.spent-mind.start_spent)/rule.food_value_scale
    captured=p.visual.body.captures>mind.start_capture
    arrived=haskey(c,"target") && hypot(p.visual.body.x-c["target"][1],p.visual.body.z-c["target"][2])<=get(c,"arrival_radius",rule.arrival_radius)
    observed=true
    actual=if action==:hunt
        (p.eaten-mind.start_eaten)/rule.food_value_scale-cost
    elseif action==:rest
        physiology===nothing ? -cost : max(0.,get(c,"body_start_need",predator_recovery_need(physiology.body))-predator_recovery_need(physiology.body))-cost
    elseif action==:idle
        -cost
    elseif action in (:visit_food,:visit_rest,:cross_river)
        (arrived ? rule.place_prior : 0.)-cost
    else
        observed=rival.actor!==nothing && isfinite(mind.start_rival_distance)
        observed ? clamp((rival.distance-mind.start_rival_distance)/PREDATOR_ANIMAL_TRIAL.rival_sight,-1.,1.)-cost : 0.
    end
    fulfilled=!dead && (action==:hunt ? captured : action==:idle ? false : action==:rest ? (physiology===nothing ? rival.actor===nothing : actual>rule.tolerance) :
        action in (:visit_food,:visit_rest,:cross_river) ? arrived : observed && actual>0)
    LW.action_trial_close!(mind.trial,dead ? "interrupted" : fulfilled ? "achieved" : "failed",LW.D("actual"=>actual,"observed"=>observed))
    if action in (:visit_food,:visit_rest,:cross_river)
        # Waypoint outcomes update only the method MB, not the body's parent H.
        LW.resolve_method!(mind.loop,mind.trial["id"],arrived,nothing;creditable=false,goal_H_increment=0)
    else
        LW.resolve_prediction!(mind.loop,mind.trial["id"],c["expected"],observed ? actual : nothing;
            observed,fulfilled,tolerance=rule.tolerance)
    end
    predator_cost_learn!(mind,action,mind.trial["elapsed"],p.spent-mind.start_spent)
    if action==:hunt
        captured && predator_food_site_gain!(mind,p,p.eaten-mind.start_eaten)
        samples=get(mind.estimates,"hunt_samples",0.)+1
        prior=get(mind.estimates,"hunt",rule.hunt_prior)
        mind.estimates["hunt"]=prior+(actual-prior)/samples
        mind.estimates["hunt_samples"]=samples
    end
    action==:warn && mind.trial["elapsed"]>=PREDATOR_ANIMAL_TRIAL.warning_duration_ticks && (p.warning_timeouts+=1)
    # A reached waypoint is only local success, never recorded as food acquired.
    action==:hunt && captured && predator_remember_place!(mind,p,"food",t)
    action==:rest && fulfilled && predator_remember_place!(mind,p,"rest",t)
    if action in (:visit_food,:visit_rest)
        LW.acquisition_result!(mind.acquisition,string(action),c["site"],c["forecast"],mind.trial["elapsed"],arrived;now=t,energy=p.spent-mind.start_spent)
        LW.acquisition_finish!(mind.acquisition,arrived ? "achieved" : "failed","local_waypoint")
    end
    push!(mind.records,LW.D("tick"=>t,"method"=>c["method"],"status"=>mind.trial["status"],
        "forecast"=>c["forecast"],"elapsed"=>mind.trial["elapsed"],"expected"=>c["expected"],"actual"=>observed ? actual : nothing,
        "H"=>mind.loop.H,"trial_H"=>mind.trial["H"],"fulfilled"=>fulfilled,
        "body_end_reason"=>get(c,"body_end_reason",nothing)))
    mind.records[end]["food_demand_forecast"]=get(c,"food_demand_forecast",nothing)
    length(mind.records)>rule.history_limit && popfirst!(mind.records)
    mind.completed+=1;mind.trial=nothing;mind.selected=nothing
end
function predator_mind_plan!(s,p,predators,mind,t;scents=nothing,index=1,search_attention=nothing,local_planner=nothing,physiology=nothing,idle_gate=PREDATOR_IDLE_GATE.enabled)
    rule=PREDATOR_COGNITION;body=p.visual.body
    rival=trial_visible_rival(s,p,predators,t)
    rival.actor!==nothing && !p.last_rival && p.alive && (p.encounters+=1)
    p.last_rival=rival.actor!==nothing
    configured_predator_idle_hold!(mind,p,rival,t,physiology;enabled=idle_gate) && return
    if mind.trial!==nothing
        LW.action_trial_step!(mind.trial,configured_predator_idle_elapsed!(mind,t),max(0.,p.spent-mind.start_spent-mind.trial["energy"]);now=t)
        captured=body.captures>mind.start_capture
        if mind.selected["action"]==:hunt && p.alive && !captured
            predator_food_site_effort!(mind,p)
        end
        arrived=haskey(mind.selected,"target") && hypot(body.x-mind.selected["target"][1],body.z-mind.selected["target"][2])<=get(mind.selected,"arrival_radius",rule.arrival_radius)
        due=mind.trial["elapsed"]>=mind.selected["forecast"]
        body_reconsider=false
        if physiology!==nothing && body.state!=P.ATTACK
            if mind.selected["action"]==:rest
                recovered=predator_recovery_need(physiology.body)<=PREDATOR_BODY.need_band
                hunger_before=max(0.,(PREDATOR_ANIMAL_TRIAL.initial_food-mind.start_food)/rule.food_pressure_scale)
                hunger_now=max(0.,(PREDATOR_ANIMAL_TRIAL.initial_food-p.food)/rule.food_pressure_scale)
                hunger_changed=rule.food_weight*(hunger_now-hunger_before)>rule.tolerance
                body_reconsider=recovered || hunger_changed
                body_reconsider && (mind.selected["body_end_reason"]=recovered ? "recovered" : "hunger_changed")
            elseif physiology.body.strain>=1
                body_reconsider=true;mind.selected["body_end_reason"]="body_limited"
            end
        end
        # 暫定: 水中で休息へ切替せず、一つの移動試行として岸まで継続。
        crossing_in_water=configured_crossing_committed(s.world,mind,p)
        if !p.alive || captured || arrived || (!crossing_in_water && (body_reconsider || (due && body.state!=P.ATTACK)))
            predator_mind_close!(mind,p,rival,t;dead=!p.alive,physiology)
        end
    end
    if !p.alive;p.mode=:dead;return;end
    if mind.trial===nothing
        rows=predator_candidates(mind,p,rival,scents,index;physiology,world=s.world)
        filter!(c->c["action"]!=:warn || t>=p.warning_blocked_until,rows)
        source=mind.loop.sequence+1
        mind.selected=LW.choose_method!(mind.loop,rows,source)
        c=mind.selected
        physiology!==nothing && (c["body_start_need"]=predator_recovery_need(physiology.body))
        c["rival_heading"]=body.heading
        mind.trial=LW.action_trial(source,c["method"],c["question"],c["forecast"])
        mind.start_food=p.food;mind.start_spent=p.spent;mind.start_eaten=p.eaten
        mind.start_capture=body.captures;mind.start_rival_distance=rival.distance
        if c["action"]==:warn
            p.warning_started=t;p.warning_blocked_until=t+PREDATOR_ANIMAL_TRIAL.warning_duration_ticks+PREDATOR_ANIMAL_TRIAL.warning_cooldown_ticks
        end
    end
    p.mode=mind.selected["action"]
    if p.mode==:hunt
        body.state==P.REST && (body.state=P.SEARCH;body.timer=0)
        G.configured_wildlife_predator_plan!(trial_proxy(s,p),t;search_attention,local_planner)
    else
        body.state=P.REST;body.target=0;body.pursuit=0;body.timer=0
        if haskey(mind.selected,"target")
            target=mind.selected["target"];body.heading=atan(target[2]-body.z,target[1]-body.x)
        elseif rival.actor!==nothing && p.mode in (:warn,:retreat)
            body.heading=atan(rival.actor.visual.body.z-body.z,rival.actor.visual.body.x-body.x)
            mind.selected["rival_heading"]=body.heading
        elseif p.mode in (:warn,:retreat)
            body.heading=mind.selected["rival_heading"]
        end
        p.visual.gaze=P.turn_gaze(p.visual.gaze,body.heading+G.WILDLIFE_PREDATOR.scan_amplitude*sin(t/G.WILDLIFE_PREDATOR.scan_period))
    end
end
predator_mind_report(mind)=(loop=LW.loop_snapshot(mind.loop),places=deepcopy(mind.places),
    food_site_evidence=Dict(k=>v for (k,v) in mind.estimates if startswith(k,"food_site:")),
    single_rest_place=PREDATOR_COGNITION.single_rest_place,
    completed=mind.completed,records=deepcopy(mind.records),active=deepcopy(mind.trial))
