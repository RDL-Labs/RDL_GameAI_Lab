# Outbound experience establishes relatedness, never a reverse route or home success.
function mb_exploration_state!(s)
    get!(s,"exploration_relations") do
        D("scenes"=>D(),"links"=>D(),"pending"=>nothing,"selected"=>0,"created"=>0,
          "observed"=>0,"missing"=>0,"blocked"=>0,"offered"=>0,"used"=>0,"records"=>Any[])
    end
end
mb_exploration_enabled(s)=get(s,"exploration_relations_enabled",false)
function mb_exploration_observe!(s,obs,receipt,now;home=false)
    mb_exploration_enabled(s) || return
    r=mb_exploration_state!(s);frame=s["current"];frame===nothing && return
    scenes=r["scenes"]
    # A measured home observation is the origin. Connected outward movement can
    # carry its relation to later scenes, without asserting the reverse is feasible.
    if home && (haskey(scenes,frame.key) || length(scenes)<MB_MAP_NODE_LIMIT)
        scenes[frame.key]=1.
    elseif receipt!==nothing && receipt["now"]+1_000_000==now && receipt["status"]=="performed" &&
        receipt["action"] in ("walk","run") && receipt["distance"]>0
        source=get(scenes,receipt["from"],0.)
        if source>0 && (haskey(scenes,frame.key) || length(scenes)<MB_MAP_NODE_LIMIT)
            scenes[frame.key]=max(get(scenes,frame.key,0.),source*exp(-receipt["distance"]/60))
        end
    end
    pending=r["pending"];r["pending"]=nothing
    pending===nothing && return
    pending["now"]+1_000_000==now || return
    link=get(r["links"],pending["link"],nothing);link===nothing && return
    if pending["status"]!="performed"
        link["failures"]+=1;r["blocked"]+=1;return
    end
    # Correspondence is uncertain: color plus observed angle/range, not World ID.
    patches=landmark_patches(merge(obs,D("coverage"=>"complete")),pending["label"])
    best=0.;distance=nothing
    expected=max(0.,pending["distance"]-pending["moved"])
    for p in patches
        p["distance"]===nothing && continue
        fit=exp(-abs(wrap_angle(p["angle"]-pending["angle"]))/45-
            abs(p["distance"]-expected)/max(2.,pending["distance"]))
        if fit>best;best=fit;distance=p["distance"];end
    end
    if distance===nothing;r["missing"]+=1;return;end
    r["observed"]+=1
    link["support"]+=best;link["contradiction"]+=1-best
    progress=clamp((pending["distance"]-distance)/max(.1,pending["moved"]),0.,1.)
    # Continuous near-target evidence, not a binary arrival certificate.
    near=exp(-distance/2)*best
    link["approach_evidence"]=max(link["approach_evidence"],progress*best)
    link["arrival_evidence"]=max(link["arrival_evidence"],near)
    link["target_scene"]=frame.key
end
function mb_exploration_record!(s,p,status,now;turn=0.,distance=0.)
    mb_exploration_enabled(s) || return
    r=mb_exploration_state!(s)
    haskey(p,"mb_outbound_home") && (r["used"]+=1)
    (get(p,"purpose_family",nothing)=="food" && get(p,"cue_kind",nothing)=="shape" &&
      p["action"]=="walk" && get(p,"cue_distance",nothing)!==nothing && s["current"]!==nothing) || return
    frame=s["current"];strength=get(r["scenes"],frame.key,0.)
    strength>0 || return
    key=frame.key*":"*p["cue_label"]
    if !haskey(r["links"],key)
        length(r["links"])<256 || return
        r["links"][key]=D("source"=>frame.key,"label"=>p["cue_label"],"origin_home_strength"=>strength,
            "predicted_strength"=>.5strength,"support"=>0.,"contradiction"=>0.,"failures"=>0,
            "approach_evidence"=>0.,"arrival_evidence"=>0.,"target_scene"=>nothing,"selected"=>0)
        r["created"]+=1
    end
    link=r["links"][key];link["selected"]+=1;r["selected"]+=1
    r["pending"]=D("link"=>key,"label"=>p["cue_label"],"distance"=>p["cue_distance"],
        "angle"=>wrap_angle(p["cue_angle"]-turn),"moved"=>distance,"status"=>status,"now"=>now)
    push!(r["records"],D("us"=>now,"link"=>key,"predicted_strength"=>link["predicted_strength"],"status"=>status))
    length(r["records"])>64 && popfirst!(r["records"])
end
function mb_exploration_project!(s,candidates,goal,H,now)
    mb_exploration_enabled(s) && goal=="home" || return candidates
    r=mb_exploration_state!(s);isempty(r["links"]) && return candidates
    s["current_us"]==now || return candidates
    targets=unique([l["source"] for l in values(r["links"])])
    matches=mb_correspondences(s,targets,now;scope="outbound_home",H=H,retrieval_strength=r["scenes"])
    for p in candidates
        (get(p,"cue_kind",nothing)=="shape" && p["action"]=="walk") || continue
        best=0.
        for m in matches
            l=get(r["links"],m["key"]*":"*p["cue_label"],nothing);l===nothing && continue
            support=(1+l["support"])/(2+l["support"]+l["contradiction"]+l["failures"])
            # Predicted relation exists immediately; experience strengthens it.
            value=l["predicted_strength"]*(1+max(l["approach_evidence"],l["arrival_evidence"]))
            best=max(best,value*support*2m["weight"])
        end
        best>0 || continue
        p["priority"]+=log1p(best);p["mb_outbound_home"]=best;r["offered"]+=1
    end
    candidates
end
