# Frozen-source replay with read-only action diagnostics. No policy edits.
using JSON3, Serialization, Test
length(ARGS) in (2,3) || error("usage RUN_ROOT OUTPUT [fixed]")
const HOUSE_TRACE_FIXED=length(ARGS)==3 && ARGS[3]=="fixed"
const HOUSE_TRACE_ROOT=abspath(ARGS[1]);const HOUSE_TRACE_OUT=abspath(ARGS[2])
ispath(HOUSE_TRACE_OUT) && error("fresh output required")
mkpath(HOUSE_TRACE_OUT)
include(joinpath(HOUSE_TRACE_ROOT,"source/integrations/lightweight_julia/native.jl"))
if HOUSE_TRACE_FIXED
    # Only the corrected arrival function is overlaid on the frozen implementation.
    current=read(joinpath(@__DIR__,"../../src/lw/configured_paths/personal_house_idle.jl"),String)
    start=first(findfirst("function configured_house_plan!",current))
    stop=first(findnext("function configured_house_idle_tick!",current,start))
    Base.include_string(Main,current[start:prevind(current,stop)],"house-arrival-fix-only")
end
const HOUSE_TRACE_ROWS=Any[]
function house_trace_action(a,now,plan,status,before,after,before_yaw,after_yaw,body,map)
    a=="npc_d" || return
    push!(HOUSE_TRACE_ROWS,D("us"=>now,"action"=>plan["action"],"method"=>get(plan,"method",nothing),
        "rule"=>get(plan,"configured_rule",nothing),"status"=>status,"before"=>collect(before),"after"=>collect(after),
        "yaw_before"=>before_yaw,"yaw_after"=>after_yaw,"demand"=>body_demand(body),"strain"=>body.strain,
        "mode"=>map["configured_house"]["mode"],"travel_count"=>map["configured_house"]["travel_ticks"],
        "direction"=>get(plan,"direction",nothing),"angle"=>get(plan,"approach_angle",nothing),
        "span"=>get(plan,"approach_span",nothing),"house_target"=>get(plan,"house_target",nothing),
        "field"=>get(plan,"field_vector",nothing),"rho"=>get(plan,"rho_profile",nothing),
        "potential"=>get(plan,"potential",nothing)))
end
path=joinpath(HOUSE_TRACE_ROOT,"source/src/lw/simulation/day.jl")
src=read(path,String)
src=src[first(findfirst("function lw_day(",src)):end]
anchor="            mb_simulation && mb_record!"
length(findall(anchor,src))==1 || error("trace anchor mismatch")
src=replace(src,anchor=>"            house_trace_action(a,now,plan,status,p,w.positions[a],before_yaw,yaw[a],w.bodies[a],mb_maps[a])\n"*anchor)
Base.include_string(Main,src,path)
input=JSON3.read(read(joinpath(HOUSE_TRACE_ROOT,"input.json"),String),Dict{String,Any})
input["config"]["days"]=1
timing=@timed run_integrated(JSON3.read(JSON3.write(input)))
result,summary=timing.value
original=deserialize(joinpath(HOUSE_TRACE_ROOT,"checkpoints/day-001.jls")).state
same(a,b)=JSON3.read(JSON3.write(a),Any)==JSON3.read(JSON3.write(b),Any)
if !HOUSE_TRACE_FIXED
    @testset "house replay observable parity" begin
        @test same(original[:daily][1],result["daily"][1])
        @test same(original[:counts],result["counts"])
        @test same(original[:events],result["events"])
    end
else
    @testset "fixed house arrival" begin
        @test result["final_agents"]["npc_d"]["personal_house"].inside
        @test result["mb_map"]["npc_d"]["configured_house"]["idle_ticks"]>0
        @test !any(r->r["method"]=="personal_house_return" && hypot((r["after"].-r["before"])...)<1e-12,HOUSE_TRACE_ROWS)
    end
end
write(joinpath(HOUSE_TRACE_OUT,"trace.json"),JSON3.write(HOUSE_TRACE_ROWS))
write(joinpath(HOUSE_TRACE_OUT,"context.json"),JSON3.write(D("houses"=>summary["personal_houses"],
    "house_state"=>result["mb_map"]["npc_d"]["configured_house"],"day"=>result["daily"][1],
    "diagnostic_seconds"=>timing.time,"parity"=>HOUSE_TRACE_FIXED ? "behavior changed; fixed arrival checks" : "daily, counts, events; not every internal field or RNG")))
println(JSON3.write((rows=length(HOUSE_TRACE_ROWS),seconds=timing.time,output=HOUSE_TRACE_OUT)))
