using JSON3, Random, Test
include(joinpath(@__DIR__, "../../../src/ecology/motion-vision-cpu/trial.jl"))
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
