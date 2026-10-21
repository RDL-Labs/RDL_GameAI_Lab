# Static World geometry prepared once; observations retain the existing bounded output.
prepare_landmark_objects(objects) = [(x=Float64(o.x),z=Float64(o.z),
    radius=Float64(o.radius),height=Float64(o.height),
    color=hasproperty(o,:color) ? String(o.color) : "ochre") for o in objects]

# Port of the finite LW horizontal fan / directional color route roles.
# World geometry is consumed only here; policy receives color/angle/band/source.
function landmark_fan(objects,position,yaw,source)
    features=Any[]
    for angle in -90:15:90
        s,c=sincos(deg2rad(yaw+angle));best=Inf;hit=nothing
        for o in objects
            d=RDLMigrationProbe.ray_hit(position,(s,c),RDLMigrationProbe.Circle(o.x,o.z,o.radius))
            if d!==nothing && d<=48 && o.height>=1 && d<best
                best=d;hit=o
            end
        end
        color=hit===nothing ? nothing : hasproperty(hit,:color) ? String(hit.color) : "ochre"
        if color!==nothing && color!="ochre"
            push!(features,D("color"=>color,"azimuth"=>[max(-90.,angle-7.5),min(90.,angle+7.5)],
                "range_band"=>best<=8 ? "near" : best<=24 ? "mid" : "far"))
        end
    end
    D("coverage"=>"complete","features"=>features,"source"=>source)
end

function landmark_patches(observed,color)
    observed["coverage"]=="complete" || return nothing
    fs=sort([f for f in observed["features"] if f["color"]==color],by=f->f["azimuth"][1])
    groups=Any[]
    for f in fs
        lo,hi=f["azimuth"]
        if !isempty(groups) && lo<=groups[end]["hi"]
            groups[end]["hi"]=max(hi,groups[end]["hi"])
            groups[end]["near"]|=f["range_band"]=="near"
        else
            push!(groups,D("lo"=>lo,"hi"=>hi,"near"=>f["range_band"]=="near"))
        end
    end
    [D("angle"=>(g["lo"]+g["hi"])/2,"near"=>g["near"],"width"=>g["hi"]-g["lo"]) for g in groups]
end
trail()=D("points"=>Any[],"overflow"=>false)
route_memory()=D("routes"=>D(),"outbound"=>trail(),"trip"=>nothing,"at_home"=>false,
    "cursors"=>Dict{String,Int}(),"day"=>-1,"selections"=>0,"admissions"=>0,"blocked"=>0)

function record_landmark!(t,obs,operation;relational=false)
    if obs["coverage"]!="complete";t["overflow"]=true;return;end
    t["overflow"] && return
    candidates=Any[]
    for color in sort(unique([f["color"] for f in obs["features"]]))
        ps=landmark_patches(obs,color)
        if length(ps)==1 && abs(ps[1]["angle"])<=45
            push!(candidates,(abs(ps[1]["angle"]),color))
        end
    end
    isempty(candidates) && return
    sort!(candidates)
    length(candidates)>1 && candidates[1][1]==candidates[2][1] && return
    color=candidates[1][2]
    !isempty(t["points"]) && t["points"][end]["color"]==color && return
    if length(t["points"])>=8;t["overflow"]=true;return;end
    point=D("color"=>color,"source"=>obs["source"],"result"=>operation)
    relational && (point["scene"]=something(relation_scene(obs),Any[]))
    push!(t["points"],point)
end

function admit_route!(memory,goal,t,receipt;relational=false)
    (t["overflow"] || isempty(t["points"])) && return
    for reverse in (false,true)
        g=reverse ? (goal=="food" ? "home" : "food") : goal
        points=reverse ? Base.reverse(t["points"]) : t["points"]
        key=g*":"*join([p["color"] for p in points],",")
        relational && (key*="/"*bytes2hex(sha256(JSON3.write(relation_signature(points))))[1:16])
        if !haskey(memory["routes"],key)
            length(memory["routes"])>=16 && continue
            memory["routes"][key]=D("goal"=>g,"points"=>deepcopy(points),"support"=>0,"H"=>0,"receipts"=>String[],"proposals"=>String[])
        end
        node=memory["routes"][key];ids=node[reverse ? "proposals" : "receipts"]
        if !(receipt in ids)
            push!(ids,receipt);length(ids)>32 && popfirst!(ids)
            if !reverse;node["support"]=min(8,node["support"]+1);node["H"]=0;memory["admissions"]+=1;end
        end
    end
