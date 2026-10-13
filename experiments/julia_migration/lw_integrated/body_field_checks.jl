include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "read-only method comparison" begin
 s=BasicLoop("food")
 cs=[D("method"=>m,"priority"=>p,"action"=>a,"question"=>"movement_progress") for (m,p,a) in (("a",2.,"walk"),("b",1.5,"scan"),("c",1.,"rest"))]
 for i in 1:40
    before=deepcopy(loop_snapshot(s));trial=s.trial;receipt=s.receipt
    peek=method_choice(s,cs)
    @test loop_snapshot(s)==before && s.trial==trial && s.receipt==receipt
    reference=choose_method!(deepcopy(s),cs,"op$i")
    @test peek["method"]==reference["method"]
    actual=choose_method!(s,cs,"op$i")
    @test actual==reference
    resolve_method!(s,"op$i",i%3==0,false)
 end
end
@testset "body contributions preserve authority" begin
 candidates()=[D("method"=>m,"priority"=>p,"action"=>a,"question"=>q) for (m,p,a,q) in
    (("walk",1.5,"walk","movement_progress"),("rest",1.,"rest","rested"),("work",.5,"pickup","acquired"))]
 h=hunger_state("a");cs=candidates();b=Body(10.,.79,90.,0.)
 @test project_body_methods!(cs,h,b,"exploration")
 @test isapprox(cs[1]["priority"],1.105) && isapprox(cs[2]["priority"],1.79) && cs[3]["priority"]==.5
 @test method_choice(BasicLoop("food"),cs)["method"]=="rest"
 h["intensity"]=1.;h["H"]=2;cs=candidates();b=Body(10.,.79,0.,0.)
 project_body_methods!(cs,h,b,"return")
 @test isapprox(cs[1]["priority"],2.105) && cs[2]["priority"]==0.
 @test method_choice(BasicLoop("food"),cs)["method"]=="walk"
 for phase in ("night","orientation","safety")
    cs=candidates();old=deepcopy(cs)
    @test !project_body_methods!(cs,h,b,phase) && cs==old
 end
 cs=candidates();cs[1]["record_trial"]=false
 project_body_methods!(cs,h,b,"return")
 @test cs[1]["priority"]==1.5
 s=BasicLoop("food");c=choose_method!(s,[candidates()[2]],"rest")
 resolve_method!(s,"rest",true,false)
 @test s.methods["rest"].H==0 && s.H==1
end
out=ARGS[1]
for mode in ("off","on")
 dir=joinpath(out,mode)
 native_main([dir,"--days","3","--seed","20261005","--food","renewable","--orientation","on",
    "--hazards","mixed","--safety-methods","continuous","--food-body","on","--body-field",mode,
    "--general-sleep","apply","--sleep-retention","strata","--sleep-maintenance","on"])
 r=JSON3.read(read(joinpath(dir,"result.json"),String));validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
 if mode=="on"
    @testset "living body field" begin
        @test sum(s.applied for s in values(r.body_field))>0
        @test all(0<=s.changed<=s.applied for s in values(r.body_field))
    end
 end
end
