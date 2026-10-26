module Herbivores
using JSON3, Random
include("../../geometry/RDLMigrationProbe.jl")
using .RDLMigrationProbe
include("../state_ids.jl")
const STATES=("search","graze","rest","sleep","flee")
const OFFSETS=((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1))
include("../herbivore/features.jl")
mutable struct World
    xmin::Float64; zmin::Float64; xmax::Float64; zmax::Float64
    cellsize::Float64; nx::Int; nz::Int; phase::Float64
    material::Vector{UInt8}; walkable::BitVector
    grass::Vector{Float64}; capacity::Vector{Float64}; updated::Vector{Int}
    obstacles::Vector{RDLMigrationProbe.Circle}
    features::Vector{NamedTuple}
    traits::Union{Nothing,WorldFeatures.GrassTraits}
    grown::Float64; eaten::Float64; initial::Float64
end
mutable struct Animals
    x::Vector{Float64}; z::Vector{Float64}; heading::Vector{Float64}
    energy::Vector{Float64}; gut::Vector{Float64}; sleepy::Vector{Float64}
    state::Vector{UInt8}; previous_cell::Vector{Int32}; current_cell::Vector{Int32}
    target::Vector{Int32}; next_sense::Vector{Int}
    distance::Vector{Float64}; consumed::Vector{Float64}; digested::Vector{Float64}
    starvation_ticks::Vector{Int}; blocked::Vector{Int}; counts::Matrix{Int}
end
function material(phase,x,z)
    river=12+5sin((z-6)/22+phase); width=1.2+.4*(1+sin(z/13)); d=abs(x-river)
    d<=width/2 && return WATER
    d<4 && return BANK
    (((x+28)/18)^2+((z-28)/24)^2<1 || ((x-37)/17)^2+((z+20)/25)^2<1) && return FOREST
    ((x+23)/13)^2+((z+25)/15)^2<1 && return ROCK
    GRASSLAND
end
cell(w,x,z)=clamp(floor(Int,(x-w.xmin)/w.cellsize)+1,1,w.nx)+(clamp(floor(Int,(z-w.zmin)/w.cellsize)+1,1,w.nz)-1)*w.nx
center(w,k)=(w.xmin+(mod(k-1,w.nx)+.5)*w.cellsize,w.zmin+(div(k-1,w.nx)+.5)*w.cellsize)
function clear(w,p,q)
    w.xmin+.25<=q[1]<=w.xmax-.25 && w.zmin+.25<=q[2]<=w.zmax-.25 || return false
    material(w.phase,q...)!=WATER && material(w.phase,(p[1]+q[1])/2,(p[2]+q[2])/2)!=WATER || return false
    !any(o->RDLMigrationProbe.segment_hit(p,q,o,.25),w.obstacles)
end
function build(spec; seed=20261005, grass_scale=1.,rich=false)
    s=rich && !hasproperty(spec.scene,:world_features) ? WorldFeatures.enrich_scene(spec.scene;seed) : spec.scene; land=s.landscape; xmin,xmax,zmin,zmax=Float64.(land.extent)
    nx=round(Int,(xmax-xmin)/2); nz=round(Int,(zmax-zmin)/2); n=nx*nz
    objects=[RDLMigrationProbe.Circle(Float64(o.x),Float64(o.z),Float64(o.radius)) for o in vcat(collect(s.obstacles),collect(s.low_obstacles)) if !hasproperty(o,:solid) || o.solid]
    w=World(xmin,zmin,xmax,zmax,2.,nx,nz,land.phase,zeros(UInt8,n),falses(n),zeros(n),zeros(n),zeros(Int,n),objects,rich ? NamedTuple[(x=Float64(o.x),z=Float64(o.z),radius=Float64(o.radius),height=Float64(o.height),color=UInt8(something(findfirst(==(o.color),WorldFeatures.COLORS),0)),kind=o.kind) for o in vcat(collect(s.obstacles),collect(s.low_obstacles))] : NamedTuple[],rich ? WorldFeatures.grass_traits(nx,nz;seed) : nothing,0.,0.,0.)
    rng=MersenneTwister(seed)
    for k in 1:n
        p=center(w,k); m=material(w.phase,p...); w.material[k]=m
        w.walkable[k]=m!=WATER && !any(o->hypot(p[1]-o.x,p[2]-o.z)<=o.radius+.25,objects)
        cap=m==GRASSLAND ? 6. : m==BANK ? 5. : m==FOREST ? 2. : 0.
        w.capacity[k]=w.walkable[k] ? grass_scale*cap*(.75+.5rand(rng)) : 0.
    end
    if rich;w.capacity .*= w.traits.density;end
    w.grass.=w.capacity; w.initial=sum(w.grass)
    n=length(s.positions)
    a=Animals([Float64(p[1]) for p in s.positions],[Float64(p[2]) for p in s.positions],2pi.*rand(rng,n),fill(70.,n),zeros(n),[.5*(i-1)/max(n-1,1) for i in 1:n],fill(SEARCH,n),zeros(Int32,n),zeros(Int32,n),zeros(Int32,n),zeros(Int,n),zeros(n),zeros(n),zeros(n),zeros(Int,n),zeros(Int,n),zeros(Int,n,5))
    for i in 1:n
        clear(w,(a.x[i],a.z[i]),(a.x[i],a.z[i])) || error("original spawn is not traversable")
        a.current_cell[i]=cell(w,a.x[i],a.z[i])
    end
    w,a
