using Random
include("animals_only.jl")
include("../../src/lw/configured_paths/raptor_trial.jl")
@testset "close range airborne notice" begin
 base,_=animal_trial_world();empty!(base.world.obstacles);base.world.traits.density.=0.
 scene=JSON3.read(read(joinpath(@__DIR__,"../../outputs/lw-rabbit-family-30d-20261106/input.json"),String)).scene
 for (mode,distance,expected) in ((:hunt,3.,true),(:hunt,3.01,false),(:hunt,7.,false),(:eat,7.,true))
  s=deepcopy(base);b=configured_raptor(s,scene);b.mode=mode;b.present=true
  s.animals.x[1]=0.;s.animals.z[1]=0.;s.animals.heading[1]=0.;s.gaze[1]=0.
  b.visual.body.x=distance;b.visual.body.z=0.;b.visual.previous_position=(distance+1,0.)
  G.prepare!(s,Tuple{Float64,Float64}[],0;additional_predators=[b.visual],additional_predator_alive=[true],additional_predator_visible=(i,d)->configured_raptor_notice(b,d),motion_speed=true)
  @test (s.last_seen[1]==0)==expected
 end
 # Default callback-free ground predator perception stays available beyond 3.
 s=deepcopy(base);b=configured_raptor(s,scene)
 s.animals.x[1]=0.;s.animals.z[1]=0.;s.animals.heading[1]=0.;s.gaze[1]=0.
 b.visual.body.x=7.;b.visual.body.z=0.;b.visual.previous_position=(8.,0.)
 G.prepare!(s,Tuple{Float64,Float64}[],0;additional_predators=[b.visual],additional_predator_alive=[true],motion_speed=true)
 @test s.last_seen[1]==0
end