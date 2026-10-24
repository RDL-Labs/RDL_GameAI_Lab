# Shared, actor-relative grouping of sampled ground and obstacle surfaces.
# Edges are hypotheses between samples, never surveyed continuous geometry.
structure_kind(appearance)=appearance in ("bare_ground","trampled_grass") ? "worn_ground" : appearance
structure_memory(actor)=D("actor"=>actor,"source"=>nothing,"capture_us"=>-1,"sequence"=>0,
    "models"=>Any[],"events"=>Any[],"observation"=>nothing)

function local_structures(ground,obstacles;max_link=2.5)
    nodes=Any[];edges=Tuple{Int,Int}[]
    for (i,c) in enumerate(ground["cells"])
        push!(nodes,D("sample"=>i,"layer"=>"ground","kind"=>structure_kind(c["appearance"]),
            "status"=>c["status"],"point"=>(c["distance"]*sind(c["angle"]),c["distance"]*cosd(c["angle"]))))
        for j in ground_neighbors(i);i<j && push!(edges,(i,j));end
    end
    # The ray sensor's explicit sample indices preserve missing/clear intervals.
    offset=length(nodes)
    for (i,c) in enumerate(obstacles["samples"])
        push!(nodes,D("sample"=>offset+i,"layer"=>"obstacle","kind"=>c["status"]=="hit" ? "obstacle" : "clear_ray",
            "status"=>c["status"] in ("hit","clear") ? "sampled" : "occluded",
            "point"=>(c["distance"]*sind(c["angle"]),c["distance"]*cosd(c["angle"]))))
        i>1 && push!(edges,(offset+i-1,offset+i))
    end
    n=length(nodes);neighbors=[Int[] for _ in 1:n];joins=[Int[] for _ in 1:n]
    boundaries=Any[];links=Any[]
    for (i,j) in edges
        push!(neighbors[i],j);push!(neighbors[j],i)
        a,b=nodes[i],nodes[j]
        reason=if a["status"]!="sampled" || b["status"]!="sampled"
            "unobserved"
        elseif a["kind"]!=b["kind"]
            "observed_transition"
        elseif hypot(a["point"][1]-b["point"][1],a["point"][2]-b["point"][2])>max_link
            "unresolved_interval"
        else
            "sampled_continuity"
        end
        record=D("samples"=>[i,j],"status"=>reason)
        if reason=="sampled_continuity"
            push!(joins[i],j);push!(joins[j],i);push!(links,record)
        else
            push!(boundaries,record)
        end
    end
    groups=Any[];remaining=Set(i for i in 1:n if nodes[i]["status"]=="sampled" && nodes[i]["kind"]!="clear_ray")
    while !isempty(remaining)
        seed=minimum(remaining);todo=[seed];component=Int[];delete!(remaining,seed)
        while !isempty(todo)
            i=pop!(todo);push!(component,i)
            for j in joins[i]
                if j in remaining;delete!(remaining,j);push!(todo,j);end
            end
        end
        sort!(component)
        push!(groups,D("kind"=>nodes[seed]["kind"],"layer"=>nodes[seed]["layer"],"samples"=>component,
            "points"=>[nodes[i]["point"] for i in component],
            "links"=>[e for e in links if first(e["samples"]) in component],
            "boundaries"=>[e for e in boundaries if any(i->i in component,e["samples"])],
            "outside_observation"=>"unknown","continuity"=>"between_samples_unverified"))
    end
    breaks=Any[]
    for middle in 1:n
        nodes[middle]["status"]=="sampled" || continue
        ns=neighbors[middle]
        for i in ns, j in ns
            i<j || continue
            a,b,c=nodes[i],nodes[middle],nodes[j]
            a["status"]==c["status"]=="sampled" || continue
            a["kind"]==c["kind"] && a["kind"]!=b["kind"] && a["kind"]!="clear_ray" || continue
            push!(breaks,D("samples"=>[i,middle,j],"kind"=>a["kind"],"status"=>"sampled_break","passability"=>"unverified"))
        end
    end
    D("source"=>ground["source"],"nodes"=>nodes,"groups"=>groups,"breaks"=>breaks,
        "boundaries"=>boundaries,"max_link"=>max_link,"authority"=>"local sampled structure hypotheses")
end

function update_structures!(state,ob,result)
    source=ob["source"];source["actor"]==state["actor"] || error("structure_actor")
    source["observation"]==state["source"] && return state
    linked=result!==nothing && result["actor"]==state["actor"] && result["source"]==state["source"] &&
        result["before_us"]==state["capture_us"] && result["after_us"]==source["capture_us"]
    empty!(state["events"])
    if state["source"]!==nothing && !linked
        empty!(state["models"]);push!(state["events"],"body_correspondence_unavailable")
    end
    if linked
        sn,cs=sincosd(result["yaw"])
        for m in state["models"]
            m["points"]=[(cs*(x-result["right"])-sn*(z-result["forward"]),sn*(x-result["right"])+cs*(z-result["forward"])) for (x,z) in m["points"]]
            m["status"]="not_currently_supported"
            # Old topology cannot be presented as current evidence.
            m["current"]=nothing
        end
    end
    filter!(m->source["capture_us"]-m["last_seen_us"]<=8_000_000,state["models"])
    groups=[g for g in ob["groups"] if g["kind"] in ("worn_ground","water","obstacle")]
    choices=[[i for (i,m) in enumerate(state["models"]) if m["kind"]==g["kind"] &&
        count(p->any(q->hypot(p[1]-q[1],p[2]-q[2])<=.6,m["points"]),g["points"])>=2] for g in groups]
    old=copy(state["models"])
    for (g,options) in zip(groups,choices)
        unique_match=length(options)==1 && count(cs->first(options) in cs,choices)==1
        if unique_match
            model=old[first(options)]
        else
            # Split/merge evidence starts new hypotheses rather than retaining a false union.
            for i in options;old[i]["status"]="restructured";end
            !isempty(options) && push!(state["events"],"split_or_merge")
            filter!(m->m["status"]!="restructured",state["models"])
            if count(m->m["kind"]==g["kind"],state["models"])>=8
                push!(state["events"],"capacity");continue
            end
            state["sequence"]+=1
            model=D("model_ref"=>"structure_$(state["sequence"])","kind"=>g["kind"])
            push!(state["models"],model)
        end
        model["points"]=copy(g["points"]);model["current"]=g;model["status"]="observed"
        model["last_seen_us"]=source["capture_us"];model["source"]=source["observation"]
    end
    state["source"]=source["observation"];state["capture_us"]=source["capture_us"];state["observation"]=ob
    state
end
