# World model, quantities in existing grass units; time in simulation ticks.
# Separate short/long capacities retain the legacy total. New short shoots regrow
# even when long grass is full. Maturation stops at long capacity (world simplification).
# regrowth_days is an exponential time constant, not time to full; calibrated fixture.
const GRASS_LAYERS=(initial_short_fraction=.6,maturation_days=4.,day_ticks=17280,
    regrowth_days=.1,short_cover_weight=.2,short_capacity_fraction=.6)
mutable struct GrassLayers
    short::Vector{Float64}
    long::Vector{Float64}
    long_demand::Vector{Float64}
    long_ratio::Vector{Float64}
    short_eaten::Float64
    long_eaten::Float64
    matured::Float64
    regrowth_days::Float64
    renewal::Bool
end
function enable_grass_layers!(w;regrowth_days=GRASS_LAYERS.regrowth_days,renewal=true)
    w.layers===nothing || error("grass layers already enabled")
    isfinite(regrowth_days) && regrowth_days>0 || error("positive regrowth time required")
    w.layers=GrassLayers(w.grass.*GRASS_LAYERS.initial_short_fraction,
        w.grass.*(1-GRASS_LAYERS.initial_short_fraction),zeros(length(w.grass)),zeros(length(w.grass)),0.,0.,0.,regrowth_days,renewal)
end
function grass_short_solution(initial,capacity,growth,maturation,dt)
    rate=growth+maturation;equilibrium=growth*capacity/rate
    response=-expm1(-rate*dt)
    short=initial+(equilibrium-initial)*response
    transfer=maturation*(equilibrium*dt+(initial-equilibrium)*response/rate)
    short,max(0.,transfer)
end
function renewing_grass_update!(w,k,t)
    l=w.layers;p=GRASS_LAYERS;dt=t-w.updated[k];dt>=0 || error("time reversal")
    dt==0 && return w.grass[k]
    short_capacity=w.capacity[k]*p.short_capacity_fraction
    long_capacity=w.capacity[k]-short_capacity
    growth=1/(l.regrowth_days*p.day_ticks);maturation=1/(p.maturation_days*p.day_ticks)
    available=max(0.,long_capacity-l.long[k]);short_before=l.short[k]
    short_after,transfer=grass_short_solution(short_before,short_capacity,growth,maturation,dt)
    if transfer>available
        # Maturation stops at long-layer capacity; solve its hit time independently
        # of observation frequency. Then short shoots refill their own capacity.
        lo=0.;hi=Float64(dt)
        if available>0
            for _ in 1:48
                mid=(lo+hi)/2
                grass_short_solution(short_before,short_capacity,growth,maturation,mid)[2]<available ? (lo=mid) : (hi=mid)
            end
        else
            hi=0.
        end
        at_capacity=grass_short_solution(short_before,short_capacity,growth,maturation,hi)[1]
        short_after=short_capacity+(at_capacity-short_capacity)*exp(-growth*(dt-hi))
        transfer=available
    end
    short_after=clamp(short_after,0.,short_capacity)
    gain=max(0.,short_after-short_before+transfer)
    l.short[k]=short_after;l.long[k]+=transfer;l.matured+=transfer
    w.grass[k]=l.short[k]+l.long[k];w.grown+=gain;w.updated[k]=t
    w.grass[k]
end
function layered_grass_update!(w,k,t)
    w.layers.renewal && return renewing_grass_update!(w,k,t)
    dt=t-w.updated[k];dt>=0 || error("time reversal")
    dt==0 && return w.grass[k]
    l=w.layers;p=GRASS_LAYERS;rate=w.capacity[k]/(l.regrowth_days*p.day_ticks)
    gain=min(max(0.,w.capacity[k]-w.grass[k]),rate*dt)
    growing=rate>0 ? min(Float64(dt),gain/rate) : 0.
    decay=1/(p.maturation_days*p.day_ticks)
    short_after=(l.short[k]*exp(-decay*growing)+rate*(-expm1(-decay*growing))/decay)*exp(-decay*(dt-growing))
    total=w.grass[k]+gain
    short_after=clamp(short_after,0.,total)
    l.matured+=max(0.,l.short[k]+gain-short_after)
    l.short[k]=short_after;l.long[k]=total-short_after
    w.grass[k]=total;w.grown+=gain;w.updated[k]=t
    total
end
function grass_layer_snapshot(w)
    w.layers===nothing && return nothing
    l=w.layers
    @assert all(isfinite,l.short) && all(isfinite,l.long)
    @assert all(>=(0.),l.short) && all(>=(0.),l.long)
    @assert all(k->isapprox(l.short[k]+l.long[k],w.grass[k];atol=1e-8),eachindex(w.grass))
    @assert isapprox(l.short_eaten+l.long_eaten,w.eaten;rtol=1e-8,atol=1e-6)
    (renewal=l.renewal,regrowth_days=l.regrowth_days,short=sum(l.short),long=sum(l.long),short_eaten=l.short_eaten,
     long_eaten=l.long_eaten,matured=l.matured)
end
