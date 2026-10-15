include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "movement continuation authority" begin
 move=D("visible"=>Any[],"energy"=>D("rows"=>[D("cost"=>1.) for i in 1:5]))
 clear=D("coverage"=>"complete","features"=>Any[])
 methods=Dict("step"=>MethodNode(0,2,1))
 receipt(t)=(actor="a",source="op",executed_us=t,phase="exploration",family="food",action="walk",status="performed",moved=true,method="step",route=nothing)
 s=inertia_state("a")
 for i in 1:4
    observe_inertia!(s,"a",i,Any["same"]);s["receipt"]=receipt(i)
    p=inertia_candidate!(s,move,clear,"exploration","food",methods,"now$i")
    @test p!==nothing && p["direction"]==2 && p["method"]=="step"
 end
 observe_inertia!(s,"a",5,Any["same"]);s["receipt"]=receipt(5)
 @test inertia_candidate!(s,move,clear,"exploration","food",methods,"5")===nothing
 @test s["H"]==4 && s["interrupts"]["repetition_threshold"]==1
 observe_inertia!(s,"a",6,Any["new"]);s["receipt"]=receipt(6)
 @test s["H"]==0 && inertia_candidate!(s,move,clear,"exploration","food",methods,"6")!==nothing
 for r in (merge(receipt(6),(moved=false,)),merge(receipt(6),(status="blocked",)),merge(receipt(6),(executed_us=4,)),merge(receipt(6),(phase="return",)),merge(receipt(6),(actor="b",)))
    s["receipt"]=r
    @test inertia_candidate!(s,move,clear,"exploration","food",methods,"stop")===nothing
 end
 s["receipt"]=receipt(6)
 @test inertia_candidate!(s,move,D("coverage"=>"partial","features"=>Any[]),"exploration","food",methods,"partial")===nothing
 @test inertia_candidate!(s,move,D("coverage"=>"complete","features"=>[D("distance"=>10.)]),"exploration","food",methods,"threat")===nothing
 @test inertia_candidate!(s,merge(move,D("visible"=>[D()])),clear,"exploration","food",methods,"food")===nothing
 blocked=deepcopy(move);blocked["energy"]["rows"][3]["cost"]=nothing
 @test inertia_candidate!(s,blocked,clear,"exploration","food",methods,"blocked")===nothing
 @test inertia_candidate!(s,move,clear,"night","food",methods,"night")===nothing
 @test inertia_candidate!(s,move,clear,"exploration","food",Dict(),"retired")===nothing
 @test_throws Exception observe_inertia!(s,"b",7,Any[])
 @test_throws Exception observe_inertia!(s,"a",6,Any[])
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--orientation","on",
    "--relation-field","on","--hazards","mixed","--safety-methods","continuous","--food-body","on","--body-field","on",
    "--movement-inertia",mode,"--general-sleep","apply","--sleep-retention","strata","--sleep-maintenance","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
    @testset "living continuation" begin
        @test sum(s.continued for s in values(r.movement_inertia))>0
        @test all(length(s.records)<=32 for s in values(r.movement_inertia))
        @test all(s.H<=32 for s in values(r.movement_inertia))
    end
 end
end
