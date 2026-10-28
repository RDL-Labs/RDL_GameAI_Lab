# Goal-linked cue hypotheses, not object identities or a new join subgoal.
function mb_goal_cue_project!(s,candidates,pool,goal,H,now)
    get(s,"navigation_mode","explicit_join")=="goal_cues" || return candidates
    (isempty(candidates) || s["current"]===nothing || s["current_us"]!=now) && return candidates
    stats=get!(s,"goal_cues") do
        D("offered"=>0,"selected"=>0,"by_goal"=>D(),"records"=>Any[],"cache"=>D())
    end
    cache=get(stats["cache"],goal,nothing)
    # Derived index only: 64-second refresh does not expire memories or forbid recall.
    if cache===nothing || cache["credits"]!=s["chunk_goal_credits"] || now>=cache["refresh_us"]
        cache=D("terminals"=>mb_channel_terminals(s,goal),"credits"=>s["chunk_goal_credits"],"refresh_us"=>now+64_000_000)
        stats["cache"][goal]=cache
    end
    terminals=cache["terminals"];isempty(terminals) && return candidates
    strengths=Dict(k=>c.depth/(1+c.cost) for (k,c) in terminals)
    matches=mb_correspondences(s,keys(terminals),now;scope="goal_cue",H=H,retrieval_strength=strengths)
    cues=Dict(c["key"]=>c for c in pool.items)
    for p in candidates
        cue=get(cues,p["method"],nothing)
        (cue===nothing || cue["kind"]!="shape" || p["action"]!="walk") && continue
        best=0.;evidence=nothing
        for match in matches
            c=terminals[match["key"]]
            # Sleep can remove edges between index refreshes; never use stale links.
            all(k->haskey(s["edges"],k),c.path) || continue
            chunk=get(s["chunks"],c.chunk,nothing);chunk===nothing && continue
            edge=s["edges"][first(c.path)];edge["action"]=="walk" || continue
            features=s["nodes"][match["key"]]["features"]
            f=get(features,cue["label"],nothing);f===nothing && continue
            # A co-visible object behind the successful movement is weak evidence.
            historical=exp(-abs(wrap_angle(f.angle-edge["offset"]))/45)
            aligned=exp(-abs(wrap_angle(cue["angle"]-(match["anchor"]+edge["offset"])))/45)
            strength=2match["weight"]*mb_chunk_depth(chunk)/(1+c.cost)*historical*aligned
            if strength>best
                best=strength;evidence=(node=match["key"],chunk=c.chunk,confidence=match["confidence"])
            end
        end
        best>0 || continue
        gain=log1p(best)
        p["priority"]+=gain
        p["mb_goal_cue"]=D("goal"=>goal,"label"=>cue["label"],"strength"=>best,"gain"=>gain,
            "node"=>evidence.node,"chunk"=>evidence.chunk,"confidence"=>evidence.confidence)
        stats["offered"]+=1
    end
    candidates
end
function mb_goal_cue_selected!(s,p,now)
    evidence=get(p,"mb_goal_cue",nothing);evidence===nothing && return
    stats=s["goal_cues"];stats["selected"]+=1
    goal=evidence["goal"];stats["by_goal"][goal]=get(stats["by_goal"],goal,0)+1
    push!(stats["records"],merge(D("us"=>now,"method"=>p["method"]),evidence))
    length(stats["records"])>64 && popfirst!(stats["records"])
end
