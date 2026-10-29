# Observation-only opportunity decisions. World legality is tested separately.
using Test, Random, Serialization
include("../../src/lw/LW.jl")
if !isdefined(LW,:incidental_item_state)
    Base.include(LW,normpath(joinpath(@__DIR__,"../../src/lw/decision/incidental_items.jl")))
end

const INC_ACTOR="npc_a"
inc_body(;reserve=90.,strain=0.,damage=0.)=Dict{String,Any}("reserve"=>reserve,"strain"=>strain,"damage"=>damage)
inc_parent(family="food")=LW.BasicLoop(INC_ACTOR*":"*family;probabilistic=true,seed=17)
inc_row(;ref=1,color="cyan",size=.12,light=.02,distance=.5,holder=nothing,location=1)=
    Dict{String,Any}("ref"=>ref,"color"=>color,"size"=>size,"light_source"=>light,
        "distance"=>distance,"forward"=>distance,"right"=>0.,"holder"=>holder,"location"=>location)
inc_view(rows=[inc_row()];load=0.,mass_limit=5.,size_limit=1.)=Dict{String,Any}(
    "visible"=>rows,"own"=>Dict("held"=>Any[],"stored"=>Any[]),
    "own_load"=>Dict("mass"=>load,"size"=>0.,"count"=>0),
    "carry_capacity"=>Dict("mass"=>mass_limit,"size"=>size_limit))
inc_candidates(s,v=inc_view(),body=inc_body(),parent=inc_parent();family="food",pressure=0.)=
    LW.incidental_item_candidates(s,v,body,parent;family,pressure)
function inc_probability(s,candidates)
    isempty(candidates) && return 0.
    probabilities=LW.method_distribution(s["loop"],candidates)
    sum(probabilities[i] for i in eachindex(candidates) if get(candidates[i],"incidental_item",false))
end
inc_pick(candidates)=only(filter(c->get(c,"incidental_item",false),candidates))
function inc_selected!(s,view=inc_view(),body=inc_body(),parent=inc_parent();family="food",start=0)
    # Repeated real draws with the ordinary continuation alternative; no forced plan.
    for offset in 0:4095
        now=start+offset*1_000_000
        p=LW.incidental_item_plan!(s,view,body,parent,now;family)
        p===nothing || return p,now
    end
    error("bounded fixture could not select a reachable opportunity")
end
function inc_serialized(x)
    io=IOBuffer();serialize(io,x);seekstart(io);deserialize(io)
end

@testset "no observed opportunity does not consume choice or parent state" begin
    s=LW.incidental_item_state(INC_ACTOR,13);parent=inc_parent()
    before=LW.loop_snapshot(parent);rng_before=deepcopy(s["loop"].rng)
    sequence=s["loop"].sequence;memory=deepcopy(s["memory"])
    for view in (nothing,inc_view(Any[]),inc_view([inc_row(distance=2.)]))
        @test isempty(inc_candidates(s,view,inc_body(),parent))
        @test LW.incidental_item_plan!(s,view,inc_body(),parent,0;family="food")===nothing
    end
    @test s["loop"].sequence==sequence && s["memory"]==memory
    @test rand(deepcopy(s["loop"].rng),16)==rand(rng_before,16)
    @test LW.loop_snapshot(parent)==before
end

@testset "observable feasibility and category-independent object handling" begin
    s=LW.incidental_item_state(INC_ACTOR,23)
    for view in (inc_view([inc_row(holder="npc_b",location=2)]),inc_view([inc_row(location=3)]),
            inc_view([inc_row(size=1.1)]),inc_view(;load=5.),inc_view([inc_row(distance=1.251)]))
        @test isempty(inc_candidates(s,view))
    end
    for body in (inc_body(reserve=0.),inc_body(strain=1.),inc_body(damage=1.))
        @test isempty(inc_candidates(s,inc_view(),body))
    end
    clean=inc_candidates(s)
    poisoned=inc_row();merge!(poisoned,Dict("kind"=>65535,"mass"=>100000.,"label"=>"secret","history"=>["private"]))
    @test inc_candidates(s,inc_view([poisoned]))==clean
    renamed=inc_pick(inc_candidates(s,inc_view([inc_row(ref=99)])))
    @test renamed["item_id"]==99
    @test renamed["method"]==inc_pick(clean)["method"]
    @test renamed["expected_benefit"]==inc_pick(clean)["expected_benefit"]
    @test all(get(c,"action",nothing)!="item_give" for c in clean)
end

@testset "continuing and picking compete and urgency changes their probability" begin
    s=LW.incidental_item_state(INC_ACTOR,31);parent=inc_parent()
    before=LW.loop_snapshot(parent)
    ordinary=inc_candidates(s,inc_view(),inc_body(),parent)
    @test count(c->get(c,"incidental_continue",false),ordinary)==1
    @test 0<inc_probability(s,ordinary)<1
    @test all(>(0),LW.method_distribution(s["loop"],ordinary))
    @test inc_probability(s,inc_candidates(s,inc_view(),inc_body(),parent;pressure=1.))<inc_probability(s,ordinary)
    @test inc_probability(s,inc_candidates(s,inc_view(),inc_body(reserve=30.,strain=.7),parent))<inc_probability(s,ordinary)
    @test LW.loop_snapshot(parent)==before
    picks=0;continues=0
    for seed in 1:256
        trial=LW.incidental_item_state(INC_ACTOR,seed)
        p=LW.incidental_item_plan!(trial,inc_view(),inc_body(),parent,0;family="food")
        if p===nothing
            continues+=1
            @test trial["loop"].trial===nothing
        else
            picks+=1
            @test p["action"]=="item_pickup" && p["portable_item_action"] && p["incidental_item"]
        end
    end
    @test picks>0 && continues>0
    @test LW.loop_snapshot(parent)==before
