# Own unmet-goal conjunctions; unvalidated local materials, not canonical T1.
bundle_state(actor)=D("actor"=>actor,"active"=>Any[],"dormant"=>Any[],"history"=>Any[],"used"=>Set{String}(),"comparison"=>0,"sequence"=>0,"usage"=>D(),"cycles"=>Int[],"reviews"=>Any[],"woken"=>0,"changes"=>0,"matched"=>0)
bundle_context(inventory,body,move,hazard)=Any[food_band(inventory),move["food_coverage"],!isempty(move["visible"]),hazard["coverage"],!isempty(hazard["features"]),body.reserve<=80,body.strain>=.8]
function remember_bundle!(s,record)
    record["actor"]==s["actor"] || error("bundle_owner")
    push!(s["history"],deepcopy(record));length(s["history"])>8 && popfirst!(s["history"])
end
function form_bundle!(s,h,now)
    h["actor"]==s["actor"] || error("bundle_hunger_owner")
    h["comparisons"]==s["comparison"] && return
    s["comparison"]=h["comparisons"]
    h["H"]>=h["threshold"] || return
    if length(s["active"])>=32 || length(s["active"])+length(s["dormant"])>=256
        s["formation_status"]="capacity_reached";return
    end
    sources=[deepcopy(r) for r in s["history"] if !(r["operation"] in s["used"]) && 0<now-r["capture_us"]<=10_000_000 && r["executed_us"]<now && !(r["outcome"] in ("stale","expired"))]
    isempty(sources) && return
    s["sequence"]+=1;ref="conjunction:$(s["actor"]):$(s["sequence"])"
    push!(s["active"],D("model_ref"=>ref,"formed_us"=>now,"H"=>h["H"],"comparison"=>h["comparisons"],"sources"=>sources))
    union!(s["used"],(r["operation"] for r in sources));s["usage"][ref]=D("uses"=>0,"opportunities"=>0,"idle"=>0)
    s["formation_status"]="formed_unvalidated"
end
function wake_bundles!(s,context,phase)
    phase in ("exploration","return") || return
    keep=Any[]
    for b in s["dormant"]
        if length(s["active"])<32 && any(r->r["context"]==context && r["phase"]==phase,b["sources"])
            push!(s["active"],b);s["usage"][b["model_ref"]]["idle"]=0;s["woken"]+=1
        else
            push!(keep,b)
        end
    end
    s["dormant"]=keep
end
function project_bundles!(s,candidates,loop,context,phase,now)
    phase in ("exploration","return") || return nothing
    matches=[(b["model_ref"],r) for b in s["active"] for r in b["sources"] if b["formed_us"]<now && r["context"]==context && r["phase"]==phase]
    isempty(matches) && return nothing
    baseline=method_choice(loop,candidates)["method"];refs=Set{String}();contributors=Set{String}()
    for (ref,_) in matches;push!(refs,ref);end
    for c in candidates
        get(c,"record_trial",true) || continue
        evidence=[ref for (ref,r) in matches if r["action"]==c["action"]]
        isempty(evidence) && continue
        c["priority"]-=.75*length(evidence)/length(matches);union!(contributors,evidence)
    end
    selected=method_choice(loop,candidates)["method"];s["matched"]+=1
    D("changed"=>baseline!=selected,"selected"=>selected,"refs"=>sort(collect(refs)),"contributors"=>sort(collect(contributors)))
end
function use_bundles!(s,trace,method,status)
    trace===nothing && return
    used=trace["changed"] && method==trace["selected"] && !(status in ("stale","expired","unexecuted"))
    used && (s["changes"]+=1)
    for ref in trace["refs"]
        s["usage"][ref]["opportunities"]+=1
        used && ref in trace["contributors"] && (s["usage"][ref]["uses"]+=1)
    end
end
function sleep_bundles!(s,day,formation)
    day in s["cycles"] && return
    active=Any[];decisions=Any[]
    for b in s["active"]
        u=s["usage"][b["model_ref"]]
        if b["formed_us"]>=formation;push!(active,b);continue;end
        u["idle"]=u["uses"]>0 ? 0 : u["idle"]+1
        dormant=u["uses"]==0 && u["idle"]>=(u["opportunities"]>0 ? 2 : 3)
        push!(decisions,D("model_ref"=>b["model_ref"],"uses"=>u["uses"],"opportunities"=>u["opportunities"],"idle"=>u["idle"],"dormant"=>dormant))
        push!(dormant ? s["dormant"] : active,b);u["uses"]=0;u["opportunities"]=0
    end
    s["active"]=active;push!(s["cycles"],day);push!(s["reviews"],D("day"=>day,"decisions"=>decisions))
end
bundle_snapshot(s)=D(k=>(k=="used" ? sort(collect(v)) : deepcopy(v)) for (k,v) in s)
