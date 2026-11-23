using Test, Random
check(ok,message)=ok || error(message)
include("../../src/lw/decision/basic_loop.jl")
candidate(id,score)=Dict{String,Any}("method"=>id,"priority"=>score)
@testset "relation mass independent of enumeration" begin
 for H in (0.,8.,32.)
  loop=BasicLoop("food";probabilistic=true,seed=22);loop.H=H
  rng_before=copy(loop.rng)
  base=[candidate("fish_a",1.),candidate("explore",0.)]
  p=relational_candidate_distribution(loop,base,["fish","explore"])
  duplicated=[candidate("fish_$i",1.) for i in 1:8];push!(duplicated,base[2])
  q=relational_candidate_distribution(loop,duplicated,vcat(fill("fish",8),["explore"]))
  @test sum(q[1:8])≈p[1]
  @test q[end]≈p[2]
  @test maximum(q[1:8])≈minimum(q[1:8])
  weaker=vcat(base,[candidate("fish_weak",-2.)])
  w=relational_candidate_distribution(loop,weaker,["fish","explore","fish"])
  @test w[1]+w[3]≈p[1]
  @test w[1]>w[3]
  stronger=vcat(base,[candidate("fish_strong",2.)])
  t=relational_candidate_distribution(loop,stronger,["fish","explore","fish"])
  @test t[1]+t[3]>p[1]
  @test rand(copy(loop.rng))==rand(rng_before)
  @test relational_candidate_distribution(loop,base,["a","b"])≈method_distribution(loop,base)
  @test all(>(0.),q)
 end
 @test isempty(relational_candidate_distribution(BasicLoop("x"),Any[],String[]))
 @test_throws ErrorException relational_candidate_distribution(BasicLoop("x"),[candidate("a",0.)],String[])
end
