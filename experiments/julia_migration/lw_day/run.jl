using Test
include(joinpath(@__DIR__,"hazard.jl"))
include(joinpath(@__DIR__,"orientation.jl"))
include(joinpath(@__DIR__,"world_hazards.jl"))
include(joinpath(@__DIR__,"ground.jl"))
include(joinpath(@__DIR__,"ground_wear.jl"))
include(joinpath(@__DIR__,"ground_pattern.jl"))
include(joinpath(@__DIR__,"ground_continuity.jl"))
include(joinpath(@__DIR__,"climbing.jl"))
include(joinpath(@__DIR__,"dropped_cargo.jl"))
include(joinpath(@__DIR__,"return_purpose.jl"))
include(joinpath(@__DIR__,"social_response.jl"))
include(joinpath(@__DIR__,"food_body.jl"))
include(joinpath(@__DIR__,"general_sleep.jl"))
include(joinpath(@__DIR__,"sleep_action_model.jl"))
include(joinpath(@__DIR__,"sleep_maintenance.jl"))
include(joinpath(@__DIR__,"../moving_social/run.jl"))
include(joinpath(@__DIR__,"basic_loop.jl"))
include(joinpath(@__DIR__,"safety_methods.jl"))
include(joinpath(@__DIR__,"movement_inertia.jl"))
include(joinpath(@__DIR__,"landmark_routes.jl"))
include(joinpath(@__DIR__,"relation_field.jl"))
include(joinpath(@__DIR__,"harvest_learning.jl"))
include(joinpath(@__DIR__,"harvest_field.jl"))
include(joinpath(@__DIR__,"harvest_review.jl"))
include(joinpath(@__DIR__,"harvest_relearn.jl"))

# B0 lifecycle scaffold. Current observed relative beacon only; no stored home coordinate in policy.
function home_observation(w,a,yaw,home;visual_obstacles=w.obstacles)
    p=w.positions[a];dx,dz=home[1]-p[1],home[2]-p[2]
    s,c=sincos(deg2rad(yaw[a]));f,r=dx*s+dz*c,dx*c-dz*s
    d=hypot(dx,dz)
    if d<=60 && (f>=0 || d<=1.25) && !any(o->segment_hit(p,(Float64(home[1]),Float64(home[2])),o,0.),visual_obstacles)
        return D("forward"=>f,"right"=>r,"distance"=>d)
    end
    nothing
end

function replenish_food!(stock,food)
    added=0
    for (i,f) in enumerate(food)
        amount=max(0,Int(f.stock)-stock[i]);stock[i]+=amount;added+=amount
    end
    added
end

