# World model, quantities in existing grass units; time in simulation ticks.
# Same total capacity/regrowth as legacy. Maturation transfers mass, never creates it.
const GRASS_LAYERS=(initial_short_fraction=.6,maturation_days=4.,day_ticks=17280,
    regrowth_days=2.,short_cover_weight=.2)
mutable struct GrassLayers
    short::Vector{Float64}
    long::Vector{Float64}
    long_demand::Vector{Float64}
    long_ratio::Vector{Float64}
    short_eaten::Float64
    long_eaten::Float64
    matured::Float64
end
function enable_grass_layers!(w)
    w.layers===nothing || error("grass layers already enabled")
    w.layers=GrassLayers(w.grass.*GRASS_LAYERS.initial_short_fraction,
        w.grass.*(1-GRASS_LAYERS.initial_short_fraction),zeros(length(w.grass)),zeros(length(w.grass)),0.,0.,0.)
end
function layered_grass_update!(w,k,t)
    dt=t-w.updated[k];dt>=0 || error("time reversal")
    dt==0 && return w.grass[k]
    l=w.layers;p=GRASS_LAYERS;rate=w.capacity[k]/(p.regrowth_days*p.day_ticks)
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
    (short=sum(l.short),long=sum(l.long),short_eaten=l.short_eaten,
     long_eaten=l.long_eaten,matured=l.matured)
end
