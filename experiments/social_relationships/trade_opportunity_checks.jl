include("camp_trade_calls_checks.jl")
@testset "uncapped opportunity and residual" begin
    f=camp_fixture();a,b,c=f.ids;state=f.states[a];day=17_280_000_000
    opportunity=LW.configured_trade_opportunity_enable!(state)
    state["trade_daily_start"]=D("day"=>0,"used"=>8)
    LW.configured_camp_trade_state!(state)["last_day"]=0
    @test LW.trade_start_available(state,1,day)
    call(now)=LW.configured_camp_trade_call!(state,f.maps[a],f.w.bodies[a],nothing,f.foods.personal[a],now,day)
    event=nothing
    for now in 1:100
        event=call(now)
        event!==nothing && break
    end
    @test event!==nothing
    key="buy:$(event["kind"])"
    forecast=LW.configured_trade_opportunity_score(state,key,10.)
    stock_before=deepcopy(f.foods.personal)
    # Nobody is present to hear: ordinary expiry ends the attempt, once.
    LW.configured_camp_trade_tick!(f.states,f.maps,f.w,f.foods,nothing,nothing,event["expires_us"],a->false,a->false,a->false)
    @test opportunity["pending"]===nothing
    @test opportunity["evidence"][key]["trials"]==1
    @test LW.configured_trade_opportunity_score(state,key,10.).priority<forecast.priority
    @test call(event["expires_us"]+1)===nothing
    @test opportunity["ready_home"]
    @test f.foods.personal==stock_before
    LW.configured_trade_opportunity_finish!(state,false,event["expires_us"]+2;reason="duplicate")
    @test opportunity["evidence"][key]["trials"]==1
    # Body/stock-driven larger benefit can exceed prior disappointment. Day reset isn't needed.
    @test LW.configured_trade_opportunity_score(state,key,1000.).priority>0
    @test LW.configured_trade_opportunity_score(state,"buy:7",10.).H==0
    house=LW.configured_house_state();target=(x=0.,z=0.,radius=1.)
    plan=LW.configured_trade_opportunity_house!(state,house,target,(0.,0.),0.,200_000_000,day,Any[];demand=0.)
    @test plan["method"]=="personal_house_rest"
    @test house["mode"]=="idle"
    @test LW.configured_trade_opportunity_house!(state,house,target,(0.,0.),0.,200_000_001,day,Any[];blocked=true)===nothing
    # Successful outcome releases only the corresponding trial, allowing same-day retries.
    LW.configured_trade_opportunity_begin!(state,key,10.,event)
    channel=LW.configured_camp_trade_state!(state)
    channel["meeting"]=D("peer"=>b)
    LW.configured_camp_trade_state!(f.states[b])["meeting"]=D("peer"=>a)
    LW.configured_camp_trade_result!(f.states,a,D("status"=>"exchanged"),200_000_002)
    @test opportunity["evidence"][key]["H"]==0
    @test opportunity["evidence"][key]["successes"]==1
    next_event=nothing
    for now in 200_000_003:200_000_103
        next_event=call(now);next_event!==nothing && break
    end
    @test next_event!==nothing
    @test channel["calls"]==2
    @test !opportunity["ready_home"]
    # Serialized derived decision and unresolved trial survive resume.
    io=IOBuffer();serialize(io,state);seekstart(io)
    @test deserialize(io)["trade_opportunity"]==opportunity
    # Rejection lowers the originating call; interrupted calls do not inherit others' results.
    channel["meeting"]=D("peer"=>b)
    LW.configured_camp_trade_result!(f.states,a,D("status"=>"rejected"),200_000_104)
    @test opportunity["evidence"][key]["H"]>0
    saved=deepcopy(opportunity["evidence"])
    LW.configured_trade_opportunity_begin!(state,key,10.,event)
    LW.configured_trade_opportunity_cancel!(state,200_000_105)
    LW.configured_trade_opportunity_finish!(state,true,200_000_106;reason="other_trade")
    @test opportunity["evidence"]==saved
    channel["outgoing"]=nothing;opportunity["ready_home"]=true
    travelling=LW.configured_house_state()
    walk=LW.configured_trade_opportunity_house!(state,travelling,(x=5.,z=0.,radius=1.),(0.,0.),0.,200_000_107,day,
        Any[D("cost"=>1.,"clear"=>true,"ref"=>"0")])
    @test walk["method"]=="personal_house_return"
    @test travelling["mode"]=="travelling"
    println(JSON3.write((calls=channel["calls"],evidence=opportunity["evidence"],house=house["mode"])))
end
