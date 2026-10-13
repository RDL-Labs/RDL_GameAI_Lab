include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "incomplete reposition boundaries" begin
 w=(positions=Dict("a"=>(0.,0.)),obstacles=Any[],bodies=Dict("a"=>Body(10.,0.,90.,0.)),inventory=Dict("a"=>0))
 food=[(x=Float64(i)/10,z=3.,stock=1) for i in 1:6]
 m=movement_observation(w,"a",Dict("a"=>0.),food,ones(Int,6))
 @test m["food_coverage"]=="partial"
 s=reposition_state("a")
 @test isempty(reposition_candidates!(s,"a",m,0))
 @test isempty(reposition_candidates!(s,"a",m,1_000_000;linked=true))
 @test isempty(reposition_candidates!(s,"a",m,2_000_000;linked=true))
 cs=reposition_candidates!(s,"a",m,3_000_000;linked=true)
 @test length(cs)==3
 @test all(c["direction"] in (1,2,3) for c in cs)
 @test isempty(reposition_candidates!(s,"a",m,3_000_000;linked=true))
 @test s["residual"]==2
 for t in 4:7;cs=reposition_candidates!(s,"a",m,t*1_000_000;linked=true);end
 @test length(cs)==5
 @test_throws Exception reposition_candidates!(s,"b",m,8_000_000;linked=true)
 blocked=deepcopy(m);blocked["movement_surface"]["ground"]["samples"][3]["status"]="blocked"
 cs=reposition_candidates!(s,"a",blocked,8_000_000;linked=true)
 @test all(c["direction"]!=2 for c in cs)
 limited=deepcopy(m);limited["movement_surface"]["ground"]["output_limited"]=true
 @test isempty(reposition_candidates!(s,"a",limited,9_000_000;linked=true))
 exhausted=deepcopy(m);for r in exhausted["energy"]["rows"];r["cost"]=nothing;end
 @test isempty(reposition_candidates!(s,"a",exhausted,10_000_000;linked=true))
 complete=deepcopy(m);complete["food_coverage"]="complete"
 @test isempty(reposition_candidates!(s,"a",complete,30_000_000;linked=true))
 @test s["residual"]==0
end
root=ARGS[1]
for mode in ("off","on")
 native_main([joinpath(root,mode),"--days","3","--seed","20261005","--food","renewable","--reposition",mode])
 r=JSON3.read(read(joinpath(root,mode,"result.json"),String));input=JSON3.read(read(joinpath(root,mode,"spec.json"),String))
 validate_integrated(r,input)
end
# Explicit finite visual-overflow fixture, same native lifecycle.
x=JSON3.read(read(joinpath(root,"on","spec.json"),String),Dict{String,Any});x["config"]["days"]=1
x["scene"]["obstacles"]=Any[]
x["scene"]["food"]=[Dict("x"=>Float64(i)/10,"z"=>8.,"stock"=>12) for i in 1:6]
p=joinpath(root,"overflow-input.json");write(p,JSON3.write(x))
for name in ("overflow","replay")
 native_main([joinpath(root,name),"--spec",p])
 r=JSON3.read(read(joinpath(root,name,"result.json"),String));validate_integrated(r,JSON3.read(read(p,String)))
 @test sum(s.offered for s in values(r.reposition))>0
end
@test read(joinpath(root,"overflow","result.json"))==read(joinpath(root,"replay","result.json"))
