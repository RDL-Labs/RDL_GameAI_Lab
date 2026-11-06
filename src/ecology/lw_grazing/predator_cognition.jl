# Adapter only: selection, prediction-result learning, trial lifecycle and
# acquisition residuals call the SAME functions used by human LW actors.
include("../../lw/configured_paths/predator_cognition_parameters.jl")
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
        oldest=first(sort!(collect(keys(mind.places));by=k->(mind.places[k].seen,k)))
        delete!(mind.places,oldest)
    end
    prior=get(mind.places,key,nothing)
    mind.places[key]=(kind=kind,x=body.x,z=body.z,seen=t,successes=prior===nothing ? 1 : prior.successes+1)
end
function predator_candidates(mind,p,rival,scents,i)
    rule=PREDATOR_COGNITION;body=p.visual.body
    hunger=max(0.,(PREDATOR_ANIMAL_TRIAL.initial_food-p.food)/rule.food_pressure_scale)
    rows=Any[LW.D("method"=>"hunt","action"=>:hunt,"question"=>"acquired_food",
        "priority"=>rule.food_weight*hunger,"forecast"=>rule.episode_ticks,"expected"=>get(mind.estimates,"hunt",rule.hunt_prior)),
        LW.D("method"=>"rest","action"=>:rest,"question"=>"rested",
        "priority"=>rule.rest_weight-rule.food_weight*hunger,"forecast"=>rule.episode_ticks,
        "expected"=>rule.rest_benefit)]
    for key in sort!(collect(keys(mind.places)))
        place=mind.places[key];distance=hypot(place.x-body.x,place.z-body.z)
        distance>rule.arrival_radius || continue
        travel=LW.mb_travel_seconds(distance) # Shared coarse human estimate, not exact geometry planning.
        action=place.kind=="food" ? :visit_food : :visit_rest
        value=LW.acquisition_value(mind.acquisition,string(action),key,travel,0.5,hunger)
        pressure=place.kind=="food" ? rule.food_weight*hunger : rule.rest_weight-rule.food_weight*hunger
        push!(rows,LW.D("method"=>"visit:"*key,"action"=>action,"question"=>"reached_remembered_place",
            "priority"=>pressure+value.score+rule.place_prior,"forecast"=>travel,
            "expected"=>rule.place_prior,"target"=>(place.x,place.z),"site"=>key))
    end
    if rival.actor!==nothing
        push!(rows,LW.D("method"=>"retreat","action"=>:retreat,"question"=>"rival_farther",
            "priority"=>rule.rival_weight,"forecast"=>rule.decision_ticks,"expected"=>rule.place_prior))
        own=scents===nothing ? 0. : scents.observed[i].own
        foreign=scents===nothing ? 0. : scents.observed[i].foreign
        push!(rows,LW.D("method"=>"warn","action"=>:warn,"question"=>"rival_farther",
            "priority"=>rule.rival_weight+own-foreign,"forecast"=>PREDATOR_ANIMAL_TRIAL.warning_duration_ticks,
            "expected"=>rule.place_prior))
    end
    rows
end
function predator_mind_close!(mind,p,rival,t;dead=false)
    mind.trial===nothing && return
    rule=PREDATOR_COGNITION;c=mind.selected;action=c["action"]
    cost=(p.spent-mind.start_spent)/rule.food_value_scale
    captured=p.visual.body.captures>mind.start_capture
    arrived=haskey(c,"target") && hypot(p.visual.body.x-c["target"][1],p.visual.body.z-c["target"][2])<=rule.arrival_radius
    observed=true
    actual=if action==:hunt
        (p.eaten-mind.start_eaten)/rule.food_value_scale-cost
    elseif action==:rest
        rule.rest_benefit-cost
    elseif action in (:visit_food,:visit_rest)
        (arrived ? rule.place_prior : 0.)-cost
    else
        observed=rival.actor!==nothing && isfinite(mind.start_rival_distance)
        observed ? clamp((rival.distance-mind.start_rival_distance)/PREDATOR_ANIMAL_TRIAL.rival_sight,-1.,1.)-cost : 0.
    end
    fulfilled=!dead && (action==:hunt ? captured : action==:rest ? rival.actor===nothing :
        action in (:visit_food,:visit_rest) ? arrived : observed && actual>0)
    LW.action_trial_close!(mind.trial,dead ? "interrupted" : fulfilled ? "achieved" : "failed",LW.D("actual"=>actual,"observed"=>observed))
    if action in (:visit_food,:visit_rest)
        # Waypoint outcomes update only the method MB, not the body's parent H.
        LW.resolve_method!(mind.loop,mind.trial["id"],arrived,nothing;creditable=false,goal_H_increment=0)
    else
        LW.resolve_prediction!(mind.loop,mind.trial["id"],c["expected"],observed ? actual : nothing;
            observed,fulfilled,tolerance=rule.tolerance)
    end
    if action==:hunt
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
        "H"=>mind.loop.H,"trial_H"=>mind.trial["H"],"fulfilled"=>fulfilled))
    length(mind.records)>rule.history_limit && popfirst!(mind.records)
    mind.completed+=1;mind.trial=nothing;mind.selected=nothing
end
function predator_mind_plan!(s,p,predators,mind,t;scents=nothing,index=1)
    rule=PREDATOR_COGNITION;body=p.visual.body
    rival=trial_visible_rival(s,p,predators,t)
    rival.actor!==nothing && !p.last_rival && p.alive && (p.encounters+=1)
    p.last_rival=rival.actor!==nothing
    if mind.trial!==nothing
        LW.action_trial_step!(mind.trial,1.,max(0.,p.spent-mind.start_spent-mind.trial["energy"]);now=t)
        captured=body.captures>mind.start_capture
        arrived=haskey(mind.selected,"target") && hypot(body.x-mind.selected["target"][1],body.z-mind.selected["target"][2])<=rule.arrival_radius
        due=mind.trial["elapsed"]>=mind.selected["forecast"]
        if !p.alive || captured || arrived || (due && body.state!=P.ATTACK)
            predator_mind_close!(mind,p,rival,t;dead=!p.alive)
        end
    end
    if !p.alive;p.mode=:dead;return;end
    if mind.trial===nothing
        rows=predator_candidates(mind,p,rival,scents,index)
        filter!(c->c["action"]!=:warn || t>=p.warning_blocked_until,rows)
        source=mind.loop.sequence+1
        mind.selected=LW.choose_method!(mind.loop,rows,source)
        c=mind.selected
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
        G.configured_wildlife_predator_plan!(trial_proxy(s,p),t)
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
    completed=mind.completed,records=deepcopy(mind.records),active=deepcopy(mind.trial))
