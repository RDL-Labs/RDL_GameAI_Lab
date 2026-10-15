include(joinpath(@__DIR__,"../lw_day/run.jl"))
plain(x)=JSON3.read(JSON3.write(x))
@testset "Bounded learned approach field" begin
    h=harvest_state("a")
    h["model"]=D("model_ref"=>"test","appearance"=>"brown_capped_ovoid","formed_us"=>10)
    h["admission"]=D("status"=>"LOCAL_ADOPTED")
    move=D("visible"=>[D("appearance"=>"brown_capped_ovoid","forward"=>0.,"right"=>5.,"distance"=>5.)],
        "energy"=>D("rows"=>[D("ref"=>"2","cost"=>1.),D("ref"=>"4","cost"=>1.)]))
    cs=[D("method"=>"front","action"=>"walk","direction"=>2,"priority"=>3.,"question"=>"target_nearer"),
        D("method"=>"right","action"=>"walk","direction"=>4,"priority"=>2.9,"question"=>"target_nearer")]
    before=deepcopy((cs,move,h))
    projected,tr=harvest_field(cs,move,h,"a",11;enabled=true)
    @test choose_method!(BasicLoop("food"),cs,"x")["method"]=="front"
    @test choose_method!(BasicLoop("food"),projected,"x")["method"]=="right"
    @test tr["applied"]
    @test all(0<=r["value"]<=0.5 for r in tr["contributions"])
    @test (cs,move,h)==before
    @test harvest_field(cs,move,h,"a",11)[1]==cs
    @test harvest_field(cs,move,h,"a",9;enabled=true)[1]==cs
    @test harvest_field(cs,move,h,"a",11;enabled=true,complete=false)[1]==cs
    @test harvest_field(cs,move,harvest_state("a"),"a",11;enabled=true)[1]==cs
    @test_throws ErrorException harvest_field(cs,move,h,"b",11;enabled=true)
    blocked=deepcopy(move);blocked["energy"]["rows"][2]["cost"]=nothing
    @test harvest_field(cs,blocked,h,"a",11;enabled=true)[1][2]==cs[2]
    absent=deepcopy(move);empty!(absent["visible"])
    @test harvest_field(cs,absent,h,"a",11;enabled=true)[1]==cs
    @test harvest_predict(h,harvest_section(move,"ob",11))["status"]=="unknown"
    scan=[D("method"=>"survey","action"=>"scan","priority"=>2.,"question"=>"target_observed")]
    @test harvest_field(scan,move,h,"a",11;enabled=true)[1]==scan
end
input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D())
@testset "Learned field continuous living" begin
    for spec in input.scenes
        off=lw_day(spec,input.clock;days=3,basic_loop=true,landmark_routes=true,harvest_sleep=true)
        on=lw_day(spec,input.clock;days=3,basic_loop=true,landmark_routes=true,harvest_sleep=true,model_field=true)
        @test all(sum(values(on["counts"][a]))==3*17_280 for a in IDS)
        @test all(plain(on["day_starts"][d])==plain(on["daily"][d-1]["physical"]) for d in 2:3)
        @test all(n["sleep"][a]["sleep"]["cycle"]["status"]=="completed" for n in on["daily"] for a in IDS)
        @test all(n["ground"]+n["consumed"]+sum(n["physical"][a]["inventory"]+n["physical"][a]["personal_stock"] for a in IDS)==on["initial_food"] for n in on["daily"])
        @test all(on["final_agents"][a]["model_field"]["selection_changes"]<=on["final_agents"][a]["model_field"]["applied"] for a in IDS)
        report["scenes"][spec.name]=D("disabled"=>off,"enabled"=>on)
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
