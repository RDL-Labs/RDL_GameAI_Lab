# Sleep and waking share mb_search; hypothetical paths never earn goal credit.
function mb_sleep_freeze!(s,now)
    s["sleep"]["frozen"]=D("nodes"=>deepcopy(s["nodes"]),"edges"=>deepcopy(s["edges"]),"formation_us"=>now)
end
function mb_sleep_review!(s,day,now)
    state=s["sleep"]
    any(r->r["day"]==day,state["reviews"]) && return
    frozen=state["frozen"];frozen===nothing && return
    frozen["formation_us"]<now || error("mb_sleep_time")
    # Bounded review of recent observed origins; no access to the sleeping body's World.
    starts=sort(collect(keys(frozen["nodes"])),by=k->(-frozen["nodes"][k]["seen"],k))
    resize!(starts,min(8,length(starts)))
    searches=0;expanded=0;found=0
    for start in starts,goal in ("home","food")
        result=mb_search(frozen,start,goal,now);searches+=1;expanded+=result.expanded
        result.solution===nothing && continue
        path=result.solution.path
        id=goal*":"*bytes2hex(sha256(join(path,"|")))[1:16]
        state["hypotheses"][id]=D("goal"=>goal,"from"=>start,"edges"=>path,"formed_us"=>now)
        found+=1
    end
    filter!(p->now-p.second["formed_us"]<=17_280_000_000 && all(k->haskey(s["edges"],k),p.second["edges"]),state["hypotheses"])
    ordered=sort(collect(keys(state["hypotheses"])),by=k->(-state["hypotheses"][k]["formed_us"],k))
    for id in Iterators.drop(ordered,64);delete!(state["hypotheses"],id);end
    push!(state["reviews"],D("day"=>day,"formation_us"=>frozen["formation_us"],"completed_us"=>now,
        "searches"=>searches,"expanded"=>expanded,"found"=>found,"retained"=>length(state["hypotheses"])))
    state["frozen"]=nothing
end
function mb_sleep_candidates!(s,move,goal,H,threshold,reserve,strain,now)
    frame=s["current"];state=s["sleep"]
    (frame===nothing || s["current_us"]!=now || H<threshold || reserve<=20 || strain>=.8) && return Any[]
    out=Any[]
    for id in sort(collect(keys(state["hypotheses"])))
        h=state["hypotheses"][id]
        h["goal"]==goal && h["from"]==frame.key && h["formed_us"]<now && now-h["formed_us"]<=17_280_000_000 || continue
        all(k->haskey(s["edges"],k) && now-s["edges"][k]["seen"]<=17_280_000_000,h["edges"]) || continue
        endpoint=get(s["nodes"],s["edges"][last(h["edges"])]["to"],nothing)
        endpoint!==nothing && endpoint[goal] && now-endpoint["seen"]<=17_280_000_000 || continue
        key=first(h["edges"]);edge=s["edges"][key]
        p=mb_first_action(edge,frame,move);p===nothing && continue
        cost=sum(mb_edge_cost(s["edges"][k]) for k in h["edges"])
        # Same method and scoring as waking search: no duplicate vote or imagined support.
        merge!(p,D("method"=>"mb_sim:"*key,"priority"=>3.0+1/(1+cost),"question"=>"target_observed",
            "mb_edge"=>key,"mb_expected"=>edge["to"],"mb_depth"=>length(h["edges"]),"mb_sleep"=>id))
        push!(out,p)
    end
    sort!(out,by=p->(-p["priority"],p["method"]))
    unique!(p->p["method"],out);length(out)>4 && resize!(out,4)
    state["proposals"]+=length(out)
    out
end
