include("prey_scent_compare.jl")
@testset "boundary field and shared execution" begin
    s,ps=animal_trial_world();w=s.world
    @test w.boundary_gradient
    @test H.configured_boundary_heading(w,(0.,6.),.7)==.7
    for (p,h,axis,sign) in (((w.xmin+.5,6.),pi,1,1),((w.xmax-.5,6.),0.,1,-1),((0.,w.zmin+.5),-pi/2,2,1),((0.,w.zmax-.5),pi/2,2,-1))
        q=H.configured_boundary_step(w,p,h,.6)
        @test sign*(q[axis]-p[axis])>0
        @test hypot(q[1]-p[1],q[2]-p[2])≈.6
    end
    p=(w.xmin+.5,w.zmin+.5)
    q=H.configured_boundary_step(w,p,-3pi/4,.6)
    @test q[1]>p[1] && q[2]>p[2]
    b=ps[1].visual.body;b.x=w.xmin+.5;b.z=6.;b.heading=pi
    q=H.configured_boundary_step(w,(b.x,b.z),b.heading,.35)
    @test P.move!(w,b,.35;turn=false)
    @test (b.x,b.z)==q
    w.boundary_gradient=false
    @test H.configured_boundary_heading(w,p,.7)==.7
    io=IOBuffer();serialize(io,s);seekstart(io)
    @test !deserialize(io).world.boundary_gradient
end
out=abspath(ARGS[1]);mkpath(out)
println("CONDITIONS: same seed/map, 95 adults + 5 young, 2 predators, local hunt/wait ON; boundary OFF/ON; 3 days; provisional width=8 strength=2; rest unchanged")
rows=Any[]
for enabled in (false,true)
    run=scent_run(true;days=3,cautious=true,motion_speed=true,local_hunt=true,boundary_gradient=enabled)
    if !enabled
        old=JSON3.read(read(joinpath(@__DIR__,"../../outputs/local-wait-child-30d-20261107/result.json"),String))
        @test JSON3.read(JSON3.write(run.daily))==old.result.daily[1:3]
    end
    push!(rows,(boundary_gradient=enabled,run=run))
    println(JSON3.write((enabled=enabled,seconds=run.seconds,predators=run.final_state.predators)))
end
write(joinpath(out,"result.json"),JSON3.write((conditions="paired 3-day boundary gradient OFF/ON; same initial state and seed",rule=H.WILDLIFE_BOUNDARY,runs=rows)))
