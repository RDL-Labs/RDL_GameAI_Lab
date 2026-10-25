# A selected path is one attempt, shared by chunks, sleep and waking search.
mb_route_state()=D("active"=>nothing,"stats"=>D(),"events"=>Any[],"started"=>0,"outcomes"=>D())
function mb_route_finish!(s,outcome,now;reward=0.)
    r=s["routes"];a=r["active"];a===nothing && return
    st=get(r["stats"],a["id"],nothing)
    if st!==nothing
        st[outcome]=get(st,outcome,0)+1;st["reward"]+=reward
    end
    r["outcomes"][outcome]=get(r["outcomes"],outcome,0)+1
    push!(r["events"],D("id"=>a["id"],"kind"=>a["kind"],"goal"=>a["goal"],"started_us"=>a["started_us"],"ended_us"=>now,
        "steps"=>a["cursor"]-1,"length"=>length(a["path"]),"verified_steps"=>a["verified"],"outcome"=>outcome,"reward"=>reward))
    length(r["events"])>64 && popfirst!(r["events"])
    r["active"]=nothing
end
function mb_route_attach!(p,s,path,goal,kind;chunk=nothing,sleep=nothing)
    id=goal*":"*bytes2hex(sha256(join(path,"|")))[1:16]
    merge!(p,D("mb_path"=>copy(path),"mb_route"=>id,"mb_route_kind"=>kind,"mb_route_index"=>1,"mb_route_goal"=>goal))
    st=get(s["routes"]["stats"],id,nothing)
    if st!==nothing
        failures=sum(get(st,k,0) for k in ("unresolved","blocked","mismatch","lost"))
        p["priority"]+=log1p(get(st,"success",0))-log1p(failures)
    end
    p
end
function mb_route_record!(s,p,status,now)
    r=s["routes"];a=r["active"];id=get(p,"mb_route",nothing)
    if id===nothing
        # Endpoint acquisition may resolve the parent on the following tick.
        if a!==nothing && a["cursor"]>length(a["path"]) && status in ("picked_up","recovered")
            a["last_us"]=now;return
        end
        a!==nothing && mb_route_finish!(s,a["cursor"]>length(a["path"]) ? "unresolved" : "interrupted",now)
        return
    end
    if a===nothing || a["id"]!=id
        a!==nothing && mb_route_finish!(s,"interrupted",now)
        path=p["mb_path"]
        get(p,"mb_route_index",1)==1 || return
        if !haskey(r["stats"],id) && length(r["stats"])<256
            r["stats"][id]=D("starts"=>0,"reward"=>0.)
        end
        haskey(r["stats"],id) && (r["stats"][id]["starts"]+=1)
        a=D("id"=>id,"path"=>copy(path),"goal"=>p["mb_route_goal"],"kind"=>p["mb_route_kind"],
            "chunk"=>get(p,"mb_chunk",nothing),"sleep"=>get(p,"mb_sleep",nothing),"cursor"=>1,"verified"=>0,
            "started_us"=>now,"last_us"=>now,"priority"=>p["priority"])
        r["active"]=a;r["started"]+=1
    end
    a["last_us"]=now
    status=="performed" || mb_route_finish!(s,"blocked",now)
end
function mb_route_observe!(s,receipt,frame,now)
    a=s["routes"]["active"];a===nothing && return
    receipt===nothing && (mb_route_finish!(s,"lost",now);return)
    get(receipt,"route",nothing)==a["id"] || return
    i=a["cursor"]
    (i<=length(a["path"]) && receipt["predicted"]==a["path"][i]) || return
    outcome=mb_prediction_outcome(s,receipt,frame,now)
    if outcome in ("mismatch","execution_failure")
        mb_route_finish!(s,outcome=="mismatch" ? "mismatch" : "blocked",now);return
    end
    (frame===nothing || now!=receipt["now"]+1_000_000) && (mb_route_finish!(s,"lost",now);return)
    # Unknown is tentative execution progress, never a verified transition or reward.
    a["cursor"]+=1;a["verified"]+=Int(outcome=="match")
end
function mb_route_goal!(s,goal,source,resolved,H_before,H_after,now)
    a=s["routes"]["active"];a===nothing && return
    a["goal"]==goal && source=="op:$(a["last_us"]):$(s["actor"])" || return
    if resolved===true && H_after==0 && H_before>H_after
        mb_route_finish!(s,"success",now;reward=Float64(H_before-H_after))
    elseif a["cursor"]>length(a["path"]) && now>a["last_us"]+1_000_000
        mb_route_finish!(s,"unresolved",now)
    end
end
function mb_route_candidates!(s,move,goal,reserve,strain,now)
    a=s["routes"]["active"];a===nothing && return Any[]
    if a["goal"]!=goal || reserve<=20 || strain>=.8
        mb_route_finish!(s,"interrupted",now);return Any[]
    end
    i=a["cursor"]
    if i>length(a["path"])
        mb_route_finish!(s,"unresolved",now);return Any[]
    end
    all(k->haskey(s["edges"],k),a["path"]) || (mb_route_finish!(s,"lost",now);return Any[])
    edge=a["path"][i];e=s["edges"][edge]
    matches=mb_correspondences(s,[e["from"]],now;scope="route")
    isempty(matches) && (mb_route_finish!(s,"lost",now);return Any[])
    match=first(matches);p=mb_first_action(e,(anchor=match["anchor"],),move)
    p===nothing && (mb_route_finish!(s,"blocked",now);return Any[])
    merge!(p,D("method"=>"mb_route:"*a["id"],"priority"=>a["priority"],"question"=>"target_observed",
        "mb_edge"=>edge,"mb_expected"=>e["to"],"mb_depth"=>length(a["path"])-i+1,
        "mb_path"=>a["path"],"mb_route"=>a["id"],"mb_route_kind"=>a["kind"],"mb_route_index"=>i,"mb_route_goal"=>goal))
    a["chunk"]!==nothing && merge!(p,D("mb_chunk"=>a["chunk"],"mb_chunk_index"=>i))
    a["sleep"]!==nothing && (p["mb_sleep"]=a["sleep"])
    mb_attach_correspondence!(p,s,match)
    Any[p]
end
