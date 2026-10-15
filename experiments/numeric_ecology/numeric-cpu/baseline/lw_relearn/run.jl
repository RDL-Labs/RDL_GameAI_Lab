include(joinpath(@__DIR__,"../lw_day/run.jl"))
plain(x)=JSON3.read(JSON3.write(x))
section(t;present=true)=D("source"=>"ob:$t","capture_us"=>t,"complete"=>true,"affordance"=>present,"count"=>Int(present))
function invalidated()
    h=harvest_state("a");h["relearn_enabled"]=true
    h["model"]=D("model_ref"=>"old","appearance"=>"brown_capped_ovoid","formed_us"=>0,
        "formation"=>["f1","f2","f3"],"validation"=>["v1","v2"],
        "prediction"=>D("acquired"=>1,"affordance_persists"=>1))
    h["admission"]=D("status"=>"LOCAL_ADOPTED")
    review_harvest!(h,"a","counterexample",harvest_predict(h,section(1)),section(1),"picked_up",2,section(2;present=false))
    h
end
function materials!(h;failure=0)
    for i in 1:5
        replacement_result!(h,"a","n$i",section(3i),i==failure ? "not_found" : "picked_up",3i+1,section(3i+2;present=false))
    end
end
@testset "Independent replacement boundaries" begin
    h=invalidated();old=deepcopy(h["model"])
    @test !replacement_result!(h,"a","counterexample",section(1),"picked_up",2,section(2;present=false))
    @test !replacement_result!(h,"a","f1",section(3),"picked_up",4,section(5))
    materials!(h)
    @test length(h["replacement_records"])==5
    @test !replacement_result!(h,"a","n1",section(3),"picked_up",4,section(5;present=false))
    @test_throws ErrorException replacement_result!(h,"a","n1",section(3),"not_found",4,section(5;present=false))
    @test_throws ErrorException replacement_result!(h,"b","x",section(3),"picked_up",4,section(5))
    @test_throws ErrorException replacement_result!(h,"a","x",section(3),"picked_up",4,section(5);accepted=false)
    l=sleeper(0,REST-1_000_000);c=l["sleep"]["cycle"];freeze_harvest!(h,c,100)
    @test h["invalidated"] && h["model"]==old
    receipt!(l,14_400_000_000;on_complete=(c,t)->consolidate_harvest!(h,c,t))
    @test c["result"]["status"]=="LOCAL_REPLACED"
    @test h["model"]["prediction"]==D("acquired"=>1)
    @test h["previous_model"]==old
    @test !h["invalidated"]
    @test isempty(intersect(vcat(old["formation"],old["validation"]),vcat(h["model"]["formation"],h["model"]["validation"])))
    t=17_280_000_000;p=harvest_predict(h,section(t))
    @test p["status"]=="known"
    review_harvest!(h,"a","newsuccess",p,section(t),"picked_up",t+1,section(t+2;present=false))
    @test !h["invalidated"] # persistence is no longer predicted
    p=harvest_predict(h,section(t+3))
    review_harvest!(h,"a","newfailure",p,section(t+3),"not_found",t+4,section(t+5;present=false))
    @test h["invalidated"] && length(h["invalidations"])==2
    @test !replacement_result!(h,"a","again",section(t+6),"picked_up",t+7,section(t+8))
    for (failure,expected) in ((4,"REPLACEMENT_REJECT"),(0,"LOCAL_REPLACED"))
        s=invalidated();materials!(s;failure=failure);cy=sleeper(0)["sleep"]["cycle"];freeze_harvest!(s,cy,100)
        consolidate_harvest!(s,cy,200);@test cy["result"]["status"]==expected
    end
    s=invalidated();cy=sleeper(0)["sleep"]["cycle"];freeze_harvest!(s,cy,100)
    materials!(s);consolidate_harvest!(s,cy,200)
    @test cy["result"]["status"]=="REPLACEMENT_INSUFFICIENT" # no late evidence in frozen cycle
end
input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D())
@testset "Replacement in four-day living" begin
    for spec in input.scenes
        off=lw_day(spec,input.clock;days=4,basic_loop=true,landmark_routes=true,harvest_sleep=true,model_field=true,model_review=true)
        on=lw_day(spec,input.clock;days=4,basic_loop=true,landmark_routes=true,harvest_sleep=true,model_field=true,model_review=true,model_relearn=true)
        @test all(sum(values(on["counts"][a]))==4*17_280 for a in IDS)
        @test all(plain(on["day_starts"][d])==plain(on["daily"][d-1]["physical"]) for d in 2:4)
        @test all(n["sleep"][a]["sleep"]["cycle"]["status"]=="completed" for n in on["daily"] for a in IDS)
        @test all(n["ground"]+n["consumed"]+sum(n["physical"][a]["inventory"]+n["physical"][a]["personal_stock"] for a in IDS)==on["initial_food"] for n in on["daily"])
        @test all(length(get(on["final_agents"][a]["harvest"],"replacement_records",[]))<=6 for a in IDS)
        report["scenes"][spec.name]=D("disabled"=>off,"enabled"=>on)
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
