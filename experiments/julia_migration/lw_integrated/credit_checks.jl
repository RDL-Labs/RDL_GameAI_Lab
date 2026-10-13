include(joinpath(@__DIR__,"bundle_checks.jl"))
@testset "parent credit is shared and once-only" begin
 s=bundle_state("a");s["active"]=[D("model_ref"=>"b1"),D("model_ref"=>"b2")]
 trace=D("changed"=>true,"selected"=>"walk","contributors"=>["b1","b2"])
 parent=D("actor"=>"a","due"=>5_000_000,"H"=>6)
 admit_bundle_credit!(s,trace,"walk","performed",parent,"op1")
 admit_bundle_credit!(s,trace,"walk","performed",parent,"op2")
 @test length(s["parent_credit"]["pending"])==1
 h=hunger_state("a");h["due"]=5_000_000;h["H"]=6
 hunger_update!(h,"a",5_000_000,90.)
 resolve_bundle_credit!(s,h)
 @test s["parent_credit"]["strength"]==D("b1"=>3.,"b2"=>3.)
 @test isempty(s["parent_credit"]["pending"])
 before=deepcopy(s);resolve_bundle_credit!(s,h);admit_bundle_credit!(s,trace,"walk","performed",parent,"op3")
 @test s==before
 parent["due"]=10_000_000
 admit_bundle_credit!(s,trace,"scan","performed",parent,"wrong")
 @test isempty(s["parent_credit"]["pending"])
 admit_bundle_credit!(s,trace,"walk","expired",parent,"expired")
 @test isempty(s["parent_credit"]["pending"])
 admit_bundle_credit!(s,trace,"walk","blocked",parent,"blocked")
 h["due"]=10_000_000;hunger_update!(h,"a",10_000_000,60.)
 resolve_bundle_credit!(s,h)
 @test s["parent_credit"]["records"]["10000000"]["credit"]==0
 @test s["parent_credit"]["strength"]["b1"]==3.
 @test_throws Exception resolve_bundle_credit!(s,hunger_state("other"))
end
dir=joinpath(ARGS[1],"credit")
native_main([dir,"--days","4","--seed","20261005","--food","renewable","--food-body","on","--general-sleep","apply","--sleep-retention","strata","--experience-bundles","on","--bundle-credit","on"])
r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
@testset "living credit bounds" begin
 @test all(all(0<=v<=8 for v in values(s.parent_credit.strength)) for s in values(r.experience_bundles))
 @test all(all(0<=v.credit<=8 for v in values(s.parent_credit.records)) for s in values(r.experience_bundles))
end
