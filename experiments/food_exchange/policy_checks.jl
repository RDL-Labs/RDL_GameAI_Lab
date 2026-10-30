# Lower-level negotiation regression fixture: necessity is explicitly disabled here.
# Controlled policy fixtures: no long world simulation or repeated resource suite.
using Test, Serialization, JSON3
include("../../src/lw/LW.jl")
const PB=LW.RDLBody
const PA="npc_a";const POTHER="npc_b";const PC="npc_c"
const PHOME=(0.,0.)
function policy_saved(x)
    io=IOBuffer();serialize(io,x);seekstart(io);deserialize(io)
end
function policy_fixture(seed=1;third_fruit=0)
    kinds=[fill(PB.RAW_ACORN,20),fill(PB.FRUIT_FOOD,20),fill(PB.FRUIT_FOOD,third_fruit)]
    w=LW.world(true)
    for (i,a) in enumerate(LW.IDS)
        w.inventory[a]=length(kinds[i]);w.bodies[a]=PB.Body(10.,0.,90.,0.)
    end
    w.positions[PC]=third_fruit>0 ? (.8,0.) : (100.,100.) # no omnipresent third participant
    stores=Dict(a=>0 for a in LW.IDS)
    spec=(typed_food=true,initial_inventory_kinds=kinds)
    r=LW.food_resources(spec,w,Any[],Int[],0,stores)
    for a in LW.IDS
        amount=w.inventory[a];LW.food_deposit!(r,a,false)
        stores[a]+=amount;w.inventory[a]=0
    end
    (r=r,w=w,stores=stores,t=LW.food_trade_state(seed))
end

# One-candidate configured fixture isolates outcome learning; ordinary proposal
# and response selection are exercised probabilistically in the first testset.
function controlled_policy_offer!(x;weights=LW.food_trade_weights(x.w.bodies[PA],nothing))
    gain=LW.food_trade_gain(x.r.personal[PA],weights,PB.RAW_ACORN,1,PB.FRUIT_FOOD,1)
    source="controlled-offer"
    candidate=Dict{String,Any}("method"=>"offer:$(POTHER):$(PB.RAW_ACORN):1:$(PB.FRUIT_FOOD):1",
        "action"=>"trade_offer","priority"=>0.,"question"=>"stock_value_improved",
        "target"=>POTHER,"give_kind"=>PB.RAW_ACORN,"give_count"=>1,
        "want_kind"=>PB.FRUIT_FOOD,"want_count"=>1,"trade_gain"=>gain,
        "trade_role"=>"offer","trade_source"=>source,"trade_weights"=>weights,
        "trade_partner"=>POTHER,"food_exchange"=>true)
    plan=LW.choose_method!(x.t["minds"][PA]["offer"],Any[candidate],source)
    receipt=execute_policy_plan!(x,PA,plan,0)
    receipt["status"]=="offered" || error("controlled offer unavailable")
    plan,receipt["offer_id"]
end
policy_audit(x)=LW.food_audit!(x.r,x.w,Int[],0,x.stores)
function execute_policy_plan!(x,a,p,now)
    result=if p["action"]=="trade_offer"
        LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,PHOME,a,p["trade_source"],p["action"],now;
            target=p["target"],give_kind=p["give_kind"],give_count=p["give_count"],
            want_kind=p["want_kind"],want_count=p["want_count"])
    else
        LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,PHOME,a,p["trade_source"],p["action"],now;
            offer_id=p["offer_id"])
    end
    LW.food_trade_executed!(x.t,a,p,result)
    result
end
function policy_tick!(x,now)
    views=LW.food_trade_views!(x.t,x.r,x.w,PHOME,now)
    plans=Dict(a=>LW.food_trade_plan!(x.t,a,get(views,a,nothing),x.w.bodies[a],nothing,now;require_need=false) for a in LW.IDS)
    results=Dict(a=>execute_policy_plan!(x,a,plans[a],now) for a in LW.IDS if plans[a]!==nothing)
    policy_audit(x)
    (plans=plans,results=results)
end
function offered_policy_fixture()
    for seed in 1:128
        x=policy_fixture(seed);views=LW.food_trade_views!(x.t,x.r,x.w,PHOME,0)
        p=LW.food_trade_plan!(x.t,PA,views[PA],x.w.bodies[PA],nothing,0;require_need=false)
        if p!==nothing && p["trade_gain"]>LW.FOOD_TRADE_TOLERANCE
            result=execute_policy_plan!(x,PA,p,0)
            result["status"]=="offered" && return x,p
        end
    end
    error("controlled seeds did not produce an offer")
end

