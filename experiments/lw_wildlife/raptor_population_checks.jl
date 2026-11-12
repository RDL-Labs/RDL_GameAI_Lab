include("animals_only.jl")
include("../../src/lw/configured_paths/raptor_trial.jl")
@testset "raptor ratio50" begin
 input=JSON3.read(read(joinpath(@__DIR__,"ecology_dual_input.json"),String))
 s,ps=animal_trial_world(;adult_rabbits=250);birds=RaptorTrial[]
 configured_raptor_population_world!(birds,s,input.scene,0)
 @test length(birds)==3
 @test all(b->b.present,birds)
 for (slot,b) in enumerate(birds)
  configured_raptor_population!(b,150,17280;arrival=150+50*(slot-1),departure=100+50*(slot-1))
 end
 @test birds[1].mode!=:depart
 @test birds[2].mode==:depart && birds[3].mode==:depart
 io=IOBuffer();serialize(io,birds);seekstart(io);restored=deserialize(io)
 @test configured_raptor_report(restored)==configured_raptor_report(birds)
 for t in 0:119
  animal_trial_prepare!(s,ps,t;raptor=birds)
  animal_trial_advance!(s,ps,t)
  configured_raptor_step!(birds,s,ps,t)
 end
 @test animal_trial_report(s,ps;raptor=birds).rabbits.alive>=0
 @test configured_raptor_captures(birds)==sum(b.captures for b in birds)
end
