using JSON3, Serialization, Test
const root=abspath(ARGS[1]);const out=abspath(ARGS[2])
ispath(out) && error("fresh output required");mkpath(out)
include(joinpath(root,"source/src/lw/LW.jl"))
const enabled=Ref(false);const imposed=Ref(.85);const injection=Ref{Any}(nothing)
const trace=Any[];const results=Any[]
struct Done <: Exception end
function inject!(w,a,plan,returning,at_home,home,now)
    injection[]===nothing && a=="npc_b" && plan===nothing && returning && !at_home && home!==nothing || return
    b=w.bodies[a]
    injection[]=(us=now,position=collect(w.positions[a]),reserve=b.reserve,original_strain=b.strain,
        strain=imposed[],observed_home_distance=home["distance"],inventory=w.inventory[a])
    w.bodies[a]=LW.Body(b.burst,imposed[],b.reserve,b.damage)
end
function record!(w,mb_maps,plans,now)
    injection[]===nothing && return
    b=w.bodies["npc_b"]
    push!(trace,(us=now,position=collect(w.positions["npc_b"]),strain=b.strain,reserve=b.reserve,
        action=get(get(plans,"npc_b",LW.D()),"action",nothing)))
    @assert 0<=b.strain<=1 && b.reserve>0
    now-injection[].us>=180_000_000 && throw(Done())
end
function once(s,a,b)
    @assert count(a,s)==1 a
    replace(s,a=>b)
end
const file=joinpath(root,"source/src/lw/simulation/day.jl")
source=replace(read(file,String),r"(?m)^include.*\r?\n"=>"")
source=once(source,"get(spec,:fatigue_forecast,true)","Main.enabled[]")
source=once(source,"fatigue_continue=configured_legacy_fatigue_continue(w.bodies[a])",
    "Main.inject!(w,a,plan,returning,at_home,home,now);fatigue_continue=configured_legacy_fatigue_continue(w.bodies[a])")
source=once(source,"if mod(now+1_000_000,clock.day_us)==0",
    "Main.record!(w,mb_maps,plans,now);if mod(now+1_000_000,clock.day_us)==0")
# Capture just the relevant diagnostics before the bounded local stop; no trial checkpoint.
source=replace(source,"Main.record!(w,mb_maps,plans,now)"=>"Main.last_map[]=mb_maps;Main.record!(w,mb_maps,plans,now)")
const last_map=Ref{Any}(nothing)
write(joinpath(out,"instrumented_day.jl"),source);Base.include_string(LW,source,file)
input=JSON3.read(read(joinpath(root,"run/input.json"),String),Dict{String,Any});input["config"]["days"]=10
for fatigue in (.85,.95), forecast in (false,true)
    imposed[]=fatigue;enabled[]=forecast;injection[]=nothing;empty!(trace);last_map[]=nothing
    println("START strain=",fatigue," forecast=",forecast);flush(stdout)
    measured=@timed try
        LW.run_integrated(JSON3.read(JSON3.write(input));resume_from=joinpath(root,"run/checkpoints/day-009.jls"))
    catch e
        e isa Done || rethrow()
    end
    @assert injection[]!==nothing && length(trace)==181
    inside(t)=hypot(t.position[1],t.position[2]-6)<=1.25 # Observer metric only.
    arrival=findfirst(inside,trace)
    choices=get(last_map[]["npc_b"],"fatigue_forecast",nothing)
    # Trace state is post-action; first row already represents one elapsed second.
    result=(strain=fatigue,forecast,injection=injection[],arrival_seconds=arrival,
        observed_ticks=length(trace),outside_rest_ticks=count(t->t.action=="rest" && !inside(t),trace),
        rest_ticks=count(t->t.action=="rest",trace),walk_ticks=count(t->t.action in ("walk","run"),trace),
        max_strain=maximum(t.strain for t in trace),final=trace[end],choices,call_seconds=measured.time)
    push!(results,result)
    write(joinpath(out,"trace-$(fatigue)-$(forecast).json"),JSON3.write(trace))
    write(joinpath(out,"results.json"),JSON3.write(results));println(JSON3.write(result));flush(stdout)
end
@testset "same forced state before choice" begin
    @test results[1].injection==results[2].injection
    @test results[3].injection==results[4].injection
    @test results[2].choices!==nothing
    @test results[4].choices!==nothing
end
