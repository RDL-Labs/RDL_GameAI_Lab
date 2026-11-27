"""Local prototype: cumulative physical wear, separate from fuel and short strain.

Enabled in LW through scene.activity_capacity; not a body-mass fraction.
Rates are game calibration per simulated hour, not measured human physiology.
Repair supply is a caller-provided fraction, not a hidden read of food stocks.
This prototype does not yet debit nutrients for repair.
"""
module ActivityWear
# Walking wear is 1% per simulated hour before load adjustment (game calibration).
const RULES=(walk_per_hour=.01,run_per_hour=.15,work_per_hour=.04,
    fish_per_hour=.015,rest_per_hour=.025,sleep_per_hour=.10)
mutable struct State
    wear::Float64
    accumulated::Float64
    repaired::Float64
end
State()=State(0.,0.,0.)
ability(s::State)=max(0.,1-s.wear)
function rate(action;rules=RULES)
    action==:walk && return rules.walk_per_hour
    action==:run && return rules.run_per_hour
    action==:work && return rules.work_per_hour
    action==:fish && return rules.fish_per_hour
    action in (:rest,:sleep,:eat,:observe) && return 0.
    throw(ArgumentError("unknown action: $action"))
end
function step!(s::State,action,hours;effort=1.,repair_supply=1.,rules=RULES)
    isfinite(hours) && hours>=0 || throw(ArgumentError("hours"))
    isfinite(effort) && effort>=0 || throw(ArgumentError("effort"))
    isfinite(repair_supply) && 0<=repair_supply<=1 || throw(ArgumentError("repair_supply"))
    load=rate(action;rules)*effort*hours
    repair_rate=action==:sleep ? rules.sleep_per_hour : action==:rest ? rules.rest_per_hour : 0.
    added=min(1-s.wear,load)
    repaired=min(s.wear,repair_rate*repair_supply*hours)
    s.wear=clamp(s.wear+added-repaired,0.,1.)
    s.accumulated+=added;s.repaired+=repaired
    (added=added,repaired=repaired,ability=ability(s))
end
end
