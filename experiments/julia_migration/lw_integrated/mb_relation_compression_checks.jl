include("mb_exploration_relation_checks.jl")
function compression_fixture()
 s=mb_map_state("a");s["exploration_relations_enabled"]=true;r=mb_exploration_state!(s)
 for (key,sig) in (("a","brown:near:0|gray:far:2"),("b","brown:near:1|gray:far:3"),
                   ("different","brown:far:0|gray:near:2"))
  s["nodes"][key]=D("signature"=>sig,"home"=>false,"food"=>false)
 end
 for key in ("a","b")
  r["links"][key*":brown"]=D("source"=>key,"label"=>"brown","origin_home_strength"=>.8,
   "predicted_strength"=>.4,"support"=>2.,"contradiction"=>.2,"failures"=>0,"selected"=>3,
   "approach_evidence"=>.5,"arrival_evidence"=>.1,"target_scene"=>key)
 end
 s,r
end
@testset "sleep compression of similar outbound relations" begin
 s,r=compression_fixture();nodes=deepcopy(s["nodes"]);edges=deepcopy(s["edges"])
 before=sum(l["selected"] for l in values(r["links"]))
 report=mb_compress_exploration!(s,1,100)
 @test report["before"]==2 && report["after"]==1
 l=only(values(r["links"]))
 @test l["represented"]==2 && l["selected"]==before && l["support"]==4.
 @test s["nodes"]==nodes && s["edges"]==edges && s["chunk_goal_credits"]==0
 @test mb_compress_exploration!(s,1,101)===nothing
 @test mb_compress_exploration!(s,2,200)["merged"]==0
 @test only(values(r["links"]))["selected"]==before
 # Recall still offers a continuous contribution at the merged-away scene.
 s["current"]=(key="b",signature=nodes["b"]["signature"],anchor=0.)
 s["current_us"]=200
 p=D("cue_kind"=>"shape","cue_label"=>"brown","action"=>"walk","priority"=>2.5)
 @test only(mb_exploration_project!(s,[p],"home",8,200))["priority"]>2.5
 for change in (:label,:strength,:outcome,:unknown,:geometry,:pending)
  s,r=compression_fixture();b=r["links"]["b:brown"]
  change==:label && (b["label"]="gray")
  change==:strength && (b["predicted_strength"]=.1)
  change==:outcome && (b["target_scene"]="different")
  change==:unknown && (b["target_scene"]=nothing)
  change==:geometry && (b["source"]="different")
  change==:pending && (r["pending"]=D("link"=>"b:brown"))
  @test mb_compress_exploration!(s,1,100)["after"]==2
 end
 # No evidence means keep rather than silently delete; disabled runs unchanged.
 s,r=compression_fixture();delete!(s["nodes"],"b")
 @test mb_compress_exploration!(s,1,100)["after"]==2
 s,r=compression_fixture();s["exploration_relations_enabled"]=false
 @test mb_compress_exploration!(s,1,100)===nothing && length(r["links"])==2
 # Same 30-degree storage tolerance under a learned angle metric.
 s,r=compression_fixture();s["recognition"]["metric"]["enabled"]=true
 s["recognition"]["metric"]["weights"]=[2.,1.8]
 s["nodes"]["b"]["signature"]="brown:near:0|gray:far:3"
 @test mb_compress_exploration!(s,1,100)["after"]==1
end
