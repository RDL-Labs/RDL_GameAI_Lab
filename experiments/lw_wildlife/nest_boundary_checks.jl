using JSON3,Test
include("predator_generations.jl")
include("../../src/lw/configured_paths/rabbit_distributed_layout.jl")
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
s=G.build(input.scene,input.clock);w=s.world
@testset "nest boundary exclusion" begin
 @test !G.configured_rabbit_nest_allowed(w,(63.,-43.))
 @test !G.configured_rabbit_nest_allowed(w,(-33.,-57.))
 @test G.configured_rabbit_nest_allowed(w,(w.xmin+8.25,0.))
 @test !G.configured_rabbit_nest_allowed(w,(w.xmin+8.249,0.))
 @test G.configured_rabbit_nest_allowed(w,(63.,-43.);enabled=false)
 configured_rabbit_distributed_layout!(s)
 @test all(i->G.configured_rabbit_nest_allowed(w,(s.animals.x[i],s.animals.z[i])),eachindex(s.alive))
 mother=1;s.animals.x[mother]=63.;s.animals.z[mother]=-43.
 candidates=G.configured_rabbit_nest_candidates(s,mother,0)
 @test !isempty(candidates)
 @test all(c->G.configured_rabbit_nest_allowed(w,c.position;extra_margin=G.RABBIT_NEST_PREPARATION.arrival_radius),candidates)
 s.life.due[mother]=17280;s.life.litter[mother]=3;s.life.invested[mother]=30.
 before=s.life.births;G.rabbit_daily!(s,17280)
 @test s.life.births==before
 @test s.life.due[mother]==17280
 safe=candidates[1].position;s.animals.x[mother],s.animals.z[mother]=safe
 G.rabbit_daily!(s,34560)
 @test s.life.births>=before+3
end
