include("nest_preparation_checks.jl")
@testset "river traversal body cost" begin
 s=reproductive_world();h=G.H;w=s.world;a=s.animals
 z=6.;x=12+5sin(w.phase);a.x[1]=x;a.z[1]=z;a.energy[1]=85.;a.gut[1]=0.;a.heading[1]=0.;a.target[1]=h.cell(w,x+3,z);a.next_sense[1]=100
 @test h.material(w.phase,x,z)==h.WATER
 @test h.clear(w,(x,z),(x+.2,z))
 @test !G.configured_rabbit_nest_allowed(w,(x,z))
 @test h.configured_rabbit_terrain_distance(w,(x-3,z),(x+3,z))>6
 h.step!(w,a,1,s.demand,s.ratio,s.requests,s.active;alive=Bool[true,false],overrides=UInt8[h.SEARCH,0],steering=(args...)->0.)
 @test a.x[1]-x≈h.RABBIT_TERRAIN.water_speed
 @test 85-a.energy[1]≈.012*h.RABBIT_TERRAIN.water_cost_multiplier
end