end

function route_result!(m,obs,operation,action,status,goal,at_home,selected_route=nothing;delivered=String[],relational=false)
    at_home && m["trip"]===nothing && (m["at_home"]=true)
    if action=="walk" && status=="performed"
        if goal=="food" && m["at_home"] && m["trip"]===nothing
            record_landmark!(m["outbound"],obs,operation;relational=relational)
        elseif goal=="home" && m["trip"]!==nothing
            record_landmark!(m["trip"]["inbound"],obs,operation;relational=relational)
        end
    end
    if action=="pickup" && status=="picked_up" && m["trip"]===nothing
        m["trip"]=D("pickup"=>operation,"outbound"=>m["at_home"] ? deepcopy(m["outbound"]) : nothing,"inbound"=>trail())
        m["at_home"]=false
    elseif action=="deposit" && status=="performed"
        if m["trip"]!==nothing && m["trip"]["pickup"] in delivered
            for (g,t) in (("food",m["trip"]["outbound"]),("home",m["trip"]["inbound"]))
                t!==nothing && admit_route!(m,g,t,operation;relational=relational)
            end
        end
        m["trip"]=nothing;m["at_home"]=true;m["outbound"]=trail();empty!(m["cursors"])
    end
    if selected_route!==nothing && status=="blocked"
        node=m["routes"][selected_route];node["H"]=min(32,node["H"]+1);m["blocked"]+=1
    end
end

function landmark_candidates(move,obs,m,goal,source;include_routes=true)
    obs["coverage"]=="complete" || return Any[]
    targets=Any[]
    for color in sort(unique([f["color"] for f in obs["features"]]))
        ps=landmark_patches(obs,color)
        if length(ps)==1 && !ps[1]["near"] && ps[1]["width"]<=45
            push!(targets,D("name"=>"landmark:"*color,"color"=>color,"angle"=>ps[1]["angle"],"priority"=>2.5,"route"=>nothing))
        end
    end
    for key in sort(collect(keys(m["routes"])))
        include_routes || continue
        n=m["routes"][key];n["goal"]==goal || continue
        goal=="food" && !m["at_home"] && continue
        cursor=get(m["cursors"],key,1)
        while cursor<=length(n["points"])
            ps=landmark_patches(obs,n["points"][cursor]["color"])
            if length(ps)==1 && ps[1]["near"]
                cursor+=1
            else
                break
            end
        end
        m["cursors"][key]=cursor
        cursor>length(n["points"]) && continue
        color=n["points"][cursor]["color"];ps=landmark_patches(obs,color)
        length(ps)==1 || continue # Absent/ambiguous is never a remembered direction.
        push!(targets,D("name"=>"route:"*key,"color"=>color,"angle"=>ps[1]["angle"],
            "priority"=>2.5+(1+.25*n["support"])/(1+n["H"]),"route"=>key))
    end
    out=Any[]
    for t in targets
        rows=[r for r in move["energy"]["rows"] if r["cost"]!==nothing]
        isempty(rows) && continue
        sort!(rows,by=r->(abs(ANGLES[parse(Int,r["ref"])+1]-t["angle"]),r["cost"],r["ref"]))
        index=parse(Int,first(rows)["ref"])
        push!(out,D("method"=>t["name"],"action"=>"walk","direction"=>index,"priority"=>t["priority"],
            "question"=>"landmark_progress","landmark_color"=>t["color"],"route"=>t["route"],"observation_source"=>source))
    end
    out
end
