using JSON3, Random, Test
include(joinpath(@__DIR__, "../../../src/ecology/directional-vision-cpu/trial.jl"))
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

@testset "directional vision and independent gaze" begin
    @test P.field_factor(pi/2,true)==1
    @test P.field_factor(pi,true)==0
    @test P.field_factor(0.,false)==1
    @test P.field_factor(pi/2,false)==.3
    @test P.field_factor(pi,false)==0
    @test isapprox(P.turn_gaze(0.,pi/2),pi/6)
    @test abs(P.angle_delta(P.turn_gaze(pi-.1,-pi+.1)-(-pi+.1)))<1e-10
    w,a=H.build(spec); empty!(w.obstacles); p=P.spawn(w)
    p.x=-8.; p.z=6.; a.x[1]=-1.; a.z[1]=6.
    p.target=1; p.expires=20
    @test P.visible(w,p,a,1,1;motion=true,moved=true,gaze=0.)
    @test !P.visible(w,p,a,1,1;motion=true,moved=true,gaze=pi)
    a.x[1]=-8.; a.z[1]=13.
    @test !P.visible(w,p,a,1,1;motion=true,moved=true,gaze=0.)
    a.z[1]=7.
    @test P.visible(w,p,a,1,1;motion=true,moved=true,gaze=0.)
    a.x.=-8.; a.z.=6.; p.x=-12.; p.z=6.
    aw=Awareness(30); alive=trues(30); o=zeros(UInt8,30); pos=fill((0.,0.),30)
    perceive!(w,a,p,alive,aw,0,true,true,o,pos;gaze=zeros(30))
    @test o[1]==0
    perceive!(w,a,p,alive,aw,1,true,true,o,pos;gaze=fill(pi,30))
    @test o[1]==H.ALERT
    heading=copy(a.heading); before=(copy(a.x),copy(a.z))
    gaze=P.turn_gaze(0.,pi/2)
    @test a.heading==heading && before==(a.x,a.z)
end
trial(spec;days=0,motion=true,directional=false)
trial(spec;days=0,motion=true,directional=true)
results=NamedTuple[]
previous=JSON3.read(read(joinpath(@__DIR__,"../motion-vision-cpu/results.json"),String))
for seed in 20261005:20261009, directional in (false,true)
    m=@timed trial(spec;seed,motion=true,directional)
    r=m.value; push!(results,(result=r,seconds=m.time))
    if !directional
        old=only(x.result for x in previous.runs if x.result.seed==seed && x.result.motion)
        @test JSON3.write(Base.structdiff(r,(directional=false,)))==JSON3.write(old)
    end
    println(JSON3.write((seed=seed,directional=directional,survivors=r.survivors,captures=r.captures,starvation=r.starvation_deaths,seconds=m.time)))
end
@test trial(spec;seed=20261005,motion=true,directional=true)==results[2].result
write(joinpath(@__DIR__,"results.json"),JSON3.write((runs=results,peak_rss_bytes=Sys.maxrss())))
println("Baseline parity and deterministic replay passed")
