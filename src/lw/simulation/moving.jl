include(joinpath(@__DIR__, "social.jl"))
include(joinpath(@__DIR__, "../learning/aid.jl"))

include(joinpath(@__DIR__, "../world/moving_world.jl"))

include(joinpath(@__DIR__, "../perception/movement.jl"))
include(joinpath(@__DIR__, "../decision/movement.jl"))

function movement_observation(w,actor,yaw,food,stock;policy=EnergyMovementPolicy(),kwargs...)
    evaluate_movement(policy,perceive_movement(w,actor,yaw,food,stock;kwargs...))
end

function moving_scenario(spec;incremental=false,recording=:detailed)
    check(recording in (:detailed,:compact),"a2_recording_mode")
    w=moving_world(spec);yaw=Dict(a=>0. for a in IDS);stock=Int[f.stock for f in spec.food]
    states=D(a=>social_initial() for a in IDS);pressures=D(a=>pressure_update(nothing,D(),a,3) for a in IDS)
    live=Dict(a=>live_aid(a) for a in IDS)
    results=D(a=>D() for a in IDS);answered=Dict(a=>Set{String}() for a in IDS)
    rows=Any[];nights=Any[];effects=D();requests=Dict(a=>0 for a in IDS)
    transitions=Any[];previous=Dict{String,Any}();counts=Dict(a=>Dict{String,Int}() for a in IDS)
    function actor_state(actor)
        p=w.positions[actor]
        D("position"=>D("x"=>p[1],"z"=>p[2],"yaw"=>yaw[actor]),
          "body"=>bodydict(w.bodies[actor]),"inventory"=>w.inventory[actor])
    end
    function integrate(actor,now,obs)
        p=D("agent_id"=>actor,"capture_us"=>now,"observation_id"=>"ob:$now:$actor","social"=>obs)
        count_before=length(states[actor]["records"])
        states[actor]=ingest(states[actor],p,results[actor])
        if incremental
            records=states[actor]["records"]
            # ingest appends at most one accepted result; no full-history diff/hash.
            pressures[actor]=pressure_poll!(live[actor],records,count_before)
        else
            pressures[actor]=pressure_update(pressures[actor],states[actor]["records"],actor,3)
        end
    end
    function execute(actor,op,plan)
        if haskey(effects,op)
            old,r=effects[op];check(old==plan,"a2_operation_conflict");return deepcopy(r)
        end
        action=plan["action"];origin=w.positions[actor]
        if action in ("request","give","refuse","warn","withdraw","eat","wait")
            r=communicate!(w,actor,op,action,get(plan,"target",nothing),get(plan,"reply_to",nothing))
        elseif action=="pickup"
            j=plan["food_ref"]+1;f=spec.food[j]
            legal=stock[j]>0 && hypot(f.x-origin[1],f.z-origin[2])<=1.25 && !any(o->segment_hit(origin,(Float64(f.x),Float64(f.z)),o,0.),w.obstacles)
            if legal
                stock[j]-=1;w.inventory[actor]+=1
            end
            r=D("status"=>legal ? "picked_up" : "not_found")
        elseif action=="walk"
            yaw[actor]=mod(yaw[actor]+ANGLES[plan["direction"]+1]+180,360)-180
            dx,dz=sincos(deg2rad(yaw[actor]));b=w.bodies[actor]
            endpoint=(origin[1]+dx*.5*(1-b.damage),origin[2]+dz*.5*(1-b.damage))
            clear=!any(o->segment_hit(origin,endpoint,o,.2),w.obstacles)
            w.bodies[actor],status,distance,_=step(b,"walk",w.inventory[actor],1.5,clear)
            w.positions[actor]=(origin[1]+dx*distance,origin[2]+dz*distance)
            r=D("status"=>status,"distance"=>distance)
        else
            w.bodies[actor],status,_,_=step(w.bodies[actor],"rest",w.inventory[actor]);r=D("status"=>status)
        end
        effects[op]=(deepcopy(plan),deepcopy(r));r
    end
    for day in 0:2
        b=w.bodies["npc_a"];w.bodies["npc_a"]=Body(b.burst,b.strain,max(0.,b.reserve-20),b.damage)
        for tick in 0:spec.ticks-1
            now=day*DAY+tick*1_000_000;w.seconds=now/1e6
            observations=D(a=>observe(w,a) for a in IDS)
            moves=D(a=>movement_observation(w,a,yaw,spec.food,stock) for a in IDS);plans=D();selections=D()
            for actor in IDS
                obs=observations[actor];integrate(actor,now,obs);s=states[actor]
                messages=[m for m in reverse(obs["messages"]) if !(m["id"] in answered[actor]) && m["kind"] in ("request","warn","reach")]
                plan=nothing
                if !isempty(messages)
                    m=messages[1];act,t,r=response(merge(copy(obs),D("messages"=>[m])),actor!="npc_b")
                    plan=D("action"=>act,"target"=>t,"reply_to"=>r);push!(answered[actor],m["id"])
                elseif obs["inventory"]>0 && obs["body"]["reserve"]<80
                    plan=D("action"=>"eat")
                elseif s["pending"]!==nothing
                    plan=D("action"=>"rest")
                elseif obs["body"]["reserve"]<80
                    targets=[o["ref"] for o in obs["others"] if o["holding_food"]]
                    target,selections[actor]=select_target(targets,s["model"],pressures[actor])
                    if target!==nothing
                        plan=D("action"=>"request","target"=>target);op="op:$now:$actor"
                        s["pending"]=D("message_id"=>actor*":"*op,"target"=>target,"deadline"=>now+5_000_000,
                            "request_observation_id"=>"ob:$now:$actor","operation_id"=>op)
                        requests[actor]+=1
                    end
                end
                if plan===nothing
                    visible=moves[actor]["visible"];chosen=moves[actor]["energy"]["selected"]
                    if !isempty(visible) && visible[1]["distance"]<=1.25
                        plan=D("action"=>"pickup","food_ref"=>visible[1]["ref"])
                    elseif obs["inventory"]>0 || chosen===nothing
                        plan=D("action"=>"rest")
                    else
                        plan=D("action"=>"walk","direction"=>parse(Int,chosen))
                    end
                end
                plans[actor]=plan
            end
            w.seconds=(now+1_000_000)/1e6
            for actor in IDS
                op="op:$now:$actor";r=execute(actor,op,plans[actor])
                saved=deepcopy((w.inventory,w.bodies,w.positions,yaw,stock,w.consumed))
                @assert execute(actor,op,plans[actor])==r
                @assert saved==(w.inventory,w.bodies,w.positions,yaw,stock,w.consumed)
                results[actor][op]=r;p=w.positions[actor]
                if recording==:compact
                    action=plans[actor]["action"]
                    counts[actor][action]=get(counts[actor],action,0)+1
                    signature=(day,action,get(plans[actor],"target",nothing),get(plans[actor],"direction",nothing),
                        get(plans[actor],"food_ref",nothing),get(r,"status",nothing))
                    if get(previous,actor,nothing)!=signature
                        push!(transitions,D("day"=>day,"tick"=>tick,"actor"=>actor,
                            "plan"=>copy(plans[actor]),"status"=>get(r,"status",nothing)))
                        previous[actor]=signature
                    end
                    if action=="request"
                        @assert plans[actor]["target"] in [o["ref"] for o in observations[actor]["others"] if o["holding_food"]]
                    end
                    continue
                end
                push!(rows,D("day"=>day,"tick"=>tick,"actor"=>actor,"observation"=>observations[actor],"movement"=>moves[actor],
                    "plan"=>plans[actor],"selection"=>get(selections,actor,nothing),"result"=>r,
                    "position"=>D("x"=>p[1],"z"=>p[2],"yaw"=>yaw[actor]),"body"=>bodydict(w.bodies[actor]),
                    "inventory"=>copy(w.inventory),"stock"=>copy(stock),"social"=>deepcopy(states[actor]),
                    "pressure"=>incremental ? pressure_snapshot(live[actor]) : deepcopy(pressures[actor])))
            end
            @assert sum(stock)+sum(values(w.inventory))+w.consumed==60
        end
        start=day*DAY+14_400_000_000;w.seconds=start/1e6;night=D()
        for actor in IDS
            integrate(actor,start,observe(w,actor));learning=sleeper(day)
            for sec in 0:2879
                phase=spec.interrupt && sec==100 ? "safety" : "night"
                w.bodies[actor],_,_,_=step(w.bodies[actor],"rest",w.inventory[actor])
                receipt!(learning,start+sec*1_000_000;phase=phase)
            end
            cycle=learning["sleep"]["cycle"]
            spec.adopt && (states[actor]=consolidate_social(states[actor],merge(copy(cycle),D("formation_us"=>start)),actor))
            night[actor]=merge(D("sleep"=>learning["sleep"],"social"=>deepcopy(states[actor])),actor_state(actor))
        end
        push!(nights,night)
    end
    output=D("rows"=>rows,"nights"=>nights,"request_counts"=>requests,"consumed"=>w.consumed,"stock"=>stock,"inventory"=>w.inventory,
      "final_agents"=>D(a=>actor_state(a) for a in IDS))
    if recording==:compact
        output["transitions"]=transitions;output["action_counts"]=counts
        output["recording"]="compact-v1"
    end
    output
