module LWGrazing
using Random
# Reuse the tested six-state body, grazing allocation, escape steps and vision rules.
# No predator is instantiated by this adapter.
include("../directional-vision-cpu/DirectionalVision.jl")
const V=DirectionalVision
const H=V.H
const P=V.P

mutable struct GrazingWorld
    world::H.World
    animals::H.Animals
    alive::BitVector
    gaze::Vector{Float64}
    last_seen::Vector{Int}
    seen_actor::Vector{Int}
    seen_position::Vector{Tuple{Float64,Float64}}
    flee_until::Vector{Int}
    calm_since::Vector{Int}
    overrides::Vector{UInt8}
    threats::Vector{Tuple{Float64,Float64}}
    demand::Vector{Float64}
    ratio::Vector{Float64}
    requests::Vector{Float64}
    active::Vector{Int}
    previous_humans::Vector{Tuple{Float64,Float64}}
    seen_ticks::Vector{Int}
    alert_entries::Vector{Int}
    flee_entries::Vector{Int}
    human_seen::Vector{Int}
    initial_positions::Vector{Tuple{Float64,Float64}}
    ticks::Int
    prepared::Bool
    deaths::Int
end

function build(scene,clock;low_obstacles=true)
    cfg=get(scene,:wildlife,nothing)
    (cfg===nothing || !get(cfg,:enabled,false)) && return nothing
    get(cfg,:enabled,false)===true || error("wildlife.enabled must be Bool")
    hasproperty(scene,:landscape) || error("grazing requires a riparian landscape")
    scene.landscape.rule=="lw-riparian-base-v1" || error("unsupported grazing landscape")
    clock.day_us==17_280_000_000 || error("grazing body requires the 17280-second day")
    get(scene,:world_history,nothing)===nothing || error("grazing cohort transfer is not supported; use daily checkpoints")
    n=get(cfg,:count,30);seed=get(cfg,:seed,20261028)
    n isa Integer && !(n isa Bool) && 1<=n<=10000 || error("wildlife.count must be 1..10000")
    seed isa Integer && !(seed isa Bool) && seed>=0 || error("wildlife.seed must be nonnegative")
    scale=Float64(get(cfg,:grass_scale,1.))
    isfinite(scale) && scale>0 || error("wildlife.grass_scale must be positive")
    rmin=Float64(get(cfg,:spawn_min_distance,8.));rmax=Float64(get(cfg,:spawn_max_distance,40.))
    isfinite(rmin) && isfinite(rmax) && 0<=rmin<rmax || error("wildlife spawn annulus")
    # rich=true would alter existing trees and food. Keep the exact LW geometry,
    # add only the existing numeric grass-patch traits to this world's grass.
    s=merge((;pairs(scene)...),(positions=Tuple{Float64,Float64}[],
        low_obstacles=low_obstacles ? scene.low_obstacles : Any[]))
    w,_=H.build((scene=s,);seed,grass_scale=scale,rich=false)
    w.traits=H.WorldFeatures.grass_traits(w.nx,w.nz;seed)
    w.capacity .*= w.traits.density;w.grass.=w.capacity;w.initial=sum(w.grass)
    candidates=Int[]
    for k in eachindex(w.grass)
        p=H.center(w,k)
        w.capacity[k]>0 && rmin<=hypot(p[1]-scene.home[1],p[2]-scene.home[2])<=rmax &&
            H.clear(w,p,p) && push!(candidates,k)
    end
    length(candidates)>=n || error("not enough distinct grazing spawn cells")
    rng=MersenneTwister(seed);shuffle!(rng,candidates)
    positions=[H.center(w,candidates[i]) for i in 1:n]
    a=H.Animals(first.(positions),last.(positions),2pi.*rand(rng,n),fill(70.,n),zeros(n),
        [.5*(i-1)/max(n-1,1) for i in 1:n],fill(H.SEARCH,n),zeros(Int32,n),
        Int32.(candidates[1:n]),zeros(Int32,n),zeros(Int,n),zeros(n),zeros(n),zeros(n),
        zeros(Int,n),zeros(Int,n),zeros(Int,n,6))
    humans=[(Float64(p[1]),Float64(p[2])) for p in scene.positions]
    GrazingWorld(w,a,trues(n),copy(a.heading),fill(-1000,n),zeros(Int,n),fill((0.,0.),n),
        fill(-1000,n),fill(-1000,n),zeros(UInt8,n),fill((0.,0.),n),zeros(length(w.grass)),
        zeros(length(w.grass)),zeros(n),Int[],humans,zeros(Int,n),zeros(Int,n),zeros(Int,n),
        zeros(Int,length(humans)),positions,0,false,0)
end

