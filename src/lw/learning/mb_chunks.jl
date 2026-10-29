# Goal-credited, removable experience chunks; not preconfigured routes.
const MB_CHUNK_LIMIT=64
const MB_TRACE_LIMIT=32
function mb_trace_reset!(s)
    empty!(s["route_trace"]);s["trace_goal"]=nothing
end
function mb_prune_chunks!(s)
    filter!(p->all(k->haskey(s["edges"],k),p.second["edges"]),s["chunks"])
    all(k->haskey(s["edges"],k),s["route_trace"]) || mb_trace_reset!(s)
end
function mb_trace_observation!(s,receipt,frame,now)
    s["chunks_enabled"] || return
    s["last_chunk_operation"]=nothing
    receipt===nothing && return
    valid=frame!==nothing && now==receipt["now"]+1_000_000
    incidental=get(receipt,"incidental_item",false) && receipt["action"]=="item_pickup"
    # Collecting an incidental object is not evidence that food/home was reached.
    valid && !incidental && (s["last_chunk_operation"]="op:$(receipt["now"]):$(s["actor"])")
    goal=get(receipt,"goal",nothing)
    if !valid || !(goal in ("home","food")) || (!incidental && !(receipt["status"] in ("performed","picked_up","recovered")))
        mb_trace_reset!(s);return
    end
    if s["trace_goal"]!=goal
        mb_trace_reset!(s);s["trace_goal"]=goal
    end
    if !isempty(s["route_trace"])
        last_edge=get(s["edges"],last(s["route_trace"]),nothing)
        if last_edge===nothing || last_edge["to"]!=receipt["from"]
            mb_trace_reset!(s);s["trace_goal"]=goal
        end
    end
    # An unexplained scene change cannot bridge a remembered path.
    if receipt["from"]!=frame.key && !(receipt["action"] in ("walk","run","scan"))
        mb_trace_reset!(s)
    end
end
function mb_trace_edge!(s,key)
    s["chunks_enabled"] && s["trace_goal"]!==nothing || return
    push!(s["route_trace"],key)
    length(s["route_trace"])>MB_TRACE_LIMIT && popfirst!(s["route_trace"])
end
function mb_chunk_prediction!(s,receipt,frame,now)
    id=get(receipt,"chunk",nothing)
    (id===nothing || !haskey(s["chunks"],id)) && return
    c=s["chunks"][id];key=receipt["predicted"]
    outcome=mb_prediction_outcome(s,receipt,frame,now)
    field=outcome=="match" ? "matches" : outcome=="mismatch" ? "misses" : outcome=="execution_failure" ? "execution_failures" : "unknown"
    c[field]=get(c,field,0)+1
end
function mb_goal_result!(s,goal,source,resolved,H_before,H_after,now;completion_reward=nothing)
    s["chunks_enabled"] || return false
    resolved===true || return false
    s["last_chunk_operation"]===nothing && return false
    source==s["last_chunk_operation"] || error("mb_chunk_result_binding")
    source==s["last_chunk_credit"] && return false
    s["last_chunk_credit"]=source
    path=copy(s["route_trace"]);family=s["trace_goal"];mb_trace_reset!(s)
    reward=Float64(completion_reward===nothing ? max(0,H_before-H_after) : completion_reward)
    family==goal && length(path)>=2 || return false
    all(k->haskey(s["edges"],k),path) || return false
    all(s["edges"][path[i]]["to"]==s["edges"][path[i+1]]["from"] for i in 1:length(path)-1) || return false
    frame=s["current"]
    frame!==nothing && s["current_us"]==now && s["edges"][last(path)]["to"]==frame.key || return false
    key=goal*":"*bytes2hex(sha256(join(path,"|")))[1:16]
    if !haskey(s["chunks"],key)
        if length(s["chunks"])>=MB_CHUNK_LIMIT
            s["recognition"]["admission_blocked"]+=1;return false
        end
        s["chunks"][key]=D("goal"=>goal,"edges"=>path,"from"=>s["edges"][first(path)]["from"],
            "to"=>frame.key,"successes"=>0,"reward"=>0.,"matches"=>0,"misses"=>0,"unknown"=>0,"last_success_us"=>now)
        s["chunk_formations"]+=1
    end
    c=s["chunks"][key];c["successes"]+=1;c["reward"]+=reward;c["last_success_us"]=now
    s["chunk_goal_credits"]+=1;s["chunk_reward"]+=reward
    push!(s["chunk_records"],D("chunk"=>key,"source"=>source,"goal"=>goal,"H_before"=>H_before,"H_after"=>H_after,
        "reward"=>reward,"edges"=>length(path),"successes"=>c["successes"],"tentative"=>c["successes"]==1))
    length(s["chunk_records"])>32 && popfirst!(s["chunk_records"])
    true
