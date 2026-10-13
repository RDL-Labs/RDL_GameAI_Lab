include(joinpath(@__DIR__,"native.jl"))
include(joinpath(@__DIR__,"checks.jl"))
@testset "ground observation, effort and method identity" begin
    patches=[(x=0.,z=.25,radius=.1,resistance=4.)]
    @test ground_resistance((0.,.25),patches)==4.
    @test ground_resistance((2.,2.),patches)==1.5
    w=(positions=Dict("a"=>(0.,0.)),obstacles=Any[],bodies=Dict("a"=>Body(10.,0.,90.,0.)),inventory=Dict("a"=>0))
    yaw=Dict("a"=>0.)
    m=movement_observation(w,"a",yaw,Any[],Int[];resistance_at=p->ground_resistance(p,patches))
    @test m["movement_surface"]["ground"]["coverage"]=="complete"
    @test length(m["movement_surface"]["ground"]["samples"])==5
    @test all(v["status"]=="sampled" && v["height_delta"]==0 for v in m["movement_surface"]["ground"]["samples"])
    @test m["energy"]["rows"][3]["resistance"]==4.
    @test m["energy"]["rows"][1]["resistance"]==1.5
    _,status,_,delta=step(w.bodies["a"],"walk",0,4.,true)
    @test status=="performed" && delta==m["energy"]["rows"][3]["expected_delta"]
    _,_,_,heavy=step(w.bodies["a"],"walk",6,4.,true)
    @test heavy["reserve"]<delta["reserve"]
    @test heavy["strain"]>delta["strain"]
    cs=[D("method"=>"front","action"=>"walk","direction"=>2,"priority"=>3.,"question"=>"target_nearer"),
        D("method"=>"side","action"=>"walk","direction"=>0,"priority"=>2.8,"question"=>"target_nearer")]
    projected=ground_candidates(cs,m,0)
    @test cs[1]["priority"]==3.
    @test choose_method!(BasicLoop("food"),cs,"old")["method"]=="front"
    @test choose_method!(BasicLoop("food"),projected,"new")["method"]=="side"
    w.bodies["a"]=Body(10.,0.,.00001,0.)
    blocked=movement_observation(w,"a",yaw,Any[],Int[];resistance_at=p->4.)
    @test all(r["cost"]===nothing for r in blocked["energy"]["rows"])
    @test blocked["movement_surface"]==m["movement_surface"]
    obstructed=merge(w,(obstacles=[RDLMigrationProbe.Circle(0.,.6,.25)],))
    oc=movement_observation(obstructed,"a",yaw,Any[],Int[])
    @test oc["movement_surface"]["ground"]["samples"][3]["status"]=="blocked"
    @test oc["movement_surface"]["ground"]["samples"][3]["height_delta"]===nothing
    @test oc["movement_surface"]["ground"]["coverage"]=="complete"
    @test !oc["movement_surface"]["ground"]["output_limited"]
    loop=BasicLoop("food");loop.H=3
    candidates=search_candidates(blocked,nothing,loop)
    @test length(candidates)==1 && candidates[1]["method"]=="survey"
    @test choose_method!(loop,candidates,"scan")["action"]=="scan"
    resolve_method!(loop,"scan",false,false)
    @test loop.H==4 && !haskey(loop.methods,"front")
end

out=ARGS[1]
for mode in ("flat","shadow","patches")
    dir=joinpath(out,mode)
    native_main([dir,"--days","3","--seed","20261004","--food","renewable","--hazards","crossing","--ground",mode])
    r=JSON3.read(read(joinpath(dir,"result.json"),String))
    validate_integrated(r,JSON3.read(read(joinpath(dir,"spec.json"),String)))
    if mode!="flat"
        @testset "ground execution correspondence $mode" begin
            @test sum(s.high_resistance_walks for s in values(r.ground_effects))>0
            @test all(s.delta_mismatches==0 for s in values(r.ground_effects))
            @test all(length(s.records)<=32 for s in values(r.ground_effects))
        end
    end
end
