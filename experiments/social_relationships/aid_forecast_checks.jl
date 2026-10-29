using Test, Serialization
include("../../src/lw/LW.jl")
isdefined(LW,:resolve_prediction!) || Base.include(LW,normpath(joinpath(@__DIR__,"../../src/lw/decision/prediction_result.jl")))
isdefined(LW,:social_aid_state) || Base.include(LW,normpath(joinpath(@__DIR__,"../../src/lw/learning/social_aid.jl")))
const AID_A="npc_a";const AID_B="npc_b";const AID_C="npc_c"
function roundtrip_aid(state)
    io=IOBuffer();serialize(io,state);seekstart(io);deserialize(io)
end
function start_aid(s,id,t;probability=.5,values=[1.,.3],kinds=Dict{Int,Float64}())
    LW.social_aid_begin!(s,id,AID_B,t;probability,values,kind_probabilities=kinds)
end

@testset "aid forecasts freeze owner value and observed food predictions" begin
    s=LW.social_aid_state(AID_A);values=[1.,.3];kinds=Dict(1=>.75,2=>.25)
    forecast=start_aid(s,"first",0;values,kinds)
    @test forecast["expected"]≈.5*(.75+.25*.3)
    values[1]=100.;kinds[1]=0.
    @test s["pending"]["values"]==[1.,.3]
    @test s["pending"]["kind_probabilities"][1]==.75
    @test s["loop"].H===0.
    @test_throws ErrorException LW.social_aid_finish!(s,"first",AID_C,"given",1;received_kind=1)
    @test s["loop"].trial!==nothing
    result=LW.social_aid_finish!(s,"first",AID_B,"given",1;received_kind=1,source="receipt:1")
    @test result["actual"]==1. && result["evaluated"]
    @test result["reward"]≈.95
    @test s["loop"].methods[AID_B].reward≈.95
    before=deepcopy(s)
    @test LW.social_aid_finish!(s,"first",AID_B,"given",1;received_kind=1,source="receipt:1")==result
    @test LW.social_aid_snapshot(s)==LW.social_aid_snapshot(before)
    @test_throws ErrorException LW.social_aid_finish!(s,"first",AID_B,"given",1;received_kind=2,source="receipt:1")
    @test_throws ErrorException start_aid(s,"first",2)
    # The return value is a copy, not mutable access to future prediction data.
    forecast["values"][1]=99.
    @test result["forecast"]["values"][1]==1.
end

@testset "continuous unmet forecasts and measured partial relief" begin
    s=LW.social_aid_state(AID_A)
    start_aid(s,"refusal",0;probability=.8,values=[1.])
    r=LW.social_aid_finish!(s,"refusal",AID_B,"refuse",1)
    @test r["pressure"]≈.75 && r["H_after"]≈.75
    @test s["loop"].methods[AID_B].H≈.75
    @test s["loop"].methods[AID_B].failure_H_total≈.75
    start_aid(s,"small-gift",2;probability=.1,values=[.3])
    r=LW.social_aid_finish!(s,"small-gift",AID_B,"given",3;received_kind=1)
    @test r["pressure"]==0. && r["relief"]≈.25
    @test r["H_after"]≈.5 # Receiving something does not erase all old pressure.
    @test s["loop"].methods[AID_B].H≈.5
    # Same success flag, but a less valuable food falls short of the frozen forecast.
    start_aid(s,"different-taste",4;probability=1.,values=[1.,.2],kinds=Dict(1=>1.))
    r=LW.social_aid_finish!(s,"different-taste",AID_B,"given",5;received_kind=2)
    @test r["actual"]==.2 && r["pressure"]≈.75
    @test r["H_after"]≈1.1 && r["reward"]≈.15
    @test s["loop"].methods[AID_B].failure_count==2
    @test LW.social_aid_pressure(s).parent.H===s["loop"].H
    @test LW.social_aid_pressure(s).methods[AID_B].H===s["loop"].methods[AID_B].H