function lw_day(spec,clock;days=1,basic_loop=false,landmark_routes=false,harvest_sleep=false,model_field=false,model_review=false,model_relearn=false,renewable_food=false,hazard_mode=false,ground_mode="flat",running=false,climbing=false,low_obstacles=false,dropping=false,social_response=false,general_sleep=false,sleep_actions=false,sleep_retention=false,sleep_maintenance=false,ground_wear=false,ground_perception=false,ground_continuity=false,food_body=false,dynamic_hazard_mode="off",continuous_safety=false,orientation=false,relation_field=false,body_field=false,movement_inertia=false)
    check(days isa Int && 1<=days<=30,"lw_days")
    check(!landmark_routes || basic_loop,"landmark_loop_required")
    check(!model_field || (harvest_sleep && basic_loop),"harvest_field_requires_learning_loop")
    check(!model_review || harvest_sleep,"harvest_review_requires_learning")
    check(!model_relearn || model_review,"harvest_relearn_requires_review")
    w=moving_world(spec);w.capacity=100_000
    high=copy(w.obstacles);low=low_obstacles ? spec.low_obstacles : Any[]
    append!(w.obstacles,[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in low])
    climb_stats=Dict(a=>D("attempts"=>0,"performed"=>0,"distance"=>0.,"delta_mismatches"=>0,"records"=>Any[]) for a in IDS)
    hazard_world=dynamic_hazards()
    sky=Dict(a=>orientation_state(a) for a in IDS)
    safety_loops=Dict(a=>BasicLoop(a*":safety";parent=a*":life") for a in IDS)
    safety=Dict(a=>safety_state() for a in IDS)
    inertia=Dict(a=>inertia_state(a) for a in IDS)
    check(!movement_inertia || landmark_routes,"inertia_requires_observed_fan")
    hunger=Dict(a=>hunger_state(a) for a in IDS)
    metabolism=Dict(a=>0. for a in IDS)
    check(!body_field || food_body,"body_field_requires_hunger")
    body_fields=Dict(a=>D("applied"=>0,"changed"=>0) for a in IDS)
    response_stats=Dict(a=>D("decisions"=>0,"request_decisions"=>0,"requests"=>0,"withheld"=>0,"give"=>0,"refuse"=>0,"experienced"=>0,"records"=>Any[]) for a in IDS)
    check(ground_mode in ("flat","patches","shadow"),"ground_mode")
    patches=ground_mode=="flat" ? Any[] : spec.ground_patches
    check(!ground_continuity || ground_perception,"ground_continuity_requires_perception")
    ground_models=Dict(a=>ground_memory(a) for a in IDS);ground_receipts=Dict{String,Any}()
    wear=GroundWear(Int(clock.day_us))
    ground_views=Dict(a=>D("observations"=>0,"counts"=>D(),"records"=>Any[]) for a in IDS)
    base_resistance_at=p->ground_resistance(p,patches)
    resistance_at=p->1+(base_resistance_at(p)-1)*(ground_wear ? wear_factor(wear,p) : 1.)
    ground_stats=Dict(a=>D("walks"=>0,"high_resistance_walks"=>0,"projection_decisions"=>0,"delta_mismatches"=>0,"records"=>Any[]) for a in IDS)
    food=Any[f for f in spec.food];dropped=cargo_ground()
    yaw=Dict(a=>0. for a in IDS);stock=Int[f.stock for f in food]
    stores=Dict(a=>0 for a in IDS);states=Dict(a=>social_initial() for a in IDS)
    live=Dict(a=>live_aid(a) for a in IDS);results=Dict(a=>D() for a in IDS)
    answered=Dict(a=>Set{String}() for a in IDS);learning=Dict(a=>sleeper(0) for a in IDS)
    counts=Dict(a=>Dict{String,Int}() for a in IDS);events=Any[];previous=Dict{String,Any}()
    distance=Dict(a=>0. for a in IDS)
    run_stats=Dict(a=>D("attempts"=>0,"performed"=>0,"distance"=>0.,"delta_mismatches"=>0,"records"=>Any[]) for a in IDS)
    routes=Dict(a=>route_memory() for a in IDS)
    relation_fields=Dict(a=>relation_field_state() for a in IDS)
    check(!relation_field || landmark_routes,"relation_requires_routes")
    harvest=Dict(a=>harvest_state(a) for a in IDS);harvest_pending=Dict{String,Any}()
    model_relearn && foreach(a->(harvest[a]["relearn_enabled"]=true),IDS)
    field_stats=Dict(a=>D("applied"=>0,"selection_changes"=>0,"examples"=>Any[],"by_model"=>D()) for a in IDS)
    cargo=Dict(a=>Union{Nothing,String}[] for a in IDS)
    max_radius=Dict(a=>0. for a in IDS)
    loops=Dict(a=>Dict(f=>BasicLoop(a*":"*f;parent=a*":food-security") for f in ("food","home")) for a in IDS)
    check(!sleep_maintenance || sleep_actions,"maintenance_needs_sleep_actions")
    check(!sleep_actions || general_sleep,"sleep_actions_need_review")
    action_models=Dict(a=>sleep_action_state(a) for a in IDS)
    general=Dict(a=>general_sleep_state() for a in IDS)
    purposes=Dict(a=>return_purpose() for a in IDS)
    pending=Dict{String,Any}();daily=Any[];day_starts=Any[]
    physical()=D(a=>D("position"=>collect(w.positions[a]),"yaw"=>yaw[a],"body"=>bodydict(w.bodies[a]),
        "return_purpose"=>deepcopy(purposes[a]),"inventory"=>w.inventory[a],"personal_stock"=>stores[a],"social_count"=>length(states[a]["records"]),
        "social_model"=>deepcopy(states[a]["model"]),"loops"=>D(f=>loop_snapshot(s) for (f,s) in loops[a]),
        "routes"=>landmark_routes ? deepcopy(routes[a]) : nothing,"max_radius_observer_only"=>max_radius[a],
        "harvest"=>harvest_sleep ? deepcopy(harvest[a]) : nothing) for a in IDS)
    for (i,a) in enumerate(IDS)
        w.inventory[a]=spec.initial_inventory[i];w.bodies[a]=Body(10.,0.,spec.reserve[i],0.)
        append!(cargo[a],fill(nothing,w.inventory[a]))
        hasproperty(spec,:initial_personal_stock) && (stores[a]=spec.initial_personal_stock[i])
    end
    initial=sum(stock)+sum(values(w.inventory))+sum(values(stores));bounds=Int.(clock.phase_boundaries_us)
    replenished=0;replenishments=Any[]
    integrate(a,now,obs)=begin
        before=length(states[a]["records"])
        if states[a]["pending"]!==nothing
            states[a]=ingest(states[a],D("agent_id"=>a,"capture_us"=>now,
                "observation_id"=>"ob:$now:$a","social"=>obs),results[a])
        end
        pressure_poll!(live[a],states[a]["records"],before)
    end
    for sec in 0:days*div(clock.day_us,1_000_000)-1
        now=sec*1_000_000;w.seconds=sec
        (ground_wear || ground_perception) && advance_wear!(wear,now)
        if ground_perception
            for a in IDS
                view=ground_appearance(w,a,yaw,wear,now)
                record_ground_patterns!(ground_views[a],view)
                ground_continuity && update_ground!(ground_models[a],view,get(ground_receipts,a,nothing))
            end
        end
        day=div(now,clock.day_us);local_us=mod(now,clock.day_us)
        if local_us==0
            push!(day_starts,physical())
            if day>0
                learning=Dict(a=>sleeper(day) for a in IDS)
                if renewable_food
                    added=replenish_food!(stock,spec.food);replenished+=added
                    push!(replenishments,D("day"=>day,"us"=>now,"added"=>added))
                end
            end
        end
        phase=local_us<bounds[1] ? "orientation" : local_us<bounds[2] ? "exploration" : local_us<bounds[3] ? "return" : "night"
        if food_body
            for a in IDS
                hunger_update!(hunger[a],a,now,w.bodies[a].reserve)
            end
        end
        if dynamic_hazard_mode!="off"
            advance_hazards!(hazard_world,now,w.positions,w.obstacles;patrol=dynamic_hazard_mode=="mixed")
        end
        hazard_sources=dynamic_hazard_mode=="off" ? spec.hazards : dynamic_hazard_sources(hazard_world,sec;patrol=dynamic_hazard_mode=="mixed")
        if orientation
            for a in IDS;observe_sky!(sky[a],sky_sample(a,"ob:$now:$a",now,yaw[a],clock));end
        end
        obs=Dict(a=>observe(w,a) for a in IDS)
        moves=Dict(a=>movement_observation(w,a,yaw,food,stock;resistance_at=resistance_at,run_resistance_at=base_resistance_at,running=running,visual_obstacles=high) for a in IDS)
        homes=Dict(a=>home_observation(w,a,yaw,spec.home;visual_obstacles=high) for a in IDS)
        sections=harvest_sleep ? Dict(a=>harvest_section(moves[a],"ob:$now:$a",now) for a in IDS) : nothing
        if harvest_sleep
            for a in IDS
                harvest_observe!(harvest[a],sections[a])
                if haskey(harvest_pending,a)
                    t=pop!(harvest_pending,a)
                    model_relearn && replacement_result!(harvest[a],a,t.op,t.before,t.status,t.executed,sections[a];
                        pose=t.position==w.positions[a] && t.yaw==yaw[a])
                    harvest_result!(harvest[a],a,t.op,t.before,t.status,t.executed,sections[a])
                    if model_review
                        review_harvest!(harvest[a],a,t.op,t.prediction,t.before,t.status,t.executed,sections[a];
                            pose=t.position==w.positions[a] && t.yaw==yaw[a])
                    end
                end
                prediction=harvest_predict(harvest[a],sections[a])
                harvest[a]["prediction_counts"][prediction["status"]]+=1
                if prediction["status"]=="known"
                    bymodel=get!(harvest[a],"prediction_by_model",D());ref=prediction["model_ref"]
                    bymodel[ref]=get(bymodel,ref,0)+1
                end
                if prediction["status"]=="known" && harvest[a]["first_known"]===nothing
                    harvest[a]["first_known"]=merge(prediction,D("capture_us"=>now))
                end
            end
        end
        landmarks=landmark_routes ? Dict(a=>landmark_fan(spec.obstacles,w.positions[a],yaw[a],"ob:$now:$a") for a in IDS) : nothing
        climbs=climbing ? Dict(a=>[climb_sample(w,a,yaw[a],i,low,high,base_resistance_at) for i in 0:4] for a in IDS) : nothing
        # Safety and learning share the same current, actor-local observation.
        hazard_views=(hazard_mode || general_sleep || movement_inertia) ? Dict(a=>hazard_observation(w,a,yaw,hazard_mode ? hazard_sources : Any[],sec;visual_obstacles=high) for a in IDS) : nothing
        contexts=general_sleep ? Dict(a=>sleep_context(moves[a],hazard_views[a]) for a in IDS) : nothing
        plans=D()
        for a in IDS
            integrate(a,now,obs[a]);o=obs[a];plan=nothing;home=homes[a]
            at_home=home!==nothing && home["distance"]<=1.25
            movement_inertia && observe_inertia!(inertia[a],a,now,inertia_view(moves[a],landmarks[a],hazard_views[a]))
            if basic_loop && haskey(pending,a)
                t=pop!(pending,a);s=loops[a][t.family]
                target=t.family=="home" ? home : isempty(moves[a]["visible"]) ? nothing : first(moves[a]["visible"])
                same=target!==nothing && (t.family=="home" || t.ref===nothing || target["ref"]==t.ref)
                value=t.question=="ground_extension" ? t.status=="performed" && any(m->m["model_ref"]==loops[a][t.family].trial.method && m["status"]=="observed" && m["extended"],ground_models[a]["models"]) : t.question=="movement_progress" ? t.status=="performed" && t.moved : t.question=="rested" ? t.status=="performed" : t.question=="load_reduced" ? t.status=="dropped" : t.question=="recovered" ? t.status=="recovered" : t.question=="landmark_progress" ? t.status=="performed" : t.question=="acquired" ? t.status=="picked_up" : t.question=="home_confirmed" ? at_home && t.status=="performed" : t.question=="target_observed" ? target!==nothing :
                    same ? target["distance"]<t.distance : nothing
                # No move/turn result is credited as acquired food or confirmed home.
                goal=t.family=="home" ? at_home : t.status in ("picked_up","recovered")
                resolve_method!(s,t.source,t.phase==phase || value===true ? value : nothing,t.phase==phase || goal ? goal : nothing)
            end
            if ground_continuity
                active=Set(m["model_ref"] for m in ground_models[a]["models"])
                for loop in values(loops[a])
                    filter!(kv->!startswith(first(kv),"ground_") || first(kv) in active,loop.methods)
                end
            end
            messages=[m for m in reverse(o["messages"]) if !(m["id"] in answered[a]) && m["kind"] in ("request","warn","reach")]
            if hazard_mode
                hazard_view=hazard_views[a]
                plan=continuous_safety ? safety_methods!(safety[a],safety_loops[a],hazard_view,moves[a],"op:$now:$a";running=running) : safety_plan!(safety[a],hazard_view,moves[a];running=running)
            end
            if plan!==nothing
                # Safety has authority before social, food and night priorities.
            elseif !isempty(messages)
                m=first(messages);current=merge(copy(o),D("messages"=>[m]))
                if social_response || food_body
                    decision,trace=experienced_response(current,states[a]["records"],live[a].state,a,"respond:$now:$a:$(m["id"])";retention=food_body ? retention_cost(current,hunger[a]) : 0.)
                    act,t,r=decision
                    if trace!==nothing
                        rs=response_stats[a];rs["decisions"]+=1;rs[act]+=1
                        trace["weight"]>0 && (rs["experienced"]+=1)
                        push!(rs["records"],trace);length(rs["records"])>32 && popfirst!(rs["records"])
                    end
                else
                    act,t,r=response(current,a!="npc_b")
                end
                plan=D("action"=>act,"target"=>t,"reply_to"=>r);push!(answered[a],m["id"])
            elseif (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) && w.inventory[a]>0
                plan=D("action"=>"eat")
            elseif at_home && (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) && stores[a]>0
                plan=D("action"=>"retrieve")
            elseif phase=="night" && local_us>=clock.quiet_night_us
                plan=D("action"=>"rest")
            elseif states[a]["pending"]!==nothing
                plan=D("action"=>"rest")
            elseif food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80
                targets=[x["ref"] for x in o["others"] if x["holding_food"]]
                target,_=select_target(targets,states[a]["model"],live[a].state)
                request_allowed=target!==nothing
                if request_allowed && social_response
                    request_allowed,trace=experienced_request(o,states[a]["records"],live[a].state,a,target,"request:$now:$a:$target")
                    rs=response_stats[a];rs["request_decisions"]+=1;rs[request_allowed ? "requests" : "withheld"]+=1
                    push!(rs["records"],trace);length(rs["records"])>32 && popfirst!(rs["records"])
                end
                if request_allowed
                    op="op:$now:$a"
                    states[a]["pending"]=D("message_id"=>a*":"*op,"target"=>target,"deadline"=>now+5_000_000,
                        "request_observation_id"=>"ob:$now:$a","operation_id"=>op)
                    plan=D("action"=>"request","target"=>target)
                end
            end
            returning=returning!(purposes[a],phase,w.inventory[a],at_home,now)
            if plan===nothing
                if returning && at_home
                    plan=D("action"=>w.inventory[a]>0 ? "deposit" : "rest")
                elseif food_body && phase=="exploration" && !returning && w.bodies[a].reserve>=80 && w.inventory[a]>=3
                    plan=D("action"=>"rest")
                elseif phase=="orientation"
                    plan=D("action"=>"rest")
                elseif w.bodies[a].strain>=.8 || w.bodies[a].reserve<=0
                    plan=D("action"=>"rest")
                elseif basic_loop
                    family=returning ? "home" : "food"
                    visible=moves[a]["visible"];target=returning ? home : isempty(visible) ? nothing : first(visible)
                    if !returning && target!==nothing && target["distance"]<=1.25
                        plan=D("action"=>haskey(dropped["origins"],target["ref"]+1) ? "recover" : "pickup","food_ref"=>target["ref"])
                    else
                        s=loops[a][family];source="op:$now:$a"
                        rolling=movement_inertia ? inertia_candidate!(inertia[a],moves[a],hazard_views[a],phase,family,s.methods,source) : nothing
                        if rolling!==nothing
                            plan=choose_method!(s,[rolling],source)
                        else
                        candidates=search_candidates(moves[a],target,s)
                        body_field && push!(candidates,D("method"=>"rest","action"=>"rest","priority"=>1.,"question"=>"rested"))
                        climbing && append!(candidates,climb_candidates(climbs[a],moves[a],target,s))
                        dropping && climbing && append!(candidates,drop_candidates(climbs[a],w.bodies[a],w.inventory[a],target))
                        if landmark_routes
                            if routes[a]["day"]!=day
                                empty!(routes[a]["cursors"]);routes[a]["day"]=day
                            end
                            # Direct currently observed goal wins over remembered detours.
                            if target===nothing
                                append!(candidates,landmark_candidates(moves[a],landmarks[a],routes[a],family,landmarks[a]["source"];include_routes=!relation_field))
                                relation_field && append!(candidates,relation_candidates!(relation_fields[a],moves[a],landmarks[a],routes[a],family,landmarks[a]["source"]))
                            end
                        end
                        if ground_continuity && phase=="exploration" && !returning && target===nothing
                            append!(candidates,ground_proposals(ground_models[a],moves[a]))
                        end
                        if ground_mode=="patches"
                            candidates=ground_candidates(candidates,moves[a],w.inventory[a])
                            ground_stats[a]["projection_decisions"]+=1
                        end
                        counterfactual=nothing;field_trace=nothing
                        if model_field && family=="food"
                            projected,field_trace=harvest_field(candidates,moves[a],harvest[a],a,now;enabled=true)
                            if field_trace["applied"]
                                counterfactual=method_choice(s,candidates)
                                candidates=projected;field_stats[a]["applied"]+=1
                                m=get!(field_stats[a]["by_model"],field_trace["model_ref"],D("applied"=>0,"selection_changes"=>0))
                                m["applied"]+=1
                            end
                        end
                        sleep_maintenance && wake_sleep_usage!(action_models[a],contexts[a],phase)
                        sleep_without=sleep_actions ? method_choice(s,candidates) : nothing
                        sleep_applied=sleep_actions && project_sleep_actions!(action_models[a],candidates,contexts[a],a,now)
                        sleep_selected=sleep_actions ? method_choice(s,candidates) : nothing
                        field_selected=sleep_actions ? sleep_without : method_choice(s,candidates)
                        body_before=body_field ? method_choice(s,candidates)["method"] : nothing
                        body_applied=body_field && project_body_methods!(candidates,hunger[a],w.bodies[a],phase)
                        plan=choose_method!(s,candidates,source)
                        if body_applied
                            body_fields[a]["applied"]+=1;body_fields[a]["changed"]+=Int(body_before!=plan["method"])
                        end
                        relation_field && startswith(plan["method"],"relation:") && (relation_fields[a]["selections"]+=1)
                        ground_continuity && startswith(plan["method"],"ground_") && (ground_models[a]["selections"]+=1)
                        sleep_maintenance && (plan["sleep_changed"]=sleep_applied && sleep_without["method"]!=sleep_selected["method"] && plan["method"]==sleep_selected["method"])
                        sleep_applied && sleep_without["method"]!=sleep_selected["method"] && (action_models[a]["selection_changes"]+=1)
                        if counterfactual!==nothing && counterfactual["method"]!=field_selected["method"]
                            field_stats[a]["selection_changes"]+=1
                            field_stats[a]["by_model"][field_trace["model_ref"]]["selection_changes"]+=1
                            if length(field_stats[a]["examples"])<8
                                push!(field_stats[a]["examples"],D("source"=>"ob:$now:$a","without"=>counterfactual["method"],
                                    "with"=>field_selected["method"],"field"=>field_trace))
                            end
                        end
                        end
                        landmark_routes && get(plan,"route",nothing)!==nothing && (routes[a]["selections"]+=1)
                        pending[a]=(family=family,source=source,phase=phase,question=plan["question"],
                            distance=target===nothing ? nothing : target["distance"],
                            ref=target===nothing || returning ? nothing : target["ref"],status="unexecuted")
                    end
                elseif returning && home===nothing
                    plan=D("action"=>"scan")
                else
                    visible=moves[a]["visible"];target=returning ? home : isempty(visible) ? nothing : first(visible)
                    if !returning && target!==nothing && target["distance"]<=1.25
                        plan=D("action"=>haskey(dropped["origins"],target["ref"]+1) ? "recover" : "pickup","food_ref"=>target["ref"])
                    else
                        scored=[r for r in moves[a]["energy"]["rows"] if r["cost"]!==nothing]
                        if isempty(scored)
                            plan=D("action"=>"scan")
                        else
                            # Temporary local steering, not ported LW nested M_B navigation.
                            sort!(scored,by=r->begin
                                ang=deg2rad(Float64(ANGLES[parse(Int,r["ref"])+1]))
                                target===nothing ? r["cost"] : hypot(target["forward"]-cos(ang),target["right"]-sin(ang))
                            end)
                            plan=D("action"=>"walk","direction"=>parse(Int,first(scored)["ref"]))
                        end
                    end
                end
            end
            if basic_loop && !haskey(pending,a) && (plan["action"] in ("pickup","recover","deposit") || (at_home && plan["action"]=="rest" && loops[a]["home"].H>0))
                family=plan["action"] in ("pickup","recover") ? "food" : "home"
                question=plan["action"]=="recover" ? "recovered" : family=="food" ? "acquired" : "home_confirmed"
                source="op:$now:$a"
                plan=choose_method!(loops[a][family],[merge(plan,D("method"=>"work","priority"=>5.,"question"=>question))],source)
                pending[a]=(family=family,source=source,phase=phase,question=question,distance=nothing,ref=nothing,status="unexecuted")
            end
            if orientation && plan["action"]=="scan" && !get(plan,"safety",false)
                plan["scan_angle"]=orientation_scan!(sky[a],clock)
            end
            plan["purpose_family"]=returning ? "home" : "food"
            plans[a]=plan
        end
        w.seconds=sec+1
        for a in IDS
            plan=plans[a];action=plan["action"];op="op:$now:$a";p=w.positions[a];before_yaw=yaw[a];status="performed"
            frozen_prediction=harvest_sleep && action=="pickup" ? harvest_predict(harvest[a],sections[a]) : nothing
            leg=plan["purpose_family"] # Frozen selection-time parent, not post-drop load.
            delivered=String[]
            # Exactly one body update per simulated second, including non-movement actions.
            if action=="climb"
                actual=climb_sample(w,a,yaw[a],plan["direction"],low,high,base_resistance_at)
                expected=climbs[a][plan["direction"]+1]
                yaw[a]=mod(yaw[a]+ANGLES[plan["direction"]+1]+180,360)-180
                s,c=sincos(deg2rad(yaw[a]))
                w.bodies[a],status,d,delta=step(w.bodies[a],"climb",w.inventory[a],actual["resistance"],actual["clear"])
                w.positions[a]=(p[1]+s*d,p[2]+c*d);distance[a]+=d
                g=climb_stats[a];g["attempts"]+=1;g["distance"]+=d
                status=="performed" && (g["performed"]+=1)
                comparable=expected["load"]==w.inventory[a] && expected["clear"]==actual["clear"] && expected["resistance"]==actual["resistance"]
                comparable && expected["expected_delta"]!=delta && (g["delta_mismatches"]+=1)
                push!(g["records"],D("source"=>op,"status"=>status,"height"=>actual["height"],"capacity"=>actual["capacity"],
                    "load"=>w.inventory[a],"resistance"=>actual["resistance"],"distance"=>d,"expected_delta"=>expected["expected_delta"],"actual_delta"=>delta))
                length(g["records"])>32 && popfirst!(g["records"])
            elseif action in ("walk","run")
                yaw[a]=mod(yaw[a]+ANGLES[plan["direction"]+1]+180,360)-180
                s,c=sincos(deg2rad(yaw[a]))
                span=action=="run" ? 1.5*(1-w.bodies[a].damage) : .5
                q=(p[1]+s*span,p[2]+c*span)
                clear=!any(o->segment_hit(p,q,o,.2),w.obstacles)
                sample_span=(action=="run" ? 1.5 : .5)*(1-w.bodies[a].damage)
                midpoint=(p[1]+s*sample_span/2,p[2]+c*sample_span/2)
                resistance=(action=="run" ? base_resistance_at : resistance_at)(midpoint)
                expected=(action=="run" ? moves[a]["run_rows"] : moves[a]["energy"]["rows"])[plan["direction"]+1]
                w.bodies[a],status,d,delta=step(w.bodies[a],action,w.inventory[a],resistance,clear)
                if action=="run"
                    g=run_stats[a];g["attempts"]+=1;g["distance"]+=d
                    status=="performed" && (g["performed"]+=1)
                    comparable=expected["load"]==w.inventory[a] && expected["clear"]==clear && expected["resistance"]==resistance
                    comparable && expected["expected_delta"]!=delta && (g["delta_mismatches"]+=1)
                    push!(g["records"],D("source"=>op,"status"=>status,"load"=>w.inventory[a],"resistance"=>resistance,
                        "distance"=>d,"expected_delta"=>deepcopy(expected["expected_delta"]),"actual_delta"=>delta,"comparable"=>comparable))
                    length(g["records"])>32 && popfirst!(g["records"])
                elseif ground_mode!="flat"
                    g=ground_stats[a];g["walks"]+=1
                    resistance>1.5 && (g["high_resistance_walks"]+=1)
                    # The observed clearance horizon is 1 unit, execution is at most .5.
                    # Compare matching clearance only; distinguish that geometric boundary.
                    comparable=expected["clear"]==clear && expected["load"]==w.inventory[a] && expected["resistance"]==resistance
                    match=comparable && expected["expected_delta"]==delta && expected["resistance"]==resistance
                    comparable && !match && (g["delta_mismatches"]+=1)
                    push!(g["records"],D("source"=>op,"load"=>w.inventory[a],"resistance"=>resistance,
                        "status"=>status,"expected_delta"=>deepcopy(expected["expected_delta"]),"actual_delta"=>delta,
                        "comparable"=>comparable,"matches"=>match))
                    length(g["records"])>32 && popfirst!(g["records"])
                end
                w.positions[a]=(p[1]+s*d,p[2]+c*d);distance[a]+=d
            elseif action in ("eat","request","give","refuse","warn","withdraw","wait")
                r=communicate!(w,a,op,action,get(plan,"target",nothing),get(plan,"reply_to",nothing));status=r["status"]
                if status=="ate"
                    popfirst!(cargo[a])
                elseif status=="transferred"
                    push!(cargo[plan["target"]],popfirst!(cargo[a]))
                end
                results[a]=D(op=>r)
                if action!="eat"
                    w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
                end
            else
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
                if action in ("drop","recover")
                    status=cargo_transfer!(dropped,w,cargo,food,stock,a,op,now,action;index=action=="recover" ? plan["food_ref"]+1 : 0)
                elseif action=="scan"
                    yaw[a]=mod(yaw[a]+get(plan,"scan_angle",60)+180,360)-180
                elseif action=="pickup"
                    j=plan["food_ref"]+1;f=food[j]
                    legal=stock[j]>0 && hypot(f.x-p[1],f.z-p[2])<=1.25 && !any(o->segment_hit(p,(Float64(f.x),Float64(f.z)),o,0.),w.obstacles)
                    if legal;stock[j]-=1;w.inventory[a]+=1;push!(cargo[a],op);end
                    status=legal ? "picked_up" : "not_found"
                elseif action in ("deposit","retrieve")
                    legal=hypot(p[1]-spec.home[1],p[2]-spec.home[2])<=1.25
                    if legal && action=="deposit"
                        delivered=String[id for id in cargo[a] if id!==nothing];empty!(cargo[a])
                        stores[a]+=w.inventory[a];w.inventory[a]=0
                    elseif legal && stores[a]>0
                        stores[a]-=1;w.inventory[a]+=1
                        push!(cargo[a],nothing)
                    else
                        status="unavailable"
                    end
                end
            end
            if ground_wear && action=="walk" && status=="performed"
                tread!(wear,op,a,p,w.positions[a],now)
            end
            if ground_continuity
                dx=w.positions[a][1]-p[1];dz=w.positions[a][2]-p[2];sn,cs=sincosd(before_yaw)
                ground_receipts[a]=D("actor"=>a,"source"=>"ob:$now:$a","operation"=>op,
                    "before_us"=>now,"after_us"=>now+1_000_000,"forward"=>dx*sn+dz*cs,"right"=>dx*cs-dz*sn,"yaw"=>yaw[a]-before_yaw)
            end
            if continuous_safety && get(plan,"safety",false)
                safety[a]["accepted"]=true
                safety[a]["body_result"]=(action=action,status=status,yaw=mod(yaw[a]-before_yaw+180,360)-180)
            end
            sleep_maintenance && record_sleep_use!(action_models[a],plan,op,status)
            @assert all(length(cargo[x])==w.inventory[x] for x in IDS)
            max_radius[a]=max(max_radius[a],hypot(w.positions[a][1]-spec.home[1],w.positions[a][2]-spec.home[2]))
            if landmark_routes && !get(plan,"safety",false)
                near=homes[a]!==nothing && homes[a]["distance"]<=1.25
                route_result!(routes[a],landmarks[a],op,action,status,leg,near,get(plan,"route",nothing);delivered=delivered,relational=relation_field)
            end
            if phase=="night"
                cycle=learning[a]["sleep"]["cycle"]
                harvest_sleep && action=="rest" && freeze_harvest!(harvest[a],cycle,now)
                if general_sleep && cycle["status"]=="pending" && cycle["rest_us"]==0 && action=="rest"
                    freeze_general!(general[a],a,now;retained=sleep_retention)
                end
                callback=(harvest_sleep || general_sleep) ? ((c,t)->begin
                    harvest_sleep && consolidate_harvest!(harvest[a],c,t)
                    general_sleep && review_general!(general[a],a,day,t)
                    sleep_maintenance && review_sleep_usage!(action_models[a],day,general[a]["formation_us"])
                    sleep_actions && adopt_sleep_actions!(action_models[a],last(general[a]["reviews"]),a,t)
                    sleep_maintenance && enroll_sleep_usage!(action_models[a],t)
                end) : nothing
                receipt!(learning[a],now;phase=phase,kind=action=="rest" ? "wait" : action,status=action=="rest" ? "waited" : status,on_complete=callback)
            end
            general_sleep && remember_general!(general[a],a,op,action,status,get(plan,"target",nothing),phase,now+1_000_000;context=contexts[a],direction=get(plan,"direction",nothing),retain=sleep_retention)
            if harvest_sleep && action=="pickup"
                harvest_pending[a]=(op=op,before=deepcopy(sections[a]),status=status,executed=now+1_000_000,
                    prediction=frozen_prediction,position=p,yaw=yaw[a])
            end
            if haskey(pending,a)
                pending[a]=merge(pending[a],(status=status,moved=w.positions[a]!=p,))
            end
            if movement_inertia
                inertia[a]["receipt"]=(actor=a,source=op,executed_us=now+1_000_000,phase=phase,family=leg,
                    action=action,status=status,moved=w.positions[a]!=p,method=get(plan,"method",nothing),route=get(plan,"route",nothing))
            end
            counts[a][action]=get(counts[a],action,0)+1
            sig=(phase,leg,action,get(plan,"target",nothing),status,get(plan,"method",nothing),get(plan,"direction",nothing),get(plan,"selection_mode",nothing))
            if get(previous,a,nothing)!=sig
                push!(events,D("us"=>now,"actor"=>a,"phase"=>phase,"purpose_family"=>leg,"action"=>action,"status"=>status,"target"=>get(plan,"target",nothing),
                    "method"=>get(plan,"method",nothing),"direction"=>get(plan,"direction",nothing),"selection_mode"=>get(plan,"selection_mode",nothing),
                    "route"=>get(plan,"route",nothing),"landmark_color"=>get(plan,"landmark_color",nothing)))
                previous[a]=sig
            end
        end
        if food_body
            for a in IDS
                before=w.bodies[a].reserve;w.bodies[a]=metabolize(w.bodies[a],1.)
                metabolism[a]+=before-w.bodies[a].reserve
            end
        end
        @assert sum(stock)+sum(values(w.inventory))+sum(values(stores))+w.consumed==initial+replenished
        if mod(now+1_000_000,clock.day_us)==0
            for a in IDS
                integrate(a,now+1_000_000,observe(w,a))
                cycle=learning[a]["sleep"]["cycle"]
                states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>now+1_000_000)),a)
            end
            push!(daily,D("physical"=>physical(),"sleep"=>deepcopy(learning),"counts"=>deepcopy(counts),
                "ground"=>sum(stock),"consumed"=>w.consumed,"replenished_food"=>replenished))
        end
    end
    ground_wear && advance_wear!(wear,Int(days*clock.day_us))
    terminal=D()
    for a in IDS
        integrate(a,Int(days*clock.day_us),observe(w,a))
        cycle=learning[a]["sleep"]["cycle"]
        states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>Int(days*clock.day_us))),a)
        terminal[a]=D("return_purpose"=>deepcopy(purposes[a]),"position"=>collect(w.positions[a]),"body"=>bodydict(w.bodies[a]),"inventory"=>w.inventory[a],
            "personal_stock"=>stores[a],"sleep"=>learning[a],"social"=>states[a],"aid"=>pressure_snapshot(live[a]),"distance"=>distance[a],
            "routes"=>landmark_routes ? deepcopy(routes[a]) : nothing,"max_radius_observer_only"=>max_radius[a],
            "harvest"=>harvest_sleep ? deepcopy(harvest[a]) : nothing,"model_field"=>field_stats[a])
    end
    D("movement_inertia"=>movement_inertia ? inertia : nothing,"body_field"=>body_field ? body_fields : nothing,"relation_field"=>relation_field ? relation_fields : nothing,"orientation"=>orientation ? sky : nothing,"safety_methods"=>continuous_safety ? D(a=>loop_snapshot(safety_loops[a]) for a in IDS) : nothing,"world_hazards"=>dynamic_hazard_mode!="off" ? hazard_world : nothing,"food_body"=>food_body ? D("hunger"=>hunger,"metabolic_loss"=>metabolism) : nothing,"ground_continuity"=>ground_continuity ? ground_models : nothing,"ground_perception"=>ground_perception ? ground_views : nothing,"ground_wear"=>ground_wear ? wear_snapshot(wear) : nothing,"sleep_action_models"=>sleep_actions ? action_models : nothing,"general_sleep"=>general_sleep ? general : nothing,"social_response"=>(social_response || food_body) ? response_stats : nothing,"ended_us"=>days*clock.day_us,"initial_food"=>initial,"ground"=>sum(stock),"consumed"=>w.consumed,
        "replenished_food"=>replenished,"replenishments"=>replenishments,
        "dropped_cargo"=>dropping ? D("dropped"=>dropped["dropped"],"recovered"=>dropped["recovered"],"cross_actor"=>dropped["cross_actor"],"records"=>dropped["records"],"sites"=>[D("index"=>i,"x"=>food[i].x,"z"=>food[i].z,"stock"=>stock[i],"source"=>dropped["origins"][i]) for i in sort(collect(keys(dropped["origins"])))]) : nothing,"climbing"=>climbing ? climb_stats : nothing,"running"=>running ? run_stats : nothing,"ground_effects"=>ground_mode=="flat" ? nothing : ground_stats,"safety"=>hazard_mode ? deepcopy(safety) : nothing,"counts"=>counts,"events"=>events,"final_agents"=>terminal,"daily"=>daily,"day_starts"=>day_starts)
end

if abspath(PROGRAM_FILE)==@__FILE__
input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D(),"clock"=>input.clock)
@testset "LW day lifecycle" begin
    for spec in input.scenes
        elapsed=@elapsed r=lw_day(spec,input.clock)
        @test r["ended_us"]==17_280_000_000
        @test all(sum(values(r["counts"][a]))==17_280 for a in IDS)
        @test all(r["final_agents"][a]["sleep"]["sleep"]["cycle"]["status"]=="completed" for a in IDS)
        @test r["ground"]+r["consumed"]+sum(r["final_agents"][a]["inventory"]+r["final_agents"][a]["personal_stock"] for a in IDS)==r["initial_food"]
        @test all(isfinite(r["final_agents"][a]["body"]["reserve"]) for a in IDS)
        report["scenes"][spec.name]=D("elapsed_seconds_including_first_compilation"=>elapsed,"result"=>r)
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
end
