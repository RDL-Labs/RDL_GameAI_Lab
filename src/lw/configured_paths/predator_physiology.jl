# Provisional species calibration, per one simulation tick (17280 ticks/day).
# Same Body/recovery kernel as humans; no forced sleep schedule or rest benefit.
# Food remains in legacy food-equivalent units, with one authoritative transaction
# in configured_trial_advance!. The Body reserve is its checked checkpoint mirror.
# Default ON in scent_run; shared_body=false restores the legacy experiment.
# No digestion yet. Replace coefficients with calibrated species/body parameters.
const PREDATOR_BODY=(burst_capacity=10.,recovery_energy=360.,
    rest_burst=2.,rest_strain=.15/60,rest_energy=.05*(64/17280)*18,
    move_strain=.001,attack_strain=.003,attack_burst=.6,
    rest_need_weight=4.,need_band=1e-6)
mutable struct PredatorPhysiology
    body::LW.Body
    limited_ticks::Int
end
PredatorPhysiology(p)=PredatorPhysiology(LW.Body(PREDATOR_BODY.burst_capacity,0.,p.food,0.),0)
predator_recovery_need(b)=b.strain+max(0.,1-b.burst/(PREDATOR_BODY.burst_capacity*max(1e-9,1-b.damage)))
function predator_rest_forecast(b,budget)
    r=PREDATOR_BODY;factor=min(1.,b.reserve/r.recovery_energy)*(1-b.damage)
    factor<=0 && return 1.
    clamp(ceil(max(b.strain/(r.rest_strain*factor),
        max(0.,r.burst_capacity*(1-b.damage)-b.burst)/(r.rest_burst*factor))),1.,Float64(budget))
end
function predator_recover(b,dt=1.)
    r=PREDATOR_BODY
    LW.RDLBody.recover(b;burst_capacity=r.burst_capacity,energy_scale=r.recovery_energy,
        burst_rate=r.rest_burst,strain_rate=r.rest_strain,reserve_rate=r.rest_energy,dt)
end
function predator_physiology_update!(state,p,moved,attacking,resting)
    b=state.body
    # Meal/maintenance/movement cost has already been applied once by the world.
    b=LW.Body(b.burst,b.strain,p.food,b.damage)
    out=resting ? predator_recover(b) : LW.RDLBody.exert(b,0.,
        moved*PREDATOR_BODY.move_strain+(attacking ? PREDATOR_BODY.attack_strain : 0.),
        attacking ? PREDATOR_BODY.attack_burst : 0.)
    extra=b.reserve-out.reserve;p.food=out.reserve;p.spent+=extra
    p.food<=0 && (p.alive=false)
    state.body=out
end
predator_physiology_report(s)=(burst=s.body.burst,strain=s.body.strain,reserve=s.body.reserve,
    damage=s.body.damage,need=predator_recovery_need(s.body),limited_ticks=s.limited_ticks)
include("predator_composition.jl")
