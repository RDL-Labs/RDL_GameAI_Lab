using Test, Serialization, Random, JSON3
include("../../src/lw/LW.jl")
const D=LW.D
# Synthetic observations, but real LW selection, acquisition and trade adapters.
# No long run or claim of autonomous forecast generation.
candidate(method;priority=0.)=D("method"=>method,"priority"=>priority,"question"=>"local_outcome")
function trial!(loop,id,method)
    LW.choose_method!(loop,[candidate(method)],id)
end
@testset "human selection: own residual, no parent temperature" begin
    loop=LW.BasicLoop("human";probabilistic=true,seed=7)
    rows=[candidate("fish";priority=2.),candidate("gather")]
    before=LW.method_distribution(loop,rows)
    loop.H=32.
    @test LW.method_distribution(loop,rows)==before
    rows[1]["decision_H"]=32.;rows[1]["goal_arrival"]=true
    @test LW.method_distribution(loop,rows)==before
    loop.methods["fish"]=LW.MethodNode(2.,2.,0)
    @test LW.method_distribution(loop,rows)[1]<before[1]
    loop.methods["fish"].failure_H_total=100.
    penalized=LW.method_distribution(loop,rows)
    loop.methods["fish"].failure_H_total=0.
    @test LW.method_distribution(loop,rows)==penalized
    relation=D()
    LW.gradient_capture!(relation,loop,rows,rows[1],"trace",0)
    traced=last(relation["gradient_maps"]["records"])["candidates"]
    @test all(r->r["temperature"]==1. && r["repulsion"]==0.,traced)
    @test only(filter(r->r["method"]=="fish",traced))["method_penalty"]==1.
    @test only(filter(r->r["method"]=="fish",traced))["probability"]==penalized[1]
    legacy=LW.BasicLoop("animal";probabilistic=true,h_mode=:legacy)
    base=LW.method_distribution(legacy,[candidate("a";priority=2.),candidate("b")])
    legacy.H=32.
    @test LW.method_distribution(legacy,[candidate("a";priority=2.),candidate("b")])[1]<base[1]
end
@testset "real fishing acquisition ledger" begin
    map=LW.mb_map_state(first(LW.IDS))
    LW.acquisition_result!(map,"fishing",1,100.,200.,false;now=1)
    state=map["acquisition"]
    @test state["methods"]["fishing"]["H"]≈2.
    LW.acquisition_result!(map,"fishing",1,100.,0.,true;now=2)
    @test state["sites"]["fishing:1"]["H"]≈1.
    @test state["methods"]["fishing"]["H"]≈1.
    # Site switch does not erase the method's unresolved difference.
    LW.acquisition_result!(map,"fishing",2,200.,100.,true;now=3)
    @test state["sites"]["fishing:2"]["H"]==0.
    @test state["methods"]["fishing"]["H"]≈1.
    snapshot=deepcopy(state)
    LW.acquisition_result!(map,"fishing",2,200.,100.,true;now=3)
    @test state==snapshot
    @test state["sites"]["fishing:1"]["H"]≈1.
    # Re-publishing an already reported result has no effect.
    LW.acquisition_publish!(state,state["trials"][end];achieved=true)
    @test state==snapshot
    io=IOBuffer();serialize(io,map);seekstart(io);restored=deserialize(io)
    LW.acquisition_result!(restored,"fishing",2,200.,0.,true;now=4)
    LW.acquisition_result!(map,"fishing",2,200.,0.,true;now=4)
    @test restored["acquisition"]==map["acquisition"]
    @test state["methods"]["fishing"]["H"]==0.
end
@testset "real trade prediction and signed loss" begin
    a=LW.BasicLoop("A:trade";probabilistic=true)
    b=LW.BasicLoop("B:trade";probabilistic=true)
    trial!(a,1,"offer:B");trial!(b,1,"accept:A")
    LW.resolve_prediction!(a,1,.3,.3;fulfilled=true,tolerance=0.,parent_expected=.8,parent_actual=.3)
    LW.resolve_prediction!(b,1,.4,.6;fulfilled=true,tolerance=0.)
    @test a.methods["offer:B"].H==0.
    @test a.H≈.5
    @test b.H==0.
    @test !LW.resolve_prediction!(a,1,.3,.3;fulfilled=true,tolerance=0.,parent_expected=.8,parent_actual=.3)
    trial!(a,2,"offer:C")
    LW.resolve_prediction!(a,2,.2,0.;tolerance=0.)
    @test a.H≈.7
    @test a.methods["offer:C"].H≈.2
    trial!(a,3,"offer:C")
    LW.resolve_prediction!(a,3,.2,.3;fulfilled=true,tolerance=0.)
    @test a.H≈.6 # Actual is not subtracted a second time as generic success relief.
    @test a.methods["offer:C"].H≈.1
    trial!(a,4,"offer:C")
    LW.resolve_prediction!(a,4,.1,-.2;fulfilled=true,tolerance=0.)
    @test a.H≈.9
    @test a.methods["offer:C"].H≈.4
    # Real food trade adapter, including legacy relational=false route.
    trade=LW.BasicLoop("food-trade";probabilistic=true)
    weights=ones(length(LW.RDLBody.FOOD_KIND_IDS))
    trial!(trade,1,"offer")
    LW.food_trade_resolve!(trade,1,.8,weights,D("status"=>"declined");relational=false)
    @test trade.H≈.75
    trial!(trade,2,"offer")
    stock=zeros(Int,length(weights));after=copy(stock);after[1]=1
    LW.food_trade_resolve!(trade,2,.2,weights,D("status"=>"exchanged","own_before"=>stock,"own_after"=>after))
    @test trade.H≈max(0.,1.0-log(2)-LW.FOOD_TRADE_TOLERANCE)
    # Common method API cannot invent a forecast from Boolean success.
    trial!(trade,3,"offer")
    old=trade.H
    LW.resolve_method!(trade,3,true,true)
    @test trade.H==old
    trial!(trade,4,"offer")
    LW.resolve_method!(trade,4,true,false;method_forecast=(.2,.2),goal_forecast=(.5,.2))
    @test trade.H≈old+.3+LW.FOOD_TRADE_TOLERANCE # no tolerance on this API
    io=IOBuffer();serialize(io,a);seekstart(io);copy_a=deserialize(io)
    @test LW.loop_snapshot(copy_a)==LW.loop_snapshot(a)
    @test rand(copy_a.rng)==rand(a.rng)
    @test JSON3.read(JSON3.write(LW.loop_snapshot(a)))["h_mode"]=="forecast_difference"
    trial!(a,5,"offer:C")
    before=LW.loop_snapshot(a)
    @test_throws Exception LW.resolve_method!(a,5,true,false;method_forecast=(.2,.1),goal_forecast=(NaN,0.))
    @test LW.loop_snapshot(a)==before
    LW.resolve_method!(a,5,false,false;method_forecast=(.2,nothing),goal_forecast=(.2,nothing))
    @test a.H≈.9
end

@testset "short human day wiring smoke" begin
    # Test-only shortened clock, no configured action or forecast override.
    clock=merge(LW.native_clock(),(day_us=10_000_000,phase_boundaries_us=fill(10_000_000,4),quiet_night_us=10_000_000))
    result=LW.lw_day(LW.native_scene(19),clock;basic_loop=true,landmark_routes=true,mb_simulation=true)
    @test result["ended_us"]==10_000_000
    @test length(result["final_agents"])==length(LW.IDS)
end
