# An observed place episode: members and links are snapshots of actual MB evidence.
# No world coordinates or supplied entrance map enter this memory.
mb_place_state()=D("id"=>"camp","method"=>"mb_place:camp","members"=>D(),"links"=>D(),
    "sequence"=>String[],"complete"=>false,"initial_reward"=>0.,"reward_count"=>0,
    "rest_ticks"=>0,"last_rest_us"=>nothing,"signature"=>nothing,"active"=>false,
    "estimate"=>home_distance_state(),"recalls"=>0,"offers"=>0,"selected"=>0,
    "memory_selected"=>0,"visible"=>false,"records"=>Any[])
function mb_place_collect!(p,map,now)
    p["complete"] && return
    f=map["current"];f===nothing && return
    if length(p["members"])<512 || haskey(p["members"],f.key)
        p["members"][f.key]=D("signature"=>f.signature,"anchor"=>f.anchor)
        (isempty(p["sequence"]) || last(p["sequence"])!=f.key) && length(p["sequence"])<1024 && push!(p["sequence"],f.key)
    end
    for (k,e) in map["edges"]
        e["seen"]==now && haskey(p["members"],e["from"]) && haskey(p["members"],e["to"]) || continue
        length(p["links"])<512 && (p["links"][k]=deepcopy(e))
    end
end
function mb_place_finish!(p,loop,signature,now;reward=20.)
    p["complete"] && return false
    signature!==nothing && length(p["members"])>=2 && !isempty(p["links"]) || return false
    p["complete"]=true;p["signature"]=signature;p["initial_reward"]=reward;p["reward_count"]+=1
    n=get!(()->MethodNode(0,loop.threshold,0),loop.methods,p["method"])
    n.reward+=reward # Ordinary method reward/failure machinery updates it thereafter.
    push!(p["records"],D("kind"=>"configured_episode_reward","us"=>now,"reward"=>reward,
        "members"=>length(p["members"]),"links"=>length(p["links"])))
    true
end
function mb_place_recall!(p,view,receipt,at_home)
    p["complete"] || return
    estimate=p["estimate"]
    p["active"] && home_distance_profile!(estimate,receipt)
    p["visible"]=view!==nothing && view["signature"]==p["signature"]
    if p["visible"]
        !p["active"] && (p["recalls"]+=1)
        p["active"]=true;observe_home_distance!(estimate,view)
        receipt!==nothing && (estimate["receipt"]=receipt["operation"])
    end
    at_home && (p["active"]=false)
end
function mb_place_candidate!(p,move)
    p["complete"] && p["active"] || return nothing
    e=p["estimate"];angle=wrap_angle(atand(e["right"],e["forward"]))
    c=D("method"=>p["method"],"priority"=>3.,"question"=>"target_observed",
        "mb_place"=>p["id"],"mb_place_memory"=>!p["visible"])
    if e["uncertainty"]>3. || abs(angle)>90
        merge!(c,D("action"=>"scan","scan_angle"=>e["uncertainty"]>3. ? 60. : clamp(angle,-90.,90.)))
    else
        direction=argmin(abs.(ANGLES.-angle))-1
        any(r->parse(Int,r["ref"])==direction && r["cost"]!==nothing,move["energy"]["rows"]) || return nothing
        merge!(c,D("action"=>"walk","direction"=>direction,"steering_angle"=>angle))
    end
    p["offers"]+=1;c
end
