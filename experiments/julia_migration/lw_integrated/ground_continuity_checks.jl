include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
function band_view(now;angle=0,appearance="bare_ground",occluded=false)
 cells=[D("angle"=>a,"distance"=>d,"status"=>occluded ? "occluded" : "sampled","appearance"=>occluded ? nothing : a==angle ? appearance : "grass") for a in ANGLES for d in (1,2,4)]
 D("source"=>D("actor"=>"a","observation"=>"ob:$now:a","capture_us"=>now),"coverage"=>occluded ? "partial" : "complete","cells"=>cells)
end
link(before,after;forward=0.,yaw=0.)=D("actor"=>"a","source"=>"ob:$before:a","before_us"=>before,"after_us"=>after,"forward"=>forward,"right"=>0.,"yaw"=>yaw)
@testset "body-linked ground continuity" begin
 s=ground_memory("a");update_ground!(s,band_view(0),nothing)
 @test length(s["models"])==1
 name=s["models"][1]["model_ref"]
 update_ground!(s,band_view(1_000_000),link(0,1_000_000;forward=.5))
 @test s["models"][1]["model_ref"]==name
 @test s["models"][1]["extended"]
 safe=D("energy"=>D("rows"=>[D("cost"=>1.) for _ in 1:5]))
 @test ground_proposals(s,safe)[1]["direction"]==2
 prior=deepcopy(s);update_ground!(s,band_view(1_000_000),nothing)
 @test s==prior
 update_ground!(s,band_view(2_000_000;angle=-90),link(1_000_000,2_000_000;yaw=90.))
 @test s["models"][1]["model_ref"]==name
 @test ground_proposals(s,safe)[1]["direction"]==0
 update_ground!(s,band_view(3_000_000;occluded=true),link(2_000_000,3_000_000))
 @test isempty(ground_proposals(s,safe))
 update_ground!(s,band_view(4_000_000;angle=-90,appearance="grass"),link(3_000_000,4_000_000))
 @test s["models"][1]["status"]=="observed_context_changed"
 update_ground!(s,band_view(5_000_000),nothing)
 @test s["models"][1]["model_ref"]!=name
 @test_throws ErrorException update_ground!(ground_memory("other"),band_view(0),nothing)
 blocked=D("energy"=>D("rows"=>[D("cost"=>nothing) for _ in 1:5]))
 @test isempty(ground_proposals(s,blocked))
 for t in 6:80;update_ground!(s,band_view(t*1_000_000),link((t-1)*1_000_000,t*1_000_000));end
 @test all(length(m["links"])<=16 && length(m["points"])<=32 && length(m["sources"])<=16 for m in s["models"])
 loop=BasicLoop("food");plan=choose_method!(loop,ground_proposals(s,safe),"trial")
 resolve_method!(loop,"trial",false,false)
 @test loop.methods[plan["method"]].H==1 && loop.H==1
end
@testset "unsupported ground is not failure" begin
 model=D("model_ref"=>"ground_1","status"=>"observed","extended"=>true)
 state=D("models"=>[model])
 @test ground_extension_result(state,"ground_1","performed",true)===true
 @test ground_extension_result(state,"ground_1","performed",false)===false
 @test ground_extension_result(state,"ground_1","blocked",false)===false
 model["extended"]=false
 @test ground_extension_result(state,"ground_1","performed",true)===false
 for status in ("not_currently_supported","observed_context_changed")
    model["status"]=status
    @test ground_extension_result(state,"ground_1","performed",true)===nothing
 end
 @test ground_extension_result(state,"retired","performed",true)===nothing
 @test ground_extension_result(nothing,"ground_1","performed",true)===nothing
 loop=BasicLoop("food")
 candidate=D("method"=>"ground_1","priority"=>1.,"question"=>"ground_extension","action"=>"walk")
 choose_method!(loop,[candidate],"first");resolve_method!(loop,"first",false,false)
 choose_method!(loop,[candidate],"second")
 value=ground_extension_result(state,"ground_1","performed",true)
 resolve_method!(loop,"second",value,false)
 @test loop.methods["ground_1"].H==1 && loop.H==2
 @test last(loop.events).E===nothing && last(loop.events).goal_E==1
 @test !resolve_method!(loop,"second",value,false)
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--ground","patches","--ground-wear","on","--ground-perception","on","--ground-continuity",mode])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
  @testset "living continuity" begin
   @test all(s.linked_updates==51839 for s in values(r.ground_continuity))
   @test all(length(s.models)<=8 for s in values(r.ground_continuity))
   @test all(count(k->startswith(String(k),"ground_"),keys(l.methods))<=8 for day in r.daily for a in values(day.physical) for l in values(a.loops))
   @test sum(s.selections for s in values(r.ground_continuity))>0
  end
 end
end
