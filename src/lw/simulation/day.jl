include("physiology.jl")
include(joinpath(@__DIR__, "../perception/hazard.jl"))
include(joinpath(@__DIR__, "../perception/orientation.jl"))
include(joinpath(@__DIR__, "../world/world_hazards.jl"))
include(joinpath(@__DIR__, "../world/ground.jl"))
include(joinpath(@__DIR__, "../decision/reposition.jl"))
include(joinpath(@__DIR__, "../perception/skyline.jl"))
include(joinpath(@__DIR__, "../world/landscape.jl"))
include(joinpath(@__DIR__, "../world/ground_wear.jl"))
include(joinpath(@__DIR__, "../perception/ground_pattern.jl"))
include(joinpath(@__DIR__, "../perception/local_structures.jl"))
include(joinpath(@__DIR__, "../perception/rho_map.jl"))
include(joinpath(@__DIR__, "../perception/ground_continuity.jl"))
include(joinpath(@__DIR__, "../decision/climbing.jl"))
include(joinpath(@__DIR__, "../world/dropped_cargo.jl"))
include(joinpath(@__DIR__, "../decision/return_purpose.jl"))
include(joinpath(@__DIR__, "../decision/social_response.jl"))
include(joinpath(@__DIR__, "../decision/food_body.jl"))
include(joinpath(@__DIR__, "../learning/experience_bundles.jl"))
include(joinpath(@__DIR__, "../learning/selection_trail.jl"))
include(joinpath(@__DIR__, "../learning/general_sleep.jl"))
include(joinpath(@__DIR__, "../learning/sleep_action_model.jl"))
include(joinpath(@__DIR__, "../learning/sleep_maintenance.jl"))
include(joinpath(@__DIR__, "moving.jl"))
include(joinpath(@__DIR__, "../../body/load.jl"))
include(joinpath(@__DIR__, "../decision/basic_loop.jl"))
include(joinpath(@__DIR__, "../decision/approach.jl"))
include(joinpath(@__DIR__, "../decision/local_descent.jl"))
include(joinpath(@__DIR__, "../decision/repetition_pressure.jl"))
include(joinpath(@__DIR__, "../decision/safety_methods.jl"))
include(joinpath(@__DIR__, "../decision/movement_inertia.jl"))
include(joinpath(@__DIR__, "../decision/exploration_horizon.jl"))
include(joinpath(@__DIR__, "../learning/landmark_routes.jl"))
include(joinpath(@__DIR__, "../perception/observed_cues.jl"))
include(joinpath(@__DIR__, "../decision/relation_field.jl"))
include(joinpath(@__DIR__, "../decision/lateral_bias.jl"))
include(joinpath(@__DIR__, "../learning/harvest_learning.jl"))
include(joinpath(@__DIR__, "../learning/harvest_field.jl"))
include(joinpath(@__DIR__, "../learning/harvest_review.jl"))
include(joinpath(@__DIR__, "../learning/harvest_relearn.jl"))

# B0 lifecycle scaffold. Current observed relative beacon only; no stored home coordinate in policy.
function home_observation(w,a,yaw,home;visual_obstacles=w.obstacles,range=60)
    p=w.positions[a];dx,dz=home[1]-p[1],home[2]-p[2]
    s,c=sincos(deg2rad(yaw[a]));f,r=dx*s+dz*c,dx*c-dz*s
    d=hypot(dx,dz)
    if d<=range && (f>=0 || d<=1.25) && !any(o->segment_hit(p,(Float64(home[1]),Float64(home[2])),o,0.),visual_obstacles)
        return D("forward"=>f,"right"=>r,"distance"=>d)
    end
    nothing
end

function replenish_food!(stock,food;capacity=0)
    added=0
    for (i,f) in enumerate(food)
        amount=max(0,(capacity>0 ? capacity : Int(f.stock))-stock[i]);stock[i]+=amount;added+=amount
    end
    added
end

