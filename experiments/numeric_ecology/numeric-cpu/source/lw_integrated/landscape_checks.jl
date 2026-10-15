include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "riparian material and placement" begin
 land=(rule="lw-riparian-base-v1",phase=0.)
 @test landscape_material(land,(river_x(0.,6),6.))=="water"
 @test landscape_resistance(land,(river_x(0.,6),6.))==3.
 @test landscape_material(land,(river_x(0.,6)+2,6.))=="bank"
 @test landscape_resistance(land,(-28.,28.))==2.
 @test landscape_resistance(land,(-23.,-25.))==2.5
 @test landscape_resistance(land,(0.,0.))==1.5
 g=GroundWear(100);dry=p->landscape_material(land,p)!="water"
 tread!(g,"water","a",(12.,6.),(12.,6.1),0;walkable=dry)
 @test isempty(g.cells)
 tread!(g,"dry","b",(0.,0.),(.5,0.),0;walkable=dry)
 @test !isempty(g.cells)
 w=(positions=Dict("a"=>(12.,6.)),obstacles=Any[])
 v=ground_appearance(w,"a",Dict("a"=>0.),g,0;dry=dry)
 @test any(c["appearance"]=="water" for c in v["cells"])
 for seed in (20261004,20261005)
  scene=native_landscape_scene(seed)
  @test length(scene.food)==10
  @test length(scene.obstacles)+length(scene.low_obstacles)<=100
  @test all(hypot(f.x,f.z-6)>=16 for f in scene.food)
  @test all(landscape_material(scene.landscape,(f.x,f.z))!="water" for f in scene.food)
  @test JSON3.write(scene)==JSON3.write(native_landscape_scene(seed))
 end
end
root=ARGS[1]
for seed in (20261004,20261005)
 dir=joinpath(root,string(seed))
 native_main([dir,"--days","1","--seed",string(seed),"--layout","riparian","--food","renewable",
  "--skyline","rays","--ground","patches","--ground-wear","on","--ground-perception","on",
  "--low-obstacles","on","--climbing","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));input=JSON3.read(read(joinpath(dir,"spec.json"),String))
 validate_integrated(r,input)
 @test r.world_checkpoint.landscape==input.scene.landscape
 @test all(length(s.records)==16 for s in values(r.skyline))
 @test all(s.delta_mismatches==0 for s in values(r.ground_effects))
end
native_main([joinpath(root,"replay"),"--spec",joinpath(root,"20261005","spec.json")])
@test read(joinpath(root,"20261005","result.json"))==read(joinpath(root,"replay","result.json"))
