using Test
D(args...)=Dict{String,Any}(args...)
const ANGLES=[-90.,-45.,0.,45.,90.]
wrap_angle(x)=mod(x+180,360)-180
include("../../src/lw/configured_paths/camp_landmark.jl")
@testset "configured exterior view" begin
 s=configured_camp_landmark_state();s["stage"]=7
 clock=(quiet_night_us=15_000_000_000,)
 view=D("coverage"=>"complete","features"=>Any[D("color"=>"ochre")])
 args=(s,(0.,6.),(0.,22.))
 p=configured_camp_landmark_tour!(args...,0.,100,nothing,80.,0.,100_000_000,clock;exterior=true)
 @test p["action"]=="scan" && abs(p["scan_angle"])==90
 @test get(s,"exterior_views",0)==0
 for sec in 101:103
  p=configured_camp_landmark_tour!(args...,180.,sec,nothing,80.,0.,sec*1_000_000,clock;exterior=true,landmark_view=view,skyline_view=view)
  @test p["configured_observation"] && p["scan_angle"]==0
 end
 @test s["exterior_views"]==1 && s["stage"]==8
 @test !s["tour_completed"] && !s["learned"]
 @test s["records"][end]["distance"]==16.
 @test s["records"][end]["skyline"][1]["color"]=="ochre"
 @test configured_camp_landmark_tour!(args...,180.,3600,nothing,80.,0.,1_200_000_000,clock;exterior=true)===nothing
end

using JSON3
@testset "exterior fixture waypoint clearance" begin
 scene=JSON3.read(read(joinpath(@__DIR__,"navigation_idle_10d_input.json"),String)).scene
 for (p,q) in (((0.,9.),(0.,22.)),((0.,22.),(0.,16.)),((0.,16.),(0.,9.)))
  dx=q[1]-p[1];dz=q[2]-p[2]
  @test all(scene.obstacles) do o
   t=clamp(((o.x-p[1])*dx+(o.z-p[2])*dz)/(dx*dx+dz*dz),0.,1.)
   hypot(o.x-(p[1]+t*dx),o.z-(p[2]+t*dz))>=o.radius+.2
  end
 end
end
