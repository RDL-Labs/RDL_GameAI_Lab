# Read-only diagnostic probes in an in-memory copy of the frozen simulation.
using JSON3, SHA, Serialization
length(ARGS)==2 || error("usage: navigation_breakdown_replay.jl RUN NEW_OUTPUT")
const run=abspath(ARGS[1]);const out=abspath(ARGS[2])
ispath(out) && error("fresh output required");mkpath(out)
const snapshot=joinpath(run,"source")
include(joinpath(snapshot,"integrations/lightweight_julia/native.jl"))
const trace=open(joinpath(out,"trace.jsonl"),"w")
function breakdown_probe(a,now,position,yaw,leg,plan,status,m,loops)
    a in ("npc_b","npc_c") || return
    plan["action"]=="rest" && return
    rows=get(get(m["recognition"],"retrieval",Dict()),"records",Any[])
    active=m["routes"]["active"]
    route=active===nothing ? nothing : Dict(k=>get(active,k,nothing) for k in
        ("id","goal","cursor","path","H","effort","estimate","uncertain","reason","repair_pending","repairs","verified","pending_edge"))
    frame=m["current"]
    selected=Dict(k=>get(plan,k,nothing) for k in ("action","method","purpose_family","mb_route","mb_route_index","mb_recognition_confidence","mb_recognized","steering_angle","priority"))
    row=(actor=a,us=now,position=position,yaw=yaw,goal=leg,selected=selected,status=status,
        H=Dict(g=>l.H for (g,l) in loops),frame=frame,route=route,
        retrieval=filter(x->x["us"]==now,rows),
        route_events=filter(x->x["ended_us"]==now,m["routes"]["events"]),
        repairs=filter(x->get(x,"us",-1)==now,m["routes"]["repair_records"]),
        forecast=filter(x->get(x,"us",-1)==now,m["routes"]["forecast"]["records"]),
        parent=filter(x->get(x,"evaluated_us",-1)==now,m["parent_mb"]["records"]))
    JSON3.write(trace,row);write(trace,'\n')
end
file=joinpath(snapshot,"src/lw/simulation/day.jl")
source=replace(read(file,String),r"(?m)^include.*\r?\n"=>"")
anchor="counts[a][action]=get(counts[a],action,0)+1"
count(anchor,source)==1 || error("probe anchor mismatch")
source=replace(source,anchor=>anchor*"\n            Main.breakdown_probe(a,now,w.positions[a],yaw[a],leg,plan,status,mb_maps[a],loops[a])")
write(joinpath(out,"instrumented_day.jl"),source)
Base.include_string(Main,source,file)
checkpoint=joinpath(run,"checkpoints/day-009.jls")
write(joinpath(out,"provenance.json"),JSON3.write((checkpoint_sha256=bytes2hex(sha256(read(checkpoint))),
    source_code_hash=checkpoint_code_hash(),probe_sha256=bytes2hex(sha256(codeunits(source))))))
input=JSON3.read(read(joinpath(run,"input.json"),String))
println("Replay day 10 with B/C diagnostic trace");flush(stdout)
r,s=try
    run_integrated(input;resume_from=checkpoint)
finally
    close(trace)
end
original=JSON3.read(read(joinpath(run,"run/result.json"),String),Dict{String,Any})
same=isequal(original,JSON3.read(JSON3.write(r),Dict{String,Any}))
write(joinpath(out,"completed.json"),JSON3.write((day=10,result_identical=same)))
same || error("diagnostic replay diverged")
println("Completed; complete result matches original")