@testset "probabilistic food proposals produce exchanges and refusals" begin
    totals=Dict(k=>0 for k in ("offered","exchanged","declined","expired","unavailable"))
    rewarded=0;failed=0;skipped=0
    for seed in 1:8
        x=policy_fixture(seed)
        for sec in 0:383;policy_tick!(x,sec*1_000_000);end
        LW.food_trade_views!(x.t,x.r,x.w,PHOME,414_000_000)
        @test policy_audit(x)===nothing
        @test isempty(x.t["world"]["offers"])
        for (k,n) in x.t["world"]["counts"];totals[k]+=n;end
        for mind in values(x.t["minds"]),role in ("offer","response")
            loop=mind[role]
            rewarded+=count(n->n.reward>0,values(loop.methods))
            failed+=sum(n.failure_count for n in values(loop.methods);init=0)
            skipped+=count(e->e.method=="continue_activity",loop.events)
        end
    end
    @test totals["offered"]>0 && totals["exchanged"]>0
    @test totals["declined"]>0 && rewarded>0 && failed>0 && skipped>0
    println("policy sample ",JSON3.write((world=totals,rewarded_methods=rewarded,failed_trials=failed,skip_events=skipped)))
end

@testset "pending exchanges resolve once rather than adding H each tick" begin
    x,p=offered_policy_fixture();mind=x.t["minds"][PA];loop=mind["offer"]
    original_H=loop.H;events=length(loop.events)
    @test mind["pending"]!==nothing && loop.trial!==nothing
    for sec in (1,2,5,10,29)
        LW.food_trade_views!(x.t,x.r,x.w,PHOME,sec*1_000_000)
        @test loop.H==original_H && length(loop.events)==events
        @test loop.trial!==nothing && mind["pending"]!==nothing
    end
    LW.food_trade_views!(x.t,x.r,x.w,PHOME,LW.FOOD_EXCHANGE_TTL_US)
    @test mind["pending"]===nothing && loop.trial===nothing
    @test length(loop.events)==events+1 && loop.H>original_H
    settled=LW.loop_snapshot(loop)
    LW.food_trade_views!(x.t,x.r,x.w,PHOME,LW.FOOD_EXCHANGE_TTL_US+1_000_000)
    @test LW.loop_snapshot(loop)==settled && x.t["world"]["counts"]["expired"]==1
end

@testset "continuing and declining are neutral choices" begin
    skip_found=false
    for seed in 1:128
        x=policy_fixture(seed);loop=x.t["minds"][PA]["offer"];loop.H=2.
        view=LW.food_trade_views!(x.t,x.r,x.w,PHOME,0)[PA]
        p=LW.food_trade_plan!(x.t,PA,view,x.w.bodies[PA],nothing,0;require_need=false)
        if p===nothing && loop.sequence>0
            @test loop.trial===nothing && loop.H==2.
            @test last(loop.events).method=="continue_activity" && last(loop.events).goal_E===nothing
            @test all(n->n.failure_count==0 && n.reward==0,values(loop.methods))
            skip_found=true;break
        end
    end
    @test skip_found
    x=policy_fixture();loop=x.t["minds"][POTHER]["response"];loop.H=2.
    receipt=LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,PHOME,PA,"unknown-meat","trade_offer",0;
        target=POTHER,give_kind=PB.RAW_ACORN,give_count=1,want_kind=PB.MEAT_FOOD,want_count=1)
    @test receipt["status"]=="offered"
    view=LW.food_trade_views!(x.t,x.r,x.w,PHOME,1_000_000)[POTHER]
    p=LW.food_trade_plan!(x.t,POTHER,view,x.w.bodies[POTHER],nothing,1_000_000;require_need=false)
    @test p["action"]=="trade_decline"
    before=LW.food_snapshot(x.r);result=execute_policy_plan!(x,POTHER,p,1_000_000)
    @test result["status"]=="declined" && LW.food_snapshot(x.r)==before
    @test loop.H==2. && loop.trial===nothing && last(loop.events).goal_E===nothing
end

