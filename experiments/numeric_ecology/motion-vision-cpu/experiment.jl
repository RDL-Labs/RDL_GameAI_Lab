using JSON3, Random, Test
include("Predators.jl")
const P=Predators; const H=P.H
# Numeric short-term perception only; no hidden predator state is consulted.
mutable struct Awareness
    last_seen::Vector{Int}; x::Vector{Float64}; z::Vector{Float64}
    flee_until::Vector{Int}; calm_since::Vector{Int}
end
Awareness(n)=Awareness(fill(-1000,n),zeros(n),zeros(n),fill(-1000,n),fill(-1000,n))
function reaction(d,closing,recent)
    d<=3 || (recent && d<7 && closing>.1) ? H.FLEE : H.ALERT
end
function perceive!(w,a,p,alive,aw,t,motion,p_moved,overrides,positions)
    fill!(overrides,0)
    k=H.cell(w,p.x,p.z); cover=w.capacity[k]>0 ? H.grass!(w,k,t)/w.capacity[k] : 0.
    for i in eachindex(alive)
        alive[i] || continue
        recent=t-aw.last_seen[i]<=20
        d=hypot(a.x[i]-p.x,a.z[i]-p.z)
        seen=d<=10/(1+.8cover)*P.vision_factor(motion,p_moved,recent) && P.los(w,(a.x[i],a.z[i]),(p.x,p.z))
        if seen
            # Distance change due to observed predator displacement, excluding own movement.
            olddist=hypot(a.x[i]-aw.x[i],a.z[i]-aw.z[i])
            closing=recent ? (olddist-d)/max(1,t-aw.last_seen[i]) : 0.
            state=reaction(d,closing,recent)
            aw.last_seen[i]=t; aw.x[i]=p.x; aw.z[i]=p.z
            if state==H.FLEE
                aw.flee_until[i]=t+3; aw.calm_since[i]=t
            elseif !recent
                aw.calm_since[i]=t
            end
            # After 10 quiet ticks, permit normal feeding but interrupt it to scan.
            overrides[i]=t<aw.flee_until[i] ? H.FLEE : (t-aw.calm_since[i]<10 || t%5==0 ? H.ALERT : UInt8(0))
        elseif t<aw.flee_until[i]
            overrides[i]=H.FLEE
        elseif t-aw.last_seen[i]<=10
            overrides[i]=H.ALERT
        elseif recent && t%5==0
            overrides[i]=H.ALERT
        end
        positions[i]=(aw.x[i],aw.z[i])
    end
end
function trial(spec;seed=20261005,motion=false,days=3)
    w,a=H.build(spec;seed); a.counts=zeros(Int,length(a.x),6)
    p=P.spawn(w); alive=trues(length(a.x)); aw=Awareness(length(alive))
    rng=MersenneTwister(seed+1); moved=falses(length(alive)); p_moved=false
    oldx=similar(a.x); oldz=similar(a.z)
    overrides=zeros(UInt8,length(alive)); positions=fill((0.,0.),length(alive))
    demand=zeros(length(w.grass)); ratio=similar(demand); requests=zeros(length(alive)); active=Int[]
    events=NamedTuple[]; starvation=0; daily=NamedTuple[]
    for t in 0:days*17280-1
        perceive!(w,a,p,alive,aw,t,motion,p_moved,overrides,positions)
        P.plan!(w,p,a,alive,t,rng;motion,moved)
        copyto!(oldx,a.x); copyto!(oldz,a.z); px,pz=p.x,p.z
        H.step!(w,a,t,demand,ratio,requests,active;alive,overrides,threat_positions=positions)
        P.advance!(w,p,a,alive,t,rng,events)
        for i in eachindex(alive)
            moved[i]=hypot(a.x[i]-oldx[i],a.z[i]-oldz[i])>1e-6
            if alive[i] && a.energy[i]<=0
                alive[i]=false; starvation+=1; push!(events,(tick=t,kind="energy_death",id=i))
            end
        end
        p_moved=hypot(p.x-px,p.z-pz)>1e-6
        if (t+1)%17280==0
            push!(daily,(day=div(t+1,17280),alive=count(alive),captures=p.captures,starvation=starvation,state_ticks=vec(sum(a.counts,dims=1))))
        end
    end
    for k in eachindex(w.grass); H.grass!(w,k,days*17280); end
    @assert count(!,alive)==p.captures+starvation
    @assert isapprox(w.initial+w.grown,sum(w.grass)+w.eaten;atol=1e-6)
    @assert isapprox(w.eaten,sum(a.consumed);atol=1e-6)
    @assert isapprox(sum(a.consumed),sum(a.gut)+sum(a.digested);atol=1e-6)
    @assert p.attacks==p.captures+p.misses+(p.state==P.ATTACK ? 1 : 0)
    (seed=seed,motion=motion,days=days,survivors=count(alive),captures=p.captures,starvation_deaths=starvation,
        attacks=p.attacks,grass_eaten=w.eaten,state_ticks=vec(sum(a.counts,dims=1)),daily=daily,events=events)
end
spec=JSON3.read(read(joinpath(@__DIR__,"map-spec.json"),String))
@testset "motion perception and alert rules" begin
    @test P.vision_factor(true,false,false)<P.vision_factor(true,true,false)
    @test P.vision_factor(true,false,true)==1
    @test P.vision_factor(false,false,false)==1
    @test reaction(6.,0.,false)==H.ALERT
    @test reaction(6.,.3,true)==H.FLEE
    @test reaction(2.,0.,false)==H.FLEE
    @test reaction(6.,-.3,true)==H.ALERT
    w,a=H.build(spec); empty!(w.obstacles); p=P.spawn(w)
    p.x=-8.; p.z=6.; a.x[1]=-1.; a.z[1]=6.
    @test !P.visible(w,p,a,1,0;motion=true,moved=false)
    @test P.visible(w,p,a,1,0;motion=true,moved=true)
    p.target=1; p.expires=20
    @test P.visible(w,p,a,1,1;motion=true,moved=false)
    push!(w.obstacles,H.RDLMigrationProbe.Circle(-4.5,6.,.5))
    @test !P.visible(w,p,a,1,1;motion=true,moved=true)
    empty!(w.obstacles); aw=Awareness(30); alive=trues(30); o=zeros(UInt8,30); pos=fill((0.,0.),30)
    a.x.=-1.; a.z.=6.; p.x=-8.
    perceive!(w,a,p,alive,aw,0,true,false,o,pos)
    @test o[1]==0
    p.x=-5.
    perceive!(w,a,p,alive,aw,1,true,true,o,pos)
    @test o[1]==H.ALERT
    p.x=50.
    perceive!(w,a,p,alive,aw,2,true,true,o,pos)
    @test pos[1]==(-5.,6.) && o[1]==H.ALERT
    perceive!(w,a,p,alive,aw,22,true,true,o,pos)
    @test o[1]==0
end
# Warm both specializations before reporting measured runs.
trial(spec;days=0,motion=false); trial(spec;days=0,motion=true)
results=NamedTuple[]
for seed in 20261005:20261009, motion in (false,true)
    m=@timed trial(spec;seed,motion)
    r=m.value; push!(results,(result=r,seconds=m.time))
    println(JSON3.write((seed=seed,motion=motion,survivors=r.survivors,captures=r.captures,starvation=r.starvation_deaths,seconds=m.time)))
end
@test trial(spec;seed=20261005,motion=true)==results[2].result
write(joinpath(@__DIR__,"results.json"),JSON3.write((runs=results,peak_rss_bytes=Sys.maxrss())))
println("Replay matched")
