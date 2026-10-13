include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
root=ARGS[1];firstdir=joinpath(root,"first")
native_main([firstdir,"--days","1","--seed","20261005","--food","renewable","--hazards","mixed","--ground","patches","--ground-wear","on","--dropping","on"])
input=JSON3.read(read(joinpath(firstdir,"spec.json"),String));prior=JSON3.read(read(joinpath(firstdir,"result.json"),String))
scene=merge(D(String(k)=>v for (k,v) in pairs(input.scene)),D("world_history"=>prior.world_checkpoint))
path=joinpath(root,"inherited.json");write(path,JSON3.write(D("scene"=>scene,"config"=>input.config,"clock"=>input.clock)))
for name in ("next","replay")
 dir=joinpath(root,name);native_main([dir,"--spec",path])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(path,String)))
 @testset "world cohort transfer" begin
  @test r.world_checkpoint.next_us==2input.clock.day_us
  @test r.initial_food==sum(prior.world_checkpoint.stock)+sum(input.scene.initial_inventory)
  @test r.replenished_food==sum(max(0,f.stock-prior.world_checkpoint.stock[i]) for (i,f) in enumerate(input.scene.food))
  @test r.world_checkpoint.hazards.last_us>=input.clock.day_us
  @test r.ground_wear.now_us==2input.clock.day_us
 end
end
@test read(joinpath(root,"next","result.json"))==read(joinpath(root,"replay","result.json"))
