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

mutable_input()=JSON3.read(read(path,String),Dict{String,Any})
freeze(x)=JSON3.read(JSON3.write(x))
@testset "reject incompatible world histories" begin
 for mutate in (
    x->(x["config"]["food"]="finite"),
    x->(x["scene"]["world_history"]["next_us"]+=1),
    x->(x["scene"]["world_history"]["stock"][1]=-1),
    x->(x["scene"]["world_history"]["stock"][1]=1.5),
    x->(x["scene"]["world_history"]["ground"]["now_us"]-=1),
    x->(x["scene"]["world_history"]["hazards"]["last_us"]-=2_000_000),
    x->(x["scene"]["world_history"]["food"][1]["x"]+=1),
    x->push!(x["scene"]["world_history"]["cargo"],Dict("index"=>1)))
    bad=mutable_input();mutate(bad)
    @test_throws Exception run_integrated(freeze(bad))
 end
end
# Explicit environmental fixture: three old dropped food units at the new camp,
# zero renewable site stock, and an old territorial target that must be released.
fixture=mutable_input();hist=fixture["scene"]["world_history"]
fixture["config"]["food"]="finite";hist["renewable"]=false
fill!(hist["stock"],0)
for x in (-2.,0.,2.)
 push!(hist["food"],Dict("x"=>x,"z"=>4.,"stock"=>0,"appearance"=>"loose_food"))
 push!(hist["stock"],1)
 push!(hist["cargo"],Dict("index"=>length(hist["food"]),"source"=>Dict("source"=>nothing,"dropper"=>"old_actor","drop_operation"=>"old_drop_$x")))
end
hist["hazards"]["territory"]["target"]="old_actor";hist["hazards"]["territory"]["mode"]="warning"
fixturepath=joinpath(root,"cargo-input.json");write(fixturepath,JSON3.write(fixture))
native_main([joinpath(root,"cargo"),"--spec",fixturepath])
r=JSON3.read(read(joinpath(root,"cargo","result.json"),String))
validate_integrated(r,freeze(fixture))
@testset "inherited cargo and departed target" begin
 @test r.initial_food==7
 @test r.replenished_food==0
 @test r.dropped_cargo.recovered>0
 @test r.dropped_cargo.cross_actor==r.dropped_cargo.recovered
 @test r.world_hazards.territory.target!="old_actor"
 @test all(v.source.dropper=="inherited/old_actor" for v in r.world_checkpoint.cargo)
end
