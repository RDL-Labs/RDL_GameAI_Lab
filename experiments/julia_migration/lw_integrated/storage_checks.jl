include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "stock floor" begin
 food=[(stock=12,),(stock=12,)];stock=[2,20]
 @test replenish_food!(stock,food;capacity=8)==6
 @test stock==[8,20]
 @test replenish_food!(stock,food;capacity=8)==0
end
root=ARGS[1]
for mode in ("personal","shared")
 native_main([joinpath(root,mode),"--days","4","--seed","20261005","--food","renewable",
  "--stores",mode,"--regrowth-days","3","--regrowth-capacity","12"])
 r=JSON3.read(read(joinpath(root,mode,"result.json"),String));input=JSON3.read(read(joinpath(root,mode,"spec.json"),String))
 validate_integrated(r,input)
 @test length(r.replenishments)==1 && only(r.replenishments).day==3
 @test r.world_checkpoint.regrowth_days==3
 @test mode!="shared" || all(a.personal_stock==0 for a in values(r.final_agents))
end
x=JSON3.read(read(joinpath(root,"shared","spec.json"),String),Dict{String,Any})
x["config"]["days"]=1;x["config"]["food"]="finite"
x["scene"]["positions"]=[[0.,4.],[0.,4.],[0.,4.]]
x["scene"]["initial_inventory"]=[6,0,0];x["scene"]["reserve"]=[100,30,30]
x["scene"]["food"]=Any[];x["scene"]["obstacles"]=Any[]
p=joinpath(root,"sharing-input.json");write(p,JSON3.write(x))
for name in ("sharing","replay")
 native_main([joinpath(root,name),"--spec",p])
 r=JSON3.read(read(joinpath(root,name,"result.json"),String));validate_integrated(r,JSON3.read(read(p,String)))
 @test r.shared_storage.deposited>=6
 @test r.shared_storage.taken>0
 @test any(t.actor!="npc_a" && t.action=="retrieve" && t.status=="performed" for t in r.shared_storage.records)
end
@test read(joinpath(root,"sharing","result.json"))==read(joinpath(root,"replay","result.json"))
r=JSON3.read(read(joinpath(root,"sharing","result.json"),String))
x["scene"]["world_history"]=r.world_checkpoint;x["scene"]["initial_inventory"]=[0,0,0]
p=joinpath(root,"inherited-input.json");write(p,JSON3.write(x))
native_main([joinpath(root,"inherited"),"--spec",p])
n=JSON3.read(read(joinpath(root,"inherited","result.json"),String));validate_integrated(n,JSON3.read(read(p,String)))
@test n.initial_food==r.shared_stock
