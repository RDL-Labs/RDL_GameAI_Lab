include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "ground history decay and isolation" begin
 g=GroundWear(100);advance_wear!(g,10);tread!(g,"old","a",(0.,0.),(1.,0.),10)
 advance_wear!(g,120);snap=JSON3.read(JSON3.write(wear_snapshot(g)))
 restored=restore_wear(snap,100)
 @test wear_factor(g,(.5,0.))==wear_factor(restored,(.5,0.))
 @test haskey(restored.cells[(0,0)]["agents"],"inherited/a")
 advance_wear!(g,130);advance_wear!(restored,130)
 @test wear_factor(g,(.5,0.))≈wear_factor(restored,(.5,0.))
 tread!(restored,"new","a",(0.,0.),(1.,0.),130)
 @test restored.cells[(0,0)]["distance"]>g.cells[(0,0)]["distance"]
 @test haskey(restored.cells[(0,0)]["agents"],"a")
 @test_throws Exception restore_wear(snap,200)
 @test_throws Exception advance_wear!(restored,129)
end
root=ARGS[1];firstdir=joinpath(root,"first")
native_main([firstdir,"--days","1","--seed","20261005","--food","renewable","--ground","patches","--ground-wear","on","--ground-perception","on"])
original=JSON3.read(read(joinpath(firstdir,"spec.json"),String));prior=JSON3.read(read(joinpath(firstdir,"result.json"),String))
input=D("scene"=>merge(D(String(k)=>v for (k,v) in pairs(original.scene)),D("ground_history"=>prior.ground_wear)),"clock"=>original.clock,"config"=>original.config)
path=joinpath(root,"inherited.json");write(path,JSON3.write(input))
for name in ("next","replay")
 dir=joinpath(root,name);native_main([dir,"--spec",path])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(path,String)))
 @testset "inherited living ground" begin
  @test r.ground_wear.now_us==2original.clock.day_us
  @test r.ground_wear.operations>prior.ground_wear.operations
  @test sum(c.distance for c in values(r.ground_wear.cells))≈sum(c.distance for c in values(prior.ground_wear.cells))+sum(a.distance for a in values(r.final_agents))
 end
end
@test read(joinpath(root,"next","result.json"))==read(joinpath(root,"replay","result.json"))