end
function grass!(w,k,t)
    # Lazy linear regeneration is exactly the same regardless of observation count.
    elapsed=t-w.updated[k]; elapsed>=0 || error("time reversal")
    add=min(w.capacity[k]-w.grass[k],w.capacity[k]*elapsed/(2*17280))
    w.grass[k]+=add; w.grown+=add; w.updated[k]=t
    w.grass[k]
end
include("../herbivore/perception.jl")
include("../herbivore/decision.jl")
function target!(w,a,i,t,policy=StateMachinePolicy())
    a.target[i]=choose_target(policy,observe_neighbors!(w,a,i,t),a.heading[i],a.previous_cell[i])
    a.next_sense[i]=t+10
end
function step!(w,a,t,demand,ratio,requests,active; policy=StateMachinePolicy(), threat=nothing, alive=nothing)
    fill!(demand,0.); empty!(active)
    n=length(a.x)
    for i in 1:n
        alive!==nothing && !alive[i] && continue
        dig=min(a.gut[i],.02); a.gut[i]-=dig; a.digested[i]+=dig
        a.energy[i]=min(100.,a.energy[i]+3dig)
        a.sleepy[i]=a.state[i]==SLEEP ? max(0.,a.sleepy[i]-1/1200) : min(2.,a.sleepy[i]+1/4000)
        observation=observe_state!(w,a,i,t,threat);k=observation.cell
        a.state[i]=choose_state(policy,observation)
        requests[i]=a.state[i]==GRAZE ? min(.025,4-a.gut[i]) : 0.
        if requests[i]>0
            demand[k]==0 && push!(active,k)
            demand[k]+=requests[i]
        end
    end
    # Simultaneous proportional allocation prevents first-agent access bias.
    for k in active
        amount=min(w.grass[k],demand[k]); ratio[k]=amount/demand[k]
        w.grass[k]-=amount; w.eaten+=amount
    end
    for i in 1:n
        alive!==nothing && !alive[i] && continue
        state=a.state[i]; k=cell(w,a.x[i],a.z[i]); a.counts[i,state]+=1
        if state==GRAZE
            amount=requests[i]*ratio[k]; a.gut[i]+=amount; a.consumed[i]+=amount
        elseif state==SEARCH || state==FLEE
            if state==FLEE
                a.heading[i]=atan(a.z[i]-threat[2],a.x[i]-threat[1])
            else
                (t>=a.next_sense[i] || a.target[i]==0) && target!(w,a,i,t,policy)
                if a.target[i]!=0
                    p=center(w,a.target[i]); a.heading[i]=atan(p[2]-a.z[i],p[1]-a.x[i])
                end
            end
            speed=state==FLEE ? .6 : .2
            p=(a.x[i],a.z[i]); q=(p[1]+speed*cos(a.heading[i]),p[2]+speed*sin(a.heading[i]))
            if state==FLEE && !clear(w,p,q)
                # Choose the clear escape step farthest from the perceived threat.
                best=-Inf; chosen=nothing; base=a.heading[i]
                for offset in (pi/4,-pi/4,pi/2,-pi/2,3pi/4,-3pi/4,pi)
                    h=base+offset; candidate=(p[1]+speed*cos(h),p[2]+speed*sin(h))
                    clear(w,p,candidate) || continue
                    score=hypot(candidate[1]-threat[1],candidate[2]-threat[2])
                    if score>best; best=score; chosen=(candidate,h); end
                end
                if chosen!==nothing; q,a.heading[i]=chosen; end
            end
            if clear(w,p,q)
                a.x[i],a.z[i]=q; a.distance[i]+=speed
                next=cell(w,q...)
                if next!=a.current_cell[i]; a.previous_cell[i]=a.current_cell[i]; a.current_cell[i]=next; end
            else
                a.heading[i]+=pi/2; a.target[i]=0; a.next_sense[i]=t+10; a.blocked[i]+=1
            end
        end
        cost=state==SLEEP ? .002 : state==SEARCH ? .012 : state==FLEE ? .03 : .0047
        a.energy[i]=max(0.,a.energy[i]-cost)
        a.energy[i]==0 && (a.starvation_ticks[i]+=1)
    end
