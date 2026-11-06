# Deliberate game rules, not a biological fish/angling model.
include("fishing_parameters.jl")

game_fishing_probability(effect)=FISHING_RULES.base_probability+FISHING_RULES.skill_probability_gain*clamp(effect/FISHING_RULES.skill_saturation,0.,1.)
game_river_fishing_probability(base,fraction,effect)=clamp(base*fraction*(1+FISHING_RULES.river_skill_gain*clamp(effect/FISHING_RULES.river_skill_saturation,0.,1.)),0.,1.)

function game_fishing_forecast(skills,experience;prior_base=FISHING_RULES.base_probability)
    skill=game_skill_forecast(get(skills,"fishing",game_skill_mb()),"fishing")
    prior=game_river_fishing_probability(prior_base,1.,skill.effect)
    # Owner-observed catches update a local estimate; no water stock is consulted.
    recent=get(experience,"recent",nothing)
    caught=recent===nothing ? get(experience,"caught",0) : count(identity,recent)
    attempts=recent===nothing ? get(experience,"attempts",0) : length(recent)
    p=(GAME_FISHING_PRIOR_TRIALS*prior+caught)/(GAME_FISHING_PRIOR_TRIALS+attempts)
    (probability=p,seconds=GAME_FISHING_TICKS/max(FISHING_RULES.minimum_forecast_probability,p),skill=skill)
end

# Same-day fish: crossing a world calendar boundary invalidates acquired fish.
game_fish_expired(previous_day,day)=day>previous_day
