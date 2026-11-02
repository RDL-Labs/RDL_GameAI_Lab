include("checks.jl")
isdefined(LW,:trade_start_available) || Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/trade_daily_limit.jl"))
@testset "daily shared initiation allowance" begin
    a=LW.D();b=LW.D();day=100_000_000
    @test LW.trade_start_available(a,0,day)
    @test !LW.trade_start_record!(a,"item_offer","unavailable",0,day,"failed")
    @test LW.trade_start_record!(a,"item_offer","offered",0,day,"a:1")
    @test !LW.trade_start_available(a,1,day)
    @test !LW.trade_start_record!(a,"item_offer","offered",0,day,"a:1")
    @test a["trade_daily_start"]["total"]==1
    @test LW.trade_start_available(b,1,day)
    @test LW.trade_start_record!(b,"trade_offer","offered",1,day,"b:1")
    @test !LW.trade_start_available(b,2,day)
    for action in ("item_counter","item_accept","item_decline","trade_accept","trade_decline")
        @test !LW.trade_start_record!(a,action,"offered",2,day,action)
    end
    @test !LW.trade_start_available(item_saved_copy(a),day-1,day)
    @test LW.trade_start_available(a,day,day)
    @test LW.trade_start_record!(a,"trade_offer","offered",day,day,"a:2")
    @test a["trade_daily_start"]["used"]==1
    @test a["trade_daily_start"]["total"]==2
    state=LW.incidental_item_state(ITEM_A,1);f=item_fixture();v=item_view(f,ITEM_A)
    @test LW.item_social_plan!(state,v,f.w.bodies[ITEM_A],nothing,f.foods.personal[ITEM_A],0;allow_start=false)===nothing
    @test LW.item_attention_view!(state,f.s,f.w,ITEM_HOME,ITEM_A,0.,0;purpose=:trade,allow_start=false)===nothing
    @test state["attention"]["details"]==0
    # Exhausting initiation must not suppress another actor's negotiation.
    f=item_fixture(objects=[placed_item(1,1;owner=ITEM_A,location="held"),
        placed_item(2,2;owner=ITEM_B,location="held")])
    f.w.positions[ITEM_A]=(0.,0.);f.w.positions[ITEM_B]=(0.,.1);empty!(f.w.obstacles)
    @test offer_item(f)["status"]=="offered"
    responder=LW.incidental_item_state(ITEM_B,2)
    view=LW.item_attention_view!(responder,f.s,f.w,ITEM_HOME,ITEM_B,0.,1_000_000;purpose=:trade,allow_start=false)
    @test view!==nothing && length(view["incoming"])==1
    plan=LW.item_social_plan!(responder,view,f.w.bodies[ITEM_B],nothing,f.foods.personal[ITEM_B],1_000_000;allow_start=false)
    @test plan!==nothing && plan["action"] in ("item_accept","item_decline","item_counter")
end