end
function simulate(spec;days=3,seed=20261005,grass_scale=1.,out=nothing)
    w,a=build(spec;seed,grass_scale); n=length(a.x)
    demand=zeros(length(w.grass)); ratio=similar(demand); requests=zeros(n); active=Int[]
    initial=copy(w.grass); rows=Any[]; samples=Any[]
    ticks=days*div(Int(spec.clock.day_us),1_000_000)
    for t in 0:ticks-1
        step!(w,a,t,demand,ratio,requests,active)
        if t%60==0
            for i in 1:n; push!(samples,(t,i,a.x[i],a.z[i],a.state[i],a.energy[i],a.gut[i],a.sleepy[i])); end
        end
        if (t+1)%17280==0
            push!(rows,(day=div(t+1,17280),energy_min=minimum(a.energy),energy_mean=sum(a.energy)/n,eaten=w.eaten,distance=sum(a.distance),starvation_ticks=sum(a.starvation_ticks),state_ticks=vec(sum(a.counts,dims=1))))
        end
    end
    for k in eachindex(w.grass); grass!(w,k,ticks); end
    @assert isapprox(w.initial+w.grown,sum(w.grass)+w.eaten;atol=1e-6,rtol=1e-10)
    @assert isapprox(w.eaten,sum(a.consumed);atol=1e-6)
    @assert isapprox(sum(a.consumed),sum(a.gut)+sum(a.digested);atol=1e-6)
    @assert all(sum(a.counts[i,:])==ticks for i in 1:n)
    @assert all(isfinite,a.energy) && all(x->0<=x<=100,a.energy)
    @assert all(i->clear(w,(a.x[i],a.z[i]),(a.x[i],a.z[i])),1:n)
    report=(agents=n,days=days,ticks=ticks,agent_updates=n*ticks,grass_cells=count(>(0),w.capacity),cells=length(w.grass),grass_initial=w.initial,grass_grown=w.grown,grass_remaining=sum(w.grass),grass_eaten=w.eaten,state_names=STATES,daily=rows,final=[(id=i,x=a.x[i],z=a.z[i],energy=a.energy[i],gut=a.gut[i],distance=a.distance[i],eaten=a.consumed[i],starvation_ticks=a.starvation_ticks[i],blocked=a.blocked[i],state_ticks=a.counts[i,:]) for i in 1:n])
    if out!==nothing
        mkpath(out)
        open(joinpath(out,"result.json"),"w") do io; JSON3.write(io,report); end
        open(joinpath(out,"grass.csv"),"w") do io
            println(io,"x,z,material,walkable,initial,final,capacity")
            for k in eachindex(w.grass); x,z=center(w,k); println(io,join((x,z,w.material[k],Int(w.walkable[k]),initial[k],w.grass[k],w.capacity[k]),',')); end
        end
        open(joinpath(out,"trajectory.csv"),"w") do io
            println(io,"tick,id,x,z,state,energy,gut,sleepy")
            for row in samples; println(io,join(row,',')); end
        end
    end
    report
end
end
