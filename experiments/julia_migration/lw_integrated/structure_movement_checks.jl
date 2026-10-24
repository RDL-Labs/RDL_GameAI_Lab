include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "shared local structure field" begin
 ob=D("source"=>"o","coverage"=>"complete","output_limited"=>false,"items"=>Any[])
 state(groups)=D("source"=>"o","observation"=>D("groups"=>groups))
 surface(kind,points)=D("kind"=>kind,"points"=>points)
 right=surface("obstacle",[(.6,1.)])
 @test structure_descent(0.,ob,state([right])).angle<0
 many=surface("obstacle",[(.6,1.),(.7,1.2),(.8,1.4)])
 @test structure_descent(0.,ob,state([right]))==structure_descent(0.,ob,state([many]))
 sides=[surface("obstacle",[(-.6,1.)]),right]
 @test structure_descent(0.,ob,state(sides)).angle≈0.
 @test structure_descent(0.,ob,state(sides)).combined[1]>0
 @test abs(structure_descent(0.,ob,state([surface("water",[(.6,1.)])])).angle)<abs(structure_descent(0.,ob,state([right])).angle)
 @test structure_descent(0.,ob,state([surface("water",[(.6,1.)])]);water_weight=0.).angle==0
 @test structure_descent(0.,ob,state([right]);clearance=3.).angle<=structure_descent(0.,ob,state([right]);clearance=1.).angle
 @test structure_descent(0.,ob,D("source"=>"stale","observation"=>D("groups"=>[right]))).angle==0
 @test structure_descent(0.,merge(ob,D("coverage"=>"partial")),state([right]))===nothing
 w=(positions=Dict("a"=>(0.,0.)),bodies=Dict("a"=>Body(10.,0.,100.,0.)),inventory=Dict("a"=>0),obstacles=RDLMigrationProbe.Circle[])
 yaw=Dict("a"=>0.)
 for method in ("step_0","ground_1","landmark:orange","relation:r","walk_0","run_0")
  action=method=="run_0" ? "run" : "walk"
  p=D("method"=>method,"action"=>action,"direction"=>2,"question"=>"movement_progress")
  @test steer_structure!(p,nothing,ob,state([right]),w,"a",yaw,x->1.5)
  @test p["approach_angle"]<0
  @test p["approach_span"]==(action=="run" ? 1.5 : .5)
 end
 # Goal discovery does not hijack the selected path/escape.
 food=D("right"=>-10.,"forward"=>0.,"distance"=>10.)
 p=D("action"=>"walk","direction"=>2,"steering_angle"=>20.,"question"=>"ground_extension")
 @test steer_structure!(p,food,ob,nothing,w,"a",yaw,x->1.5)
 @test p["approach_angle"]≈20.
 p=D("action"=>"walk","direction"=>2,"question"=>"target_nearer")
 @test steer_structure!(p,food,ob,nothing,w,"a",yaw,x->1.5)
 @test p["approach_angle"]≈-90.
 push!(w.obstacles,RDLMigrationProbe.Circle(0.,.3,.1))
 p=D("action"=>"walk","direction"=>2)
 @test !steer_structure!(p,nothing,ob,nothing,w,"a",yaw,x->1.5)
 @test !haskey(p,"approach_angle")
 @test !steer_structure!(D("action"=>"climb"),nothing,ob,nothing,w,"a",yaw,x->1.5)
end