end
# Repeated goal credit deepens a channel; transition contradictions weaken it.
# Logarithmic growth avoids a hard saturation without making credit linear votes.
mb_chunk_depth(c)=(log1p(c["successes"])+log1p(c["reward"]))/(1+c["misses"]+get(c,"execution_failures",0))
# One remembered suffix per entry; no hidden goal coordinates or invented links.
function mb_channel_terminals(s,goal)
    terminals=Dict{String,Any}()
    s["chunks_enabled"] || return terminals
    for id in sort(collect(keys(s["chunks"])))
        c=s["chunks"][id];c["goal"]==goal && c["successes"]>0 || continue
        path=c["edges"];isempty(path) && continue
        all(k->haskey(s["edges"],k),path) || continue
        all(s["edges"][path[i]]["to"]==s["edges"][path[i+1]]["from"] for i in 1:length(path)-1) || continue
        depth=mb_chunk_depth(c);cost=0.
        for index in reverse(eachindex(path))
            e=s["edges"][path[index]];e["action"] in ("walk","scan") || break
            cost+=mb_edge_cost(e);origin=e["from"]
            rank=(cost/(1+depth),id,index)
            previous=get(terminals,origin,nothing)
            if previous===nothing || rank<previous.rank
                terminals[origin]=(chunk=id,index=index,path=path[index:end],cost=cost,depth=depth,rank=rank)
            end
        end
    end
    terminals
end
function mb_chunk_candidates!(s,move,goal,reserve,strain,now;H=0)
    frame=s["current"]
    (!s["chunks_enabled"] || frame===nothing || s["current_us"]!=now || reserve<=20 || strain>=.8) && return Any[]
    out=Any[]
    entries=Dict{String,Vector{Tuple{String,Int}}}();strength=Dict{String,Float64}()
    for id in sort(collect(keys(s["chunks"])))
        c=s["chunks"][id];c["goal"]==goal || continue
        all(k->haskey(s["edges"],k),c["edges"]) || (mb_reject!(s,"chunk","missing_edge");continue)
        for (index,edge) in enumerate(c["edges"])
            origin=s["edges"][edge]["from"]
            push!(get!(()->Tuple{String,Int}[],entries,origin),(id,index))
            # Several chunks sharing an origin must not multiply its retrieval votes.
            strength[origin]=max(get(strength,origin,0.),mb_chunk_depth(c))
        end
    end
    matches=mb_correspondences(s,keys(entries),now;scope="chunk",H=H,retrieval_strength=strength)
    for match in matches, (id,index) in entries[match["key"]]
        c=s["chunks"][id];edge=c["edges"][index];p=mb_first_action(s["edges"][edge],(anchor=match["anchor"],),move)
        p===nothing && (mb_reject!(s,"chunk","infeasible_action");continue)
        depth=mb_chunk_depth(c)
        merge!(p,D("method"=>"mb_chunk:"*id,"action"=>p["action"],"priority"=>3.0+depth,"mb_channel_depth"=>depth,
            "question"=>"target_observed","mb_edge"=>edge,"mb_expected"=>s["edges"][edge]["to"],
            "mb_chunk"=>id,"mb_chunk_index"=>index,"mb_chunk_start_index"=>index,"mb_depth"=>length(c["edges"])-index+1))
        mb_attach_correspondence!(p,s,match);mb_route_attach!(p,s,c["edges"][index:end],goal,"chunk");push!(out,p)
    end
    sort!(out,by=p->(-p["priority"],p["method"]))
    unique!(p->p["method"],out);length(out)>4 && resize!(out,4)
    s["chunk_proposals"]+=length(out)
    out
end
