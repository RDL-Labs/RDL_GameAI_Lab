include(joinpath(@__DIR__,"native.jl"))
using Test
function sceneview(now,bands;rotation=0.,coverage="complete")
 D("source"=>"ob:$now:a","coverage"=>coverage,"features"=>[
 D("color"=>color,"azimuth"=>[angle+rotation-5,angle+rotation+5],"range_band"=>band,"distance"=>band=="near" ? 4. : 12.)
 for (color,angle,band) in zip(("brown","gray"),(0.,45.),bands)])
end
move=D("energy"=>D("rows"=>[D("ref"=>string(i),"cost"=>1.) for i in 0:4]))
walk=D("action"=>"walk","direction"=>0)
@testset "observed graph and bounded multistep simulation" begin
 s=mb_map_state("a")
 a=sceneview(0,("far","far"));b=sceneview(1_000_000,("mid","far"));c=sceneview(2_000_000,("near","mid"))
 @test mb_scene(a).key==mb_scene(sceneview(0,("far","far");rotation=20.)).key
 @test mb_scene(sceneview(0,("far","far");coverage="partial"))===nothing
 @test_throws ErrorException mb_observe!(s,a,1)
 mb_observe!(s,a,0);mb_record!(s,walk,"performed",.02,0)
 mb_observe!(s,b,1_000_000);mb_record!(s,walk,"performed",.03,1_000_000)
 mb_observe!(s,c,2_000_000;home=true)
 @test length(s["edges"])==2
 @test all(e["from"]!=mb_scene(c).key for e in values(s["edges"]))
 mb_observe!(s,sceneview(3_000_000,("far","far")),3_000_000)
 @test isempty(mb_simulate!(s,move,"home",0,2,90.,0.,3_000_000))
 @test isempty(mb_simulate!(s,move,"home",4,2,10.,0.,3_000_000))
 @test isempty(mb_simulate!(s,move,"home",4,2,90.,.9,3_000_000))
 cs=mb_simulate!(s,move,"home",4,2,90.,0.,3_000_000)
 @test length(cs)==1 && cs[1]["mb_depth"]==2
 @test cs[1]["question"]=="target_observed"
 @test s["expanded"]<=64
 @test isempty(mb_simulate!(s,move,"home",4,2,90.,0.,4_000_000))
 key=cs[1]["mb_edge"];cost=mb_edge_cost(s["edges"][key])
 mb_record!(s,cs[1],"performed",.02,3_000_000)
 mb_observe!(s,sceneview(4_000_000,("far","far")),4_000_000)
 @test s["prediction_miss"]==1 && mb_edge_cost(s["edges"][key])>cost
 mb_record!(s,cs[1],"performed",.02,4_000_000)
 mb_observe!(s,sceneview(5_000_000,("mid","far")),5_000_000)
 @test s["prediction_match"]==1
 before=length(s["edges"])
 mb_record!(s,walk,"blocked",.01,5_000_000)
 mb_observe!(s,sceneview(6_000_000,("near","mid")),6_000_000;home=true)
 @test length(s["edges"])==before
 @test isempty(mb_simulate!(s,move,"food",4,2,90.,0.,70_000_000))
 @test_throws ErrorException mb_simulate!(s,move,"home",4,2,90.,0.,80_000_000;max_depth=5)
 # Unknown next observations must not count as failed predictions.
 mb_observe!(s,sceneview(80_000_000,("far","far")),80_000_000)
 mb_record!(s,cs[1],"performed",.01,80_000_000)
 mb_observe!(s,sceneview(81_000_000,("mid","far");coverage="partial"),81_000_000)
 @test s["prediction_unknown"]==1
end
@testset "integrated observation graph" begin
 input=JSON3.read(read(joinpath(@__DIR__,"search_review_spec.json"),String),Dict{String,Any})
 input["config"]["days"]=1;input["config"]["mb_simulation"]="on";input["config"]["body_purpose"]="on"
 input["config"]["general_landmarks"]="on";input["config"]["rho_profile"]="coarse"
 input["clock"]["day_us"]=600_000_000;input["clock"]["phase_boundaries_us"]=[1_000_000,200_000_000,300_000_000,600_000_000]
 input["clock"]["quiet_night_us"]=400_000_000
 r,summary=run_integrated(JSON3.read(JSON3.write(input)))
 @test r["mb_map"]==summary["mb_map"]
 @test all(m["observations"]==600 && length(m["nodes"])<=1280 && length(m["edges"])<=5120 && length(m["records"])<=32 for m in values(r["mb_map"]))
 @test sum(length(m["edges"]) for m in values(r["mb_map"]))>0
 @test all(m["expanded"]<=64*m["searches"] for m in values(r["mb_map"]))
 @test r["initial_food"]+r["replenished_food"]==r["ground"]+r["shared_stock"]+r["consumed"]+sum(s["inventory"]+s["personal_stock"] for s in values(r["final_agents"]))
 println(JSON3.write(D(a=>D("nodes"=>length(m["nodes"]),"edges"=>length(m["edges"]),"searches"=>m["searches"],"proposals"=>m["proposals"]) for (a,m) in r["mb_map"])))
end
@testset "bounded memory and missing evidence" begin
 s=mb_map_state("a")
 for i in 0:1399
  ob=sceneview(i*1_000_000,("far","mid"));ob["features"][2]["color"]="gray$i"
  mb_observe!(s,ob,i*1_000_000)
  mb_record!(s,walk,"performed",.01,i*1_000_000)
  if i==139; @test length(s["nodes"])==140 && s["evictions"]==0; end
 end
 @test length(s["nodes"])==1280
 @test length(s["edges"])<=5120 && s["evictions"]>0
 @test all(haskey(s["nodes"],e["from"]) && haskey(s["nodes"],e["to"]) for e in values(s["edges"]))
 @test isempty(mb_simulate!(s,move,"home",32,2,90.,0.,200_000_000)) # stale observation
 @test s["searches"]==0
end

@testset "expanded edge capacity" begin
 s=mb_map_state("a");now=0;count=0
 for from in 1:80,to in 1:80
  from==to && continue
  count+=1;count>5125 && break
  ob=sceneview(now,("far","mid"));ob["features"][2]["color"]="gray$from"
  mb_observe!(s,ob,now);mb_record!(s,walk,"performed",.01,now);now+=1_000_000
  ob=sceneview(now,("far","mid"));ob["features"][2]["color"]="gray$to"
  mb_observe!(s,ob,now);now+=1_000_000
  if count==513; @test length(s["edges"])==513 && s["evictions"]==0; end
 end
 @test length(s["edges"])==5120
 @test s["evictions"]==5
 @test all(haskey(s["nodes"],e["from"]) && haskey(s["nodes"],e["to"]) for e in values(s["edges"]))
end
