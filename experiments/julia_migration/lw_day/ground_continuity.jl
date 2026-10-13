# Native same-process port of runtime/ground_continuity.py.
ground_points(v,g)=[(v["cells"][i+1]["distance"]*sind(v["cells"][i+1]["angle"]),v["cells"][i+1]["distance"]*cosd(v["cells"][i+1]["angle"])) for i in g["sample_indices"]]
point_near(p,q,r)=hypot(p[1]-q[1],p[2]-q[2])<=r
function ground_memory(actor)
 D("actor"=>actor,"sequence"=>0,"models"=>Any[],"source"=>nothing,"capture_us"=>-1,
   "events"=>Any[],"selections"=>0,"linked_updates"=>0)
end
function update_ground!(s,v,result)
 source=v["source"];source["actor"]==s["actor"] || error("ground_model_binding")
 source["observation"]==s["source"] && return s
 linked=result!==nothing && result["actor"]==s["actor"] && result["source"]==s["source"] &&
    result["before_us"]==s["capture_us"] && result["after_us"]==source["capture_us"]
 empty!(s["events"])
 if s["source"]!==nothing && !linked
    empty!(s["models"]);push!(s["events"],"body_correspondence_unavailable")
 end
 if linked
    s["linked_updates"]+=1;sn,cs=sincosd(result["yaw"])
    for m in s["models"]
        push!(m["pending_transforms"],copy(result));length(m["pending_transforms"])>32 && popfirst!(m["pending_transforms"])
        m["points"]=[(cs*(x-result["right"])-sn*(z-result["forward"]),sn*(x-result["right"])+cs*(z-result["forward"])) for (x,z) in m["points"]]
        m["status"]="not_currently_supported";m["current_points"]=Any[]
    end
 end
 filter!(m->source["capture_us"]-m["last_seen_us"]<=8_000_000,s["models"])
 patterns=ground_patterns(v)
 groups=[g for g in patterns["groups"] if g["appearance"] in ("trampled_grass","bare_ground") && g["shape"]=="sampled_band_candidate"]
 observed=[ground_points(v,g) for g in groups]
 choices=[[i for (i,m) in enumerate(s["models"]) if count(p->any(q->point_near(p,q,.6),m["points"]),ps)>=2] for ps in observed]
 used=Set{String}()
 for (g,ps,options) in zip(groups,observed,choices)
    unique_match=length(options)==1 && count(cs->first(options) in cs,choices)==1
    if unique_match
        m=s["models"][first(options)]
        m["extended"]=any(p->all(q->!point_near(p,q,.25),m["points"]),ps)
        push!(m["links"],D("from"=>last(m["sources"]),"to"=>source["observation"],"transforms"=>copy(m["pending_transforms"])))
        length(m["links"])>16 && popfirst!(m["links"]);empty!(m["pending_transforms"])
        m["points"]=vcat(ps,[q for q in m["points"] if all(p->!point_near(p,q,.25),ps)])[1:min(32,length(ps)+count(q->all(p->!point_near(p,q,.25),ps),m["points"]))]
    else
        if !isempty(options);push!(s["events"],"ambiguous_correspondence");continue;end
        if length(s["models"])>=8;push!(s["events"],"active_model_capacity");continue;end
        s["sequence"]+=1
        m=D("model_ref"=>"ground_$(s["sequence"])","points"=>ps,"sources"=>Any[],"links"=>Any[],"pending_transforms"=>Any[],"extended"=>false)
        push!(s["models"],m)
    end
    push!(used,m["model_ref"]);m["status"]="observed";m["current_points"]=ps
    m["last_seen_us"]=source["capture_us"];m["pattern_ref"]=g["pattern_ref"]
    push!(m["sources"],source["observation"]);length(m["sources"])>16 && popfirst!(m["sources"])
 end
 grass=[ground_points(v,g) for g in patterns["groups"] if g["appearance"]=="grass"]
 for m in s["models"]
    m["model_ref"] in used && continue
    count(p->any(ps->any(q->point_near(p,q,.6),ps),grass),m["points"])>=2 && (m["status"]="observed_context_changed")
 end
 s["source"]=source["observation"];s["capture_us"]=source["capture_us"];s
end
function ground_proposals(s,move)
 out=Any[]
 for m in s["models"]
    m["status"]=="observed" || continue
    x,z=last(sort(m["current_points"],by=q->(hypot(q...),q[2],q[1])))
    angle=rad2deg(atan(x,z))
    safe=[i for i in 1:5 if move["energy"]["rows"][i]["cost"]!==nothing && abs(ANGLES[i]-angle)<=22.5]
    isempty(safe) && continue
    i=first(sort(safe,by=i->abs(ANGLES[i]-angle)))
    push!(out,D("method"=>m["model_ref"],"action"=>"walk","direction"=>i-1,"priority"=>2.25,"question"=>"ground_extension"))
 end
 out
end

# Lack of current support is not evidence that following the band failed.
# Mirrors continuous_selection.review ground_extension's three-valued result.
function ground_extension_result(state,method,status,moved)
    state===nothing && return nothing
    index=findfirst(m->m["model_ref"]==method,state["models"])
    index===nothing && return nothing
    model=state["models"][index]
    model["status"]=="observed" || return nothing
    status=="performed" && moved && model["extended"]
end
