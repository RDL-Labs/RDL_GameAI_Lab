include(joinpath(@__DIR__,"../lw_day/run.jl"))
plain(x)=JSON3.read(JSON3.write(x))
section(t;present=true,complete=true)=D("source"=>"ob:$t","capture_us"=>t,"complete"=>complete,"affordance"=>present,"count"=>Int(present))
function adopted()
    h=harvest_state("a");h["model"]=D("model_ref"=>"m","formed_us"=>0,"appearance"=>"brown_capped_ovoid",
        "prediction"=>D("acquired"=>1,"affordance_persists"=>1));h["admission"]=D("status"=>"LOCAL_ADOPTED");h
end
@testset "Later harvest comparison boundaries" begin
    for (status,present,complete,pose,expected) in (("picked_up",true,true,true,"confirmed"),
            ("picked_up",false,true,true,"difference"),("not_found",true,true,true,"difference"),
            ("picked_up",false,false,true,"defer"),("picked_up",false,true,false,"defer"),
            ("unexecuted",false,true,true,"defer"))
        h=adopted();before=section(1);after=section(3;present=present,complete=complete)
        pred=harvest_predict(h,before);model=deepcopy(h["model"])
        @test review_harvest!(h,"a","op",pred,before,status,2,after;pose=pose)
        @test last(h["comparisons"])["status"]==expected
        @test get(h,"invalidated",false)==(expected=="difference")
        @test h["model"]==model
        snapshot=deepcopy(h)
        @test !review_harvest!(h,"a","op",pred,before,status,2,after;pose=pose)
        @test snapshot==h
        @test_throws ErrorException review_harvest!(h,"a","op",pred,before,"not_found",2,after;pose=!pose)
        if expected=="difference"
            @test harvest_predict(h,section(4))["status"]=="unknown"
            move=D("visible"=>Any[],"energy"=>D("rows"=>Any[]))
            @test harvest_field(Any[],move,h,"a",4;enabled=true)[2]["status"]=="model_invalidated"
            c=sleeper(1)["sleep"]["cycle"];freeze_harvest!(h,c,4);consolidate_harvest!(h,c,5)
            @test c["result"]["status"]=="MODEL_INVALIDATED"
        end
    end
    h=adopted();pred=harvest_predict(h,section(1))
    @test_throws ErrorException review_harvest!(h,"b","x",pred,section(1),"picked_up",2,section(3))
    @test_throws ErrorException review_harvest!(h,"a","x",pred,section(1),"picked_up",2,section(3);accepted=false)
    @test_throws ErrorException review_harvest!(h,"a","x",pred,section(0),"picked_up",2,section(3))
    @test_throws ErrorException review_harvest!(h,"a","x",merge(pred,D("model_ref"=>"other")),section(1),"picked_up",2,section(3))
    for i in 1:40
        before=section(3i);review_harvest!(h,"a",string(i),harvest_predict(h,before),before,"picked_up",3i+1,section(3i+2))
    end
    @test length(h["comparisons"])==32
    @test h["comparison_counts"]["confirmed"]==40
    @test_throws ErrorException review_harvest!(h,"a","old",pred,section(1),"picked_up",2,section(3))
end
input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D())
@testset "Review during continuous living" begin
    for spec in input.scenes
        off=lw_day(spec,input.clock;days=3,basic_loop=true,landmark_routes=true,harvest_sleep=true,model_field=true)
        on=lw_day(spec,input.clock;days=3,basic_loop=true,landmark_routes=true,harvest_sleep=true,model_field=true,model_review=true)
        @test all(sum(values(on["counts"][a]))==3*17_280 for a in IDS)
        @test all(plain(on["day_starts"][d])==plain(on["daily"][d-1]["physical"]) for d in 2:3)
        @test all(n["sleep"][a]["sleep"]["cycle"]["status"]=="completed" for n in on["daily"] for a in IDS)
        @test all(n["ground"]+n["consumed"]+sum(n["physical"][a]["inventory"]+n["physical"][a]["personal_stock"] for a in IDS)==on["initial_food"] for n in on["daily"])
        @test all(length(get(on["final_agents"][a]["harvest"],"comparisons",[]))<=32 for a in IDS)
        report["scenes"][spec.name]=D("disabled"=>off,"enabled"=>on)
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
