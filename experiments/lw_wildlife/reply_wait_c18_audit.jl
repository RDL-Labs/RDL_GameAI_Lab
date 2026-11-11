using JSON3, Serialization, Test
const root=abspath(ARGS[1]);const output=abspath(ARGS[2])
include(joinpath(root,"source/src/lw/LW.jl"))
const revised=length(ARGS)>=3 && ARGS[3]=="wait"
revised && Base.include(LW,joinpath(@__DIR__,"../../src/lw/decision/task_focus.jl"))
const rows=Any[];const target_id=Ref{Any}(nothing);const ending=Ref{Any}(nothing)
struct Done <: Exception end
function record!(stage,w,states,maps,plans,thinking,focused,now)
    second=mod(now,17_280_000_000)÷1_000_000
    320<=second<=405 || return
    a="npc_c";pending=states[a]["pending"];focus=maps[a]["task_focus"]
    if target_id[]===nothing && second>=327 && pending!==nothing
        target_id[]=pending["message_id"]
    end
    reply=target_id[]===nothing ? nothing : get(states[a]["records"],target_id[],nothing)
    plan=get(plans,a,LW.D())
    messages=[deepcopy(m) for m in w.inbox[a] if m["time"]>=17*17280+320]
    push!(rows,(stage,second,thinking=a in thinking,focused=a in focused,
        pending=deepcopy(pending),reply=deepcopy(reply),inbox=messages,
        focus_active=get(focus,"active",false),review_us=get(focus,"review_us",nothing),
        wakeups=copy(focus["wakeups"]),action=get(plan,"action",nothing),rule=get(plan,"configured_rule",nothing),
        plans=Dict(b=>(action=get(p,"action",nothing),target=get(p,"target",nothing),reply_to=get(p,"reply_to",nothing)) for (b,p) in plans)))
    if stage=="after" && second==405
        ending[]=deepcopy(states[a]["records"]);throw(Done())
    end
end
function once(s,a,b)
    @assert count(a,s)==1 a
    replace(s,a=>b)
end
const file=joinpath(root,"source/src/lw/simulation/day.jl")
source=replace(read(file,String),r"(?m)^include.*\r?\n"=>"")
if revised
    # Local intervention begins at the known request tick. Applying the fix from
    # dawn changes earlier interactions and can remove this particular request.
    source=once(source,"focus_phase,now,notice;","focus_phase,now,notice;wait_notice=(now>=(17*17280+327)*1_000_000 ? task_wait_notice(fs,w.inbox[a],now) : nothing),")
    source=once(source,"rest_enabled=get(spec,:rest_task_focus,true))","rest_enabled=get(spec,:rest_task_focus,true),pending_wait=states[a][\"pending\"])")
end
anchor="thinking_ids=Tuple(a for a in IDS if !(a in paused_ids) && !(a in sleeping_ids) && !(a in collapsed_ids) && !(a in focused_ids))"
source=once(source,anchor,anchor*";Main.record!(\"before\",w,states,mb_maps,D(),thinking_ids,focused_ids,now)")
anchor="if mod(now+1_000_000,clock.day_us)==0"
source=once(source,anchor,"Main.record!(\"after\",w,states,mb_maps,plans,thinking_ids,focused_ids,now);"*anchor)
Base.include_string(LW,source,file)
input=JSON3.read(read(joinpath(root,"run/input.json"),String),Dict{String,Any});input["config"]["days"]=18
measured=@timed try
    LW.run_integrated(JSON3.read(JSON3.write(input));resume_from=joinpath(root,"run/checkpoints/day-017.jls"))
catch e
    e isa Done || rethrow()
end
@test length(rows)==172
@test target_id[]!==nothing
result=(revised,target_id=target_id[],rows,call_seconds=measured.time)
write(output,JSON3.write(result));println(JSON3.write((target_id=target_id[],rows=length(rows),call_seconds=measured.time)))
