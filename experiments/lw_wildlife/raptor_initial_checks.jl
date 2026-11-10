using Random
include("animals_only.jl")
include("../../src/lw/configured_paths/rabbit_diverse_start.jl")
@testset "variable initial population" begin
    for total in (100,150)
        s,_=animal_trial_world(;adult_rabbits=total-5)
        configured_rabbit_diverse_start!(s)
        @test count(s.alive)==total
        @test count(i->G.dependent(s.life,i,0),eachindex(s.alive))==15
        @test count(i->35<=-s.life.born[i]/17280<=149,eachindex(s.alive))==20
        @test all(i->s.life.mother[i]<=total,eachindex(s.alive))
    end
end