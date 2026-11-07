# Shared sensory model, not an activity schedule. These are provisional game
# coefficients, not measured species physiology. No learning/action override.
module AmbientVision
const RULE=(day_seconds=17280.,night_fraction=2/3,
    human_dark_range=.25,predator_dark_range=.65,rabbit_dark_range=.50)
function illumination(seconds;day_seconds=RULE.day_seconds,night_start=RULE.night_fraction*day_seconds)
    isfinite(seconds) && isfinite(day_seconds) && day_seconds>0 && 0<night_start<day_seconds || throw(ArgumentError("vision clock"))
    mod(seconds,day_seconds)<night_start ? 1. : 0.
end
function range_factor(species,light)
    isfinite(light) && 0<=light<=1 || throw(ArgumentError("illumination must be in [0,1]"))
    floor=species===:human ? RULE.human_dark_range : species===:predator ? RULE.predator_dark_range : species===:rabbit ? RULE.rabbit_dark_range : throw(ArgumentError("vision species"))
    floor+(1-floor)*light
end
end