end

@testset "tolerance applies to residual, not success or observation" begin
    for expected in (.0,.02,.05)
        s=LW.social_aid_state(AID_A)
        start_aid(s,"within",0;probability=expected,values=[1.])
        r=LW.social_aid_finish!(s,"within",AID_B,"refuse",1)
        @test r["evaluated"] && r["pressure"]==0. && r["reward"]==0.
        @test !last(s["loop"].events).fulfilled
    end
    s=LW.social_aid_state(AID_A)
    start_aid(s,"outside",0;probability=.07,values=[1.])
    r=LW.social_aid_finish!(s,"outside",AID_B,"refuse",1)
    @test r["pressure"]≈.02
end

@testset "missing observations and failed execution never become observed refusal" begin
    for (outcome,kind) in (("request_not_executed",nothing),("unobserved",nothing),("given",nothing))
        s=LW.social_aid_state(AID_A);s["loop"].H=1.25
        start_aid(s,"unknown",0;probability=.9,values=[1.])
        r=LW.social_aid_finish!(s,"unknown",AID_B,outcome,1;received_kind=kind)
        @test !r["evaluated"] && r["pressure"]==0. && r["reward"]==0.
        @test r["H_after"]==1.25 && s["deferred"]==1
        @test s["loop"].methods[AID_B].failure_count==0
    end
    s=LW.social_aid_state(AID_A)
    start_aid(s,"waiting",0;probability=.6,values=[1.])
    @test_throws ErrorException LW.social_aid_finish!(s,"waiting",AID_B,"no_response_observed",4_999_999)
    @test s["loop"].H==0. && s["loop"].trial!==nothing
    r=LW.social_aid_finish!(s,"waiting",AID_B,"no_response_observed",5_000_000)
    @test r["pressure"]≈.55 && r["outcome"]=="no_response_observed"
end

@testset "stored aid trials resume with the same evidence and bounds" begin
    s=LW.social_aid_state(AID_A;seed=203)
    start_aid(s,"pending",0)
    restored=roundtrip_aid(s)
    for x in (s,restored)
        LW.social_aid_finish!(x,"pending",AID_B,"given",1;received_kind=2,source="observed:1")
        for i in 1:45
            start_aid(x,"later-$i",2i;probability=.2,values=[.5])
            LW.social_aid_finish!(x,"later-$i",AID_B,"refuse",2i+1)
        end
    end
    @test LW.social_aid_snapshot(s)==LW.social_aid_snapshot(restored)
    @test length(s["records"])==32 && length(s["loop"].events)==32
    @test length(s["loop"].methods)==1 && s["pending"]===nothing
    @test 0<s["loop"].H<=32 && s["resolved"]==46
    snapshot=LW.social_aid_snapshot(s);empty!(snapshot["records"])
    @test length(s["records"])==32
end

@testset "target choice uses persistent learned methods once" begin
    s=LW.social_aid_state(AID_A)
    start_aid(s,"successful",0;probability=.5,values=[1.])
    LW.social_aid_finish!(s,"successful",AID_B,"given",1;received_kind=1)
    target,trace=LW.select_target([AID_B,AID_C],LW.D(),LW.social_aid_pressure(s);seed="compare")
    probs=Dict(c["target"]=>p for (c,p) in zip(trace["candidates"],trace["probabilities"]))
    @test haskey(probs,nothing) && probs[AID_B]>probs[AID_C]
    @test trace["selection"]=="common_H_distribution"
    obs=LW.D("self_id"=>AID_A,"body"=>LW.D("reserve"=>20.),
        "others"=>[LW.D("ref"=>AID_B,"holding_food"=>true)])
    allowed,request=LW.experienced_request(obs,LW.D(),LW.social_aid_pressure(s),AID_A,AID_B,"request")
    @test allowed && request["draw"]===nothing
    @test request["selection"]=="common_target_already_selected"
end