@testset "learning uses the committed swap rather than the old forecast" begin
    x=policy_fixture();loop=x.t["minds"][PA]["offer"]
    plan,id=controlled_policy_offer!(x)
    loop.H=2.
    result=LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,PHOME,POTHER,
        "normal-accept","trade_accept",1_000_000;offer_id=id)
    LW.food_trade_views!(x.t,x.r,x.w,PHOME,2_000_000)
    event=last(loop.events)
    @test result["status"]=="exchanged" && event.E==0 && event.goal_E==0
    @test event.reward≈plan["trade_gain"]-LW.FOOD_TRADE_TOLERANCE
    @test loop.H==0. && loop.methods[plan["method"]].reward>0
    @test policy_audit(x)===nothing

    # C trades with A before B answers A's pending proposal. The later swap is
    # still useful, but fruit is less scarce than at the original prediction.
    x=policy_fixture(;third_fruit=20);loop=x.t["minds"][PA]["offer"]
    plan,id=controlled_policy_offer!(x)
    frozen=copy(plan["trade_weights"])
    @test x.t["minds"][PA]["pending"]["weights"]!==plan["trade_weights"]
    fill!(plan["trade_weights"],0.) # changing a caller buffer must not change pending valuation
    extra=LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,PHOME,PC,
        "intervening-offer","trade_offer",1_000_000;target=PA,
        give_kind=PB.FRUIT_FOOD,give_count=4,want_kind=PB.RAW_ACORN,want_count=1)
    accepted=LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,PHOME,PA,
        "intervening-accept","trade_accept",2_000_000;offer_id=extra["offer_id"])
    @test accepted["status"]=="exchanged" && loop.trial!==nothing && isempty(loop.events)
    result=LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,PHOME,POTHER,
        "delayed-accept","trade_accept",3_000_000;offer_id=id)
    notice=only(filter(n->n["offer_id"]==id,x.t["world"]["notices"][PA]))
    @test notice["own_before"][PB.FRUIT_FOOD]==4 && notice["own_after"][PB.FRUIT_FOOD]==5
    @test notice["own_before"][PB.RAW_ACORN]==19 && notice["own_after"][PB.RAW_ACORN]==18
    actual=LW.food_trade_gain(notice["own_before"],frozen,PB.RAW_ACORN,1,PB.FRUIT_FOOD,1)
    @test LW.FOOD_TRADE_TOLERANCE<actual<plan["trade_gain"]-LW.FOOD_TRADE_TOLERANCE
    LW.food_trade_views!(x.t,x.r,x.w,PHOME,4_000_000)
    event=last(loop.events)
    @test event.E==0 && event.goal_E==1 && event.reward==0.
    @test event.goal_H_increment≈plan["trade_gain"]-actual-LW.FOOD_TRADE_TOLERANCE
    @test loop.H≈event.goal_H_increment
    @test !event.failed && loop.methods[plan["method"]].failure_count==0
    @test loop.credit_path==[plan["method"]] && x.t["minds"][PA]["pending"]===nothing
    settled=LW.loop_snapshot(loop)
    LW.food_trade_views!(x.t,x.r,x.w,PHOME,5_000_000)
    @test LW.loop_snapshot(loop)==settled && policy_audit(x)===nothing

    # A completed physical transaction is not necessarily useful enough to
    # count as a goal success. Preserve earlier H inside the zero-equivalent band.
    x=policy_fixture();loop=x.t["minds"][PA]["offer"];loop.H=2.
    plan,id=controlled_policy_offer!(x;weights=fill(.01,length(PB.FOOD_KIND_IDS)))
    @test 0. < plan["trade_gain"] < LW.FOOD_TRADE_TOLERANCE
    LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,PHOME,POTHER,
        "neutral-accept","trade_accept",1_000_000;offer_id=id)
    LW.food_trade_views!(x.t,x.r,x.w,PHOME,2_000_000)
    event=last(loop.events)
    @test event.E===nothing && event.goal_E===nothing && event.reward==0.
    @test loop.H==2. && event.goal_H_increment==0. && loop.trial===nothing
    @test policy_audit(x)===nothing
end

@testset "trade learning and pending decisions survive serialization" begin
    x,p=offered_policy_fixture();restored=policy_saved(x)
    @test LW.food_trade_snapshot(restored.t)==LW.food_trade_snapshot(x.t)
    next_original=policy_tick!(x,1_000_000);next_restored=policy_tick!(restored,1_000_000)
    @test next_original==next_restored
    left=[policy_tick!(x,sec*1_000_000) for sec in 2:69]
    right=[policy_tick!(restored,sec*1_000_000) for sec in 2:69]
    @test left==right
    @test LW.food_snapshot(x.r)==LW.food_snapshot(restored.r)
    @test LW.food_trade_snapshot(x.t)==LW.food_trade_snapshot(restored.t)
    @test x.stores==restored.stores && policy_audit(x)===nothing && policy_audit(restored)===nothing
end

@testset "trade actions pause existing navigation without resetting it" begin
    for action in ("trade_offer","trade_accept","trade_decline")
        route=LW.mb_route_state()
        route["active"]=Dict{String,Any}("id"=>"known-home-route","goal"=>"home","cursor"=>2,
            "path"=>["edge-1","edge-2","edge-3"],"H"=>1.25,"started_us"=>10,"last_us"=>20,
            "repair_pending"=>false,"reason"=>"progress")
        s=Dict{String,Any}("routes"=>route);before=deepcopy(route)
        p=Dict{String,Any}("action"=>action,"food_exchange"=>true,"purpose_family"=>"home")
        LW.mb_route_record!(s,p,"exchanged",30;energy=.1)
        @test route["active"]!==nothing && route["active"]["reason"]=="social_pause"
        expected=deepcopy(before);expected["active"]["reason"]="social_pause"
        @test route==expected
        LW.mb_route_repair_record!(s,p,"exchanged",.1,31)
        @test route==expected && !haskey(p,"mb_local_repair")
    end
end
