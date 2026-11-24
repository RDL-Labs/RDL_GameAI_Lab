using JSON3, Serialization, SHA
length(ARGS)==2 || error("usage: aid_replay.jl BASE_RUN FRESH_OUTPUT")
const base=abspath(ARGS[1]);const out=abspath(ARGS[2])
ispath(out) && error("fresh output required");mkpath(out)
const repo=normpath(joinpath(@__DIR__,"../.."))
const source=joinpath(out,"source");mkpath(joinpath(source,"integrations"))
cp(joinpath(repo,"src"),joinpath(source,"src"));cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(source,"integrations/lightweight_julia"))
const input=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any})
input["config"]["days"]=25
const roster=Tuple(input["scene"]["experimental_actor_ids"])
write(joinpath(source,"src/data/lw_actor_ids.jl"),"const IDS="*repr(roster)*"\n")
write(joinpath(out,"input.json"),JSON3.write(input));cp(@__FILE__,joinpath(out,"runner.jl"))
const traceio=open(joinpath(out,"aid-gradients.jsonl"),"w")
const bodyio=open(joinpath(out,"bodies.jsonl"),"w")
function aid_observe_gradient(actor,record)
    record["channel"] in ("visual_aid","aid_response") || return
    any(c->get(c,"target",nothing)=="npc_c" || occursin("npc_c",c["method"]),record["candidates"]) || return
    println(traceio,JSON3.write((actor=actor,record=record)));flush(traceio)
end
function aid_observe_bodies(w,stores,foods,relations,now)
    now%60_000_000==0 || return
    rows=[(actor=a,position=w.positions[a],body=bodydict(w.bodies[a]),stock=stores[a],held=w.inventory[a],
        visual=relations===nothing ? nothing : let v=get(relations[a],"visual_aid",D());Dict(k=>get(v,k,0) for k in ("decisions","candidates","selected","transferred","abandoned")) end) for a in IDS]
    println(bodyio,JSON3.write((us=now,actors=rows)));flush(bodyio)
end
# Observation-only hooks in the fresh frozen copy; no selection/RNG changes.
p=joinpath(source,"src/lw/decision/gradient_trace.jl")
s=read(p,String);needle="log[\"captured\"]+=1";occursin(needle,s)||error("gradient hook")
write(p,replace(s,needle=>"Main.aid_observe_gradient(relation[\"actor\"],log[\"records\"][end]);"*needle))
p=joinpath(source,"src/lw/simulation/day.jl");s=read(p,String)
needle="now=sec*1_000_000;w.seconds=sec";occursin(needle,s)||error("body hook")
write(p,replace(s,needle=>needle*";Main.aid_observe_bodies(w,stores,foods,relations,now)"))
include(joinpath(source,"integrations/lightweight_julia/native.jl"))
const original=joinpath(base,"checkpoints/day-023.jls")
const saved=deserialize(original)
@assert saved.day==23 && saved.state[:w].bodies["npc_c"].nutrients.alive
@assert Set(keys(saved.state))==Set(LW_CHECKPOINT_FIELDS)
for a in IDS;@assert saved.state[:w].bodies[a].nutrients===saved.state[:guts][a].macro_body.body;end
# Explicit experimental source migration, unchanged state graph and private RNGs.
const migrated=joinpath(out,"resume-023.jls")
serialize(migrated,merge(saved,(code=checkpoint_code_hash(),)))
write(joinpath(out,"migration.json"),JSON3.write((original=original,sha256=bytes2hex(sha256(read(original))),old_code=saved.code,new_code=checkpoint_code_hash(),state_changes="none",rules="human incapacity, voluntary aid, assisted feeding",days=[24,25])))
println("Resume day23; 4 humans, original finite food/private stocks; no forced aid; observe day24-25.");flush(stdout)
const measured=@timed run_integrated(JSON3.read(JSON3.write(input));resume_from=migrated,checkpoint_dir=joinpath(out,"checkpoints"))
const result=first(measured.value)
const events=[e for e in result["events"] if get(e,"us",0)>=23*17280000000 && (get(e,"actor",nothing)=="npc_c" || get(e,"target",nothing)=="npc_c")]
write(joinpath(out,"c-events.json"),JSON3.write(events))
const summary=(seconds=measured.time,bytes=measured.bytes,gctime=measured.gctime,days=[(day=i,physical=Dict(a=>result["daily"][i]["physical"][a]["body"] for a in IDS),counts=result["daily"][i]["counts"]) for i in 24:25])
write(joinpath(out,"completed.json"),JSON3.write(summary));close(traceio);close(bodyio)
println("COMPLETED day25 seconds=",measured.time);flush(stdout)


