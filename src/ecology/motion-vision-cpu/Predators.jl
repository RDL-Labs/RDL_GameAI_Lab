module Predators
using JSON3, Random
include("Herbivores.jl")
const H=Herbivores
const SEARCH=UInt8(1); const CHASE=UInt8(2); const ATTACK=UInt8(3); const RECOVER=UInt8(4); const REST=UInt8(5)
const NAMES=("search","chase","attack","recover","rest")
mutable struct Predator
    x::Float64; z::Float64; heading::Float64; state::UInt8
    timer::Int; target::Int; seen_x::Float64; seen_z::Float64; expires::Int; pursuit::Int
    attacks::Int; captures::Int; misses::Int; blocked::Int; distance::Float64
    counts::Vector{Int}
end
function spawn(w)
    # Fixed map position, independent of live prey positions.
    candidates=findall(w.walkable)
    k=candidates[argmin([hypot(H.center(w,j)[1]+8,H.center(w,j)[2]-6) for j in candidates])]
    x,z=H.center(w,k)
    Predator(x,z,0.,SEARCH,0,0,x,z,0,0,0,0,0,0,0.,zeros(Int,5))
end
los(w,p,q)=!any(o->H.RDLMigrationProbe.segment_hit(p,q,o,0.),w.obstacles)
function visible(w,p,a,i,t; motion=false, moved=true)
    k=H.cell(w,a.x[i],a.z[i])
    cover=w.capacity[k]>0 ? H.grass!(w,k,t)/w.capacity[k] : 0.
    tracked=p.target==i && t<p.expires
    hypot(a.x[i]-p.x,a.z[i]-p.z)<=16/(1+.8cover)*vision_factor(motion,moved,tracked) && los(w,(p.x,p.z),(a.x[i],a.z[i]))
end
vision_factor(enabled,moved,tracked)=!enabled || moved || tracked ? 1. : .55
function recover!(p)
    p.state=RECOVER; p.timer=120; p.target=0; p.pursuit=0
end
function move!(w,p,speed; turn=true)
    old=(p.x,p.z)
    for offset in (turn ? (0.,pi/4,-pi/4,pi/2,-pi/2,pi) : (0.,))
        h=p.heading+offset; q=(p.x+speed*cos(h),p.z+speed*sin(h))
        if H.clear(w,old,q)
            p.x,p.z=q; p.heading=h; p.distance+=speed; return true
        end
    end
    p.blocked+=1; p.heading+=pi/2; false
end
include("perception.jl")
include("decision.jl")
function plan!(w,p,a,alive,t,rng; motion=false, moved=nothing)
    observations=p.state in (REST,RECOVER,ATTACK) ? nothing : observe_prey(w,p,a,alive,t;motion,moved)
    decide!(p,observations,t,rng)
end
function advance!(w,p,a,alive,t,rng,events)
    if p.state==ATTACK
        start=(p.x,p.z)
        if !move!(w,p,1.;turn=false)
            p.misses+=1; push!(events,(tick=t,kind="blocked",id=0)); recover!(p); return
        end
        # Resolve at most one contact per attack, using the swept movement segment.
        for i in eachindex(alive)
            alive[i] || continue
            hit=H.RDLMigrationProbe.segment_hit(start,(p.x,p.z),H.RDLMigrationProbe.Circle(a.x[i],a.z[i],.55),0.)
            hit && los(w,(p.x,p.z),(a.x[i],a.z[i])) || continue
            away=atan(a.z[i]-start[2],a.x[i]-start[1])
            escaping=a.state[i]==H.FLEE && cos(a.heading[i]-away)>.5
            if rand(rng)<(escaping ? .28 : .78)
                alive[i]=false; p.captures+=1; p.state=REST; p.timer=8640; p.target=0; p.pursuit=0
                push!(events,(tick=t,kind="capture",id=i))
            else
                p.misses+=1; recover!(p); push!(events,(tick=t,kind="escape",id=i))
            end
            return
        end
        p.timer-=1
        if p.timer<=0; p.misses+=1; recover!(p); push!(events,(tick=t,kind="miss",id=0)); end
    elseif p.state==SEARCH || p.state==CHASE
        move!(w,p,p.state==CHASE ? .5 : .22)
    end
end
function simulate(spec;days=3,seed=20261005,predator=true,out=nothing)
    w,a=H.build(spec;seed); p=spawn(w); rng=MersenneTwister(seed+1); alive=trues(length(a.x))
    demand=zeros(length(w.grass)); ratio=similar(demand); requests=zeros(length(alive)); active=Int[]
    events=NamedTuple[]; daily=NamedTuple[]; samples=Tuple[]; ticks=days*17280; starvation_deaths=0
    for t in 0:ticks-1
        predator && plan!(w,p,a,alive,t,rng)
        # Both species sense positions before movement; contact resolves after movement.
        H.step!(w,a,t,demand,ratio,requests,active;alive,threat=predator ? (p.x,p.z) : nothing)
        predator && advance!(w,p,a,alive,t,rng,events)
        for i in eachindex(alive)
            if alive[i] && a.energy[i]<=0
                alive[i]=false; starvation_deaths+=1; push!(events,(tick=t,kind="energy_death",id=i))
            end
        end
        if t%60==0
            push!(samples,(t,0,p.x,p.z,p.state,1))
            for i in eachindex(alive); push!(samples,(t,i,a.x[i],a.z[i],a.state[i],Int(alive[i]))); end
        end
        if (t+1)%17280==0
            energies=a.energy[alive]
            push!(daily,(day=div(t+1,17280),survivors=count(alive),captures=p.captures,starvation_deaths=starvation_deaths,attacks=p.attacks,
                energy_min=isempty(energies) ? nothing : minimum(energies),starvation_ticks=sum(a.starvation_ticks),
                rabbit_state_ticks=vec(sum(a.counts,dims=1)),predator_state_ticks=copy(p.counts)))
        end
    end
    for k in eachindex(w.grass); H.grass!(w,k,ticks); end
    @assert isapprox(w.initial+w.grown,sum(w.grass)+w.eaten;atol=1e-6)
    @assert isapprox(w.eaten,sum(a.consumed);atol=1e-6)
    @assert isapprox(sum(a.consumed),sum(a.gut)+sum(a.digested);atol=1e-6)
    @assert count(!,alive)==p.captures+starvation_deaths
    @assert p.attacks==p.captures+p.misses+(p.state==ATTACK ? 1 : 0)
    @assert all(i->H.clear(w,(a.x[i],a.z[i]),(a.x[i],a.z[i])),eachindex(alive))
    report=(seed=seed,days=days,predator_enabled=predator,survivors=count(alive),captures=p.captures,starvation_deaths=starvation_deaths,
        attacks=p.attacks,misses=p.misses,grass_eaten=w.eaten,daily=daily,events=events,
        predator=(x=p.x,z=p.z,distance=p.distance,blocked=p.blocked,state_ticks=p.counts),
        final=[(id=i,alive=alive[i],x=a.x[i],z=a.z[i],energy=a.energy[i],distance=a.distance[i],state_ticks=a.counts[i,:]) for i in eachindex(alive)])
    if out!==nothing
        mkpath(out)
        write(joinpath(out,"result.json"),JSON3.write(report))
        open(joinpath(out,"trajectory.csv"),"w") do io
            println(io,"tick,id,x,z,state,alive")
            for row in samples; println(io,join(row,',')); end
        end
    end
    report
end
end
