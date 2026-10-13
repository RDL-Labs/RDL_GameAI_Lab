# Finite unvalidated action-outcome model, adapted from sleep_auto_model.py.
sleep_action_state(owner)=D("owner"=>owner,"records"=>D(),"adopted_us"=>nothing,"applications"=>0,"selection_changes"=>0)
function sleep_context(move,hazard)
    get(move,"food_coverage",nothing)=="complete" && hazard["coverage"]=="complete" || return nothing
    rows=move["energy"]["rows"]
    Any[!isempty(move["visible"]),!isempty(hazard["features"]),
        Any[Any[r["ref"],r["load"],r["status"],r["resistance"]] for r in rows]]
end
function adopt_sleep_actions!(s,review,owner,now)
    check(s["owner"]==owner,"sleep_action_owner")
    staged=copy(s["records"])
    for r in review["records"]
        check(r["actor"]==owner && r["executed_us"]<=review["formation_us"]<now,"sleep_action_source")
        if haskey(staged,r["id"])
            check(staged[r["id"]]==r,"sleep_action_conflict")
        else
            staged[r["id"]]=deepcopy(r)
        end
    end
    check(length(staged)<=192,"sleep_action_capacity")
    s["records"]=staged;s["adopted_us"]=now
end
function project_sleep_actions!(s,candidates,context,owner,now)
    check(s["owner"]==owner,"sleep_action_owner")
    context===nothing && return false
    s["adopted_us"]===nothing && return false
    s["adopted_us"]>=now && return false
    applied=false
    for c in candidates
        c["action"] in ("walk","scan") || continue
        group=[r for r in values(s["records"]) if get(r,"context",nothing)==context &&
            r["action"]==c["action"] && get(r,"direction",nothing)==get(c,"direction",nothing) &&
            r["outcome"] in ("performed","blocked")]
        isempty(group) && continue
        rate=count(r->r["outcome"]=="performed",group)/length(group)
        c["priority"]+=.75*(2*rate-1);applied=true
    end
    applied && (s["applications"]+=1)
    applied
end
