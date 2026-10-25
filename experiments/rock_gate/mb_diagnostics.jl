# Observer-only hooks in the copied source. World coordinates never enter policy state.
const mb_diag_io=open(joinpath(out,"mb-observations.jsonl"),"w")
const mb_goal_io=open(joinpath(out,"mb-goals.jsonl"),"w")
const mb_diag_samples=Set{Tuple{String,Int,String}}()
const mb_diag_before=Dict{String,Any}()
atexit(()->(close(mb_diag_io);close(mb_goal_io)))
function instrument_mb_day(s)
    anchor="            mb_simulation && mb_observe!"
    @assert count(anchor,s)==1
    s=replace(s,anchor=>"            mb_simulation && Main.diag_before!(mb_maps[a],landmarks[a],w.positions[a],yaw[a],at_home,now)\n"*anchor)
    anchor="            returning=returning!"
    @assert count(anchor,s)==1
    s=replace(s,anchor=>"            mb_simulation && Main.diag_after!(mb_maps[a],now)\n"*anchor)
    anchor="                mb_chunks && mb_goal_result!"
    @assert count(anchor,s)==1
    replace(s,anchor=>"                mb_chunks && Main.diag_goal!(mb_maps[a],t.family,t.source,goal,mb_parent_H,s.H,now)\n"*anchor)
end
function instrument_mb_files(snapshot)
    p=joinpath(snapshot,"src/lw/learning/mb_map.jl");s=read(p,String)
    anchor="    s[\"next_search_us\"]=now+64_000_000;s[\"searches\"]+=1"
    @assert count(anchor,s)==1
    write(p,replace(s,anchor=>anchor*"\n    Main.diag_search!(s,frame,move,goal,now)"))
    p=joinpath(snapshot,"src/lw/learning/mb_sleep.jl");s=read(p,String)
    anchor="    frozen[\"formation_us\"]<now || error(\"mb_sleep_time\")"
    @assert count(anchor,s)==1
    write(p,replace(s,anchor=>anchor*"\n    Main.diag_snapshot(frozen,s[\"actor\"],now,\"sleep\",nothing,nothing)"))
end
function diag_before!(s,obs,pos,yaw,home,now)
    scene=relation_scene(obs);frame=mb_scene(obs);r=s["receipt"]
    reason=obs["coverage"]!="complete" ? "partial_coverage" : get(obs,"output_limited",false) ? "output_limited" : length(scene)<2 ? "fewer_than_two_unique_colors" : "valid"
    reset="none"
    if r!==nothing
        valid=frame!==nothing && now==r["now"]+1_000_000
        reset=!valid ? "invalid_next_observation" : !(get(r,"goal",nothing) in ("home","food")) ? "no_goal" : !(r["status"] in ("performed","picked_up","recovered")) ? "status" : s["trace_goal"]!=r["goal"] ? "goal_change" : "none"
        if reset=="none" && !isempty(s["route_trace"])
            e=get(s["edges"],last(s["route_trace"]),nothing)
            (e===nothing || e["to"]!=r["from"]) && (reset="disconnected_trace")
        end
        if valid && r["from"]!=frame.key && !(r["action"] in ("walk","run","scan"));reset="nonmovement_scene_change";end
    end
    mb_diag_before[s["actor"]]=Dict("actor"=>s["actor"],"us"=>now,"position"=>pos,"yaw"=>yaw,"home"=>home,
        "key"=>frame===nothing ? nothing : frame.key,"reason"=>reason,"reset"=>reset,"trace_before"=>length(s["route_trace"]),
        "receipt"=>r===nothing ? nothing : Dict(k=>get(r,k,nothing) for k in ("from","action","status","goal")),
        "scene"=>scene===nothing ? nothing : [(x["color"],x["range_band"]) for x in scene])
end
function diag_after!(s,now)
    row=mb_diag_before[s["actor"]];row["trace_after"]=length(s["route_trace"])
    JSON3.write(mb_diag_io,row);println(mb_diag_io)
    mod(now,60_000_000)==0 && flush(mb_diag_io)
end
function diag_goal!(s,goal,source,resolved,before,after,now)
    resolved===true || return
    path=s["route_trace"]
    reason=s["last_chunk_operation"]===nothing ? "no_bound_observation" : source!=s["last_chunk_operation"] ? "wrong_source" : source==s["last_chunk_credit"] ? "duplicate" : before<=after ? "no_H_reduction" : after!=0 ? "H_not_zero" : s["trace_goal"]!=goal ? "wrong_trace_goal" : length(path)<2 ? "short_trace" : "eligible_path_checks"
    JSON3.write(mb_goal_io,Dict("actor"=>s["actor"],"us"=>now,"goal"=>goal,"H_before"=>before,"H_after"=>after,"reason"=>reason,"trace_goal"=>s["trace_goal"],"path"=>copy(path)));println(mb_goal_io);flush(mb_goal_io)
end
function diag_snapshot(s,actor,now,kind,start,allowed)
    folder=joinpath(out,"mb-snapshots");mkpath(folder)
    write(joinpath(folder,"$actor-$now-$kind.json"),JSON3.write(Dict("actor"=>actor,"now"=>now,"kind"=>kind,"start"=>start,"allowed"=>allowed,"nodes"=>s["nodes"],"edges"=>s["edges"])))
end
function diag_search!(s,frame,move,goal,now)
    sample=(s["actor"],div(now,17_280_000_000),goal)
    sample in mb_diag_samples && return
    push!(mb_diag_samples,sample)
    allowed=[k for (k,e) in s["edges"] if e["from"]==frame.key && mb_first_action(e,frame,move)!==nothing]
    diag_snapshot(s,s["actor"],now,"wake_"*goal,frame.key,allowed)
end
