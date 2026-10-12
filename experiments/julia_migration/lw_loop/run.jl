include(joinpath(@__DIR__,"../lw_day/run.jl"))
plain(x)=JSON3.read(JSON3.write(x))
proposal(name,priority=2.)=D("method"=>name,"priority"=>priority,"question"=>"tested","action"=>"scan")
@testset "Reusable local goal method loop" begin
    for family in ("home","food","arbitrary-question")
        s=BasicLoop(family;parent="living");other=BasicLoop("other")
        @test choose_method!(s,Any[],"empty")===nothing
        @test choose_method!(s,[proposal("first"),proposal("second",1.5)],"1")["method"]=="first"
        @test_throws ErrorException choose_method!(s,[proposal("first")],"again")
        @test_throws ErrorException resolve_method!(s,"wrong",false,false)
        @test_throws ErrorException resolve_method!(s,"1",false,false;accepted=false)
        @test s.H==0
        resolve_method!(s,"1",false,false)
        @test s.H==1 && s.methods["first"].H==1
        @test !resolve_method!(s,"1",false,false)
        @test_throws ErrorException resolve_method!(s,"1",true,false)
        @test choose_method!(s,[proposal("first"),proposal("second",1.5)],"2")["method"]=="second"
        resolve_method!(s,"2",true,false)
        @test s.methods["second"].H==0 && s.H==2 # Movement success is not parent success.
        choose_method!(s,[proposal("second")],"3");resolve_method!(s,"3",nothing,nothing)
        @test s.H==2 && s.methods["second"].H==0
        choose_method!(s,[proposal("second")],"4");resolve_method!(s,"4",true,true)
        @test s.H==0 && other.H==0 && isempty(other.methods)
        @test s.parent=="living"
    end
    s=BasicLoop("home");s.H=2
    move=D("energy"=>D("rows"=>[D("cost"=>nothing,"ref"=>"0")]))
    @test length(search_candidates(move,nothing,s))==1
    @test search_candidates(move,nothing,s)[1]["action"]=="scan"
    @test_throws ErrorException BasicLoop("same";parent="same")
    s=BasicLoop("unresolved");selected=String[]
    for i in 1:100
        c=choose_method!(s,[proposal("survey",2.),proposal("step",1.5)],string(i))
        push!(selected,c["method"]);resolve_method!(s,string(i),false,false)
    end
    @test Set(selected[end-9:end])==Set(["survey","step"])
    @test s.methods["survey"].H==32 && s.methods["step"].H==32
    @test length(s.events)==32
    @test choose_method!(s,[proposal("survey")],"only-feasible")["method"]=="survey"
end

input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D())
@testset "Continuous three day lifecycle" begin
    for spec in input.scenes
        baseline=lw_day(spec,input.clock)
        elapsed=@elapsed result=lw_day(spec,input.clock;days=3,basic_loop=true)
        @test result["ended_us"]==3*input.clock.day_us
        @test all(sum(values(result["counts"][a]))==3*17_280 for a in IDS)
        @test all(plain(result["day_starts"][d])==plain(result["daily"][d-1]["physical"]) for d in 2:3)
        @test all(n["sleep"][a]["sleep"]["cycle"]["status"]=="completed" for n in result["daily"] for a in IDS)
        @test all(n["ground"]+n["consumed"]+sum(n["physical"][a]["inventory"]+n["physical"][a]["personal_stock"] for a in IDS)==result["initial_food"] for n in result["daily"])
        @test any(e["phase"]=="return" && e["action"]=="walk" for e in result["events"])
        @test all(get(result["daily"][d]["counts"][a],"walk",0)>get(result["daily"][d-1]["counts"][a],"walk",0) for d in 2:3 for a in IDS)
        report["scenes"][spec.name]=D("baseline_one_day_counts"=>baseline["counts"],
            "elapsed_seconds_unpaired"=>elapsed,"result"=>result)
    end
    spec=JSON3.read(JSON3.write(merge(D(string(k)=>v for (k,v) in pairs(input.scenes[1])),D("initial_personal_stock"=>[2,0,0]))))
    result=lw_day(spec,input.clock;basic_loop=true)
    @test get(result["counts"]["npc_a"],"retrieve",0)>0
    @test get(result["counts"]["npc_a"],"eat",0)>0
    # The operation immediately after a retrieval can eat the owner's unit.
    events=[e for e in result["events"] if e["actor"]=="npc_a"]
    @test any(events[i]["action"]=="retrieve" && events[i]["status"]=="performed" && events[i+1]["action"]=="eat" && events[i+1]["status"]=="ate" for i in 1:length(events)-1)
    report["private_stock_control"]=result
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
