using JSON3, Serialization, SHA
length(ARGS) in (3,4) || error("usage: export_observer.jl BASE_RUN CHECKPOINT FRESH_OUTPUT [FINAL_DAY]")
const base=abspath(ARGS[1]);const checkpoint=abspath(ARGS[2]);const out=abspath(ARGS[3])
ispath(out) && error("fresh output required");mkpath(out)
const repo=normpath(joinpath(@__DIR__,"../.."));const source=joinpath(out,"source")
mkpath(joinpath(source,"integrations"));cp(joinpath(repo,"src"),joinpath(source,"src"));cp(joinpath(repo,"integrations/lightweight_julia"),joinpath(source,"integrations/lightweight_julia"))
const input=JSON3.read(read(joinpath(base,"input.json"),String),Dict{String,Any})
const roster=Tuple(input["scene"]["experimental_actor_ids"])
write(joinpath(source,"src/data/lw_actor_ids.jl"),"const IDS="*repr(roster)*"\n")
const frames=Any[]
const frameio=open(joinpath(out,"frames.jsonl"),"w")
function observer_frame(w,foods,stock,stores,plans,loops,now)
    now%10_000_000==0 || return
    actors=Any[]
    for a in IDS
        plan=get(plans,a,D());family=get(plan,"purpose_family",nothing)
        collapsed=configured_collapse_active(w.bodies[a])
        action=collapsed ? "collapsed" : get(plan,"action","unrecorded")
        push!(actors,(id=a,position=w.positions[a],body=bodydict(w.bodies[a]),held=w.inventory[a],stock=stores[a],
            action=action,purpose=family,method=get(plan,"method",nothing),food_ref=get(plan,"food_ref",nothing),
            target=get(plan,"target",nothing),H=family!==nothing && haskey(loops[a],family) ? loops[a][family].H : nothing))
    end
    frame=(us=now,actors=actors,stocks=copy(stock));push!(frames,frame)
    println(frameio,JSON3.write(frame));flush(frameio)
end
const decisionio=open(joinpath(out,"decisions.jsonl"),"w")
const decisions=Any[]
function observer_decision(actor,record)
    row=(actor=actor,us=record["us"],channel=record["channel"],selected=record["selected"],
        candidates=record["candidates"],owner_forecast=record["owner_forecast"])
    push!(decisions,row);println(decisionio,JSON3.write(row));flush(decisionio)
end
p=joinpath(source,"src/lw/simulation/day.jl");code=read(p,String)
needle="advance_physiology!(w,metabolism,guts,food_body;plans,sleeping_ids)"
occursin(needle,code)||error("observer hook not found")
write(p,replace(code,needle=>needle*";Main.observer_frame(w,foods,stock,stores,plans,loops,now+1_000_000)"))
p=joinpath(source,"src/lw/decision/gradient_trace.jl");code=read(p,String)
occursin("log[\"captured\"]+=1",code)||error("decision observer hook not found")
write(p,replace(code,"log[\"captured\"]+=1"=>"Main.observer_decision(relation[\"actor\"],log[\"records\"][end]);log[\"captured\"]+=1"))
include(joinpath(source,"integrations/lightweight_julia/native.jl"))
saved=deserialize(checkpoint);final_day=length(ARGS)==4 ? parse(Int,ARGS[4]) : saved.day+1
input["config"]["days"]=final_day
@assert Set(keys(saved.state))==Set(LW_CHECKPOINT_FIELDS)
resume=joinpath(out,"resume.jls");serialize(resume,merge(saved,(code=checkpoint_code_hash(),)))
write(joinpath(out,"input.json"),JSON3.write(input));cp(@__FILE__,joinpath(out,"exporter.jl"))
write(joinpath(out,"migration.json"),JSON3.write((original=checkpoint,sha256=bytes2hex(sha256(read(checkpoint))),old_code=saved.code,new_code=checkpoint_code_hash(),state_changes="none; explicit experimental code migration",sample_seconds=10)))
observer_frame(saved.state[:w],saved.state[:foods],saved.state[:stock],saved.state[:stores],D(),saved.state[:loops],saved.day*input["clock"]["day_us"])
println("Replay export day ",saved.day+1," through ",final_day,"; 10-second world observer; no decision intervention.");flush(stdout)
timing=@timed run_integrated(JSON3.read(JSON3.write(input));resume_from=resume,checkpoint_dir=joinpath(out,"checkpoints"))
result=first(timing.value);start_us=saved.day*input["clock"]["day_us"]
events=[e for e in result["events"] if get(e,"us",0)>=start_us]
scene=input["scene"]
replay=(schema="lw-observer-v1",title="LW観察 · $(saved.day+1)〜$(final_day)日目",source="Julia LW / frozen source; see migration.json",day_us=input["clock"]["day_us"],sample_seconds=10,
    scene=Dict(k=>get(scene,k,nothing) for k in ("home","food","obstacles","low_obstacles","visual_landmarks","landscape","ground_patches")),
    actors=collect(roster),frames=frames,events=events,decisions=decisions,
    notes=["世界側の観察記録。個体が知っている情報とは異なります。","位置は10秒間隔の実測点。点間は表示上の補間で、実際の経路を保証しません。","候補詳細は既存の勾配記録がある判断のみ。移動判断の全候補は未収録。"])
write(joinpath(out,"replay.json"),JSON3.write(replay));close(frameio);close(decisionio)
write(joinpath(out,"completed.json"),JSON3.write((days=final_day-saved.day,seconds=timing.time,frames=length(frames),events=length(events),decisions=length(decisions))))
println("COMPLETED frames=",length(frames));flush(stdout)
