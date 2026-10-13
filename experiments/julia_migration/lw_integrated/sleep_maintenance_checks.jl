include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "usage dormancy and reactivation" begin
 s=sleep_action_state("a");context=Any[false,false,Any[]]
 for id in ("used","idle","rare")
  s["records"][id]=D("id"=>id,"phase"=>"exploration","context"=>context)
 end
 enroll_sleep_usage!(s,1);m=s["maintenance"]
 m["usage"]["idle"]["opportunities"]=1
 plan=D("sleep_changed"=>true,"sleep_sources"=>["used"])
 record_sleep_use!(s,plan,"op","performed");record_sleep_use!(s,plan,"op","performed")
 @test m["usage"]["used"]["uses"]==1
 review_sleep_usage!(s,0,2)
 @test m["usage"]["used"]["idle"]==0
 @test !m["usage"]["idle"]["dormant"]
 m["usage"]["idle"]["opportunities"]=1
 review_sleep_usage!(s,1,3)
 @test m["usage"]["idle"]["dormant"]
 @test !m["usage"]["rare"]["dormant"]
 review_sleep_usage!(s,1,3)
 @test length(m["reviews"])==2
 review_sleep_usage!(s,2,4)
 @test m["usage"]["rare"]["dormant"]
 @test length(s["records"])==3
 wake_sleep_usage!(s,context,"night")
 @test m["usage"]["rare"]["dormant"]
 wake_sleep_usage!(s,nothing,"exploration")
 @test m["usage"]["rare"]["dormant"]
 wake_sleep_usage!(s,context,"exploration")
 @test !m["usage"]["rare"]["dormant"]
 @test m["usage"]["rare"]["idle"]==0
 for i in 1:40;s["records"]["more$i"]=D("phase"=>"exploration","context"=>context);end
 enroll_sleep_usage!(s,5);wake_sleep_usage!(s,context,"exploration")
 @test count(u->!u["dormant"],values(m["usage"]))==32
 @test length(s["records"])==43
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","4","--seed","20261005","--food","renewable","--general-sleep","apply","--sleep-retention","strata","--sleep-maintenance",mode])
 r=JSON3.read(read(joinpath(dir,"result.json"),String))
 validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
  @testset "maintenance in completed living nights" begin
   @test all(length(s.maintenance.days)==4 for s in values(r.sleep_action_models))
   @test all(count(u->!u.dormant,values(s.maintenance.usage))<=32 for s in values(r.sleep_action_models))
   @test all(Set(keys(s.records))==Set(keys(s.maintenance.usage)) for s in values(r.sleep_action_models))
  end
 end
end