@testset "cumulative outcomes survive bounded logs and duplicate delivery" begin
    s=LW.social_aid_state(AID_A;seed=203)
    for i in 1:250
        other=iseven(i) ? AID_C : AID_B
        t=10_000_000i;outcome=LW.SOCIAL_AID_OUTCOMES[mod1(i,5)]
        LW.social_aid_begin!(s,"many-$i",other,t;probability=.5,values=[1.])
        LW.social_aid_finish!(s,"many-$i",other,outcome,t+6_000_000;
            received_kind=outcome=="given" ? 1 : nothing,source="closed:$i")
    end
    @test s["resolved"]==s["forecasts"]==250
    @test s["deferred"]==100
    @test all(s["outcome_counts"][other][outcome]==25 for other in (AID_B,AID_C), outcome in LW.SOCIAL_AID_OUTCOMES)
    @test sum(sum(values(counts)) for counts in values(s["outcome_counts"]))==250
    @test length(s["records"])==32 && length(s["loop"].events)==32
    before=LW.social_aid_snapshot(s)
    LW.social_aid_finish!(s,"many-250",AID_C,"unobserved",2_506_000_000;source="closed:250")
    @test LW.social_aid_snapshot(s)==before
    @test LW.social_aid_snapshot(roundtrip_aid(s))==before
    before["outcome_counts"][AID_B]["given"]=-1
    @test s["outcome_counts"][AID_B]["given"]==25
end

@testset "real ingestion transfers 250 results without exceeding the packet window" begin
    state=LW.social_initial();aid=LW.social_aid_state(AID_A)
    relation=LW.social_relations_state(AID_A;relational=true)
    for i in 1:250
        t=10_000_000i;id="ingested-$i";op="request-$i"
        outcome=isodd(i) ? "given" : "refuse"
        state["pending"]=LW.D("message_id"=>id,"target"=>AID_B,"deadline"=>t+5_000_000,
            "request_observation_id"=>"ob:$t:$AID_A","operation_id"=>op)
        LW.social_aid_begin!(aid,id,AID_B,t;probability=.5,values=[1.])
        message=LW.D("reply_to"=>id,"sender"=>AID_B,"kind"=>outcome,"time"=>(t+1_000_000)/1e6)
        outcome=="given" && (message["food_kind"]=1)
        packet=LW.D("agent_id"=>AID_A,"capture_us"=>t+1_000_000,
            "observation_id"=>"ob:$(t+1_000_000):$AID_A","social"=>LW.D("messages"=>[message]))
        state=LW.ingest(state,packet,LW.D(op=>LW.D("status"=>"expressed")))
        r=state["records"][id]
        result=LW.social_aid_finish!(aid,id,AID_B,r["outcome"],r["tick"];
            received_kind=get(r,"received_kind",nothing),source=r["source_observation_id"])
        LW.social_relation_event!(relation,AID_B,"aid_received",id,r["tick"];
            outcome=r["outcome"],value=outcome=="given" ? result["actual"] : 0.,food_kind=get(r,"received_kind",0))
        LW.social_record_window!(state)
    end
    records=state["records"]
    @test length(records)==length(records.data)==128
    @test state["records_pruned"]==122 && state["pending"]===nothing
    @test records.order==["ingested-$i" for i in 123:250]
    @test Set(records.order)==Set(keys(records.data))
    @test aid["resolved"]==250 && aid["outcome_counts"][AID_B]["given"]==125
    @test relation["peers"][AID_B]["aid_received"]["refuse"]==125
    @test LW.social_record_window!(state)===state && state["records_pruned"]==122
    # A response without our own execution receipt cannot label the attempt as
    # executed or attach a received kind to request_not_executed.
    state["pending"]=LW.D("message_id"=>"missing-own","target"=>AID_B,"deadline"=>3_005_000_000,
        "request_observation_id"=>"missing-start","operation_id"=>"missing-op")
    packet=LW.D("agent_id"=>AID_A,"capture_us"=>3_001_000_000,"observation_id"=>"missing-end",
        "social"=>LW.D("messages"=>[LW.D("reply_to"=>"missing-own","sender"=>AID_B,
            "kind"=>"given","time"=>3001.,"food_kind"=>1)]))
    missing=LW.ingest(state,packet,LW.D())["records"]["missing-own"]
    @test missing["outcome"]=="request_not_executed" && !haskey(missing,"received_kind")
