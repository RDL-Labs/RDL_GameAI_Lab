using JSON3,Test,Serialization
include("predator_generations.jl")
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
s=G.build(input.scene,input.clock)
@testset "starvation age at death" begin
 for (i,age) in ((1,27),(2,28))
  s.life.born[i]=-age*17280
  G.record_starvation!(s,i,0)
 end
 @test G.starvation_breakdown(s)==(dependent_young=1,post_weaning=1,unknown_age=0)
 @test s.starvation_records[1].age_days==27
 @test s.starvation_records[1].category=="dependent_young"
 s.ticks=90*17280
 @test G.starvation_breakdown(s).dependent_young==1
 s.life=nothing;G.record_starvation!(s,3,s.ticks)
 @test G.starvation_breakdown(s).unknown_age==1
 io=IOBuffer();serialize(io,s);seekstart(io)
 @test deserialize(io).starvation_records==s.starvation_records
end
