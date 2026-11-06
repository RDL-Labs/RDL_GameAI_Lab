const RS=BODY_ACTION.reserve_scale_numerator_us/BODY_ACTION.reserve_scale_day_us
const SS=1/BODY_ACTION.strain_scale_ticks

"Immutable four-component body change; dictionary-compatible at record boundaries."
struct BodyDelta <: AbstractDict{String,Float64}
    burst::Float64
    strain::Float64
    reserve::Float64
    damage::Float64
end
Base.length(::BodyDelta)=4
Base.iterate(d::BodyDelta,i=1)=i>4 ? nothing : ((fieldname(BodyDelta,i)|>String)=>getfield(d,i),i+1)
function Base.getindex(d::BodyDelta,k::String)
    k=="burst" && return d.burst
    k=="strain" && return d.strain
    k=="reserve" && return d.reserve
    k=="damage" && return d.damage
    throw(KeyError(k))
end
Base.haskey(::BodyDelta,k)=k in ("burst","strain","reserve","damage")
Base.get(d::BodyDelta,k,default)=haskey(d,k) ? d[k] : default
# A0 ports walk/rest/eat only; other production body actions are not claimed.
function step(b::Body, action, load, resistance=1.0, clear=true)
    effort=(1+BODY_ACTION.load_effort*load)*resistance; integrity=1-b.damage
    burst,strain,reserve=b.burst,b.strain,b.reserve
    distance=0.0
    if action=="walk"
        if !(reserve>=BODY_ACTION.walk_reserve*effort*RS && strain<1 && integrity>0)
            status="body_limited"
        elseif !clear
            status="blocked";reserve=max(0,reserve-BODY_ACTION.blocked_reserve*effort*RS)
        else
            status="performed";distance=BODY_ACTION.walk_distance*integrity
            reserve-=BODY_ACTION.walk_reserve*effort*RS;strain=min(1,strain+BODY_ACTION.walk_strain*effort*SS)
        end
    elseif action=="run"
        if !(reserve>=BODY_ACTION.run_reserve*effort*RS && burst>=BODY_ACTION.run_burst*effort && strain<=BODY_ACTION.run_max_strain && integrity>0)
            status="body_limited"
        elseif !clear
            status="blocked";reserve=max(0,reserve-BODY_ACTION.blocked_reserve*effort*RS)
        else
            status="performed";distance=BODY_ACTION.run_distance*integrity
            burst-=BODY_ACTION.run_burst*effort;reserve-=BODY_ACTION.run_reserve*effort*RS;strain=min(1,strain+BODY_ACTION.run_strain*effort*SS)
        end
    elseif action=="climb"
        if !(reserve>=BODY_ACTION.climb_reserve*effort*RS && burst>=BODY_ACTION.climb_burst*effort && strain<=BODY_ACTION.climb_max_strain && integrity>0)
            status="body_limited"
        elseif !clear
            status="blocked";reserve=max(0,reserve-BODY_ACTION.blocked_reserve*effort*RS)
        else
            status="performed";distance=integrity
            burst-=BODY_ACTION.climb_burst*effort;reserve-=BODY_ACTION.climb_reserve*effort*RS;strain=min(1,strain+BODY_ACTION.climb_strain*effort*SS)
        end
    elseif action=="fish"
        if reserve>=BODY_ACTION.fish_reserve*RS && strain<1 && integrity>0
            status="worked"
            recovery=min(1,b.reserve/BODY_ACTION.rest_energy_scale)*integrity
            reserve-=BODY_ACTION.fish_reserve*RS
            strain=max(0.,strain-BODY_ACTION.fish_strain_recovery*recovery*SS)
        else
            status="body_limited"
        end
    elseif action=="process_food"
        if reserve>=BODY_ACTION.work_reserve*RS && strain<1 && integrity>0
            status="worked";reserve-=BODY_ACTION.work_reserve*RS;strain=min(1.,strain+BODY_ACTION.work_strain*SS)
        else
            status="body_limited"
        end
    elseif action=="eat"
        status="ate";reserve=min(BODY_ACTION.reserve_capacity,reserve+BODY_ACTION.meal_energy)
    elseif action=="rest"
        status="rested";recovery=min(1,b.reserve/BODY_ACTION.rest_energy_scale)*(1-b.damage)
        burst=min(BODY_ACTION.burst_capacity*integrity,burst+BODY_ACTION.rest_burst*recovery)
        strain=max(0,strain-BODY_ACTION.rest_strain*recovery*SS);reserve=max(0,reserve-BODY_ACTION.rest_reserve*recovery*RS)
    else
        error("action")
    end
    out=Body(min(burst,BODY_ACTION.burst_capacity*integrity),strain,reserve,b.damage)
    @assert 0<=out.reserve<=BODY_ACTION.reserve_capacity && 0<=out.strain<=1 && 0<=out.burst<=BODY_ACTION.burst_capacity
    delta=BodyDelta(out.burst-b.burst,out.strain-b.strain,
                    out.reserve-b.reserve,out.damage-b.damage)
    out,status,distance,delta
end

function metabolize(b,seconds)
    seconds>=0 || error("metabolic_clock")
    Body(b.burst,b.strain,max(0.,b.reserve-seconds*BODY_ACTION.metabolic_reserve_per_second*RS),b.damage)
end
