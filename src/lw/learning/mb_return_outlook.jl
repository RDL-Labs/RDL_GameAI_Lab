# Bounded return planning over observed directed transitions, shared across candidates.
# Reverse traversal computes reachability; it never inserts a reverse movement edge.
function mb_return_outlook!(s,now)
    state=get!(s,"return_outlook") do
        D("next_us"=>0,"paths"=>D(),"outgoing"=>D(),"builds"=>0,"evaluated"=>0,
          "known"=>0,"unknown"=>0,"selected"=>0,"records"=>Any[])
    end
    now<state["next_us"] && return state
    state["next_us"]=now+64_000_000;state["builds"]+=1
    paths=D();incoming=D();outgoing=D()
    for key in sort(collect(keys(s["edges"])))
        e=s["edges"][key]
        e["action"] in ("walk","scan") || continue
        haskey(s["nodes"],e["from"]) && haskey(s["nodes"],e["to"]) || continue
        push!(get!(() -> String[],incoming,e["to"]),key)
        push!(get!(() -> String[],outgoing,e["from"]),key)
    end
    queue=Any[]
    for key in sort([k for (k,n) in s["nodes"] if n["home"]])
        push!(queue,(node=key,path=String[],cost=0.,energy=0.,path_key=""))
    end
    expanded=0
    while !isempty(queue) && expanded<256
        sort!(queue,by=x->(x.cost,x.node,x.path_key))
        item=popfirst!(queue);haskey(paths,item.node) && continue
        expanded+=1
        paths[item.node]=D("path"=>item.path,"cost"=>item.cost,"energy"=>item.energy)
        length(item.path)>=32 && continue
        for key in get(incoming,item.node,String[])
            e=s["edges"][key];haskey(paths,e["from"]) && continue
            next_path=vcat([key],item.path)
            # Cache the exact original tie-break key once, not on every comparison.
            push!(queue,(node=e["from"],path=next_path,cost=item.cost+mb_edge_cost(e),
                energy=item.energy+e["energy_sum"]/max(1,e["samples"]),path_key=join(next_path,"/")))
        end
        sort!(queue,by=x->(x.cost,x.node,x.path_key));length(queue)>256 && resize!(queue,256)
    end
    state["paths"]=paths;state["outgoing"]=outgoing
    state
end
function mb_return_estimate(s,state,key)
    key===nothing && return nothing
    r=get(state["paths"],key,nothing);r===nothing && return nothing
    # Sleep pruning or changed home evidence invalidates a cached chain immediately.
    node=key
    for id in r["path"]
        e=get(s["edges"],id,nothing)
        (e===nothing || e["from"]!=node) && return nothing
        node=e["to"]
    end
    n=get(s["nodes"],node,nothing)
    n!==nothing && n["home"] ? r : nothing
end
function mb_project_return!(s,candidates,move,goal,reserve,now)
    goal=="food" || return candidates
    frame=s["current"]
    (frame===nothing || s["current_us"]!=now) && return candidates
    state=mb_return_outlook!(s,now)
    current=mb_return_estimate(s,state,frame.key)
    # A known first step is available as a food-exploration option, not a forced home goal.
    if current!==nothing && !isempty(current["path"])
        id=first(current["path"]);e=s["edges"][id];p=mb_first_action(e,frame,move)
        if p!==nothing && !any(get(c,"mb_edge",nothing)==id for c in candidates)
            merge!(p,D("method"=>"mb_return_link","question"=>"target_observed","priority"=>1.,
                "mb_edge"=>id,"mb_expected"=>e["to"],"mb_return_link"=>true))
            p["mb_parent_estimate"]=mb_parent_estimate!(s,p,goal,nothing)
            push!(candidates,p)
        end
    end
    known=0;unknown=0
    for p in candidates
        # Ordinary movements may match an observed transition; ambiguous endpoints stay unknown.
        key=get(p,"mb_expected",nothing)
        if key===nothing && p["action"]=="walk"
            angle=get(p,"approach_angle",ANGLES[get(p,"direction",0)+1])
            span=get(p,"approach_span",.5)
            endpoints=String[]
            for id in get(state["outgoing"],frame.key,String[])
                e=get(s["edges"],id,nothing);e===nothing && continue
                e["action"]=="walk" && abs(wrap_angle(frame.anchor+e["offset"]-angle))<=7.5 &&
                    abs(e["distance"]-span)<=.1 && push!(endpoints,e["to"])
            end
            unique!(endpoints);length(endpoints)==1 && (key=only(endpoints))
        end
        p["action"] in ("pickup","recover","rest","eat") && (key=frame.key)
        r=mb_return_estimate(s,state,key)
        uncertain=r===nothing
        uncertain ? (unknown+=1) : (known+=1)
        estimate=get(p,"mb_parent_estimate",nothing)
        outward=estimate===nothing ? 0. : estimate["energy"]
        home_energy=uncertain ? nothing : r["energy"]
        margin=uncertain ? nothing : reserve-outward-home_energy
        # Unknown is not impossible. Keep its penalty bounded, and preserve exploration.
        pressure=uncertain ? .25 : clamp((20.0-margin)/20.,0.,2.)
        p["priority"]-=pressure
        p["action"]=="scan" && current===nothing && (p["priority"]+=.25)
        outlook=D("status"=>uncertain ? "unconfirmed" : "observed_chain",
            "energy"=>home_energy,"actions"=>uncertain ? nothing : length(r["path"]),
            "margin"=>margin,"pressure"=>pressure)
        p["mb_return_outlook"]=outlook
        estimate!==nothing && (estimate["return_home"]=copy(outlook))
    end
    state["evaluated"]+=1;state["known"]+=known;state["unknown"]+=unknown
    push!(state["records"],D("us"=>now,"known"=>known,"unknown"=>unknown,"reserve"=>reserve,
        "current_status"=>current===nothing ? "unconfirmed" : "observed_chain"))
    length(state["records"])>64 && popfirst!(state["records"])
    candidates
end
