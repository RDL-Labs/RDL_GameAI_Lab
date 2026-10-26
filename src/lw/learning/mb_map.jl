# Observed MB transition graph. No World positions, object IDs or reverse-edge invention.
const MB_MAP_NODE_LIMIT=1280
const MB_MAP_EDGE_LIMIT=5120
mb_map_state(actor;chunks=false,sensitivity=D())=D("sensitivity"=>mb_sensitivity(sensitivity),"parent_mb"=>mb_parent_state(),"routes"=>mb_route_state(),"recognition"=>mb_recognition_state(),"sleep"=>D("frozen"=>nothing,"reviews"=>Any[],"hypotheses"=>D(),"proposals"=>0,"selected"=>0),"chunks_enabled"=>chunks,"chunks"=>D(),"route_trace"=>String[],"trace_goal"=>nothing,
    "last_chunk_operation"=>nothing,"last_chunk_credit"=>nothing,"chunk_formations"=>0,"chunk_goal_credits"=>0,"chunk_reward"=>0.,
    "chunk_proposals"=>0,"chunk_selected"=>0,"chunk_records"=>Any[],"actor"=>actor,"nodes"=>D(),"edges"=>D(),"current"=>nothing,"current_us"=>nothing,"receipt"=>nothing,
    "next_search_us"=>0,"observations"=>0,"searches"=>0,"expanded"=>0,"proposals"=>0,
    "selected"=>0,"prediction_match"=>0,"prediction_miss"=>0,"prediction_unknown"=>0,
    "evictions"=>0,"records"=>Any[])
function mb_scene(obs)
    scene=relation_scene(obs)
    (scene===nothing || isempty(scene)) && return nothing
    anchor=first(scene)["angle"]
    signature=join(["$(x["color"]):$(x["range_band"]):$(round(Int,wrap_angle(x["angle"]-anchor)/30))" for x in scene],"|")
    (key=bytes2hex(sha256(signature))[1:16],anchor=anchor,signature=signature,features=mb_features(signature))
end
function mb_forget_node!(s,key)
    delete!(s["nodes"],key)
    filter!(p->p.second["from"]!=key && p.second["to"]!=key,s["edges"])
    s["evictions"]+=1
    mb_prune_chunks!(s)
end
function mb_observe!(s,obs,now;home=false,food=false)
    obs["source"]=="ob:$now:$(s["actor"])" || error("mb_observation_binding")
    frame=mb_scene(obs);s["observations"]+=1;s["current"]=frame;s["current_us"]=now
    receipt=s["receipt"];s["receipt"]=nothing
    if frame!==nothing
        if !haskey(s["nodes"],frame.key)
            if length(s["nodes"])<MB_MAP_NODE_LIMIT
                s["nodes"][frame.key]=D("signature"=>frame.signature,"home"=>false,"food"=>false,"seen"=>now)
            else
                s["recognition"]["admission_blocked"]+=1
            end
        end
        if haskey(s["nodes"],frame.key)
            n=s["nodes"][frame.key];n["seen"]=now;n["home"]=home;n["food"]=food
        end
    end
    mb_route_observe!(s,receipt,frame,now)
    mb_trace_observation!(s,receipt,frame,now)
    receipt===nothing && return
    mb_recognition_feedback!(s,receipt,frame,now)
    mb_chunk_prediction!(s,receipt,frame,now)
    predicted=receipt["predicted"]
    if predicted!==nothing && haskey(s["edges"],predicted)
        e=s["edges"][predicted]
        outcome=mb_prediction_outcome(s,receipt,frame,now)
        if outcome=="match"
            e["matches"]+=1;s["prediction_match"]+=1
        elseif outcome=="mismatch"
            e["misses"]=min(32,e["misses"]+1);s["prediction_miss"]+=1
        elseif outcome=="execution_failure"
            e["execution_failures"]=get(e,"execution_failures",0)+1
        else
            s["prediction_unknown"]+=1
        end
    end
    (frame===nothing || now!=receipt["now"]+1_000_000 || receipt["status"]!="performed" ||
        !(receipt["action"] in ("walk","run","scan")) || receipt["from"]==frame.key ||
        (!haskey(s["nodes"],receipt["from"]) || !haskey(s["nodes"],frame.key))) && return
    key="$(receipt["from"]):$(receipt["action"]):$(round(Int,receipt["offset"]/15)):$(round(Int,receipt["distance"]*10)):$(frame.key)"
    if !haskey(s["edges"],key)
        if length(s["edges"])>=MB_MAP_EDGE_LIMIT
            s["recognition"]["admission_blocked"]+=1;return
        end
        s["edges"][key]=D("from"=>receipt["from"],"to"=>frame.key,"action"=>receipt["action"],
            "offset"=>receipt["offset"],"distance"=>receipt["distance"],"samples"=>0,"energy_sum"=>0.,"matches"=>0,"misses"=>0,"seen"=>now)
    end
    e=s["edges"][key];e["samples"]+=1;e["energy_sum"]+=receipt["energy"];e["seen"]=now
    mb_trace_edge!(s,key)
