using JSON3,Serialization
const root=abspath(ARGS[1]);const out=abspath(ARGS[2]);const day=parse(Int,ARGS[3])
const actor=ARGS[4];const mode=ARGS[5]
ispath(out) && error("fresh output required");mkpath(out)
include(joinpath(root,"source/src/lw/LW.jl"))
const trace=Any[];const previous=Dict{String,Any}();const actual=Ref{Any}()
struct TraceFinished <: Exception end
function probe!(a,now,phase,at_home,load,state,returning,stage)
    a==actor || return
    signature=(phase,at_home,load,state["active"],state["completed"],returning)
    get(previous,stage,nothing)==signature && return
    previous[stage]=signature
    push!(trace,(us=now,stage,phase,at_home,load,active=state["active"],completed=state["completed"],returning))
end
function action_probe!(a,now,action,status,state,load)
    a==actor && action in ("deposit","retrieve","eat") || return
    push!(trace,(us=now,stage="executed",action,status,load,active=state["active"],completed=state["completed"]))
end
function finish!(daily)
    actual[]=(counts=daily[end]["counts"],physical=daily[end]["physical"])
    throw(TraceFinished())
end
function once(s,a,b)
    count(a,s)==1 || error("anchor: $a")
    replace(s,a=>b)
end
function detail!(a,now,stage,returning,at_home,replenishing,worried,provision,s)
 a==actor && 8437<=mod(div(now,1_000_000),17280)<=8443 || return
 push!(trace,(us=now,stage,returning,at_home,replenishing,worried,provision,
     daily=deepcopy(s["daily_plan"]["active"]),meal=deepcopy(get(s,"configured_return_meal",nothing))))
end
day_file=joinpath(root,"source/src/lw/simulation/day.jl")
source=replace(read(day_file,String),r"(?m)^include.*\r?\n"=>"")
anchor="returning=observing ? false : configured_returning!(purposes[a],phase,w.inventory[a],at_home,now)"
source=once(source,anchor,anchor*"\n Main.probe!(a,now,phase,at_home,w.inventory[a],purposes[a],returning,\"legacy\")")
anchor="post_return_meal && configured_return_meal_hold(mb_maps[a],now,clock.day_us) && (returning=true)"
source=once(source,anchor,anchor*"\n Main.probe!(a,now,phase,at_home,w.inventory[a],purposes[a],returning,\"effective\")")
anchor="# Forecast shortage can redirect the purpose before hunger, never force a meal."
source=once(source,anchor,"Main.detail!(a,now,\"after_daily\",returning,at_home,replenishing,food_worried,provision_enabled,mb_maps[a])\n "*anchor)
anchor="post_return_meal && configured_return_meal_hold(mb_maps[a],now,clock.day_us) && (returning=true)"
source=once(source,anchor,anchor*"\n Main.detail!(a,now,\"after_hold\",returning,at_home,replenishing,food_worried,provision_enabled,mb_maps[a])")
anchor="ground_receipts[a]=D(\"actor\"=>a,"
source=once(source,anchor,"Main.action_probe!(a,now,action,status,purposes[a],w.inventory[a])\n "*anchor)
anchor="checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)"
source=once(source,anchor,"Main.finish!(daily)")
Base.include_string(LW,source,day_file)
input=JSON3.read(read(joinpath(root,mode,"input.json"),String),Dict{String,Any});input["config"]["days"]=day
timing=@timed try
    LW.run_integrated(JSON3.read(JSON3.write(input));resume_from=joinpath(root,mode,"checkpoints/day-"*lpad(day-1,3,'0')*".jls"))
catch e
    e isa TraceFinished || rethrow()
end
expected=deserialize(joinpath(root,mode,"checkpoints/day-"*lpad(day,3,'0')*".jls")).state[:daily][end]
matched=(counts=actual[].counts==expected["counts"],physical=actual[].physical==expected["physical"])
write(joinpath(out,"trace.json"),JSON3.write((day,actor,mode,matched,seconds=timing.time,trace)))
println(JSON3.write((day,actor,mode,matched,seconds=timing.time,records=length(trace))))
@assert matched.counts && matched.physical
