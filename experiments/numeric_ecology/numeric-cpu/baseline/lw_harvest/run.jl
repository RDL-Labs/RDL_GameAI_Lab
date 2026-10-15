include(joinpath(@__DIR__,"../lw_day/run.jl"))
plain(x)=JSON3.read(JSON3.write(x))
section(i;present=true,complete=true,count=1)=D("source"=>"ob:$i","capture_us"=>i*1_000_000,
    "complete"=>complete,"affordance"=>present,"count"=>count)
function prepared(;failure=0,incomplete=0,difference=true)
    h=harvest_state("a")
    harvest_observe!(h,section(0;count=0))
    difference && harvest_observe!(h,section(1))
    for i in 1:5
        harvest_result!(h,"a","op:$i",section(2i),i==failure ? "not_found" : "picked_up",
            (2i+1)*1_000_000,section(2i+1;complete=i!=incomplete))
    end
    h
end
@testset "Harvest sleep boundaries" begin
    h=prepared();l=sleeper(0,REST-1_000_000);c=l["sleep"]["cycle"]
    freeze_harvest!(h,c,14_400_000_000)
    @test h["model"]===nothing
    done=(c,t)->consolidate_harvest!(h,c,t)
    @test receipt!(l,14_400_000_000;on_complete=done)
    @test c["result"]["status"]=="LOCAL_ADOPTED"
    @test length(h["model"]["formation"])==3 && length(h["model"]["validation"])==2
    @test isempty(intersect(h["model"]["formation"],h["model"]["validation"]))
    saved=deepcopy(h)
    @test !receipt!(l,14_400_000_000;on_complete=done)
    @test h==saved
    @test harvest_predict(h,section(17_280))["status"]=="known"
    @test harvest_predict(h,section(17_280;present=false))["status"]=="unknown"
    @test harvest_predict(h,section(17_280;complete=false))["status"]=="unknown"
    @test harvest_predict(h,section(1))["status"]=="unknown"
    @test !harvest_result!(h,"a","op:1",section(2),"picked_up",3_000_000,section(3))
    @test_throws ErrorException harvest_result!(h,"a","op:1",section(2),"not_found",3_000_000,section(3))
    @test_throws ErrorException harvest_result!(h,"b","x",section(2),"picked_up",3_000_000,section(3))
    @test_throws ErrorException harvest_result!(h,"a","x",section(2),"picked_up",3_000_000,section(3);accepted=false)
    for (state,expected) in ((prepared(failure=4),"REJECT"),(prepared(incomplete=4),"DEFER"),
            (prepared(difference=false),"DEFER"),(harvest_state("a"),"INSUFFICIENT_EVIDENCE"))
        cycle=sleeper(0)["sleep"]["cycle"];freeze_harvest!(state,cycle,14_400_000_000)
        consolidate_harvest!(state,cycle,17_280_000_000)
        @test cycle["result"]["status"]==expected
        @test state["model"]===nothing
    end
    h=prepared();l=sleeper(0,REST-1_000_000);freeze_harvest!(h,l["sleep"]["cycle"],14_400_000_000)
    receipt!(l,14_400_000_000;phase="safety",on_complete=(c,t)->consolidate_harvest!(h,c,t))
    @test l["sleep"]["cycle"]["rest_us"]==0 && h["model"]===nothing
    h["records"][1]["acquired"]=false
    @test l["sleep"]["cycle"]["records"][1]["acquired"] # frozen before later changes
end

input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D())
@testset "Harvest in continuous living" begin
    for spec in input.scenes
        off=lw_day(spec,input.clock;days=3,basic_loop=true,landmark_routes=true)
        on=lw_day(spec,input.clock;days=3,basic_loop=true,landmark_routes=true,harvest_sleep=true)
        @test on["counts"]==off["counts"] && on["events"]==off["events"] # prediction has no new action authority
        @test on["ground"]==off["ground"] && on["consumed"]==off["consumed"]
        @test all(plain(on["day_starts"][d])==plain(on["daily"][d-1]["physical"]) for d in 2:3)
        @test all(n["sleep"][a]["sleep"]["cycle"]["status"]=="completed" for n in on["daily"] for a in IDS)
        @test all(n["ground"]+n["consumed"]+sum(n["physical"][a]["inventory"]+n["physical"][a]["personal_stock"] for a in IDS)==on["initial_food"] for n in on["daily"])
        @test all(length(on["final_agents"][a]["harvest"]["records"])<=6 for a in IDS)
        report["scenes"][spec.name]=D("disabled"=>off,"enabled"=>on)
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
