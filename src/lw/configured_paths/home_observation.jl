# Temporary first-day observation schedule, not a learned route or a supplied camp map.
configured_observation_state(position)=D("origin"=>collect(position),"ticks"=>0,"valid_views"=>0,"keys"=>String[],
    "actions"=>D(),"max_displacement"=>0.,"completed"=>false,"map_at_end"=>nothing)
function configured_observation_plan(state,position,yaw,sec,local_us,clock,reserve,strain)
    p=D("configured_observation"=>true,"method"=>"configured_observation")
    if local_us>=clock.quiet_night_us || reserve<=0 || strain>=.8
        return merge(p,D("action"=>"rest"))
    end
    # Four small viewpoints around the initial pose. Coordinates are experiment scaffolding only.
    offsets=((-.6,0.),(0.,.8),(.6,0.),(0.,-.6))
    offset=offsets[mod(div(sec,240),4)+1]
    dx=state["origin"][1]+offset[1]-position[1];dz=state["origin"][2]+offset[2]-position[2]
    d=hypot(dx,dz)
    if mod(sec,240)<16 && d>.1
        angle=wrap_angle(atand(dx,dz)-yaw)
        if abs(angle)>45
            return merge(p,D("action"=>"scan","scan_angle"=>clamp(angle,-90.,90.)))
        end
        direction=argmin(abs.(ANGLES.-angle))-1
        return merge(p,D("action"=>"walk","direction"=>direction,"approach_angle"=>angle,"approach_span"=>min(.25,d)))
    end
    merge(p,D("action"=>"scan","scan_angle"=>30.))
end
function configured_observation_record!(state,map,position,action,now,day_us)
    state["ticks"]+=1
    frame=map["current"]
    if frame!==nothing
        state["valid_views"]+=1
        frame.key in state["keys"] || push!(state["keys"],frame.key)
    end
    state["actions"][action]=get(state["actions"],action,0)+1
    state["max_displacement"]=max(state["max_displacement"],hypot(position[1]-state["origin"][1],position[2]-state["origin"][2]))
    if now+1_000_000==day_us
        state["completed"]=true
        state["map_at_end"]=D("nodes"=>length(map["nodes"]),"edges"=>length(map["edges"]),
            "home_nodes"=>count(n->n["home"],values(map["nodes"])),"chunks"=>map["chunk_formations"])
    end
end
