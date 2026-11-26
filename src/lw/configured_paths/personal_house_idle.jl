# 暫定固定: scene.personal_house_idle=false (既定)。用事のない拠点内の
# 休息を自宅へ移し、到着後だけ高レベル認知を省略する。所有する家の座標は
# 初期知識のショートカット。身体・呼びかけ・未決処理は継続監視する。
# 将来は帰宅MBと注意配分の学習へ置換。mb_map.configured_house に記録。
const HOUSE_IDLE_RULES=(max_demand=.35,wake_increase=.10,sleep_wake_demand=.80,
    records=64,arrival_fraction=.8)
configured_house_state()=D("mode"=>"active","day"=>-1,"demand"=>0.,
    "idle_ticks"=>0,"sleep_ticks"=>0,"travel_ticks"=>0,"entries"=>0,"wakeups"=>D(),"records"=>Any[])
configured_house_state!(map)=get!(configured_house_state,map,"configured_house")
function configured_house_transition!(state,mode,reason,now)
    state["mode"]==mode && return
    push!(state["records"],D("us"=>now,"from"=>state["mode"],"to"=>mode,"reason"=>reason))
    length(state["records"])>HOUSE_IDLE_RULES.records && popfirst!(state["records"])
    state["mode"]=mode
end
function configured_house_wake!(state,now,day_us,demand;inside,notice=false,busy=false,danger=false,sleeping=false)
    reason=notice ? "communication" : busy ? "pending_work" : danger ? "danger" : !inside && state["mode"]=="idle" ? "left_house" :
        sleeping ? (demand>=HOUSE_IDLE_RULES.sleep_wake_demand ? "body" : nothing) :
        state["day"]!=div(now,day_us) ? "new_day" :
        demand>min(HOUSE_IDLE_RULES.max_demand,state["demand"]+HOUSE_IDLE_RULES.wake_increase) ? "body" : nothing
    if reason!==nothing
        reason=="new_day" && (state["day"]=div(now,day_us))
        if state["mode"]!="active" || sleeping
            state["wakeups"][reason]=get(state["wakeups"],reason,0)+1
            configured_house_transition!(state,"active",reason,now)
        end
        return true
    end
    false
end
function configured_house_obligation(social,incidental,relation,items,actor,now)
    get(social,"pending",nothing)!==nothing && return true
    if incidental!==nothing
        get(get(incidental,"social",D()),"pending",nothing)!==nothing && return true
        get(get(incidental,"configured_work_wait",D()),"target",nothing)!==nothing && return true
    end
    relation!==nothing && get(relation,"aid_delivery",nothing)!==nothing && return true
    items!==nothing && any(o->now<o["expires_us"] && (o["target"]==actor || o["proposer"]==actor),values(items["offers"]))
end
function configured_house_plan!(state,house,position,yaw,now,day_us,rows;
        eligible=false,blocked=false,demand=0.)
    blocked && return nothing
    (eligible || state["mode"] in ("travelling","idle")) || return nothing
    demand<=HOUSE_IDLE_RULES.max_demand || return nothing
    if state["mode"]=="active"
        state["day"]=div(now,day_us);state["demand"]=demand
        configured_house_transition!(state,"travelling","chores_finished",now)
    end
    dx,dz=house.x-position[1],house.z-position[2];distance=hypot(dx,dz)
    # Subtraction/addition at world coordinates can leave the final position a
    # few ULP outside the requested stopping radius. This is numerical precision,
    # not cognitive tolerance: do not charge another walk for an unrepresentable step.
    arrival_radius=house.radius*HOUSE_IDLE_RULES.arrival_fraction
    arrival_roundoff=8eps(max(1.,abs(house.x),abs(house.z),abs(position[1]),abs(position[2])))
    if distance<=arrival_radius+arrival_roundoff
        if state["mode"]!="idle"
            state["entries"]+=1
            configured_house_transition!(state,"idle","arrived",now)
        end
        return D("action"=>"rest","method"=>"personal_house_rest","configured_rule"=>"personal_house_idle","configured_observation"=>true)
    end
    sn,cs=sincosd(yaw);forward=dx*sn+dz*cs;right=dx*cs-dz*sn
    viable=filter(r->r["cost"]!==nothing && r["clear"],rows)
    isempty(viable) && return nothing
    row=viable[argmin([hypot(forward-cosd(ANGLES[parse(Int,r["ref"])+1]),right-sind(ANGLES[parse(Int,r["ref"])+1])) for r in viable])]
    state["travel_ticks"]+=1
    D("action"=>"walk","direction"=>parse(Int,row["ref"]),"method"=>"personal_house_return",
        "configured_rule"=>"personal_house_idle","configured_observation"=>true,
        "house_target"=>D("forward"=>forward,"right"=>right,"distance"=>distance))
end
function configured_house_idle_tick!(state,w,actor,counts,events,previous,phase,now)
    w.bodies[actor],_,_,_=step(w.bodies[actor],"rest",w.inventory[actor])
    counts[actor]["rest"]=get(counts[actor],"rest",0)+1
    state["idle_ticks"]+=1
    sig=(phase,"personal_house_idle")
    if get(previous,actor,nothing)!=sig
        push!(events,D("us"=>now,"actor"=>actor,"phase"=>phase,"purpose_family"=>nothing,
            "action"=>"rest","status"=>"performed","method"=>"personal_house_idle","selection_mode"=>"configured",
            "configured_rule"=>"personal_house_idle","target"=>nothing,"direction"=>nothing,"route"=>nothing,"landmark_color"=>nothing))
        previous[actor]=sig
    end
end
