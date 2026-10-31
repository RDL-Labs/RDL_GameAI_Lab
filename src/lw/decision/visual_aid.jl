# Initial food-help hypothesis from ambiguous public appearance. Selection and
# transfer prediction use the shared loop and owner-local relation MBs.
function visual_aid_state(actor;seed=0)
    D("loop"=>BasicLoop(actor*":visual-aid";probabilistic=true,seed),
      "pending"=>nothing,"next_us"=>0,"decisions"=>0,"candidates"=>0,
      "selected"=>0,"transferred"=>0,"abandoned"=>0,"records"=>Any[])
end
function visual_aid_close!(s,plan,status)
    success=status=="transferred"
    changed=resolve_prediction!(s["loop"],plan["visual_aid_source"],plan["expected"],
        status=="abandoned" ? nothing : Float64(success);fulfilled=success,tolerance=.05)
    changed || return false
    s["transferred"]+=Int(success);s["abandoned"]+=Int(status=="abandoned")
    push!(s["records"],D("source"=>plan["visual_aid_source"],"target"=>plan["target"],
        "status"=>status,"expression"=>plan["expression"],"context"=>plan["context"],
        "expected"=>plan["expected"],"question"=>"food_delivered"))
    length(s["records"])>32 && popfirst!(s["records"])
    s["pending"]=nothing
    true
end
function visual_aid_plan!(relation,view,body,gut,stock,kinds,now;at_home=false,contacts=Any[])
    (relation===nothing || view===nothing) && return nothing
    check(view["actor"]==relation["actor"] && view["capture_us"]==now,"visual_aid_observation")
    s=get!(()->visual_aid_state(relation["actor"]),relation,"visual_aid")
    s["pending"]===nothing && now<s["next_us"] && return nothing
    own=stock===nothing || !at_home ? zeros(Int,4) : copy(stock)
    for k in kinds;own[k]+=1;end
    security=food_security(relation);required=max(1.,(80.0-body.reserve)/RDLBody.MEAL_ENERGY,security===nothing ? 0. : security["required"])
    spare=sum(own)+(gut===nothing ? 0. : gut.gut)-required
    able=body.reserve>=80 && body.strain<.8 && body.damage<1 && spare>=1
    held_food(other)=any(p->p["ref"]==other && p["holding_food"],contacts)
    peers=[p for p in view["peers"] if p["contact"] && p["expression"]!==nothing &&
        p["expression"].distress>0 && !held_food(p["ref"])]
    if s["pending"]!==nothing
        p=s["pending"]
        if !able || now>p["deadline_us"] || !any(x->x["ref"]==p["target"],peers)
            visual_aid_close!(s,p,"abandoned");return nothing
        end
        isempty(kinds) && return nothing
        if !RDLBody.food_edible(first(kinds))
            visual_aid_close!(s,p,"abandoned");return nothing
        end
        return merge(p,D("action"=>"give"))
    end
    now<s["next_us"] && return nothing
    s["next_us"]=now+64_000_000
    able && !isempty(peers) || return nothing
    action=if !isempty(kinds) && RDLBody.food_edible(first(kinds))
        "give"
    elseif isempty(kinds) && at_home && stock!==nothing && any(k->stock[k]>0 && RDLBody.food_edible(k),eachindex(stock))
        "retrieve"
    else
        return nothing
    end
    candidates=Any[];source="visual-aid:$now:$(relation["actor"])"
    for peer in peers
        face=peer["expression"];other=peer["ref"]
        context=D("need"=>clamp((80-body.reserve)/80,0.,1.),"distress"=>face.distress,"fear"=>face.fear)
        trace=social_relation_bias(relation,other,"give";situation=context,H=s["loop"].H)
        prediction=social_mb_predict(relation,other,"aid_given";situation=context,H=s["loop"].H)
        # Food may help this appearance; fear/fatigue can make that guess wrong.
        motivation=face.distress*(1-.5face.fear)
        push!(candidates,D("method"=>"visual_give:$other","action"=>action,"target"=>other,
            "priority"=>2motivation+trace["weight"]+.5log(2prediction["probability"])-1/(1+spare)-1,
            "question"=>"food_delivered","expected"=>prediction["probability"],
            "expression"=>face,"context"=>context,"trace"=>trace,"visual_aid"=>true,
            "visual_aid_source"=>source,"deadline_us"=>now+64_000_000))
    end
    s["decisions"]+=1;s["candidates"]+=length(candidates)
    prior=-log(length(candidates))
    for p in candidates;p["observation_log_prior"]=prior;end
    push!(candidates,D("method"=>"continue","action"=>"continue","priority"=>0.,"question"=>"food_delivered"))
    p=choose_method!(s["loop"],candidates,source)
    if p["action"]=="continue"
        resolve_method!(s["loop"],source,nothing,nothing;creditable=false,goal_H_increment=0.)
        return nothing
    end
    s["selected"]+=1;s["pending"]=p;s["next_us"]=now+300_000_000
    social_relation_use!(relation,p["target"],"give",source,now,p["trace"];action)
    p
end
function visual_aid_executed!(relation,plan,status)
    get(plan,"visual_aid",false) || return false
    s=relation["visual_aid"]
    plan["action"]=="retrieve" && status!="unavailable" && return false
    visual_aid_close!(s,plan,status)
end
function visual_aid_snapshot(s)
    out=deepcopy(s);out["loop"]=loop_snapshot(s["loop"]);out
end
