# Species-independent updates. Rates are per supplied time unit; geometry and
# action selection belong to the caller. No passive recovery during other work.
function exert(b::Body,reserve_cost,strain_load,burst_load=0.)
    Body(max(0.,b.burst-burst_load),min(1.,b.strain+strain_load),
        max(0.,b.reserve-reserve_cost),b.damage)
end
function recover(b::Body;burst_capacity,energy_scale,burst_rate,strain_rate,reserve_rate,dt=1.,strain_scale=1.,reserve_scale=1.)
    isfinite(dt) && dt>=0 || throw(ArgumentError("recovery time"))
    recovery=min(1,b.reserve/energy_scale)*(1-b.damage)
    Body(min(burst_capacity*(1-b.damage),b.burst+burst_rate*recovery*dt),
        max(0,b.strain-strain_rate*recovery*strain_scale*dt),
        max(0,b.reserve-reserve_rate*recovery*reserve_scale*dt),b.damage)
end
