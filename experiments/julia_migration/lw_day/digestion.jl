# Minimal game physiology; taste, stored nutrients and absorbed energy are separate.
mutable struct Digestion
    gut::Float64
    recent::Vector{Float64}
    eaten::Int
    absorbed::Float64
    overflow::Float64
    pleasure::Float64
    records::Vector{Any}
end
Digestion()=Digestion(0.,zeros(2),0,0.,0.,0.,Any[])
const GUT_CAPACITY=2.
const DIGEST_SECONDS=1800.
const MEAL_ENERGY=20.
const FOOD_LIKING=(1.,1.5) # ordinary / meat: scenario preference, not a biological law
can_ingest(g)=g.gut<=GUT_CAPACITY-1+1e-12
function taste(g,kind,reserve)
    kind in (1,2) || error("food kind")
    0<=reserve<=100 || error("reserve")
    FOOD_LIKING[kind]*(1-g.gut/GUT_CAPACITY)*(1-.6g.recent[kind])*(.5+.5*(1-reserve/100))
end
function ingest!(g,kind,reserve,now)
    can_ingest(g) || error("gut full")
    liking=taste(g,kind,reserve)
    g.gut+=1; g.recent[kind]=min(1.,g.recent[kind]+.6)
    g.eaten+=1; g.pleasure+=liking
    push!(g.records,(time=now,kind=kind,liking=liking,gut_after=g.gut,reserve_at_meal=reserve))
    length(g.records)>32 && popfirst!(g.records)
    liking
end
function digest!(g,b,seconds)
    isfinite(seconds) && seconds>=0 || error("digestion time")
    amount=min(g.gut,seconds/DIGEST_SECONDS); g.gut-=amount
    energy=amount*MEAL_ENERGY; used=min(100-b.reserve,energy)
    g.absorbed+=used; g.overflow+=energy-used
    g.recent .*= exp(-seconds/7200)
    Body(b.burst,b.strain,b.reserve+used,b.damage)
end
function digestion_snapshot(g)
    @assert isapprox(g.eaten*MEAL_ENERGY,g.gut*MEAL_ENERGY+g.absorbed+g.overflow;atol=1e-7)
    Dict("gut"=>g.gut,"recent"=>copy(g.recent),"eaten"=>g.eaten,"absorbed"=>g.absorbed,
        "overflow"=>g.overflow,"pleasure"=>g.pleasure,"records"=>copy(g.records))
end
