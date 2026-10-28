const RS=64_000_000/17_280_000_000
const SS=1/60

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
    effort=(1+.1*load)*resistance; integrity=1-b.damage
    burst,strain,reserve=b.burst,b.strain,b.reserve
    distance=0.0
    if action=="walk"
        if !(reserve>=.1*effort*RS && strain<1 && integrity>0)
            status="body_limited"
        elseif !clear
            status="blocked";reserve=max(0,reserve-.05*effort*RS)
        else
            status="performed";distance=.5*integrity
            reserve-=.1*effort*RS;strain=min(1,strain+.03*effort*SS)
        end
    elseif action=="run"
        if !(reserve>=.5*effort*RS && burst>=3*effort && strain<=.8 && integrity>0)
            status="body_limited"
        elseif !clear
            status="blocked";reserve=max(0,reserve-.05*effort*RS)
        else
            status="performed";distance=1.5*integrity
            burst-=3*effort;reserve-=.5*effort*RS;strain=min(1,strain+.18*effort*SS)
        end
    elseif action=="climb"
        if !(reserve>=.4*effort*RS && burst>=4*effort && strain<=.8 && integrity>0)
            status="body_limited"
        elseif !clear
            status="blocked";reserve=max(0,reserve-.05*effort*RS)
        else
            status="performed";distance=integrity
            burst-=4*effort;reserve-=.4*effort*RS;strain=min(1,strain+.15*effort*SS)
        end
    elseif action=="process_food"
        if reserve>=.1*RS && strain<1 && integrity>0
            status="worked";reserve-=.1*RS;strain=min(1.,strain+.01*SS)
        else
            status="body_limited"
        end
    elseif action=="eat"
        status="ate";reserve=min(100,reserve+20)
    elseif action=="rest"
        status="rested";recovery=min(1,b.reserve/20)*(1-b.damage)
        burst=min(10*integrity,burst+2*recovery)
        strain=max(0,strain-.15*recovery*SS);reserve=max(0,reserve-.05*recovery*RS)
    else
        error("action")
    end
    out=Body(min(burst,10*integrity),strain,reserve,b.damage)
    @assert 0<=out.reserve<=100 && 0<=out.strain<=1 && 0<=out.burst<=10
    delta=BodyDelta(out.burst-b.burst,out.strain-b.strain,
                    out.reserve-b.reserve,out.damage-b.damage)
    out,status,distance,delta
end

function metabolize(b,seconds)
    seconds>=0 || error("metabolic_clock")
    Body(b.burst,b.strain,max(0.,b.reserve-seconds*.25*RS),b.damage)
end
