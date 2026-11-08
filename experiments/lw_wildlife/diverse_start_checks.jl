using JSON3,Test,Serialization
include("predator_generations.jl")
include("../../src/lw/configured_paths/predator_crossing_layout.jl")
include("../../src/lw/configured_paths/rabbit_diverse_start.jl")
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
scene=merge((;pairs(input.scene)...),(positions=Tuple{Float64,Float64}[],wildlife=merge((;pairs(input.scene.wildlife)...),(count=95,grass_scale=1.5)),))
s=G.build(scene,input.clock);replica=deepcopy(s)
for w in (s,replica);configured_rabbit_diverse_start!(w);configured_crossing_layout!(w);end
@testset "diverse initial cohort" begin
 @test length(s.alive)==100
 @test count(i->G.dependent(s.life,i,0),1:100)==15
 @test count(i->28<=-s.life.born[i]/17280<150,1:100)==20
 @test count(i->-s.life.born[i]/17280>=150,1:100)==65
 @test count(>(0),s.life.due)==5
 @test s.life.births==0 && s.life.initial_count==100
 @test s.life.gestation_out==sum(s.life.invested)
 @test s.life.born==replica.life.born && s.animals.energy==replica.animals.energy
 @test all(s.life.reserve_balance.==0)
 for i in findall(>(0),s.life.mother)
  m=s.life.mother[i]
  @test s.life.sex[m]==1 && s.life.due[m]==0
  @test (s.animals.x[i],s.animals.z[i])==(s.animals.x[m],s.animals.z[m])
  @test s.life.next_mate[m]>0
 end
 @test count(i->s.animals.x[i]<12+5sin((s.animals.z[i]-6)/22+s.world.phase),1:100)==20
 @test G.snapshot(s).reproduction.balances.gestation.status=="ok"
 for t in 0:99
  G.prepare!(s,Tuple{Float64,Float64}[],t);G.advance!(s,t)
 end
 @test count(s.alive)==100
 io=IOBuffer();serialize(io,s);seekstart(io);saved=deserialize(io)
 @test saved.life.born==s.life.born
end