function lw_day(spec,clock;days=1,basic_loop=false,landmark_routes=false,harvest_sleep=false,model_field=false,model_review=false,model_relearn=false,renewable_food=false,hazard_mode=false,ground_mode="flat",running=false,climbing=false,low_obstacles=false,dropping=false,social_response=false,general_sleep=false,sleep_actions=false,sleep_retention=false,sleep_maintenance=false,ground_wear=false,ground_perception=false,ground_continuity=false,food_body=false,dynamic_hazard_mode="off",continuous_safety=false,orientation=false,relation_field=false,body_field=false,movement_inertia=false,exploration_horizon=false,experience_bundles=false,bundle_credit=false,selection_trails=false,reposition=false,skyline_mode="off",shared_stores=false,regrowth_days=1,regrowth_capacity=0,goal_switch_threshold=2,lateral_side="off",parent_breadth=false,repetition_pressure=false,adaptive_approach=false,continuous_descent=false,rho_profile="off",rho_opening_candidates_enabled=true,digestion_mode="off",choice_seed=0,general_landmarks=false)
    check(goal_switch_threshold isa Integer && !(goal_switch_threshold isa Bool) && 1<=goal_switch_threshold<=30,"goal_switch_threshold")
    check(days isa Int && 1<=days<=30,"lw_days")
    check(!landmark_routes || basic_loop,"landmark_loop_required")
    check(!general_landmarks || landmark_routes,"general_landmarks_requires_routes")
    cue_states=Dict(a=>cue_stats() for a in IDS)
    check(!model_field || (harvest_sleep && basic_loop),"harvest_field_requires_learning_loop")
    check(!model_review || harvest_sleep,"harvest_review_requires_learning")
    check(!model_relearn || model_review,"harvest_relearn_requires_review")
    check(lateral_side in ("off","left","right"),"lateral_side")
    repetitions=Dict(a=>repetition_state() for a in IDS)
    breadth_stats=Dict(a=>D("decisions"=>0,"offered"=>0,"admitted"=>0,"restricted"=>0,"levels"=>[0,0,0]) for a in IDS)
    lateral_stats=Dict(a=>D("evaluations"=>0,"applied"=>0,"records"=>Any[]) for a in IDS)
    landmark_objects=landmark_routes ? prepare_landmark_objects(spec.obstacles) : nothing
    skyline_objects=skyline_mode=="off" ? nothing : prepare_skyline_objects(spec.obstacles)
    history=get(spec,:world_history,nothing)
    world_offset=history===nothing ? 0 : Int(history.next_us)
    if history!==nothing
        check(history.rule=="native-cohort-world-v1" && history.day_us==clock.day_us,"world_history_rule")
        check(history.renewable==renewable_food && history.hazard_mode==dynamic_hazard_mode && history.dropping==dropping && history.wear_enabled==ground_wear,"world_history_modes")
        check(get(spec,:landscape,nothing)==get(history,:landscape,nothing),"world_history_landscape")
        check(spec.obstacles==history.obstacles && spec.food==history.renewal_targets && spec.ground_patches==history.ground_patches,"world_history_geometry")
        check(world_offset>=0 && mod(world_offset,clock.day_us)==0,"world_history_clock")
        check((history.ground!==nothing)==ground_wear,"world_history_ground")
        ground_wear && check(history.ground.now_us==world_offset,"world_history_ground_clock")
        check((history.hazards!==nothing)==(dynamic_hazard_mode!="off"),"world_history_hazards")
        dynamic_hazard_mode!="off" && check(world_offset-1_000_000<=history.hazards.last_us<=world_offset,"world_history_hazard_clock")
        check(length(history.food)>=length(spec.food) && length(history.food)==length(history.stock),"world_history_food")
        check(all(x->x isa Integer && !(x isa Bool) && x>=0,history.stock),"world_history_stock")
        check(all(history.food[i]==spec.food[i] for i in eachindex(spec.food)),"world_history_resource_geometry")
        cargo_ids=[Int(item.index) for item in history.cargo]
        check(length(cargo_ids)<=256 && length(unique(cargo_ids))==length(cargo_ids) && sort(cargo_ids)==collect(length(spec.food)+1:length(history.food)),"world_history_cargo_indices")
        check(dropping || isempty(cargo_ids),"world_history_cargo_mode")
    end
    w=moving_world(spec);w.capacity=100_000
    high=copy(w.obstacles);low=low_obstacles ? spec.low_obstacles : Any[]
    append!(w.obstacles,[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in low])
    climb_stats=Dict(a=>D("attempts"=>0,"performed"=>0,"distance"=>0.,"delta_mismatches"=>0,"records"=>Any[]) for a in IDS)
    hazard_world=dynamic_hazards()
    if history!==nothing && dynamic_hazard_mode!="off"
        old=history.hazards
        for key in ("territory","patrol")
            for (k,v) in pairs(getproperty(old,Symbol(key)))
                hazard_world[key][String(k)]=k in (:position,:home,:center) ? Tuple(Float64.(v)) : v
            end
        end
        hazard_world["last_us"]=Int(old.last_us)
        if hazard_world["territory"]["target"]!==nothing
            hazard_world["territory"]["target"]=nothing;hazard_world["territory"]["mode"]="returning"
        end
    end
    sky=Dict(a=>orientation_state(a) for a in IDS)
    safety_loops=Dict(a=>BasicLoop(a*":safety";parent=a*":life",probabilistic=true,seed=choice_seed) for a in IDS)
    safety=Dict(a=>safety_state() for a in IDS)
    horizons=Dict(a=>horizon_state(a) for a in IDS)
    check(!exploration_horizon || landmark_routes,"horizon_requires_observed_fan")
    inertia=Dict(a=>inertia_state(a) for a in IDS)
    check(!movement_inertia || landmark_routes,"inertia_requires_observed_fan")
    check(!experience_bundles || (food_body && general_sleep),"bundles_require_hunger_sleep")
    check(!bundle_credit || experience_bundles,"credit_requires_bundles")
    check(!selection_trails || food_body,"trails_require_food_body")
    check(!(selection_trails && bundle_credit),"trail_bundle_credit_conflict")
    trails=Dict(a=>selection_trail_state(a) for a in IDS)
    bundles=Dict(a=>bundle_state(a) for a in IDS)
    hunger=Dict(a=>hunger_state(a) for a in IDS)
    check(digestion_mode in ("off","ordinary","meat"),"digestion_mode")
    guts=digestion_mode=="off" ? nothing : Dict(a=>Digestion() for a in IDS)
    meal_kind=digestion_mode=="meat" ? 2 : 1
    metabolism=Dict(a=>0. for a in IDS)
    check(!body_field || food_body,"body_field_requires_hunger")
    body_fields=Dict(a=>D("applied"=>0,"changed"=>0) for a in IDS)
    response_stats=Dict(a=>D("decisions"=>0,"request_decisions"=>0,"requests"=>0,"withheld"=>0,"give"=>0,"refuse"=>0,"experienced"=>0,"records"=>Any[]) for a in IDS)
    check(ground_mode in ("flat","patches","shadow"),"ground_mode")
    patches=ground_mode=="flat" ? Any[] : spec.ground_patches
    check(!ground_continuity || ground_perception,"ground_continuity_requires_perception")
    check(rho_profile in ("off","coarse","fine"),"rho_profile")
    check(rho_profile=="off" || (ground_continuity && continuous_descent),"rho_requires_structure_and_descent")
    check(skyline_mode in ("off","rays","subrays"),"skyline_mode")
    skyline_states=Dict(a=>skyline_state() for a in IDS)
    reposition_states=Dict(a=>reposition_state(a) for a in IDS)
    ground_models=Dict(a=>ground_memory(a) for a in IDS);ground_receipts=Dict{String,Any}()
    inherited_ground=history===nothing ? get(spec,:ground_history,nothing) : history.ground
    check(inherited_ground===nothing || ground_wear,"ground_history_requires_wear")
    wear=inherited_ground===nothing ? GroundWear(Int(clock.day_us)) : restore_wear(inherited_ground,Int(clock.day_us))
    artificial_roads=get(spec,:artificial_roads,Any[])
    check(isempty(artificial_roads) || ground_wear,"artificial_roads_require_ground_wear")
    # An inherited world already owns its aged roads; never rebuild on resume.
    inherited_ground===nothing && place_roads!(wear,artificial_roads)
    wear_offset=wear.now
    ground_views=Dict(a=>D("observations"=>0,"counts"=>D(),"records"=>Any[]) for a in IDS)
    land=get(spec,:landscape,nothing)
    if land!==nothing
        check(land.rule=="lw-riparian-base-v1" && isfinite(land.phase) && -.4<=land.phase<=.4,"landscape_rule")
    end
    dry=p->land===nothing || landscape_material(land,p)!="water"
    base_resistance_at=p->land===nothing ? ground_resistance(p,patches) : landscape_resistance(land,p)
    resistance_at=p->1+(base_resistance_at(p)-1)*(ground_wear && dry(p) ? wear_factor(wear,p) : 1.)
    ground_stats=Dict(a=>D("walks"=>0,"high_resistance_walks"=>0,"projection_decisions"=>0,"delta_mismatches"=>0,"records"=>Any[]) for a in IDS)
    food=Any[f for f in spec.food];dropped=cargo_ground()
    yaw=Dict(a=>0. for a in IDS);stock=Int[f.stock for f in food]
    if history!==nothing
        food=Any[f for f in history.food];stock=Int[v for v in history.stock]
        check(length(food)==length(stock) && all(>=(0),stock),"world_history_food")
        for item in history.cargo
            index=Int(item.index);check(1<=index<=length(stock),"world_history_cargo")
            dropped["origins"][index]=(source=item.source.source,dropper=occursin('/',String(item.source.dropper)) ? String(item.source.dropper) : "inherited/"*String(item.source.dropper),drop_operation=item.source.drop_operation)
            stock[index]==0 && (dropped["empty_at"][index]=0)
        end
    end
    check(regrowth_days isa Integer && regrowth_days>=1 && regrowth_capacity isa Integer && regrowth_capacity>=0,"regrowth_config")
    shared=history===nothing ? get(spec,:initial_shared_stock,0) : get(history,:shared_stock,0)
    check(shared isa Integer && !(shared isa Bool) && shared>=0 && (shared_stores || shared==0),"shared_stock")
    history!==nothing && check(get(history,:shared_stores,false)==shared_stores && get(history,:regrowth_days,1)==regrowth_days && get(history,:regrowth_capacity,0)==regrowth_capacity,"world_history_store_regrowth")
    storage_stats=D("deposited"=>0,"taken"=>0,"records"=>Any[])
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
    loops=Dict(a=>Dict(f=>BasicLoop(a*":"*f;parent=a*":food-security",threshold=Int(goal_switch_threshold),probabilistic=true,seed=choice_seed) for f in ("food","home")) for a in IDS)
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
    check(!shared_stores || all(v==0 for v in values(stores)),"shared_personal_conflict")
    initial=shared+sum(stock)+sum(values(w.inventory))+sum(values(stores));bounds=Int.(clock.phase_boundaries_us)
    replenished=0;replenishments=Any[]
    integrate(a,now,obs)=begin
        before=length(states[a]["records"])
        if states[a]["pending"]!==nothing
            states[a]=ingest(states[a],D("agent_id"=>a,"capture_us"=>now,
                "observation_id"=>"ob:$now:$a","social"=>obs),results[a])
        end
        pressure_poll!(live[a],states[a]["records"],before)
    end
    # Tick phases: world/clock -> observations -> learning/decision -> actions -> physiology -> daily consolidation.
    for sec in 0:days*div(clock.day_us,1_000_000)-1
        now=sec*1_000_000;w.seconds=sec
        (ground_wear || ground_perception) && advance_wear!(wear,wear_offset+now)
        lateral_views=lateral_side!="off" || continuous_descent || ground_continuity ? Dict(a=>lateral_obstacles(spec.obstacles,w.positions[a],yaw[a],"ob:$now:$a") for a in IDS) : nothing
        if ground_perception
            for a in IDS
                view=ground_appearance(w,a,yaw,wear,now;dry=dry)
                patterns=ground_patterns(view)
                record_ground_patterns!(ground_views[a],view,patterns)
                ground_continuity && update_ground!(ground_models[a],view,get(ground_receipts,a,nothing),patterns)
                ground_continuity && update_structures!(ground_models[a]["structures"],(rho_profile=="off" ? local_structures(view,lateral_views[a]) : rho_map(view,lateral_views[a],rho_profile)),get(ground_receipts,a,nothing))
            end
        end
        day=div(now,clock.day_us);local_us=mod(now,clock.day_us)
        if local_us==0
            push!(day_starts,physical())
            if day>0 || world_offset>0
                day>0 && (learning=Dict(a=>sleeper(day) for a in IDS))
                if renewable_food && mod(div(world_offset,clock.day_us)+day,regrowth_days)==0
                    added=replenish_food!(stock,spec.food;capacity=regrowth_capacity);replenished+=added
                    push!(replenishments,D("day"=>day,"us"=>now,"added"=>added))
                end
            end
        end
        phase=local_us<bounds[1] ? "orientation" : local_us<bounds[2] ? "exploration" : local_us<bounds[3] ? "return" : "night"
        if food_body
            for a in IDS
                hunger_update!(hunger[a],a,now,w.bodies[a].reserve)
                selection_trails && resolve_trail!(trails[a],a,w.bodies[a].reserve,"ob:$now:$a",now)
                bundle_credit && resolve_bundle_credit!(bundles[a],hunger[a])
            end
        end
        if dynamic_hazard_mode!="off"
            advance_hazards!(hazard_world,world_offset+now,w.positions,w.obstacles;patrol=dynamic_hazard_mode=="mixed")
        end
        hazard_sources=dynamic_hazard_mode=="off" ? spec.hazards : dynamic_hazard_sources(hazard_world,sec+div(world_offset,1_000_000);patrol=dynamic_hazard_mode=="mixed")
        if orientation
            for a in IDS;observe_sky!(sky[a],sky_sample(a,"ob:$now:$a",now,yaw[a],clock));end
        end
        obs=Dict(a=>observe(w,a) for a in IDS)
        moves=Dict(a=>movement_observation(w,a,yaw,food,stock;resistance_at=resistance_at,run_resistance_at=base_resistance_at,running=running,visual_obstacles=high) for a in IDS)
        homes=Dict(a=>home_observation(w,a,yaw,spec.home;visual_obstacles=high,range=skyline_mode=="off" ? 60 : 6) for a in IDS)
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
        landmarks=landmark_routes ? Dict(a=>landmark_fan(landmark_objects,w.positions[a],yaw[a],"ob:$now:$a";night=phase=="night",all_colors=general_landmarks) for a in IDS) : nothing
        skyline_views=skyline_mode=="off" ? nothing : Dict(a=>skyline_fan(skyline_objects,w.positions[a],yaw[a],"ob:$now:$a";subrays=skyline_mode=="subrays") for a in IDS)
        if skyline_views!==nothing
            for a in IDS;record_skyline!(skyline_states[a],skyline_views[a]);end
        end
        climbs=climbing ? Dict(a=>[climb_sample(w,a,yaw[a],i,low,high,base_resistance_at) for i in 0:4] for a in IDS) : nothing
        # Safety and learning share the same current, actor-local observation.
        hazard_views=(hazard_mode || general_sleep || movement_inertia || selection_trails) ? Dict(a=>hazard_observation(w,a,yaw,hazard_mode ? hazard_sources : Any[],sec+div(world_offset,1_000_000);visual_obstacles=high) for a in IDS) : nothing
        contexts=general_sleep ? Dict(a=>sleep_context(moves[a],hazard_views[a];climbs=climbs===nothing ? nothing : climbs[a]) for a in IDS) : nothing
        bundle_contexts=(experience_bundles || selection_trails) ? Dict(a=>bundle_context(w.inventory[a],w.bodies[a],moves[a],hazard_views[a]) for a in IDS) : nothing
        # Every actor plans from observations acquired before any actor acts.
        plans=D()
        for a in IDS
            integrate(a,now,obs[a]);o=obs[a];plan=nothing;home=homes[a]
            at_home=home!==nothing && home["distance"]<=1.25
            if experience_bundles
                form_bundle!(bundles[a],hunger[a],now)
                wake_bundles!(bundles[a],bundle_contexts[a],phase)
            end
            movement_inertia && observe_inertia!(inertia[a],a,now,inertia_view(moves[a],landmarks[a],hazard_views[a]))
            if basic_loop && haskey(pending,a)
                t=pop!(pending,a);s=loops[a][t.family]
                target=t.family=="home" ? home : isempty(moves[a]["visible"]) ? nothing : first(moves[a]["visible"])
                same=target!==nothing && (t.family=="home" || t.ref===nothing || target["ref"]==t.ref)
                value=t.question=="ground_extension" ? ground_extension_result(ground_models[a],s.trial.method,t.status,t.moved) : t.question=="movement_progress" ? t.status=="performed" && t.moved : t.question=="rested" ? t.status=="performed" : t.question=="load_reduced" ? t.status=="dropped" : t.question=="recovered" ? t.status=="recovered" : t.question=="landmark_progress" ? t.status=="performed" : t.question=="acquired" ? t.status=="picked_up" : t.question=="home_confirmed" ? at_home && t.status=="performed" : t.question=="target_observed" ? target!==nothing :
                    same ? target["distance"]<t.distance : nothing
                # No move/turn result is credited as acquired food or confirmed home.
                goal=t.family=="home" ? at_home : t.status in ("picked_up","recovered")
                if reposition && t.phase==phase
                    search_review_result!(reposition_states[a],t.family,s.trial.method,target!==nothing,t.status=="performed")
                end
                resolve_method!(s,t.source,t.phase==phase || value===true ? value : nothing,t.phase==phase || goal ? goal : nothing;
                    creditable=t.phase==phase && t.status=="performed" && (t.moved || value===true))
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
            elseif (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) && w.inventory[a]>0 && (guts===nothing || can_ingest(guts[a]))
                plan=D("action"=>"eat")
            elseif at_home && (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) && (shared_stores ? shared : stores[a])>0
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
                        candidates=search_candidates(moves[a],target,s)
                        if skyline_views!==nothing && returning && target===nothing
                            append!(candidates,skyline_home_candidates(skyline_states[a],skyline_views[a],moves[a]))
                        end
                        reposition && append!(candidates,reposition_candidates!(reposition_states[a],a,moves[a],now;purpose=family,home_unresolved=returning && target===nothing && s.H>=s.threshold,linked=s.receipt!==nothing && s.receipt.source=="op:$(now-1_000_000):$a"))
                        body_field && push!(candidates,D("method"=>"rest","action"=>"rest","priority"=>1.,"question"=>"rested"))
                        climbing && append!(candidates,climb_candidates(climbs[a],moves[a],target,s))
                        dropping && climbing && append!(candidates,drop_candidates(climbs[a],w.bodies[a],w.inventory[a],target))
                        if landmark_routes
                            if routes[a]["day"]!=day
                                empty!(routes[a]["cursors"]);routes[a]["day"]=day
                            end
                            # Direct currently observed goal wins over remembered detours.
                            if target===nothing
                                append!(candidates,landmark_candidates(moves[a],landmarks[a],routes[a],family,landmarks[a]["source"];include_routes=!relation_field,include_observed=!general_landmarks))
                                relation_field && append!(candidates,relation_candidates!(relation_fields[a],moves[a],landmarks[a],routes[a],family,landmarks[a]["source"]))
                            end
                        end
                        # Local paths are movement options for either purpose, even with a visible goal.
                        if ground_continuity
                            append!(candidates,ground_proposals(ground_models[a],moves[a]))
                            if rho_profile!="off" && rho_opening_candidates_enabled && target===nothing
                                append!(candidates,rho_opening_candidates(ground_models[a]["structures"]["observation"],moves[a]))
                            end
                        end
                        if exploration_horizon && phase=="exploration" && !returning && target===nothing
                            append!(candidates,horizon_candidates(horizons[a],landmarks[a],moves[a]))
                        end
                        if general_landmarks && target===nothing
                            structure_view=ground_continuity ? ground_models[a]["structures"]["observation"] : nothing
                            pool=observed_cues(landmarks[a],skyline_views===nothing ? nothing : skyline_views[a],structure_view,moves[a],hazard_views===nothing ? nothing : hazard_views[a],"ob:$now:$a";level=min(2,fld(s.H,s.threshold)))
                            append!(candidates,cue_candidates!(cue_states[a],pool,moves[a],s.H,s.threshold))
                        end
                        reposition && project_search_review!(reposition_states[a],candidates,s,target,family)
                        if parent_breadth
                            before=length(candidates)
                            candidates=parent_candidates(s,candidates)
                            bs=breadth_stats[a];bs["decisions"]+=1;bs["offered"]+=before
                            bs["admitted"]+=length(candidates);bs["restricted"]+=Int(length(candidates)<before)
                            level=s.H>=32 ? 2 : min(2,fld(s.H,s.threshold))
                            bs["levels"][level+1]+=1
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
                        if lateral_side!="off" && lateral_views!==nothing
                            lateral_trace=project_lateral!(candidates,moves[a],lateral_views[a],lateral_side,field_trace)
                            ls=lateral_stats[a];ls["evaluations"]+=1;ls["applied"]+=Int(lateral_trace["applied"])
                            push!(ls["records"],merge(lateral_trace,D("source"=>source)));length(ls["records"])>32 && popfirst!(ls["records"])
                        end
                        sleep_maintenance && wake_sleep_usage!(action_models[a],contexts[a],phase)
                        sleep_without=sleep_actions ? method_choice(s,candidates) : nothing
                        sleep_applied=sleep_actions && project_sleep_actions!(action_models[a],candidates,contexts[a],a,now)
                        sleep_selected=sleep_actions ? method_choice(s,candidates) : nothing
                        field_selected=sleep_actions ? sleep_without : method_choice(s,candidates)
                        body_before=body_field ? method_choice(s,candidates)["method"] : nothing
                        body_applied=body_field && project_body_methods!(candidates,hunger[a],w.bodies[a],phase)
                        body_selected=body_field ? method_choice(s,candidates)["method"] : nothing
                        bundle_trace=experience_bundles ? project_bundles!(bundles[a],candidates,s,bundle_contexts[a],phase,now;credit=bundle_credit) : nothing
                        trail_trace=selection_trails ? project_trails!(trails[a],candidates,s,bundle_contexts[a],phase) : nothing
                        if repetition_pressure
                            prior_choice=method_choice(s,candidates)
                            project_repetition!(repetitions[a],candidates)
                            after_choice=method_choice(s,candidates)
                            repetitions[a]["changes"]+=Int(prior_choice!==nothing && after_choice!==nothing && prior_choice["method"]!=after_choice["method"])
                        end
                        if rho_profile!="off" && rho_opening_candidates_enabled && target===nothing
                            project_rho_affordance!(candidates,ground_models[a]["structures"]["observation"])
                        end
                        plan=choose_method!(s,candidates,source)
                        general_landmarks && record_cue_selection!(cue_states[a],plan,s.H)
                        movement_inertia && record_continuation!(inertia[a],plan,s,source)
                        skyline_mode!="off" && plan["method"]=="skyline_home" && (skyline_states[a]["selections"]+=1)
                        reposition && startswith(plan["method"],"reposition_") && (reposition_states[a]["selected"]+=1)
                        selection_trails && (plan["trail_trace"]=trail_trace)
                        experience_bundles && (plan["bundle_trace"]=bundle_trace)
                        if body_applied
                            body_fields[a]["applied"]+=1;body_fields[a]["changed"]+=Int(body_before!=body_selected)
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
                        landmark_routes && get(plan,"route",nothing)!==nothing && (routes[a]["selections"]+=1)
                        if !continuous_descent && adaptive_approach
                            refine_approach!(plan,target,w,a,yaw,resistance_at)
                        end
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
            if orientation && plan["action"]=="scan" && !get(plan,"safety",false) && !(general_landmarks && haskey(plan,"cue_kind"))
                plan["scan_angle"]=orientation_scan!(sky[a],clock)
            end
            plan["purpose_family"]=returning ? "home" : "food"
            if continuous_descent && plan["action"] in ("walk","run")
                visible=moves[a]["visible"]
                goal=returning ? home : isempty(visible) ? nothing : first(visible)
                structure_state=ground_continuity ? ground_models[a]["structures"] : nothing
                applied=steer_structure!(plan,goal,lateral_views[a],structure_state,w,a,yaw,
                    plan["action"]=="run" ? base_resistance_at : resistance_at)
                gs=ground_stats[a]
                gs["steering_attempts"]=get(gs,"steering_attempts",0)+1
                gs["steering_applied"]=get(gs,"steering_applied",0)+Int(applied)
                gs["steering_structured"]=get(gs,"steering_structured",0)+Int(applied && get(plan,"structure_groups",0)>0)
                if haskey(plan,"rho_profile")
                    gs["rho_profile"]=plan["rho_profile"]
                    gs["rho_applied"]=get(gs,"rho_applied",0)+1
                    gs["rho_last_potential"]=plan["potential"]
                    gs["rho_last_source"]=plan["rho_source"]
                end
            end
            bundle_credit && (plan["bundle_parent"]=D("actor"=>a,"due"=>hunger[a]["due"],"H"=>hunger[a]["H"]))
            selection_trails && (plan["trail_parent"]=(reserve=w.bodies[a].reserve,H=hunger[a]["H"]))
            plans[a]=plan
        end
        # Ordered action resolution: receipts are stamped at the end of this second.
        w.seconds=sec+1
        for a in IDS
            plan=plans[a];action=plan["action"];op="op:$now:$a";p=w.positions[a];before_yaw=yaw[a];status="performed"
            repetition_before=w.bodies[a]
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
                yaw[a]=mod(yaw[a]+get(plan,"approach_angle",ANGLES[plan["direction"]+1])+180,360)-180
                s,c=sincos(deg2rad(yaw[a]))
                span=get(plan,"approach_span",action=="run" ? 1.5*(1-w.bodies[a].damage) : .5)
                q=(p[1]+s*span,p[2]+c*span)
                clear=!any(o->segment_hit(p,q,o,.2),w.obstacles)
                sample_span=get(plan,"approach_span",(action=="run" ? 1.5 : .5)*(1-w.bodies[a].damage))
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
                    comparable=!haskey(plan,"approach_angle") && expected["clear"]==clear && expected["load"]==w.inventory[a] && expected["resistance"]==resistance
                    match=comparable && expected["expected_delta"]==delta && expected["resistance"]==resistance
                    comparable && !match && (g["delta_mismatches"]+=1)
                    push!(g["records"],D("source"=>op,"load"=>w.inventory[a],"resistance"=>resistance,
                        "status"=>status,"expected_delta"=>deepcopy(expected["expected_delta"]),"actual_delta"=>delta,
                        "comparable"=>comparable,"matches"=>match))
                    length(g["records"])>32 && popfirst!(g["records"])
                end
                d=min(d,get(plan,"approach_span",d))
                w.positions[a]=(p[1]+s*d,p[2]+c*d);distance[a]+=d
            elseif action in ("eat","request","give","refuse","warn","withdraw","wait")
                premeal=w.bodies[a]
                r=communicate!(w,a,op,action,get(plan,"target",nothing),get(plan,"reply_to",nothing));status=r["status"]
                if status=="ate"
                    if guts!==nothing
                        w.bodies[a]=premeal # food transfer stays committed; energy waits for digestion
                        ingest!(guts[a],meal_kind,premeal.reserve,now)
                    end
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
                        if shared_stores
                            shared+=w.inventory[a];storage_stats["deposited"]+=w.inventory[a]
                        else
                            stores[a]+=w.inventory[a]
                        end
                        w.inventory[a]=0
                    elseif legal && (shared_stores ? shared : stores[a])>0
                        if shared_stores
                            shared-=1;storage_stats["taken"]+=1
                        else
                            stores[a]-=1
                        end
                        w.inventory[a]+=1
                        push!(cargo[a],nothing)
                    else
                        status="unavailable"
                    end
                end
            end
            if shared_stores && action in ("deposit","retrieve")
                push!(storage_stats["records"],D("actor"=>a,"operation"=>op,"action"=>action,"status"=>status,"stock_after"=>shared))
                length(storage_stats["records"])>32 && popfirst!(storage_stats["records"])
            end
            if ground_wear && action=="walk" && status=="performed"
                tread!(wear,op,a,p,w.positions[a],wear_offset+now;walkable=dry)
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
                    experience_bundles && sleep_bundles!(bundles[a],day,general[a]["formation_us"])
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
            if repetition_pressure
                method=get(plan,"method",nothing)
                # Protected/automatic actions break the chain; no forced wake-up.
                active=phase in ("exploration","return") && method!==nothing
                view=(phase,leg,Tuple((r["clear"],r["status"]) for r in moves[a]["energy"]["rows"]),Tuple((f["appearance"],round(f["distance"];digits=1)) for f in moves[a]["visible"]))
                b=w.bodies[a]
                changed=w.positions[a]!=p || b.strain<repetition_before.strain-1e-9 || b.burst>repetition_before.burst+1e-9 || status in ("picked_up","recovered","dropped","ate","transferred")
                repetition_result!(repetitions[a],op,now+1_000_000,active ? method : nothing,view;changed=changed)
            end
            if haskey(pending,a)
                pending[a]=merge(pending[a],(status=status,moved=w.positions[a]!=p,))
            end
            if movement_inertia
                inertia[a]["receipt"]=(actor=a,source=op,executed_us=now+1_000_000,phase=phase,family=leg,
                    action=action,status=status,moved=w.positions[a]!=p,method=get(plan,"method",nothing),route=get(plan,"route",nothing))
            end
            if exploration_horizon
                observed_status=status=="performed" ? (action in ("walk","run","climb") && w.positions[a]!=p ? "moved" : action=="scan" ? "turned" : action=="rest" ? "waited" : status) : status
                horizon_result!(horizons[a],a,op,phase,observed_status,status in ("picked_up","recovered"))
                startswith(get(plan,"method",""),"horizon_") && (horizons[a]["selections"]+=1)
            end
            if experience_bundles
                use_bundles!(bundles[a],get(plan,"bundle_trace",nothing),get(plan,"method",nothing),status)
                bundle_credit && admit_bundle_credit!(bundles[a],get(plan,"bundle_trace",nothing),get(plan,"method",nothing),status,plan["bundle_parent"],op)
                remember_bundle!(bundles[a],D("actor"=>a,"operation"=>op,"capture_us"=>now,"executed_us"=>now+1_000_000,
                    "context"=>bundle_contexts[a],"phase"=>phase,"action"=>action,"outcome"=>status,"method"=>get(plan,"method",nothing)))
            end
            if selection_trails
                bt=get(plan,"bundle_trace",nothing);refs=bt===nothing ? String[] : bt["contributors"]
                use_trail!(trails[a],a,op,get(plan,"trail_trace",nothing),get(plan,"method",nothing),status,plan["trail_parent"].reserve,plan["trail_parent"].H,refs)
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
        advance_physiology!(w,metabolism,guts,food_body)
        @assert shared+sum(stock)+sum(values(w.inventory))+sum(values(stores))+w.consumed==initial+replenished
        if mod(now+1_000_000,clock.day_us)==0
            for a in IDS
                integrate(a,now+1_000_000,observe(w,a))
                cycle=learning[a]["sleep"]["cycle"]
                states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>now+1_000_000)),a)
            end
            push!(daily,D("physical"=>physical(),"sleep"=>deepcopy(learning),"counts"=>deepcopy(counts),
                "shared_stock"=>shared,"ground"=>sum(stock),"consumed"=>w.consumed,"replenished_food"=>replenished))
        end
    end
    ground_wear && advance_wear!(wear,wear_offset+Int(days*clock.day_us))
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
    environment=D("rule"=>"native-cohort-world-v1","day_us"=>clock.day_us,"next_us"=>world_offset+days*clock.day_us,
        "shared_stores"=>shared_stores,"shared_stock"=>shared,"regrowth_days"=>regrowth_days,"regrowth_capacity"=>regrowth_capacity,"landscape"=>land,"obstacles"=>spec.obstacles,"renewal_targets"=>spec.food,"ground_patches"=>spec.ground_patches,
        "renewable"=>renewable_food,"hazard_mode"=>dynamic_hazard_mode,"dropping"=>dropping,"wear_enabled"=>ground_wear,
        "food"=>deepcopy(food),"stock"=>copy(stock),"ground"=>ground_wear ? wear_snapshot(wear) : nothing,
        "hazards"=>dynamic_hazard_mode!="off" ? deepcopy(hazard_world) : nothing,
        "cargo"=>[D("index"=>i,"source"=>dropped["origins"][i]) for i in sort(collect(keys(dropped["origins"])))])
    merge(guts===nothing ? D() : D("digestion"=>D(a=>digestion_snapshot(guts[a]) for a in IDS)),lateral_side=="off" ? D() : D("lateral"=>lateral_stats),D("observed_cues"=>general_landmarks ? cue_states : nothing,"shared_stock"=>shared,"shared_storage"=>shared_stores ? storage_stats : nothing,"skyline"=>skyline_mode=="off" ? nothing : skyline_states,"reposition"=>reposition ? reposition_states : nothing,"world_checkpoint"=>environment,"selection_trails"=>selection_trails ? trails : nothing,"experience_bundles"=>experience_bundles ? D(a=>bundle_snapshot(bundles[a]) for a in IDS) : nothing,"exploration_horizon"=>exploration_horizon ? horizons : nothing,"movement_inertia"=>movement_inertia ? inertia : nothing,"body_field"=>body_field ? body_fields : nothing,"relation_field"=>relation_field ? relation_fields : nothing,"orientation"=>orientation ? sky : nothing,"safety_methods"=>continuous_safety ? D(a=>loop_snapshot(safety_loops[a]) for a in IDS) : nothing,"world_hazards"=>dynamic_hazard_mode!="off" ? hazard_world : nothing,"food_body"=>food_body ? D("hunger"=>hunger,"metabolic_loss"=>metabolism) : nothing,"ground_continuity"=>ground_continuity ? ground_models : nothing,"ground_perception"=>ground_perception ? ground_views : nothing,"ground_wear"=>ground_wear ? wear_snapshot(wear) : nothing,"sleep_action_models"=>sleep_actions ? action_models : nothing,"general_sleep"=>general_sleep ? general : nothing,"social_response"=>(social_response || food_body) ? response_stats : nothing,"ended_us"=>days*clock.day_us,"initial_food"=>initial,"ground"=>sum(stock),"consumed"=>w.consumed,
        "replenished_food"=>replenished,"replenishments"=>replenishments,
        "dropped_cargo"=>dropping ? D("dropped"=>dropped["dropped"],"recovered"=>dropped["recovered"],"cross_actor"=>dropped["cross_actor"],"records"=>dropped["records"],"sites"=>[D("index"=>i,"x"=>food[i].x,"z"=>food[i].z,"stock"=>stock[i],"source"=>dropped["origins"][i]) for i in sort(collect(keys(dropped["origins"])))]) : nothing,"climbing"=>climbing ? climb_stats : nothing,"running"=>running ? run_stats : nothing,"ground_effects"=>ground_mode=="flat" ? nothing : ground_stats,"safety"=>hazard_mode ? deepcopy(safety) : nothing,"repetition_pressure"=>repetition_pressure ? repetitions : nothing,"parent_breadth"=>parent_breadth ? breadth_stats : nothing,"counts"=>counts,"events"=>events,"final_agents"=>terminal,"daily"=>daily,"day_starts"=>day_starts))
end
