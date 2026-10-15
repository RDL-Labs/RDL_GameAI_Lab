include(joinpath(@__DIR__,"native.jl"))
@testset "observed target approach" begin
 spec=JSON3.read(read(joinpath(@__DIR__,"approach_spec.json"),String))
 w=moving_world(spec.scene);a="npc_a";w.positions[a]=(0.,0.);empty!(w.obstacles);yaw=Dict(a=>0.)
 target=D("forward"=>1.4,"right"=>.3,"distance"=>hypot(1.4,.3))
 plan()=D("action"=>"walk","direction"=>2)
 p=plan();@test refine_approach!(p,target,w,a,yaw,x->1.5)
 @test 0<p["approach_angle"]<45
 @test 0<p["approach_span"]<.5
 @test isapprox(target["distance"]-p["approach_span"],1.)
 @test !refine_approach!(plan(),nothing,w,a,yaw,x->1.5)
 @test !near_target(D("distance"=>17.))
 @test !near_target(D("distance"=>1.25))
 p=D("action"=>"walk","direction"=>0);@test !refine_approach!(p,target,w,a,yaw,x->1.5)
 push!(w.obstacles,RDLMigrationProbe.Circle(0.,.2,.2))
 @test !refine_approach!(plan(),target,w,a,yaw,x->1.5)
 empty!(w.obstacles);w.bodies[a]=Body(10.,0.,0.,0.)
 @test !refine_approach!(plan(),target,w,a,yaw,x->1.5)
end

