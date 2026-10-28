# Port of relational_movement scene/relation/compose; all geometry is actor-relative.
using SHA
wrap_angle(x)=mod(x+180,360)-180
function relation_scene(ob)
    ob["coverage"]=="complete" && !get(ob,"output_limited",false) || return nothing
    out=Any[]
    for color in sort(unique(f["color"] for f in ob["features"]))
        ps=landmark_patches(ob,color);length(ps)==1 || continue
        bands=unique(f["range_band"] for f in ob["features"] if f["color"]==color)
        length(bands)==1 || continue
        push!(out,D("color"=>color,"angle"=>ps[1]["angle"],"range_band"=>first(bands)))
        length(out)==5 && break
    end
    out
end
function compare_relation(ob,target)
    current=relation_scene(ob)
    compare_relation_scene(current,target)
end
function compare_relation_scene(current,target)
    current===nothing && return D("status"=>"unavailable","pairs"=>Any[])
    old=Dict(x["color"]=>x for x in get(target,"scene",Any[]));now=Dict(x["color"]=>x for x in current)
    common=sort(collect(intersect(keys(old),keys(now))))
    length(common)<2 && return D("status"=>"insufficient_landmarks","pairs"=>Any[])
    pairs=Any[]
    for i in 1:length(common),j in i+1:length(common)
        a,b=common[i],common[j]
        expected=wrap_angle(old[b]["angle"]-old[a]["angle"]);actual=wrap_angle(now[b]["angle"]-now[a]["angle"])
        push!(pairs,D("colors"=>[a,b],"expected"=>expected,"actual"=>actual,"error"=>wrap_angle(expected-actual)))
    end
    D("status"=>"comparable","pairs"=>pairs,"current"=>current,"aligned"=>all(abs(p["error"])<=7.5 for p in pairs))
end
function relation_cost(rel,angle,weight;goal_angle=nothing)
    cost=0.
    if rel["status"]=="comparable"
        pred=Dict{String,Float64}()
        for x in rel["current"]
            d=x["range_band"]=="near" ? 4. : x["range_band"]=="mid" ? 12. : 24.
            pred[x["color"]]=atand(d*sind(x["angle"])-sind(angle),d*cosd(x["angle"])-cosd(angle))
        end
        for p in rel["pairs"]
            a,b=p["colors"];error=wrap_angle(p["expected"]-wrap_angle(pred[b]-pred[a]))
            cost+=clamp((error^2-p["error"]^2)/900,-1.,1.)
        end
        cost*=weight/length(rel["pairs"])
    end
    cost+(goal_angle===nothing ? 0. : -.75*cosd(wrap_angle(angle-goal_angle)))
end
function relation_signature(points)
    [[(a["color"],b["color"],round(Int,(b["angle"]-a["angle"])/15))
      for (i,a) in enumerate(get(p,"scene",Any[])) for b in get(p,"scene",Any[])[i+1:end]] for p in points]
end
relation_field_state()=D("owner"=>nothing,"goal"=>nothing,"evaluations"=>0,"proposals"=>0,"selections"=>0,"records"=>Any[])
function relation_candidates!(state,move,ob,m,goal,source)
    eligible=Any[]
    current=nothing;prepared=false
    for key in sort(collect(keys(m["routes"])))
        n=m["routes"][key];n["goal"]==goal || continue
        cursor=get(m["cursors"],key,1)
        rel=nothing
        if cursor<=length(n["points"]) && !prepared
            current=relation_scene(ob);prepared=true
        end
        while cursor<=length(n["points"])
            rel=compare_relation_scene(current,n["points"][cursor])
            get(rel,"aligned",false) || break
            cursor+=1
        end
        m["cursors"][key]=cursor
        cursor>length(n["points"]) && continue
        rel["status"]=="comparable" || continue
        push!(eligible,(key=key,score=(1+.25*n["support"])/(1+n["H"]),relation=rel))
    end
    state["evaluations"]+=1
    if isempty(eligible);state["owner"]=nothing;return Any[];end
    owner=state["goal"]==goal ? state["owner"] : nothing
    index=findfirst(x->x.key==owner,eligible)
    selected=index===nothing ? first(sort(eligible,by=x->(-x.score,x.key))) : eligible[index]
    state["owner"]=selected.key;state["goal"]=goal
    weight=min(1.,selected.score/3)*selected.score/sum(x.score for x in eligible)
    out=Any[];samples=Any[]
    for r in move["energy"]["rows"]
        r["cost"]===nothing && continue
        i=parse(Int,r["ref"]);angle=ANGLES[i+1];cost=relation_cost(selected.relation,angle,weight)
        push!(samples,D("direction"=>angle,"cost"=>cost))
        push!(out,D("method"=>"relation:"*selected.key*":"*string(angle),"action"=>"walk","direction"=>i,
            "priority"=>2.5-cost,"question"=>"landmark_progress","route"=>selected.key,"observation_source"=>source))
    end
    state["proposals"]+=length(out)
    push!(state["records"],D("source"=>source,"owner"=>selected.key,"weight"=>weight,"relation"=>selected.relation,"samples"=>samples))
    length(state["records"])>32 && popfirst!(state["records"])
    out
end