end

function contact_boundaries(spec)
    w=moving_world(spec);w.positions["npc_a"]=(0.,0.);w.positions["npc_b"]=(0.,1.)
    out=D("near"=>contact(w,"npc_a","npc_b"))
    w.positions["npc_b"]=(0.,2.);out["far"]=contact(w,"npc_a","npc_b")
    w.positions["npc_b"]=(0.,1.);w.obstacles=[RDLMigrationProbe.Circle(0.,.5,.1)]
    out["occluded"]=contact(w,"npc_a","npc_b");empty!(w.obstacles)
    communicate!(w,"npc_a","request","request","npc_b");w.seconds=1.
    w.positions["npc_b"]=(0.,2.)
    out["departed_response"]=communicate!(w,"npc_b","response","give","npc_a","npc_a:request")
    out["departed_inventory"]=copy(w.inventory)
    w.positions["npc_b"]=(0.,1.);out["returned_contact"]=contact(w,"npc_a","npc_b")
    out["old_response"]=communicate!(w,"npc_b","response","give","npc_a","npc_a:request")
    out["new_response"]=communicate!(w,"npc_b","response2","give","npc_a","npc_a:request")
    out["final_inventory"]=copy(w.inventory)
    try communicate!(w,"npc_b","response2","refuse","npc_a","npc_a:request") catch e;out["conflict"]=e.msg;end
    out
end