end

function relational_trade_fixture(seed)
    body=LW.RDLBody;kinds=[fill(body.RAW_ACORN,20),vcat([fill(k,20) for k in body.FOOD_KIND_IDS if k!=body.RAW_ACORN]...),UInt8[]]
    w=LW.world(true);w.positions[AID_C]=(100.,100.)
    for (i,a) in enumerate(LW.IDS)
        w.inventory[a]=length(kinds[i]);w.bodies[a]=body.Body(10.,0.,90.,0.)
    end
    stores=Dict(a=>0 for a in LW.IDS)
    r=LW.food_resources((typed_food=true,initial_inventory_kinds=kinds),w,Any[],Int[],0,stores)
    for a in LW.IDS
        stores[a]=w.inventory[a];LW.food_deposit!(r,a,false);w.inventory[a]=0
    end
    relations=LW.D(a=>LW.social_relations_state(a;relational=true) for a in LW.IDS)
    for i in 1:3
        LW.social_relation_event!(relations[AID_A],AID_B,"trade_offer","prior:$i",i;
            outcome="declined",context=LW.D("need"=>0.))
    end
    t=LW.food_trade_state(seed;relational=true);t["minds"][AID_A]["offer"].H=3.
    (w=w,r=r,stores=stores,t=t,relations=relations)
end
function relational_trade_execute!(x,actor,plan,now)
    result=plan["action"]=="trade_offer" ?
        LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,(0.,0.),actor,plan["trade_source"],plan["action"],now;
            target=plan["target"],give_kind=plan["give_kind"],give_count=plan["give_count"],want_kind=plan["want_kind"],want_count=plan["want_count"]) :
        LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,(0.,0.),actor,plan["trade_source"],plan["action"],now;offer_id=plan["offer_id"])
    LW.food_trade_executed!(x.t,actor,plan,result;relation=x.relations[actor])
    result
end
function selected_relational_trade(response_action)
    for seed in 1:128
        x=relational_trade_fixture(seed)
        views=LW.food_trade_views!(x.t,x.r,x.w,(0.,0.),1_000_000;relations=x.relations)
        p=LW.food_trade_plan!(x.t,AID_A,views[AID_A],x.w.bodies[AID_A],nothing,1_000_000;relation=x.relations[AID_A])
        p===nothing && continue
        p["trade_expected_gain"]>LW.FOOD_TRADE_TOLERANCE || continue
        result=relational_trade_execute!(x,AID_A,p,1_000_000)
        result["status"]=="offered" || continue
        views=LW.food_trade_views!(x.t,x.r,x.w,(0.,0.),2_000_000;relations=x.relations)
        answer=LW.food_trade_plan!(x.t,AID_B,views[AID_B],x.w.bodies[AID_B],nothing,2_000_000;relation=x.relations[AID_B])
        answer!==nothing && answer["action"]==response_action && return x,p,answer
    end
    error("bounded deterministic fixtures did not produce $response_action")
end