end

@testset "successful handling informs similar appearances across purposes" begin
    s=LW.incidental_item_state(INC_ACTOR,41);parent=inc_parent()
    parent_before=LW.loop_snapshot(parent)
    p,t=inc_selected!(s,inc_view(),inc_body(),parent)
    LW.incidental_item_result!(s,p,"item_picked_up",.0001,t)
    @test s["succeeded"]==1 && s["loop"].trial===nothing
    @test LW.loop_snapshot(parent)==parent_before
    familiar=inc_pick(inc_candidates(s,inc_view([inc_row(ref=2,size=.121)])))
    different=inc_pick(inc_candidates(s,inc_view([inc_row(ref=3,color="red",size=.8,light=.9)])))
    @test familiar["confirmed_novelty"]<different["confirmed_novelty"]
    @test familiar["expected_benefit"]<different["expected_benefit"]
    home=inc_parent("home");before=LW.loop_snapshot(home)
    @test inc_pick(inc_candidates(s,inc_view([inc_row(ref=4,size=.121)]),inc_body(),home;family="home"))["confirmed_novelty"]==familiar["confirmed_novelty"]
    @test LW.loop_snapshot(home)==before
    @test isempty(inc_candidates(s))
    reward_before=sum(n.reward for n in values(s["loop"].methods))
    @test LW.incidental_item_plan!(s,inc_view(),inc_body(),parent,t+1_000_000;family="food")===nothing
    @test sum(n.reward for n in values(s["loop"].methods))<=reward_before+eps(Float64)
end

@testset "failed or costly opportunities update the common prediction loop" begin
    s=LW.incidental_item_state(INC_ACTOR,51)
    p,t=inc_selected!(s);failed=deepcopy(s);cheap=deepcopy(s);costly=deepcopy(s)
    before=inc_probability(s,inc_candidates(s))
    LW.incidental_item_result!(failed,p,"item_unavailable",.01,t)
    @test failed["failed"]==1 && failed["succeeded"]==0
    @test failed["loop"].H>0
    @test inc_probability(failed,inc_candidates(failed))<before
    LW.incidental_item_result!(cheap,p,"item_picked_up",0.,t)
    LW.incidental_item_result!(costly,p,"item_picked_up",2.,t)
    @test costly["loop"].H>cheap["loop"].H
    @test sum(n.reward for n in values(costly["loop"].methods))<=sum(n.reward for n in values(cheap["loop"].methods))
    skipped=deepcopy(s);before_skip=LW.loop_snapshot(skipped["loop"])
    LW.incidental_item_result!(skipped,p,"unexecuted",0.,t)
    @test skipped["loop"].H==before_skip["H"] && skipped["loop"].trial===nothing
    @test skipped["succeeded"]==0 && skipped["failed"]==0
end

@testset "result replay and checkpoint restore keep learning single-applied" begin
    s=LW.incidental_item_state(INC_ACTOR,61);p,t=inc_selected!(s)
    restored=inc_serialized(s)
    LW.incidental_item_result!(s,p,"item_picked_up",.001,t)
    LW.incidental_item_result!(restored,p,"item_picked_up",.001,t)
    @test LW.incidental_item_snapshot(restored)==LW.incidental_item_snapshot(s)
    before=LW.incidental_item_snapshot(s)
    LW.incidental_item_result!(s,p,"item_picked_up",.001,t)
    @test LW.incidental_item_snapshot(s)==before
    @test_throws Exception LW.incidental_item_result!(s,p,"item_unavailable",.001,t)
    for i in 1:8
        view=inc_view([inc_row(ref=10+i,color=isodd(i) ? "cream" : "blue",size=.1+.01i)])
        p1=LW.incidental_item_plan!(s,view,inc_body(),inc_parent(),t+i*1_000_000;family="home")
        p2=LW.incidental_item_plan!(restored,view,inc_body(),inc_parent(),t+i*1_000_000;family="home")
        @test p1==p2
        if p1!==nothing
            LW.incidental_item_result!(s,p1,"item_picked_up",.001,t+i*1_000_000)
            LW.incidental_item_result!(restored,p2,"item_picked_up",.001,t+i*1_000_000)
        end
    end
    @test LW.incidental_item_snapshot(restored)==LW.incidental_item_snapshot(s)
end

@testset "longer observation and handling retain bounded memory" begin
    s=LW.incidental_item_state(INC_ACTOR,71);now=0
    for i in 1:150
        view=inc_view([inc_row(ref=i,color="shade_$(i)",size=.1+.001i)])
        p,t=inc_selected!(s,view;start=now)
        LW.incidental_item_result!(s,p,"item_picked_up",.001,t)
        now=t+1_000_000
    end
    @test s["succeeded"]==150
    @test length(s["memory"])<=128
    @test length(s["handled_refs"])<=128
    @test length(s["records"])<=64
    @test length(s["loop"].methods)<=129
    @test length(s["loop"].events)<=32
    @test LW.incidental_item_snapshot(inc_serialized(s))==LW.incidental_item_snapshot(s)
end
