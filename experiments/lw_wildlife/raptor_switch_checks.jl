using Random
include("animals_only.jl")
include("../../src/lw/configured_paths/raptor_trial.jl")
@testset "switch after missed prey" begin
 s,_=animal_trial_world();scene=JSON3.read(read(joinpath(@__DIR__,"../../outputs/lw-rabbit-family-30d-20261106/input.json"),String)).scene
 b=configured_raptor(s,scene);empty!(s.world.obstacles);s.world.traits.density.=0.
 fill!(s.alive,false);s.alive[1]=s.alive[2]=true
 b.visual.body.x=0.;b.visual.body.z=0.;s.animals.x[1]=1.;s.animals.z[1]=0.;s.animals.x[2]=2.;s.animals.z[2]=0.
 configured_raptor_event!(b,0,"miss";id=1,probability=0.)
 @test configured_raptor_failed_target(b)==1
 configured_raptor_scan!(b,s,1);@test b.target==2
 configured_raptor_event!(b,2,"miss";id=2,probability=0.)
 configured_raptor_scan!(b,s,3);@test b.target==1
 configured_raptor_scan!(b,s,4;switch_after_miss=false);@test b.target==1
 s.alive[1]=false;perch=b.perch
 configured_raptor_scan!(b,s,5);@test b.target==0 && b.mode==:return && b.perch!=perch
 io=IOBuffer();serialize(io,b);seekstart(io);copy_bird=deserialize(io)
 @test configured_raptor_failed_target(copy_bird)==2
 configured_raptor_event!(b,6,"capture";id=1);@test configured_raptor_failed_target(b)==0
 configured_raptor_event!(b,7,"miss";id=1);configured_raptor_event!(b,8,"arrival";rabbits=150)
 @test configured_raptor_failed_target(b)==0
end