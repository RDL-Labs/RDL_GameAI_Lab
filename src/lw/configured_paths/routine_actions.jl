# Scenario policies retained for compatibility; these are not learned MB decisions.
configured_plan(action,rule;kwargs...)=D("action"=>action,"configured_rule"=>rule,(string(k)=>v for (k,v) in kwargs)...)
function configured_routine_priority(hungry,edible,can_eat,at_home,stock,phase,local_us,quiet_us,pending,overrides;enabled=true)
    enabled || return nothing
    hungry && edible && can_eat && return configured_plan("eat","immediate_meal")
    at_home && hungry && stock>0 && return configured_plan("retrieve","hungry_store_retrieve")
    phase=="night" && local_us>=quiet_us && !overrides.bypass_scheduled_rest && return configured_plan("rest","quiet_night")
    pending && !overrides.bypass_social_wait && return configured_plan("rest","pending_social_reply")
    nothing
end
function configured_navigation_priority(returning,at_home,inventory,phase,overrides;enabled=true)
    enabled || return nothing
    returning && at_home && return configured_plan(inventory>0 ? "deposit" : "rest","home_service")
    phase=="orientation" && !overrides.bypass_scheduled_rest && return configured_plan("rest","scheduled_orientation")
    nothing
end
function configured_near_food(returning,target,origins;enabled=true)
    enabled && !returning && target!==nothing && target["distance"]<=1.25 || return nothing
    configured_plan(haskey(origins,target["ref"]+1) ? "recover" : "pickup","near_food_work";food_ref=target["ref"])
end
function configured_legacy_navigation(returning,home,moves,origins)
    returning && home===nothing && return configured_plan("scan","legacy_unseen_home")
    visible=moves["visible"];target=returning ? home : isempty(visible) ? nothing : first(visible)
    p=configured_near_food(returning,target,origins);p!==nothing && return p
    scored=[r for r in moves["energy"]["rows"] if r["cost"]!==nothing]
    isempty(scored) && return configured_plan("scan","legacy_no_step")
    sort!(scored,by=r->begin
        ang=deg2rad(Float64(ANGLES[parse(Int,r["ref"])+1]))
        target===nothing ? r["cost"] : hypot(target["forward"]-cos(ang),target["right"]-sin(ang))
    end)
    configured_plan("walk","legacy_local_steering";direction=parse(Int,first(scored)["ref"]))
end
configured_legacy_generosity(actor)=actor!="npc_b"
configured_work_candidate(plan,question)=merge(plan,D("method"=>"work","priority"=>5.,"question"=>question))
function configured_camp_learning_rest(enabled,tour_completed,place_complete,at_home)
    enabled && tour_completed && !place_complete && at_home || return nothing
    merge(configured_plan("rest","camp_learning_rest"),D("method"=>"configured_camp_place_rest","configured_observation"=>true,"configured_place_rest"=>true))
end