end
function mb_record!(s,plan,status,energy,now;turn=nothing,distance=.5)
    mb_parent_record!(s,plan,energy,now)
    mb_route_record!(s,plan,status,now;energy=max(0.,energy))
    frame=s["current"];predicted=get(plan,"mb_edge",nothing)
    haskey(plan,"mb_association") && (s["recognition"]["selected"]+=1)
    haskey(plan,"mb_sleep") && (s["sleep"]["selected"]+=1)
    haskey(plan,"mb_chunk") && (s["chunk_selected"]+=1)
    predicted!==nothing && (s["selected"]+=1)
    if frame===nothing;s["receipt"]=nothing;return;end
    action=plan["action"]
    angle=turn===nothing ? (action=="scan" ? get(plan,"scan_angle",60.) : get(plan,"approach_angle",ANGLES[get(plan,"direction",0)+1])) : turn
    s["receipt"]=D("from"=>frame.key,"action"=>action,"offset"=>action=="scan" ? angle : wrap_angle(angle-frame.anchor),
        "distance"=>distance,"status"=>status,"energy"=>max(0.,energy),"now"=>now,"predicted"=>predicted,"goal"=>get(plan,"purpose_family",nothing),"local_repair"=>get(plan,"mb_local_repair",nothing),"route"=>get(plan,"mb_route",nothing),"chunk"=>get(plan,"mb_chunk",nothing),"association"=>get(plan,"mb_association",nothing))
end
mb_edge_cost(e)=1.0+e["energy_sum"]/max(1,e["samples"])+2/(1+e["samples"]+e["matches"])+2log1p(e["misses"])+log1p(get(e,"execution_failures",0))
function mb_first_action(e,frame,move)
    if e["action"]=="scan"
        return D("action"=>"scan","scan_angle"=>e["offset"])
    end
    e["action"]=="walk" || return nothing # Do not turn a learned run into an unvalidated walk.
    angle=wrap_angle(frame.anchor+e["offset"])
    rows=[r for r in move["energy"]["rows"] if r["cost"]!==nothing && abs(ANGLES[parse(Int,r["ref"])+1]-angle)<=22.5]
    isempty(rows) && return nothing
    sort!(rows,by=r->(abs(ANGLES[parse(Int,r["ref"])+1]-angle),r["ref"]))
    D("action"=>"walk","direction"=>parse(Int,first(rows)["ref"]),"steering_angle"=>angle,"approach_angle"=>angle,"approach_span"=>e["distance"])
end
function mb_search(s,start,goal,now;max_depth=4,max_expansions=64,first_allowed=e->true)
    goal in ("home","food") || error("mb_goal")
    1<=max_depth<=4 && 1<=max_expansions<=64 || error("mb_search_budget")
    queue=[(node=start,path=String[],cost=0.,visited=Set([start]))]
    expanded=0;solution=nothing
    while !isempty(queue) && expanded<max_expansions
        sort!(queue,by=x->(x.cost,join(x.path,"/")));item=popfirst!(queue);expanded+=1
        n=get(s["nodes"],item.node,nothing)
        if !isempty(item.path) && n!==nothing && n[goal]
            solution=item;break
        end
        length(item.path)>=max_depth && continue
        edges=sort([k for (k,e) in s["edges"] if e["from"]==item.node && !(e["to"] in item.visited) &&
            e["action"] in ("walk","scan")],by=k->(mb_edge_cost(s["edges"][k]),k))
        for key in Iterators.take(edges,8)
            e=s["edges"][key]
            isempty(item.path) && !first_allowed(e) && continue
            push!(queue,(node=e["to"],path=vcat(item.path,[key]),cost=item.cost+mb_edge_cost(e),visited=union(item.visited,Set([e["to"]]))))
        end
        sort!(queue,by=x->(x.cost,join(x.path,"/")));length(queue)>64 && resize!(queue,64)
    end
    (solution=solution,expanded=expanded)
end
function mb_simulate!(s,move,goal,H,threshold,reserve,strain,now;max_depth=4,max_expansions=64)
    goal in ("home","food") || error("mb_goal")
    1<=max_depth<=4 && 1<=max_expansions<=64 || error("mb_search_budget")
    frame=s["current"]
    (frame===nothing || s["current_us"]!=now) && (mb_reject!(s,"wake","no_current_observation");return Any[])
    (H<threshold || reserve<=20 || strain>=.8) && (mb_reject!(s,"wake","H_or_body_gate");return Any[])
    now<s["next_search_us"] && (mb_reject!(s,"wake","search_cooldown");return Any[])
    s["next_search_us"]=now+64_000_000;s["searches"]+=1
    matches=mb_correspondences(s,keys(s["nodes"]),now;scope="wake",H=H)
    out=Any[];expanded=0
    for match in matches
        aligned=(key=match["key"],anchor=match["anchor"],signature=frame.signature)
        search=mb_search(s,match["key"],goal,now;max_depth=max_depth,max_expansions=max(1,max_expansions-expanded),
            first_allowed=e->mb_first_action(e,aligned,move)!==nothing)
        expanded+=search.expanded;solution=search.solution
        if solution!==nothing
            key=first(solution.path);p=mb_first_action(s["edges"][key],aligned,move)
            if p!==nothing
                merge!(p,D("method"=>"mb_sim:"*key,"priority"=>3.0+1/(1+solution.cost),"question"=>"target_observed",
                    "mb_edge"=>key,"mb_expected"=>s["edges"][key]["to"],"mb_depth"=>length(solution.path)))
                mb_attach_correspondence!(p,s,match);mb_route_attach!(p,s,solution.path,goal,"wake");push!(out,p)
            end
        else
            mb_reject!(s,"wake","no_path")
        end
        push!(s["records"],D("source"=>"ob:$now:$(s["actor"])","goal"=>goal,"expanded"=>search.expanded,
            "recognized"=>match["key"],"probability"=>match["probability"],
            "path"=>solution===nothing ? String[] : solution.path,"cost"=>solution===nothing ? nothing : solution.cost))
        length(s["records"])>32 && popfirst!(s["records"])
        expanded>=max_expansions && break
    end
    s["expanded"]+=expanded;s["proposals"]+=length(out)
    out
end
