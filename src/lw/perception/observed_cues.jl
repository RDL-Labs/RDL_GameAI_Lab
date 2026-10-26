# Finite visual cue adapter. Keys describe hypotheses, NOT World object identities.
cue_stats()=D("observations"=>0,"generation_levels"=>[0,0,0],"generated"=>0,"offered"=>[0,0,0],"selected"=>[0,0,0],
    "kinds"=>D(),"tower_observations"=>0,"capacity_dropped"=>0,"records"=>Any[])

function observed_cues(obs,sky,structures,move,hazard,source;level=2)
    0<=level<=2 || error("cue_level")
    cues=Any[]
    function add(kind,label,angle,tier,distance=nothing;approach=true)
        tier<=level && isfinite(angle) || return
        push!(cues,D("kind"=>kind,"label"=>label,"angle"=>Float64(angle),"tier"=>tier,
            "distance"=>distance,"approach"=>approach,"source"=>source,
            "key"=>"cue:$kind:$label:$(round(Int,angle/15))"))
    end
    for (kind,view) in (("shape",obs),("sky",sky))
        view===nothing && continue
        view["source"]==source || error("cue_source")
        for color in sort(unique(f["color"] for f in view["features"]))
            # Group only current evidence. Do not require a unique patch to retain it.
            partial=get(view,"coverage","partial")!="complete"
            patches=landmark_patches(merge(view,D("coverage"=>"complete")),color)
            for p in patches
                tier=partial || length(patches)!=1 || p["width"]>45 ? 1 : 0
                add(kind,color,p["angle"],tier,p["distance"];approach=!p["near"] || (p["distance"]!==nothing && p["distance"]>2))
            end
        end
    end
    if obs!==nothing
        for l in get(obs,"lights",Any[])
            add("light",l["brightness"],sum(l["azimuth"])/2,l["brightness"]=="faint" ? 1 : 0;
                approach=l["brightness"]!="bright")
        end
    end
    if level>=1 && structures!==nothing
        structures["source"]["observation"]==source || error("cue_structure_source")
        for g in structures["groups"]
            ps=g["points"];isempty(ps) && continue
            x=sum(p[1] for p in ps)/length(ps);z=sum(p[2] for p in ps)/length(ps)
            hypot(x,z)>1e-8 || continue
            # Surface regions remain useful for observation, not automatic approach.
            add("surface",g["kind"],rad2deg(atan(x,z)),1,hypot(x,z);approach=false)
        end
    end
    for f in (level>=1 ? move["visible"] : ())
        add("food",get(f,"appearance","observed"),rad2deg(atan(f["right"],f["forward"])),1,f["distance"])
    end
    if level>=2 && hazard!==nothing
        for f in hazard["features"]
            add("moving", "observed",rad2deg(atan(f["right"],f["forward"])),2,f["distance"];approach=false)
        end
    end
    # Relative arrangements are tentative at high H; bounded combinations only.
    if level>=2
    anchors=[c for c in cues if c["kind"] in ("shape","sky","light")][1:min(8,count(c->c["kind"] in ("shape","sky","light"),cues))]
    for i in 1:length(anchors)-1
        a,b=anchors[i],anchors[i+1];separation=abs(a["angle"]-b["angle"])
        15<=separation<=90 || continue
        label="$(a["kind"])-$(a["label"])/$(b["kind"])-$(b["label"])/$(round(Int,separation/15))"
        add("arrangement",label,(a["angle"]+b["angle"])/2,2;approach=false)
    end
    end
    # Multiple rays describing the same cue do not multiply its selection chances.
    unique_cues=Any[];seen=Set{String}()
    for c in cues
        c["key"] in seen && continue;push!(seen,c["key"]);push!(unique_cues,c)
    end
    (items=unique_cues[1:min(96,length(unique_cues))],dropped=max(0,length(unique_cues)-96))
end

function cue_candidates!(stats,pool,move,H,threshold)
    level=min(2,floor(Int,H/threshold));stats["observations"]+=1
    stats["generation_levels"][level+1]+=1;stats["generated"]+=length(pool.items)
    stats["capacity_dropped"]+=pool.dropped
    stats["tower_observations"]+=Int(any(c->c["label"]=="ochre",pool.items))
    out=Any[]
    for cue in pool.items
        cue["tier"]<=level || continue
        rows=[r for r in move["energy"]["rows"] if r["cost"]!==nothing && abs(ANGLES[parse(Int,r["ref"])+1]-cue["angle"])<=22.5]
        can_walk=cue["approach"] && !isempty(rows) && (cue["distance"]===nothing || cue["distance"]>2)
        # Uncertain/near/dynamic cues can prompt looking, never unsafe approach.
        p=D("method"=>cue["key"],"action"=>can_walk ? "walk" : "scan",
            "priority"=>2.5-.5cue["tier"],"question"=>"target_observed",
            "cue_kind"=>cue["kind"],"cue_tier"=>cue["tier"],"cue_source"=>cue["source"],
            "cue_uncertain"=>cue["tier"]>0)
        if can_walk
            sort!(rows,by=r->(abs(ANGLES[parse(Int,r["ref"])+1]-cue["angle"]),r["ref"]))
            p["direction"]=parse(Int,first(rows)["ref"]);p["steering_angle"]=cue["angle"]
        else
            p["scan_angle"]=abs(cue["angle"])<15 ? 15. : clamp(cue["angle"],-45.,45.)
        end
        stats["offered"][cue["tier"]+1]+=1;push!(out,p)
    end
    out
end

function record_cue_selection!(stats,plan,H)
    haskey(plan,"cue_kind") || return
    stats["selected"][plan["cue_tier"]+1]+=1
    kind=plan["cue_kind"];stats["kinds"][kind]=get(stats["kinds"],kind,0)+1
    push!(stats["records"],D("method"=>plan["method"],"source"=>plan["cue_source"],"H"=>H,
        "tier"=>plan["cue_tier"],"uncertain"=>plan["cue_uncertain"],"action"=>plan["action"]))
    length(stats["records"])>32 && popfirst!(stats["records"])
end