@testset "relational trade freezes expected gain and evaluates the committed receipt" begin
    x,plan,answer=selected_relational_trade("trade_accept")
    mind=x.t["minds"][AID_A];loop=mind["offer"];pending=deepcopy(mind["pending"])
    probability=LW.social_relation_profile(x.relations[AID_A],AID_B;situation=plan["trade_context"],H=loop.H)["trade_probability"]
    @test 0<probability<.5 && pending["expected"]≈probability*plan["trade_gain"]
    @test pending["weights"]==plan["trade_weights"] && mind["pending"]["weights"]!==plan["trade_weights"]
    @test loop.H==3. && loop.trial!==nothing && isempty(loop.events)
    # Fresh knowledge and bodily valuation change before settlement. Neither
    # revises the forecast or the valuation already committed to this trial.
    for i in 1:6
        LW.social_relation_event!(x.relations[AID_A],AID_B,"trade_offer","new:$i",2_000_000+i;
            outcome="exchanged",value=.4,context=plan["trade_context"])
    end
    current=LW.social_relation_profile(x.relations[AID_A],AID_B;situation=plan["trade_context"],H=loop.H)["trade_probability"]
    @test current>probability
    plan["trade_context"]["need"]=1.
    @test mind["pending"]["context"]==pending["context"]
    @test mind["pending"]["context"]!==plan["trade_context"]
    x.w.bodies[AID_A]=LW.RDLBody.Body(10.,0.,10.,0.);fill!(plan["trade_weights"],0.)
    @test LW.food_trade_weights(x.w.bodies[AID_A],nothing)!=pending["weights"]
    result=relational_trade_execute!(x,AID_B,answer,3_000_000)
    @test result["status"]=="exchanged"
    response_event=last(x.t["minds"][AID_B]["response"].events)
    @test response_event.expected==answer["trade_gain"]
    notice=only(filter(n->n["offer_id"]==pending["offer_id"],x.t["world"]["notices"][AID_A]))
    actual=LW.food_trade_actual(pending["weights"],notice)
    pressure=max(0.,pending["expected"]-actual-.05,-actual-.05);benefit=max(0.,actual-.05)
    LW.food_trade_views!(x.t,x.r,x.w,(0.,0.),4_000_000;relations=x.relations)
    event=last(loop.events)
    @test event.expected==pending["expected"] && event.actual≈actual
    @test event.goal_H_increment≈pressure && event.reward≈benefit
    @test loop.H≈min(32.,max(0.,3. - benefit)+pressure)
    @test loop.methods[plan["method"]].H≈pressure && loop.methods[plan["method"]].reward≈benefit
    @test mind["pending"]===nothing && loop.trial===nothing
    @test last(x.relations[AID_A]["records"])["context"]==pending["context"]
    before=LW.loop_snapshot(loop)
    LW.food_trade_views!(x.t,x.r,x.w,(0.,0.),5_000_000;relations=x.relations)
    @test LW.loop_snapshot(loop)==before
    @test LW.food_audit!(x.r,x.w,Int[],0,x.stores)===nothing

    x,plan,answer=selected_relational_trade("trade_decline")
    loop=x.t["minds"][AID_A]["offer"];expected=plan["trade_expected_gain"]
    result=relational_trade_execute!(x,AID_B,answer,3_000_000)
    @test result["status"]=="declined"
    LW.food_trade_views!(x.t,x.r,x.w,(0.,0.),4_000_000;relations=x.relations)
    event=last(loop.events)
    @test event.expected==expected && event.actual==0. && event.reward==0.
    @test loop.H≈3. + max(0.,expected-.05)
    @test loop.methods[plan["method"]].H≈max(0.,expected-.05)
    @test LW.food_audit!(x.r,x.w,Int[],0,x.stores)===nothing
end

@testset "shared prediction assessment treats losses and unknown outcomes separately" begin
    loop=LW.BasicLoop("trade";probabilistic=true)
    LW.choose_method!(loop,Any[LW.D("method"=>"swap","priority"=>1.,"question"=>"own_value")],"swap-1")
    @test LW.resolve_prediction!(loop,"swap-1",-.1,-.4;fulfilled=true)
    @test loop.H≈.35 && loop.methods["swap"].H≈.35
    @test last(loop.events).reward==0. && last(loop.events).failed
    @test !LW.resolve_prediction!(loop,"swap-1",-.1,-.4;fulfilled=true)
    @test_throws ErrorException LW.resolve_prediction!(loop,"swap-1",-.1,-.3;fulfilled=true)
end
