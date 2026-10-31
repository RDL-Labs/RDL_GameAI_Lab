using Test, Serialization
include("../../src/lw/LW.jl")
const A="npc_a";const B="npc_b"
@testset "future food residual is not hunger or an accumulated failure count" begin
    body=LW.Body(10.,0.,95.,0.);s=LW.food_security_state();day=17_280_000_000
    update(stock,now=0,met=0.)=LW.food_security_update!(s,nothing,body,nothing,stock,Int[],met,now,day)
    update([1,0,0,0]);initial=s["H"]
    @test initial>0 && body.reserve>80
    @test LW.trade_food_need(body,nothing,[1,0,0,0])==0
    @test LW.trade_food_need(body,nothing,[1,0,0,0];security=s)>0
    @test LW.configured_expression(body;anxiety=s["H"]).distress>0
    for now in 1:100;update([1,0,0,0],now);end
    @test s["H"]==initial
    update([4,0,0,0],101);@test s["H"]==0
    @test s["shortfall"]==0
    update([0,0,0,0],64_000_000,.128)
    @test s["samples"]==1 && s["estimate"]["metabolic_rate"]≈.002
    @test s["H"]>initial
    @test LW.trade_food_relief(body,nothing,[1,0,0,0],[0,0,0,0],[1,0,0,0];security=s)>0
    io=IOBuffer();serialize(io,s);seekstart(io);restored=deserialize(io)
    LW.food_security_update!(restored,nothing,body,nothing,[2,0,0,0],Int[],.256,128_000_000,day)
    update([2,0,0,0],128_000_000,.256)
    @test restored==s
    @test LW.food_request_ready(s,0)
    @test LW.food_request_considered!(s,0)
    @test !LW.food_request_ready(s,63_999_999)
    @test !LW.food_request_considered!(s,63_999_999)
    @test LW.food_request_ready(s,64_000_000)
    @test s["requests"]==1
end
@testset "forecast admission and shared appearance reach actual trade plans" begin
    body=LW.Body(10.,0.,95.,0.)
    view=Dict{String,Any}("own_stock"=>[0,0,1,0],"incoming"=>Any[],"outgoing"=>nothing,"partners"=>[B])
    @test LW.food_trade_plan!(LW.food_trade_state(1),A,view,body,nothing,0)===nothing
    plans=Any[]
    for seed in 1:32
        rel=LW.social_relations_state(A;relational=true)
        security=LW.food_security_state();security["required"]=3.;security["H"]=2.
        rel["food_security"]=security
        rel["social_view"]=Dict("peers"=>[Dict("ref"=>B,"expression"=>(calm=.5,distress=.5,fear=0.))])
        p=LW.food_trade_plan!(LW.food_trade_state(seed;relational=true),A,view,body,nothing,0;relation=rel)
        p===nothing && continue
        push!(plans,p)
        @test p["trade_context"]["distress"]==.5
        @test p["want_count"]>p["give_count"]
    end
    @test !isempty(plans)
end
@testset "visible shared condition, attention, rho, and occlusion" begin
    w=LW.world(false);empty!(w.obstacles)
    w.positions[A]=(0.,0.);w.positions[B]=(0.,3.);w.positions["npc_c"]=(100.,100.)
    w.bodies[B]=LW.Body(10.,0.,37.5,0.)
    coarse=LW.social_sight(w,A,0.,0;rho="coarse",attention=B)
    fine=LW.social_sight(w,A,0.,0;rho="fine",attention=B)
    @test only(coarse["peers"])["expression"].distress==.5
    @test only(fine["peers"])["expression"].distress==.375
    @test LW.social_sight(w,A,0.,0;rho="fine")==LW.social_sight(w,A,0.,0;rho="coarse")
    rel=LW.social_relations_state(A;relational=true);rel["social_view"]=fine
    @test LW.social_observed_context(rel,B)["distress"]==.375
    @test !haskey(LW.social_observed_context(rel,B),"reserve")
    @test LW.social_attention(rel,1)==B
    w.inventory[B]=100
    @test LW.social_sight(w,A,0.,0;rho="fine",attention=B)==fine
    w.positions[B]=(0.,9.);w.bodies[B]=LW.Body(10.,0.,0.,0.)
    @test only(LW.social_sight(w,A,0.,0)["peers"])["expression"].distress==1
    push!(w.obstacles,LW.RDLMigrationProbe.Circle(0.,4.,.5))
    rel["social_view"]=LW.social_sight(w,A,0.,1;rho="fine",attention=B)
    @test isempty(rel["social_view"]["peers"])
    @test isempty(LW.social_observed_context(rel,B))
end
