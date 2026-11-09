using JSON3,Test
include("predator_generations.jl")
include("../../src/lw/configured_paths/rabbit_diverse_start.jl")
include("../../src/lw/configured_paths/rabbit_distributed_layout.jl")
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
scene=merge((;pairs(input.scene)...),(positions=Tuple{Float64,Float64}[],wildlife=merge((;pairs(input.scene.wildlife)...),(count=95,grass_scale=1.5)),))
s=G.build(scene,input.clock);configured_rabbit_diverse_start!(s);replica=deepcopy(s)
energy=copy(s.animals.energy);grass=copy(s.world.grass);born=copy(s.life.born)
record=configured_rabbit_distributed_layout!(s);record2=configured_rabbit_distributed_layout!(replica)
@testset "capacity-weighted family layout" begin
 @test record==record2
 @test s.animals.x==replica.animals.x && s.animals.z==replica.animals.z
 @test record.west+record.east==100
 @test s.animals.energy==energy && s.world.grass==grass && s.life.born==born
 @test abs(record.west-100record.west_capacity/(record.west_capacity+record.east_capacity))<=6
 roots=findall(==(0),s.life.mother)
 @test length(unique(s.animals.current_cell[roots]))==length(roots)
 for i in eachindex(s.alive)
  p=(s.animals.x[i],s.animals.z[i]);k=s.animals.current_cell[i]
  @test H.clear(s.world,p,p) && s.world.capacity[k]>0
  @test s.life.nest[i]==p
  if s.life.mother[i]>0
   @test k==s.animals.current_cell[s.life.mother[i]]
  end
 end
 @test record.occupied_tiles>30
 for t in 0:99
  G.prepare!(s,Tuple{Float64,Float64}[],t);G.advance!(s,t)
 end
 @test count(s.alive)==100
end
write("experiments/lw_wildlife/evidence/distributed-layout-initial.json",JSON3.write(record))
println(JSON3.write((west=record.west,east=record.east,west_capacity=record.west_capacity,east_capacity=record.east_capacity,tiles=record.occupied_tiles)))
