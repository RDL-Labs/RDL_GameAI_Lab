using JSON3, Test
const root=abspath(ARGS[1]);const out=abspath(ARGS[2]);mkpath(out)
include(joinpath(root,"source/src/lw/LW.jl"))
const rows=Any[];const results=Any[]
struct Done <: Exception end
function record!(w,plans,now)
    a="npc_a";p=get(plans,a,LW.D());b=w.bodies[a]
    push!(rows,(second=mod(now,17_280_000_000)÷1_000_000,action=get(p,"action",nothing),
        rule=get(p,"configured_rule",nothing),method=get(p,"method",nothing),position=collect(w.positions[a]),
        reserve=b.reserve,strain=b.strain))
    length(rows)>=180 && throw(Done())
end
const file=joinpath(root,"source/src/lw/simulation/day.jl")
source=replace(read(file,String),r"(?m)^include.*\r?\n"=>"")
anchor="if mod(now+1_000_000,clock.day_us)==0"
@assert count(anchor,source)==1
source=replace(source,anchor=>"Main.record!(w,plans,now);"*anchor)
Base.include_string(LW,source,file)
input=JSON3.read(read(joinpath(root,"run/input.json"),String),Dict{String,Any});input["config"]["days"]=41
for revised in (false,true)
    revised && Base.include(LW,joinpath(@__DIR__,"../../src/lw/configured_paths/routine_actions.jl"))
    empty!(rows)
    println("START revised=",revised);flush(stdout)
    measured=@timed try
        Base.invokelatest(LW.run_integrated,JSON3.read(JSON3.write(input));resume_from=joinpath(root,"run/checkpoints/day-040.jls"))
    catch e
        e isa Done || rethrow()
    end
    @test length(rows)==180
    fixed=count(r->r.rule=="scheduled_orientation",rows)
    @test revised ? fixed==0 : fixed==60
    arrival=findfirst(r->hypot(r.position[1],r.position[2]-6)<=1.25,rows)
    result=(revised,fixed_rest_ticks=fixed,actions=Dict(a=>count(r->r.action==a,rows) for a in unique(r.action for r in rows)),
        arrival_seconds=arrival,first=rows[1],final=rows[end],call_seconds=measured.time)
    push!(results,result)
    write(joinpath(out,revised ? "revised.json" : "baseline.json"),JSON3.write(rows))
    println(JSON3.write(result));flush(stdout)
end
write(joinpath(out,"results.json"),JSON3.write(results))
