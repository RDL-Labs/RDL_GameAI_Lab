# 暫定固定の痕跡モデル。身体収支とは独立した無次元量、消化/肥料ではない。
# optional scat_state を渡した実験のみON。将来は消化排出・共通観測MBへ接続。
const SCAT_TRACE=(day_ticks=17280,fresh_ticks=8640, rabbit_interval=720,
    predator_interval=2880,cell_size=4.,rabbit_energy=85.,predator_energy=900.,
    minimum_amount=.2,coarse_half_life_days=10.,delete_amount=.01)
struct FreshScat
    x::Float64
    z::Float64
    kind::UInt8
    tick::Int
    amount::Float64
end
mutable struct ScatTraces
    fresh::Dict{Tuple{Int,Int},Vector{FreshScat}}
    coarse::Dict{Tuple{Int,Int,UInt8},Tuple{Float64,Int}}
    last_tick::Int
    deposited::Float64
    faded::Float64
end
ScatTraces()=ScatTraces(Dict(),Dict(),-1,0.,0.)
scat_cell(x,z)=(floor(Int,x/SCAT_TRACE.cell_size),floor(Int,z/SCAT_TRACE.cell_size))
scat_decay(amount,dt)=amount*exp2(-dt/(SCAT_TRACE.day_ticks*SCAT_TRACE.coarse_half_life_days))
function configured_scat_age!(state,t)
    for (key,(amount,updated)) in state.coarse
        remaining=scat_decay(amount,t-updated)
        state.faded+=amount-remaining
        if remaining<SCAT_TRACE.delete_amount
            state.faded+=remaining;delete!(state.coarse,key)
        else
            state.coarse[key]=(remaining,t)
        end
    end
    for (cell,records) in state.fresh
        filter!(records) do record
            t-record.tick<SCAT_TRACE.fresh_ticks && return true
            # Only the time AFTER the fresh window ages the coarse contribution.
            remaining=scat_decay(record.amount,t-record.tick-SCAT_TRACE.fresh_ticks)
            state.faded+=record.amount-remaining
            key=(cell...,record.kind)
            previous=get(state.coarse,key,(0.,t))[1]
            state.coarse[key]=(previous+remaining,t)
            false
        end
        isempty(records) && delete!(state.fresh,cell)
    end
end
function configured_scat_deposit!(state,x,z,kind,t,energy,reference)
    amount=SCAT_TRACE.minimum_amount+(1-SCAT_TRACE.minimum_amount)*clamp(energy/reference,0.,1.)
    cell=scat_cell(x,z)
    push!(get!(() -> FreshScat[],state.fresh,cell),FreshScat(x,z,kind,t,amount))
    state.deposited+=amount
end
function configured_scat_step!(state,s,predators,t;present=nothing)
    t<state.last_tick && error("scat time cannot move backwards")
    t==state.last_tick && return
    state.last_tick=t
    # No scans/allocations on ordinary ticks. One aggregated deposit per interval.
    t%SCAT_TRACE.rabbit_interval==0 || return
    configured_scat_age!(state,t)
    i=findnext(s.alive,1)
    while i!==nothing
        configured_scat_deposit!(state,s.animals.x[i],s.animals.z[i],0x01,t,s.animals.energy[i],SCAT_TRACE.rabbit_energy)
        i=findnext(s.alive,i+1)
    end
    if t%SCAT_TRACE.predator_interval==0
        for (i,p) in enumerate(predators)
            p.alive && (present===nothing || present[i]) || continue
            configured_scat_deposit!(state,p.visual.body.x,p.visual.body.z,0x02,t,p.food,SCAT_TRACE.predator_energy)
        end
    end
end
# Local sensory material only: no actor ID or true deposition timestamp exposed.
function configured_scat_observe(state,x,z,t;radius=4.)
    radius>=0 || error("negative radius")
    observations=NamedTuple[]
    lo=scat_cell(x-radius,z-radius);hi=scat_cell(x+radius,z+radius)
    for cx in lo[1]:hi[1],cz in lo[2]:hi[2]
        cell=(cx,cz)
        for r in get(state.fresh,cell,FreshScat[])
            hypot(r.x-x,r.z-z)<=radius || continue
            age=t-r.tick
            if age>=SCAT_TRACE.fresh_ticks
                remaining=scat_decay(r.amount,age-SCAT_TRACE.fresh_ticks)
                remaining>=SCAT_TRACE.delete_amount && push!(observations,(kind=r.kind,
                    x=(cx+.5)*SCAT_TRACE.cell_size,z=(cz+.5)*SCAT_TRACE.cell_size,
                    amount=remaining,freshness=0.,detail=:coarse))
                continue
            end
            push!(observations,(kind=r.kind,x=r.x,z=r.z,amount=r.amount,
                freshness=clamp(1-age/SCAT_TRACE.fresh_ticks,0.,1.),detail=:fresh))
        end
        for kind in (0x01,0x02)
            amount,updated=get(state.coarse,(cell...,kind),(0.,t))
            remaining=scat_decay(amount,t-updated)
            remaining>=SCAT_TRACE.delete_amount || continue
            push!(observations,(kind=kind,x=(cx+.5)*SCAT_TRACE.cell_size,z=(cz+.5)*SCAT_TRACE.cell_size,
                amount=remaining,freshness=0.,detail=:coarse))
        end
    end
    observations
end
configured_scat_report(state)=(fresh=sum(length(v) for v in values(state.fresh);init=0),
    coarse=length(state.coarse),deposited=state.deposited,faded=state.faded,
    remaining=sum(r.amount for v in values(state.fresh) for r in v;init=0.)+
        sum(v[1] for v in values(state.coarse);init=0.))
