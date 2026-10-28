include("mb_relation_compression_checks.jl")
@testset "coarser scene representations without hidden detail" begin
 a=chunk_view(0,"far");b=deepcopy(a)
 a["features"][2]["azimuth"]=[32.,40.]
 b["features"][2]["azimuth"]=[56.,64.]
 @test mb_scene(a).key!=mb_scene(b).key
 @test mb_scene(a;abstraction="angle60").key==mb_scene(b;abstraction="angle60").key
 c=deepcopy(b);c["features"][1]["range_band"]="mid"
 @test mb_scene(c;abstraction="angle60").key!=mb_scene(b;abstraction="angle60").key
 @test mb_scene(c;abstraction="distance2").key==mb_scene(b;abstraction="distance2").key
 d=chunk_view(0,"near")
 @test mb_scene(d;abstraction="distance2").key!=mb_scene(b;abstraction="distance2").key
 @test mb_scene(d;abstraction="colors").key==mb_scene(b;abstraction="colors").key
 @test all(f.band=="any" && f.angle==0 for f in values(mb_scene(d;abstraction="colors").features))
 @test_throws ErrorException mb_scene(a;abstraction="invalid")
 @test mb_scene(merge(a,D("coverage"=>"partial"));abstraction="colors")===nothing
 original=relation_scene(a);anchor=first(original)["angle"]
 signature=join(["$(x["color"]):$(x["range_band"]):$(round(Int,wrap_angle(x["angle"]-anchor)/30))" for x in original],"|")
 @test mb_scene(a).signature==signature
 s=mb_map_state("a");s["scene_abstraction"]="colors"
 mb_observe!(s,a,0);firstkey=s["current"].key
 b["source"]="ob:1000000:a";mb_observe!(s,b,1_000_000)
 @test s["current"].key==firstkey && length(s["nodes"])==1
 @test isempty(s["edges"]) && s["chunk_goal_credits"]==0
 fresh=mb_map_state("a")
 @test_throws Exception mb_transfer!(fresh,s,1_000_000)
end
