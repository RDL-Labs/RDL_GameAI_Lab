include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "finite running body and safety" begin
    b=Body(10.,0.,90.,0.)
    after,status,d,delta=step(b,"run",0,1.5,true)
    @test status=="performed" && d==1.5
    @test after.burst==5.5
    @test isapprox(delta["reserve"],-.75*RS;atol=1e-12)
    @test after.strain==.27*SS
    @test step(b,"run",0,4.,true)[2]=="body_limited"
    @test step(b,"run",20,1.5,true)[2]=="body_limited"
    @test step(Body(0.,0.,90.,0.),"run",0,1.5,true)[2]=="body_limited"
    @test step(b,"run",0,1.5,false)[3]==0.
    @test step(Body(10.,0.,90.,.5),"run",0,1.,true)[3]==.75
    w=(positions=Dict("a"=>(0.,0.)),obstacles=RDLMigrationProbe.Circle[],bodies=Dict("a"=>b),inventory=Dict("a"=>0))
    yaw=Dict("a"=>0.)
    m=movement_observation(w,"a",yaw,Any[],Int[];running=true)
    seen=D("coverage"=>"complete","features"=>[D("forward"=>0.,"right"=>3.,"distance"=>3.)])
    @test safety_plan!(safety_state(),seen,m)["action"]=="walk"
    @test safety_plan!(safety_state(),seen,m;running=true)["action"]=="run"
    @test m["run_rows"][3]["expected_delta"]==delta
    push!(w.obstacles,RDLMigrationProbe.Circle(0.,1.4,.05))
    m=movement_observation(w,"a",yaw,Any[],Int[];running=true)
    @test m["energy"]["rows"][3]["cost"]!==nothing
    @test m["run_rows"][3]["cost"]===nothing
    w.bodies["a"]=Body(0.,0.,90.,0.)
    m=movement_observation(w,"a",yaw,Any[],Int[];running=true)
    @test safety_plan!(safety_state(),seen,m;running=true)["action"]=="walk"
end
out=ARGS[1]
for mode in ("off","on")
    dir=joinpath(out,mode)
    native_main([dir,"--days","3","--seed","20261005","--food","renewable","--hazards","crossing","--running",mode])
    r=JSON3.read(read(joinpath(dir,"result.json"),String))
    validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
    if mode=="on"
        @testset "actual running correspondence" begin
            @test sum(s.performed for s in values(r.running))>0
            @test all(s.delta_mismatches==0 for s in values(r.running))
            @test all(length(s.records)<=32 for s in values(r.running))
        end
    end
end