function prepare!(s::GrazingWorld,humans,t::Int)
    t==s.ticks && !s.prepared || error("grazing perception must run once before actions")
    length(humans)==length(s.previous_humans) || error("grazing human roster changed")
    w=s.world;a=s.animals
    fill!(s.overrides,0)
    for i in eachindex(s.alive)
        s.alive[i] || continue
        recent=t-s.last_seen[i]<=20
        remembered=s.seen_position[i]
        desired=recent ? atan(remembered[2]-a.z[i],remembered[1]-a.x[i]) : a.heading[i]+(pi/6)*sin(t/8+i)
        s.gaze[i]=P.turn_gaze(s.gaze[i],desired)
        best=0;distance=Inf
        for j in eachindex(humans)
            p=humans[j];d=hypot(p[1]-a.x[i],p[2]-a.z[i])
            d<=10 && d<distance || continue
            bearing=atan(p[2]-a.z[i],p[1]-a.x[i])
            P.field_factor(bearing-s.gaze[i],true)>0 || continue
            moved=hypot(p[1]-s.previous_humans[j][1],p[2]-s.previous_humans[j][2])>1e-6
            tracked=recent && s.seen_actor[i]==j
            cover=H.grass_cover!(w,H.cell(w,p...),t;body_height=1.7)
            d<=10/(1+.8cover)*P.vision_factor(true,moved,tracked) &&
                P.los(w,(a.x[i],a.z[i]),p) || continue
            best=j;distance=d
        end
        if best!=0
            same=recent && best==s.seen_actor[i]
            closing=same ? (hypot(a.x[i]-remembered[1],a.z[i]-remembered[2])-distance)/max(1,t-s.last_seen[i]) : 0.
            state=V.reaction(distance,closing,same)
            s.last_seen[i]=t;s.seen_actor[i]=best;s.seen_position[i]=humans[best]
            s.seen_ticks[i]+=1;s.human_seen[best]+=1
            if state==H.FLEE
                s.flee_until[i]=t+3;s.calm_since[i]=t
            elseif !same
                s.calm_since[i]=t
            end
            s.overrides[i]=t<s.flee_until[i] ? H.FLEE : (t-s.calm_since[i]<10 || t%5==0 ? H.ALERT : UInt8(0))
        elseif t<s.flee_until[i]
            s.overrides[i]=H.FLEE
        elseif t-s.last_seen[i]<=10 || (recent && t%5==0)
            s.overrides[i]=H.ALERT
        end
        # Only a last-observed position, never an unseen human's updated location.
        s.threats[i]=s.seen_position[i]
    end
    copyto!(s.previous_humans,humans)
    s.prepared=true
    nothing
end

function advance!(s::GrazingWorld,t::Int)
    t==s.ticks && s.prepared || error("grazing action without current perception")
    a=s.animals
    for i in eachindex(s.alive)
        s.alive[i] || continue
        s.overrides[i]==H.ALERT && a.state[i]!=H.ALERT && (s.alert_entries[i]+=1)
        s.overrides[i]==H.FLEE && a.state[i]!=H.FLEE && (s.flee_entries[i]+=1)
    end
    H.step!(s.world,a,t,s.demand,s.ratio,s.requests,s.active;
        alive=s.alive,overrides=s.overrides,threat_positions=s.threats)
    for i in eachindex(s.alive)
        if s.alive[i] && a.energy[i]<=0
            s.alive[i]=false;s.deaths+=1
        end
    end
    s.ticks+=1;s.prepared=false
    nothing
end

function snapshot(s::GrazingWorld)
    w=s.world;a=s.animals
    for k in eachindex(w.grass);H.grass!(w,k,s.ticks);end
    @assert isapprox(w.initial+w.grown,sum(w.grass)+w.eaten;atol=1e-6,rtol=1e-10)
    @assert isapprox(w.eaten,sum(a.consumed);atol=1e-6)
    @assert isapprox(sum(a.consumed),sum(a.gut)+sum(a.digested);atol=1e-6)
    @assert count(!,s.alive)==s.deaths
    @assert all(i->H.clear(w,(a.x[i],a.z[i]),(a.x[i],a.z[i])),eachindex(s.alive))
    @assert all(isfinite,a.energy) && all(e->0<=e<=100,a.energy)
    @assert all(i->!s.alive[i] || sum(a.counts[i,:])==s.ticks,eachindex(s.alive))
    (rule="lw-grazing-v1",count=length(s.alive),alive=count(s.alive),ticks=s.ticks,
     starvation_deaths=s.deaths,grass_initial=w.initial,grass_grown=w.grown,
     grass_remaining=sum(w.grass),grass_eaten=w.eaten,grass_cells=count(>(0),w.capacity),
     states=H.STATES,state_ticks=vec(sum(a.counts,dims=1)),human_seen=copy(s.human_seen),
     alert_entries=sum(s.alert_entries),flee_entries=sum(s.flee_entries),
     final=[(id=i,alive=s.alive[i],initial=s.initial_positions[i],position=(a.x[i],a.z[i]),
        energy=a.energy[i],gut=a.gut[i],state=H.STATES[a.state[i]],distance=a.distance[i],
        eaten=a.consumed[i],blocked=a.blocked[i],human_seen_ticks=s.seen_ticks[i],
        alert_entries=s.alert_entries[i],flee_entries=s.flee_entries[i],state_ticks=a.counts[i,:]) for i in eachindex(s.alive)])
end
end
