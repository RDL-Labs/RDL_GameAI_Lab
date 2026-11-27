# Local prototype only. Fatigue is an amount; capacity is derived from the body.
# Per simulated hour, provisional game rates, not physiological measurements.
module ActivityCapacity
using ..ActivityWear
const RULES=(walk=.12,run=.25,work=.08,fish=.03,rest=.25,sleep=.35)
mutable struct State
    physical::ActivityWear.State
    fatigue::Float64
    damage::Float64
end
State(;wear=0.,fatigue=0.,damage=0.)=begin
    all(isfinite,(wear,fatigue,damage)) && 0<=wear<=1 && fatigue>=0 && 0<=damage<=1 || throw(ArgumentError("body state"))
    State(ActivityWear.State(Float64(wear),Float64(wear),0.),Float64(fatigue),Float64(damage))
end
capacity(s::State)=ActivityWear.ability(s.physical)*(1-s.damage)
ratio(s::State)=capacity(s)>0 ? s.fatigue/capacity(s) : Inf
function step!(s::State,action,hours;effort=1.,repair_supply=1.)
    # Validate/update slow wear before applying short fatigue. No cap clamps fatigue.
    ActivityWear.step!(s.physical,action,hours;effort,repair_supply)
    load=action in (:walk,:run,:work,:fish) ? getproperty(RULES,action)*effort*hours : 0.
    recovery=action in (:rest,:sleep) ? getproperty(RULES,action)*hours : 0.
    s.fatigue=max(0.,s.fatigue+load-recovery)
    (fatigue=s.fatigue,capacity=capacity(s),ratio=ratio(s))
end
function forecast(s::State,work_hours,return_hours;effort=1.)
    all(isfinite,(work_hours,return_hours,effort)) && min(work_hours,return_hours,effort)>=0 || throw(ArgumentError("forecast"))
    home=deepcopy(s);step!(home,:walk,return_hours;effort)
    work_home=deepcopy(s);step!(work_home,:walk,work_hours+return_hours;effort)
    (home=home,work_home=work_home)
end
end
