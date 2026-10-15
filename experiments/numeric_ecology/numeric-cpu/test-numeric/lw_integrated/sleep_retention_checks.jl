include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "retained strata survive repeated rest" begin
 s=general_sleep_state()
 remember_general!(s,"a","blocked","walk","blocked",nothing,"exploration",1;retain=true)
 remember_general!(s,"a","moved","walk","performed",nothing,"exploration",2;retain=true)
 for i in 3:100
  remember_general!(s,"a","rest$i","rest","performed",nothing,"night",i;retain=true)
 end
 @test length(s["history"])==64
 @test length(s["retained"])==3
 freeze_general!(s,"a",101;retained=true)
 @test Set(r["id"] for r in s["frozen"])==Set(["blocked","moved","rest100"])
 frozen=deepcopy(s["frozen"])
 remember_general!(s,"a","later","walk","blocked",nothing,"exploration",102;retain=true)
 @test s["frozen"]==frozen
 freeze_general!(s,"a",103;retained=true)
 @test any(r->r["id"]=="later",s["frozen"])
 @test !any(r->r["id"]=="blocked",s["frozen"])
 for i in 1:40
  remember_general!(s,"a","new$i","action$i","performed",nothing,"exploration",103+i;retain=true)
 end
 @test length(s["retained"])==32
 @test s["evictions"]==11
 freeze_general!(s,"a",150;retained=true)
 @test length(s["frozen"])==6
 @test_throws Exception freeze_general!(s,"other",150;retained=true)
end
out=ARGS[1]
for mode in ("recent","strata")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--general-sleep","apply","--sleep-retention",mode])
 r=JSON3.read(read(joinpath(dir,"result.json"),String))
 validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="strata"
  @testset "retained daytime life records" begin
   @test any(x.phase!="night" for s in values(r.general_sleep) for v in s.reviews for x in v.records)
   @test all(length(s.retained)<=32 for s in values(r.general_sleep))
   @test all(length(v.records)<=6 for s in values(r.general_sleep) for v in s.reviews)
   @test all(x.executed_us<=v.formation_us for s in values(r.general_sleep) for v in s.reviews for x in v.records)
  end
 end
end
