using Test, JSON3, Serialization
include("../../src/lw/LW.jl")
@testset "frozen gradient, bounded alternatives, no RNG consumption" begin
    s=LW.social_relations_state("npc_a";relational=true)
    loop=LW.BasicLoop("test";probabilistic=true,seed=4)
    cs=[Dict{String,Any}("method"=>"m$i","priority"=>Float64(i)/10,"question"=>"food_delivered") for i in 1:30]
    rng=copy(loop.rng);probs=LW.method_distribution(loop,cs)
    LW.gradient_capture!(s,loop,cs,first(cs),"trial",0)
    @test loop.rng==rng
    r=only(s["gradient_maps"]["records"])
    @test length(r["candidates"])==16 && r["selected"]=="m1"
    @test sum(c["probability"] for c in r["candidates"])+r["omitted_probability"]≈1
    @test all(c["probability"]≈probs[parse(Int,c["method"][2:end])] for c in r["candidates"])
    frozen=deepcopy(r["candidates"]);cs[1]["priority"]=100.;loop.H=8.
    @test r["candidates"]==frozen
    @test LW.gradient_result!(s,"trial","transferred";actual=1.,now=2)
    @test !LW.gradient_result!(s,"trial","transferred";actual=1.,now=2)
    @test r["candidates"]==frozen && only(r["outcomes"])["actual"]==1.
    for i in 1:70;LW.gradient_capture!(s,loop,cs,first(cs),"trial:$i",i);end
    @test length(s["gradient_maps"]["records"])==64
    @test s["gradient_maps"]["evicted"]==7
    @test !LW.gradient_result!(s,"trial","expired")
    @test s["gradient_maps"]["unmatched_results"]==1
end
function without_gradient(x)
    x isa AbstractDict && return Dict(k=>without_gradient(v) for (k,v) in x if !(String(k) in ("gradient_maps","gradient_logging")))
    x isa AbstractVector && return map(without_gradient,x)
    x
end
@testset "actual social ticks unchanged by logging; persisted results" begin
    clock=merge(LW.native_clock(),(day_us=96_000_000,phase_boundaries_us=[96_000_000,96_000_000,96_000_000,96_000_000],quiet_night_us=96_000_000))
    base=merge(LW.native_scene(19),(positions=[[0.,0.],[0.,.75],[100.,100.]],home=[0.,0.],
        food=Any[],obstacles=Any[],low_obstacles=Any[],ground_patches=Any[],hazards=Any[],
        initial_inventory=[0,3,0],initial_inventory_kinds=[Int[],[4,4,4],Int[]],
        reserve=[30.,90.,100.],typed_food=true,social_relationships=true))
    run(enabled;kwargs...)=LW.lw_day(merge(base,(gradient_logging=enabled,)),clock;
        days=2,basic_loop=true,food_body=true,social_response=true,choice_seed=3,kwargs...)
    on=run(true);off=run(false)
    @test without_gradient(JSON3.read(JSON3.write(on),Dict{String,Any}))==without_gradient(JSON3.read(JSON3.write(off),Dict{String,Any}))
    records=vcat([get(get(s,"gradient_maps",Dict()),"records",Any[]) for s in values(on["social_relationships"])]...)
    @test !isempty(records)
    @test any(any(o["status"]=="transferred" for o in r["outcomes"]) for r in records)
    @test any(any(haskey(c,"MB") for c in r["candidates"]) for r in records)
    mktempdir() do dir
        run(true;checkpoint_dir=dir,checkpoint_identity="gradient")
        resumed=run(true;resume_from=joinpath(dir,"day-001.jls"),checkpoint_identity="gradient")
        @test isequal(JSON3.read(JSON3.write(on),Dict{String,Any}),JSON3.read(JSON3.write(resumed),Dict{String,Any}))
    end
end
