# Coarse cost prediction from actual completed/interrupted episodes. No path search.
# Existing estimates dictionary preserves checkpoint compatibility. Priors use named
# body/movement parameters; empirical rate includes terrain, recovery and movement.
function predator_cost_rate(mind,action)
    base=PREDATOR_ANIMAL_TRIAL.daily_food/PREDATOR_ANIMAL_TRIAL.day_ticks
    moving=action in (:hunt,:visit_food,:visit_rest,:cross_river)
    prior=base+(moving ? PREDATOR_ANIMAL_TRIAL.move_food*PREDATOR_COGNITION.move_speed : 0.)
    elapsed=get(mind.estimates,"cost_ticks:"*string(action),0.)
    elapsed>0 ? get(mind.estimates,"cost_spent:"*string(action),0.)/elapsed : prior
end
function predator_cost_learn!(mind,action,elapsed,spent)
    elapsed>0 || return
    key=string(action)
    mind.estimates["cost_ticks:"*key]=get(mind.estimates,"cost_ticks:"*key,0.)+elapsed
    mind.estimates["cost_spent:"*key]=get(mind.estimates,"cost_spent:"*key,0.)+max(0.,spent)
end

