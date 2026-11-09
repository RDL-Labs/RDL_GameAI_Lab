using JSON3,Test
include("../../src/ecology/motion-vision-cpu/Herbivores.jl")
const H=Herbivores
input=JSON3.read(read("outputs/lw-rabbit-family-30d-20261106/input.json",String))
w,a=H.build(input);H.enable_grass_layers!(w)
k=findfirst(k->w.capacity[k]>0 && H.clear(w,H.center(w,k),H.center(w,k)),eachindex(w.capacity))
a.x[1],a.z[1]=H.center(w,k);a.current_cell[1]=k;a.state[1]=H.GRAZE
@testset "grazing small movement" begin
 origin=(a.x[1],a.z[1]);before=a.distance[1]
 @test H.configured_rabbit_grazing_motion!(w,a,1,59;enabled=false)==0
 @test (a.x[1],a.z[1])==origin
 @test H.configured_rabbit_grazing_motion!(w,a,1,58)==0
 cost=H.configured_rabbit_grazing_motion!(w,a,1,59)
 @test cost≈.00365
 @test a.distance[1]-before≈.1
 @test H.clear(w,origin,(a.x[1],a.z[1]))
 @test a.current_cell[1]==H.cell(w,a.x[1],a.z[1])
 pos=(a.x[1],a.z[1]);@test !H.rabbit_land_step!(w,a,1,(w.xmax+1.,a.z[1]))
 @test (a.x[1],a.z[1])==pos
 a.state[1]=H.SLEEP;@test H.configured_rabbit_grazing_motion!(w,a,1,119)==0
 alive=falses(length(a.x));alive[1]=true;a.state[1]=H.GRAZE;a.energy[1]=60.;a.sleepy[1]=0.;a.gut[1]=0.
 H.step!(w,a,119,zeros(length(w.grass)),zeros(length(w.grass)),zeros(length(a.x)),Int[];alive,policy=H.RabbitApproachPolicy())
 @test w.eaten≈sum(a.consumed)
 @test w.initial+w.grown≈sum(w.grass)+w.eaten
 @test a.distance[1]>before+.1
end
