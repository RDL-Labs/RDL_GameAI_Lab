include("../perception/home_distance.jl")
include("../decision/goal_arrival.jl")
include("checkpoint.jl")
include("physiology.jl")
include("../../ecology/lw_grazing/LWGrazing.jl")
include(joinpath(@__DIR__, "../configured_paths/daily_delivery.jl"))
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
include(joinpath(@__DIR__, "../learning/social_relations.jl"))
include(joinpath(@__DIR__, "../decision/social_response.jl"))
include(joinpath(@__DIR__, "../decision/food_body.jl"))
include(joinpath(@__DIR__, "../decision/embedded_rest.jl"))
include(joinpath(@__DIR__, "../decision/night_fear.jl"))
include(joinpath(@__DIR__, "../configured_paths/include.jl"))
include(joinpath(@__DIR__, "../learning/experience_bundles.jl"))
include(joinpath(@__DIR__, "../learning/selection_trail.jl"))
include(joinpath(@__DIR__, "../learning/general_sleep.jl"))
include(joinpath(@__DIR__, "../learning/sleep_action_model.jl"))
include(joinpath(@__DIR__, "../learning/sleep_maintenance.jl"))
include(joinpath(@__DIR__, "moving.jl"))
include(joinpath(@__DIR__, "../../body/load.jl"))
include(joinpath(@__DIR__, "../world/food_resources.jl"))
include(joinpath(@__DIR__, "../world/food_exchange.jl"))
include(joinpath(@__DIR__, "../world/portable_items.jl"))
include(joinpath(@__DIR__, "../configured_paths/item_actions.jl"))
include(joinpath(@__DIR__, "../decision/basic_loop.jl"))
include(joinpath(@__DIR__, "../decision/prediction_result.jl"))
include(joinpath(@__DIR__, "../decision/incidental_items.jl"))
include(joinpath(@__DIR__, "../learning/social_aid.jl"))
include(joinpath(@__DIR__, "../decision/food_exchange.jl"))
include(joinpath(@__DIR__, "../perception/social_sight.jl"))
include(joinpath(@__DIR__, "../decision/social_approach.jl"))
include(joinpath(@__DIR__, "../decision/approach.jl"))
include(joinpath(@__DIR__, "../decision/local_descent.jl"))
include(joinpath(@__DIR__, "../decision/repetition_pressure.jl"))
include(joinpath(@__DIR__, "../decision/safety_methods.jl"))
include(joinpath(@__DIR__, "../decision/movement_inertia.jl"))
include(joinpath(@__DIR__, "../decision/exploration_horizon.jl"))
include(joinpath(@__DIR__, "../learning/landmark_routes.jl"))
include(joinpath(@__DIR__, "../perception/observed_cues.jl"))
include(joinpath(@__DIR__, "../decision/relation_field.jl"))
include(joinpath(@__DIR__, "../learning/mb_recognition.jl"))
include(joinpath(@__DIR__, "../learning/mb_map.jl"))
include(joinpath(@__DIR__, "../learning/mb_transfer.jl"))
include(joinpath(@__DIR__, "../learning/mb_local_repair.jl"))
include(joinpath(@__DIR__, "../learning/mb_routes.jl"))
include(joinpath(@__DIR__, "../learning/mb_censored.jl"))
include(joinpath(@__DIR__, "../learning/mb_parent.jl"))
include(joinpath(@__DIR__, "../learning/mb_return_outlook.jl"))
include(joinpath(@__DIR__, "../learning/mb_chunks.jl"))
include(joinpath(@__DIR__, "../learning/mb_goal_cues.jl"))
include(joinpath(@__DIR__, "../learning/mb_exploration_relations.jl"))
include(joinpath(@__DIR__, "../learning/mb_relation_compression.jl"))
include(joinpath(@__DIR__, "../learning/mb_place.jl"))
include(joinpath(@__DIR__, "../learning/mb_sleep.jl"))
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
        get(f,:renewable,true) || continue # Finite placed provisions are not vegetation.
        amount=max(0,(capacity>0 ? capacity : Int(f.stock))-stock[i]);stock[i]+=amount;added+=amount
    end
    added
end

function lw_day(spec,clock;days=1,basic_loop=false,landmark_routes=false,harvest_sleep=false,model_field=false,model_review=false,model_relearn=false,renewable_food=false,hazard_mode=false,ground_mode="flat",running=false,climbing=false,low_obstacles=false,dropping=false,social_response=false,general_sleep=false,sleep_actions=false,sleep_retention=false,sleep_maintenance=false,ground_wear=false,ground_perception=false,ground_continuity=false,food_body=false,dynamic_hazard_mode="off",continuous_safety=false,orientation=false,relation_field=false,body_field=false,movement_inertia=false,exploration_horizon=false,experience_bundles=false,bundle_credit=false,selection_trails=false,reposition=false,skyline_mode="off",shared_stores=false,regrowth_days=1,regrowth_capacity=0,goal_switch_threshold=2,lateral_side="off",parent_breadth=false,repetition_pressure=false,adaptive_approach=false,continuous_descent=false,rho_profile="off",rho_opening_candidates_enabled=true,digestion_mode="off",choice_seed=0,general_landmarks=false,body_purpose=false,mb_simulation=false,mb_chunks=false,mb_sleep=false,configured_observation_enabled=false,configured_home_rest_enabled=false,embedded_rest_enabled=false,night_fear_enabled=false,daily_delivery_enabled=false,camp_safe_zone=false,mb_sensitivities=D(),mb_similarity_learning=true,checkpoint_dir=nothing,resume_from=nothing,checkpoint_identity="")
    check(goal_switch_threshold isa Integer && !(goal_switch_threshold isa Bool) && 1<=goal_switch_threshold<=30,"goal_switch_threshold")
    check(days isa Int && 1<=days<=90,"lw_days")
    check(!landmark_routes || basic_loop,"landmark_loop_required")
    check(!general_landmarks || landmark_routes,"general_landmarks_requires_routes")
    check(!mb_simulation || (basic_loop && landmark_routes),"mb_simulation_requires_observed_loop")
    check(!mb_sleep || (mb_simulation && general_sleep),"mb_sleep_requires_map_and_sleep")
    # Shared MB search replaces the old local performed/blocked priority model in this mode.
    if mb_sleep;sleep_actions=false;sleep_maintenance=false;end
    check(!mb_chunks || mb_simulation,"mb_chunks_require_map")
    check(!configured_observation_enabled || mb_simulation,"observation_requires_mb_map")
    check(!configured_home_rest_enabled || (mb_simulation && basic_loop),"home_rest_requires_mb_loop")
    check(!embedded_rest_enabled || (mb_simulation && basic_loop),"embedded_rest_requires_mb_loop")
    check(!night_fear_enabled || (mb_simulation && basic_loop),"night_fear_requires_mb_loop")
    mb_maps=Dict(a=>mb_map_state(a;chunks=mb_chunks,sensitivity=get(mb_sensitivities,a,D())) for a in IDS)
    navigation_mode=get(spec,:mb_navigation_mode,"explicit_join")
    check(navigation_mode in ("explicit_join","goal_cues"),"mb_navigation_mode")
    check(navigation_mode!="goal_cues" || (mb_simulation && mb_chunks && general_landmarks),"goal_cues_requires_observed_mb")
    for a in IDS;mb_maps[a]["navigation_mode"]=navigation_mode;end
    scene_abstraction=get(spec,:mb_scene_abstraction,"standard")
    check(scene_abstraction in MB_SCENE_ABSTRACTIONS,"mb_scene_abstraction")
    for a in IDS;mb_maps[a]["scene_abstraction"]=scene_abstraction;end
    exploration_relations=get(spec,:mb_exploration_relations,false)
    check(!exploration_relations || (mb_simulation && general_landmarks),"exploration_relations_requires_mb")
    for a in IDS;mb_maps[a]["exploration_relations_enabled"]=exploration_relations;end
    inherited_mb=get(spec,:learned_mb_transfer,nothing)
    if inherited_mb!==nothing
        check(mb_simulation && basic_loop,"transfer_requires_mb_loop")
        inherited_mb=JSON3.read(JSON3.write(inherited_mb),Dict{String,Any})
        check(all(a->a in IDS,keys(inherited_mb["maps"])),"transfer_roster")
        for a in keys(inherited_mb["maps"]);mb_transfer!(mb_maps[a],inherited_mb["maps"][a],inherited_mb["ended_us"]);end
    end
    embedded_rest_enabled && foreach(m->m["embedded_rest"]=embedded_rest_state(),values(mb_maps))
    night_fear_enabled && foreach(m->m["night_fear"]=night_fear_state(),values(mb_maps))
    for m in values(mb_maps);m["recognition"]["metric"]["enabled"]=mb_similarity_learning;end
    rho_profile=="home-distance" && foreach(m->m["home_distance"]=home_distance_state(),values(mb_maps))
    check(rho_profile!="home-distance" || mb_simulation,"home_distance_requires_mb")
    cue_states=Dict(a=>cue_stats() for a in IDS)
    check(!model_field || (harvest_sleep && basic_loop),"harvest_field_requires_learning_loop")
    check(!model_review || harvest_sleep,"harvest_review_requires_learning")
    check(!model_relearn || model_review,"harvest_relearn_requires_review")
    check(lateral_side in ("off","left","right"),"lateral_side")
    repetitions=Dict(a=>repetition_state() for a in IDS)
    breadth_stats=Dict(a=>D("decisions"=>0,"offered"=>0,"admitted"=>0,"restricted"=>0,"levels"=>[0,0,0]) for a in IDS)
    lateral_stats=Dict(a=>D("evaluations"=>0,"applied"=>0,"records"=>Any[]) for a in IDS)
    # Visual-only markers (e.g. flames) are perceived but do not block movement or home sightlines.
    visual_objects=hasproperty(spec,:visual_landmarks) ? vcat(collect(spec.obstacles),collect(spec.visual_landmarks)) : spec.obstacles
    landmark_objects=landmark_routes ? prepare_landmark_objects(visual_objects) : nothing
    skyline_objects=skyline_mode=="off" ? nothing : prepare_skyline_objects(visual_objects)
    history=get(spec,:world_history,nothing)
    history!==nothing && (get(history,:portable_items,nothing)!==nothing || !isempty(get(spec,:portable_items,Any[])) || !isempty(get(spec,:loose_items,Any[]))) && error("portable item world transfer requires daily checkpoints")
    history!==nothing && get(history,:food_exchange,nothing)!==nothing && error("food exchange world transfer requires daily checkpoints")
    history!==nothing && get(history,:food_resources,nothing)!==nothing && error("typed food world transfer requires daily checkpoints")
    history!==nothing && get(history,:wildlife,nothing)!==nothing && error("grazing world transfer requires daily checkpoints")
    wildlife=LWGrazing.build(spec,clock;low_obstacles)
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
    check(!body_purpose || food_body,"body_purpose_requires_hunger")
    check(!daily_delivery_enabled || (mb_simulation && basic_loop),"daily_delivery_requires_mb_loop")
    if daily_delivery_enabled
        for a in IDS;mb_maps[a]["configured_daily_delivery"]=configured_daily_delivery_state();end
    end
    configured_body_states=Dict(a=>configured_body_state(a) for a in IDS)
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
    check(rho_profile in ("off","coarse","fine","home-distance"),"rho_profile")
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
    observation_states=Dict(a=>configured_observation_state(w.positions[a]) for a in IDS)
    configured_camp_landmark=get(spec,:configured_camp_landmark,false)
    configured_camp_experience=get(spec,:configured_camp_experience,false)
    goal_arrival_enabled=get(spec,:goal_arrival,false)
    check(!goal_arrival_enabled || mb_simulation,"goal_arrival_requires_mb")
    goal_arrival_enabled && foreach(a->(mb_maps[a]["goal_arrival"]=D(g=>goal_arrival_state() for g in ("home","food"))),IDS)
    check(!configured_camp_experience || configured_camp_landmark,"camp_experience_requires_landmark")
    configured_camp_experience && foreach(a->(mb_maps[a]["place_mb"]=mb_place_state()),IDS)
    check(!configured_camp_landmark || (configured_observation_enabled && landmark_routes),"camp_landmark_requires_observation")
    configured_camp_landmark && foreach(a->(observation_states[a]["camp_landmark"]=configured_camp_landmark_state()),IDS)
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
    loops=Dict(a=>Dict(f=>BasicLoop(a*":"*f;parent=a*(body_purpose ? ":energy-maintenance" : ":food-security"),threshold=Int(goal_switch_threshold),probabilistic=true,seed=choice_seed) for f in ("food","home")) for a in IDS)
    if inherited_mb!==nothing
        for a in keys(inherited_mb["maps"]),f in ("food","home");mb_transfer_methods!(loops[a][f],inherited_mb["methods"][a][f]);end
    end
    check(!sleep_maintenance || sleep_actions,"maintenance_needs_sleep_actions")
    check(!sleep_actions || general_sleep,"sleep_actions_need_review")
    action_models=Dict(a=>sleep_action_state(a) for a in IDS)
    general=Dict(a=>general_sleep_state() for a in IDS)
    purposes=Dict(a=>return_purpose() for a in IDS)
    pending=Dict{String,Any}();daily=Any[];day_starts=Any[]
    physical()=D(a=>D("position"=>collect(w.positions[a]),"yaw"=>yaw[a],"body"=>bodydict(w.bodies[a]),
        "body_purpose"=>body_purpose ? deepcopy(configured_body_states[a]) : nothing,"return_purpose"=>deepcopy(purposes[a]),"inventory"=>w.inventory[a],"personal_stock"=>stores[a],"social_count"=>length(states[a]["records"]),
        "social_model"=>deepcopy(states[a]["model"]),"loops"=>D(f=>loop_snapshot(s) for (f,s) in loops[a]),
        "routes"=>landmark_routes ? deepcopy(routes[a]) : nothing,"max_radius_observer_only"=>max_radius[a],
        "harvest"=>harvest_sleep ? deepcopy(harvest[a]) : nothing) for a in IDS)
    for (i,a) in enumerate(IDS)
        w.inventory[a]=spec.initial_inventory[i];w.bodies[a]=Body(10.,0.,spec.reserve[i],0.)
        append!(cargo[a],fill(nothing,w.inventory[a]))
        hasproperty(spec,:initial_personal_stock) && (stores[a]=spec.initial_personal_stock[i])
    end
    check(!shared_stores || all(v==0 for v in values(stores)),"shared_personal_conflict")
    foods=food_resources(spec,w,food,stock,shared,stores)
    items=portable_items(spec,w)
    item_actions=configured_item_actions(spec,items!==nothing)
    incidental_enabled=get(spec,:incidental_items,false)
    check(incidental_enabled isa Bool,"incidental_items_flag")
    check(!incidental_enabled || (items!==nothing && basic_loop),"incidental_items_require_world_and_loop")
    incidental_items=incidental_enabled ? D(a=>incidental_item_state(a,choice_seed) for a in IDS) : nothing
    incidental_snapshot()=D(a=>incidental_item_snapshot(incidental_items[a]) for a in IDS)
    exchange_enabled=get(spec,:food_exchange,false)
    check(exchange_enabled isa Bool,"food_exchange_flag")
    check(!exchange_enabled || (foods!==nothing && !shared_stores),"food_exchange_requires_personal_typed_food")
    relationship_enabled=get(spec,:social_relationships,false)
    check(relationship_enabled isa Bool,"social_relationships_flag")
    trades=exchange_enabled ? food_trade_state(choice_seed;relational=relationship_enabled) : nothing
    relations=relationship_enabled ? D(a=>social_relations_state(a;relational=true) for a in IDS) : nothing
    if relations!==nothing
        for a in IDS
            relations[a]["aid"]=social_aid_state(a;seed=choice_seed)
            relations[a]["approach"]=D("proposed"=>0,"selected"=>0,"contacts"=>0,"records"=>Any[])
            states[a]["records_pruned"]=0
        end
    end
    aid_view(a)=relations===nothing ? live[a].state : social_aid_pressure(relations[a]["aid"])
    relation_snapshot()=D(a=>social_relations_snapshot(relations[a]) for a in IDS)
    initial=shared+sum(stock)+sum(values(w.inventory))+sum(values(stores));bounds=Int.(clock.phase_boundaries_us)
    replenished=0;replenishments=Any[]
    integrate(a,now,obs)=begin
        before=length(states[a]["records"])
        old_pending=states[a]["pending"]
        if states[a]["pending"]!==nothing
            states[a]=ingest(states[a],D("agent_id"=>a,"capture_us"=>now,
                "observation_id"=>"ob:$now:$a","social"=>obs),results[a])
        end
        relations===nothing && pressure_poll!(live[a],states[a]["records"],before)
        if relations!==nothing && length(states[a]["records"])>before
            r=states[a]["records"][old_pending["message_id"]]
            evidence=social_aid_finish!(relations[a]["aid"],r["message_id"],r["target"],r["outcome"],r["tick"];
                received_kind=get(r,"received_kind",nothing),source=r["source_observation_id"])
            social_relation_event!(relations[a],r["target"],"aid_received",r["message_id"],r["tick"];outcome=r["outcome"],
                value=r["outcome"]=="given" && evidence["actual"]!==nothing ? evidence["actual"] : 0.,
                context=get(old_pending,"social_context",nothing),food_kind=get(r,"received_kind",0))
            # The new MB holds consolidated evidence; the old packet window is
            # only a bounded diagnostic history, not a second lifelong model.
            social_record_window!(states[a])
        end
    end
    # Tick phases: world/clock -> observations -> learning/decision -> actions -> physiology -> daily consolidation.
    checkpoint_code=(checkpoint_dir!==nothing || resume_from!==nothing) ? checkpoint_code_hash() : ""
    start_sec=0
    if resume_from!==nothing
        saved=checkpoint_load(resume_from,checkpoint_identity,checkpoint_code,days)
        @lw_restore saved.state
        start_sec=saved.day*div(clock.day_us,1_000_000)
    end
    for sec in start_sec:days*div(clock.day_us,1_000_000)-1
        now=sec*1_000_000;w.seconds=sec
        # Both populations sense the pre-action world. Rabbit actions use this
        # frozen perception after human actions, before the common day boundary.
        wildlife!==nothing && LWGrazing.prepare!(wildlife,[w.positions[a] for a in IDS],sec)
        (ground_wear || ground_perception) && advance_wear!(wear,wear_offset+now)
        lateral_views=lateral_side!="off" || continuous_descent || ground_continuity ? Dict(a=>lateral_obstacles(spec.obstacles,w.positions[a],yaw[a],"ob:$now:$a") for a in IDS) : nothing
        rho_baselines=D()
        if ground_perception
            for a in IDS
                view=ground_appearance(w,a,yaw,wear,now;dry=dry)
                patterns=ground_patterns(view)
                record_ground_patterns!(ground_views[a],view,patterns)
                ground_continuity && update_ground!(ground_models[a],view,get(ground_receipts,a,nothing),patterns)
                if ground_continuity && goal_arrival_enabled
                    # Consume odometry before this tick's home observation anchors the estimate.
                    rho_baselines[a]=rho_profile=="home-distance" ? home_distance_profile!(mb_maps[a]["home_distance"],get(ground_receipts,a,nothing)) : rho_profile
                end
                ground_continuity && !goal_arrival_enabled && update_structures!(ground_models[a]["structures"],(rho_profile=="off" ? local_structures(view,lateral_views[a]) : rho_map(view,lateral_views[a],rho_profile=="home-distance" ? home_distance_profile!(mb_maps[a]["home_distance"],get(ground_receipts,a,nothing)) : rho_profile)),get(ground_receipts,a,nothing))
            end
        end
        day=div(now,clock.day_us);local_us=mod(now,clock.day_us)
        if local_us==0
            push!(day_starts,physical())
            if day>0 || world_offset>0
                day>0 && (learning=Dict(a=>sleeper(day) for a in IDS))
                if renewable_food && mod(div(world_offset,clock.day_us)+day,regrowth_days)==0
                    old_stock=foods===nothing ? nothing : copy(stock)
                    added=replenish_food!(stock,spec.food;capacity=regrowth_capacity);replenished+=added
                    if foods!==nothing
                        for i in eachindex(stock);foods.added[foods.site_kinds[i]]+=stock[i]-old_stock[i];end
                    end
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
        if items!==nothing
            item_expire!(items,now)
            for a in IDS
                obs[a]["items"]=item_visible(items,w,spec.home,a,yaw[a],now;visual_obstacles=high)
            end
        end
        social_views=relations===nothing ? nothing : Dict(a=>social_sight(w,a,yaw[a],now;visual_obstacles=high) for a in IDS)
        relations!==nothing && foreach(a->social_relations_observe!(relations[a],obs[a],now),IDS)
        trade_views=trades===nothing ? nothing : food_trade_views!(trades,foods,w,spec.home,now;relations=relations)
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
        # Carried emitters follow the observed body; stored objects are hidden.
        current_landmarks=landmark_routes && items!==nothing ? vcat(landmark_objects,item_light_objects(items,w)) : landmark_objects
        landmarks=landmark_routes ? Dict(a=>landmark_fan(current_landmarks,w.positions[a],yaw[a],"ob:$now:$a";night=phase=="night",all_colors=general_landmarks) for a in IDS) : nothing
        skyline_views=skyline_mode=="off" ? nothing : Dict(a=>skyline_fan(skyline_objects,w.positions[a],yaw[a],"ob:$now:$a";subrays=skyline_mode=="subrays") for a in IDS)
        if skyline_views!==nothing
            for a in IDS;record_skyline!(skyline_states[a],skyline_views[a]);end
        end
        climbs=climbing ? Dict(a=>[climb_sample(w,a,yaw[a],i,low,high,base_resistance_at) for i in 0:4] for a in IDS) : nothing
        # Safety and learning share the same current, actor-local observation.
        hazard_views=(hazard_mode || general_sleep || movement_inertia || selection_trails || night_fear_enabled) ? Dict(a=>hazard_observation(w,a,yaw,hazard_mode ? hazard_sources : Any[],sec+div(world_offset,1_000_000);visual_obstacles=high,safe_home=camp_safe_zone ? spec.home : nothing) for a in IDS) : nothing
        contexts=general_sleep ? Dict(a=>sleep_context(moves[a],hazard_views[a];climbs=climbs===nothing ? nothing : climbs[a]) for a in IDS) : nothing
        bundle_contexts=(experience_bundles || selection_trails) ? Dict(a=>bundle_context(w.inventory[a],w.bodies[a],moves[a],hazard_views[a]) for a in IDS) : nothing
        # Every actor plans from observations acquired before any actor acts.
        plans=D()
        for a in IDS
            integrate(a,now,obs[a]);o=obs[a];plan=nothing;home=homes[a]
            rho_profile=="home-distance" && observe_home_distance!(mb_maps[a]["home_distance"],home)
            at_home=home!==nothing && home["distance"]<=1.25
            mb_simulation && mb_observe!(mb_maps[a],landmarks[a],now;home=at_home,food=any(f->f["distance"]<=1.25,moves[a]["visible"]))
            observing=configured_observation_enabled && now<clock.day_us
            camp_view=configured_camp_landmark ? configured_camp_landmark_view(landmark_objects,w.positions[a],yaw[a];night=phase=="night") : nothing
            configured_camp_landmark && configured_camp_landmark_observe!(observation_states[a]["camp_landmark"],camp_view,home,observing,now)
            if configured_camp_experience
                observing && mb_place_collect!(mb_maps[a]["place_mb"],mb_maps[a],now)
                mb_place_recall!(mb_maps[a]["place_mb"],camp_view,get(ground_receipts,a,nothing),at_home)
            end
            if goal_arrival_enabled
                for g in ("home","food")
                    goal_arrival_advance!(mb_maps[a]["goal_arrival"][g],get(ground_receipts,a,nothing))
                end
                hs=mb_maps[a]["goal_arrival"]["home"]
                confidence=home!==nothing ? 1. : configured_camp_experience ? goal_arrival_camp_match(mb_maps[a]["place_mb"],mb_maps[a]["current"]) : 0.
                hypothesis=home!==nothing ? home : confidence>=.75 ? mb_maps[a]["place_mb"]["estimate"] : nothing
                goal_arrival_update!(hs,hypothesis,"home",confidence,now;completed=at_home)
                fs=mb_maps[a]["goal_arrival"]["food"]
                available=moves[a]["visible"]
                matching=fs["mode"]=="approach" ? filter(f->f["ref"]==fs["target"],available) : available
                f=isempty(matching) ? nothing : first(matching)
                goal_arrival_update!(fs,f,f===nothing ? fs["target"] : f["ref"],f===nothing ? 0. : 1.,now)
            end
            if night_fear_enabled
                fear=mb_maps[a]["night_fear"]
                protected_home=at_home || get(hazard_views[a],"safe_zone",false)
                estimate=night_return_estimate!(mb_maps[a],fear,home,protected_home,now,clock.day_us)
                night_fear_update!(fear,estimate,protected_home,hazard_views[a],now,clock.day_us,clock.phase_boundaries_us[3])
            end
            returning=observing ? false : returning!(purposes[a],phase,w.inventory[a],at_home,now)
            replenishing=false
            if body_purpose
                parent_choice=configured_body_purpose!(configured_body_states[a],hunger[a],w.bodies[a].reserve,returning,at_home,
                    at_home ? (shared_stores ? shared : stores[a]) : 0,now)
                returning=parent_choice.returning;replenishing=parent_choice.replenishing
            end
            configured_overrides=configured_body_overrides(replenishing,states[a]["pending"]!==nothing)
            if embedded_rest_enabled && !observing
                returning=embedded_rest_request!(mb_maps[a]["embedded_rest"],w.bodies[a].strain,w.bodies[a].reserve,
                    hunger[a]["intensity"],replenishing,returning,now,clock.day_us,loops[a]["home"].rng)
            end
            food_hungry=food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80
            edible_on_hand=foods===nothing ? w.inventory[a]>0 : food_has_edible(foods,a)
            configured_action=foods===nothing ? configured_body_action(replenishing,w.inventory[a],guts===nothing || can_ingest(guts[a]),
                at_home,at_home ? (shared_stores ? shared : stores[a]) : 0) :
                configured_food_preparation(foods,a,food_hungry,guts===nothing || can_ingest(guts[a]),
                    at_home,at_home ? (shared_stores ? shared : stores[a]) : 0;
                    processing_feasible=step(w.bodies[a],"process_food",w.inventory[a])[2]=="worked")
            night_fear_enabled && !observing && (returning=night_fear_request!(mb_maps[a]["night_fear"],returning,replenishing,now,loops[a]["home"].rng))
            if daily_delivery_enabled && !observing
                returning=configured_daily_delivery_request!(mb_maps[a]["configured_daily_delivery"],returning,replenishing,w.inventory[a],at_home,at_home ? (shared_stores ? shared : stores[a]) : 0,now,clock.day_us)
            end
            # Given recipe knowledge: raw carried provisions need the observed camp
            # preparation place. Navigation still uses the normal home candidates.
            foods!==nothing && food_hungry && !edible_on_hand && food_has_raw(foods,a) && !at_home && (returning=true)
            if experience_bundles
                form_bundle!(bundles[a],hunger[a],now)
                wake_bundles!(bundles[a],bundle_contexts[a],phase)
            end
            movement_inertia && observe_inertia!(inertia[a],a,now,inertia_view(moves[a],landmarks[a],hazard_views[a]))
            if basic_loop && haskey(pending,a)
                t=pop!(pending,a);s=loops[a][t.family]
                target=t.family=="home" ? home : isempty(moves[a]["visible"]) ? nothing : first(moves[a]["visible"])
                same=target!==nothing && (t.family=="home" || t.ref===nothing || target["ref"]==t.ref)
                value=t.question=="social_contact" ? social_approach_evidence(D("social_peer"=>t.social_peer,"social_actor"=>a,"social_capture_us"=>t.social_capture_us),social_views[a]) : t.question=="ground_extension" ? ground_extension_result(ground_models[a],s.trial.method,t.status,t.moved) : t.question=="movement_progress" ? t.status=="performed" && t.moved : t.question=="rested" ? t.status=="performed" : t.question=="load_reduced" ? t.status=="dropped" : t.question=="recovered" ? t.status=="recovered" : t.question=="landmark_progress" ? t.status=="performed" : t.question=="acquired" ? t.status=="picked_up" : t.question=="home_confirmed" ? at_home && t.status=="performed" : t.question=="target_observed" ? target!==nothing :
                    same ? target["distance"]<t.distance : nothing
                if t.question=="social_contact"
                    value===true && (relations[a]["approach"]["contacts"]+=1)
                end
                # No move/turn result is credited as acquired food or confirmed home.
                goal=t.family=="home" ? at_home : t.status in ("picked_up","recovered")
                if reposition && t.phase==phase
                    search_review_result!(reposition_states[a],t.family,s.trial.method,target!==nothing,t.status=="performed")
                end
                mb_parent_H=s.H
                child_increment=mb_simulation ? mb_route_H_increment!(mb_maps[a],t.family,t.source,goal,now) : nothing
                forecast_increment=mb_simulation ? mb_parent_H_increment!(mb_maps[a],t.family,t.source,goal,now;
                    child_increment=child_increment===nothing ? 0 : child_increment) : nothing
                forecast_increment===nothing && (forecast_increment=child_increment)
                t.question=="social_contact" && forecast_increment===nothing && (forecast_increment=0.)
                completion_reward=mb_simulation ? mb_parent_reward(mb_maps[a],t.family,t.source,now) : nothing
                method_evidence=forecast_method_evidence(forecast_increment,goal,t.phase==phase,value)
                resolve_method!(s,t.source,method_evidence,forecast_increment!==nothing ? goal : (t.phase==phase || goal ? goal : nothing);
                    creditable=t.phase==phase && t.status=="performed" && (t.moved || value===true),
                    goal_H_increment=forecast_increment===nothing ? 1 : forecast_increment,completion_reward=completion_reward)
                mb_simulation && mb_route_goal!(mb_maps[a],t.family,t.source,goal,mb_parent_H,s.H,now;completion_reward=completion_reward)
                mb_chunks && mb_goal_result!(mb_maps[a],t.family,t.source,goal,mb_parent_H,s.H,now;completion_reward=completion_reward)
                configured_home_rest_enabled && t.family=="home" && goal && t.moved &&
                    configured_home_rest_arrival!(mb_maps[a],s,t.source,now)
            end
            if goal_arrival_enabled
                for g in ("home","food")
                    mb_parent_arrival_sync!(mb_maps[a],loops[a][g],g,now)
                end
                if ground_perception && ground_continuity
                    # Use this tick's recognition and selected purpose, not another goal's hypothesis.
                    receipt=get(ground_receipts,a,nothing)
                    baseline=rho_baselines[a]
                    arrival=mb_maps[a]["goal_arrival"][returning ? "home" : "food"]
                    effective=goal_arrival_rho_record!(arrival,baseline,goal_arrival_rho(arrival,baseline))
                    view=last(ground_views[a]["records"])["observation"]
                    structure=effective=="off" ? local_structures(view,lateral_views[a]) : rho_map(view,lateral_views[a],effective)
                    update_structures!(ground_models[a]["structures"],structure,receipt)
                end
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
                plan=continuous_safety ? safety_methods!(safety[a],safety_loops[a],hazard_view,moves[a],"op:$now:$a";running=running,home=camp_safe_zone ? home : nothing) : safety_plan!(safety[a],hazard_view,moves[a];running=running)
            end
            if plan!==nothing
                # Safety has authority before social, food and night priorities.
            elseif configured_action!==nothing
                plan=D("action"=>configured_action)
                foods!==nothing && (plan["configured_food_preparation"]=true)
            elseif !isempty(messages)
                m=first(messages);current=merge(copy(o),D("messages"=>[m]))
                if social_response || food_body || relations!==nothing
                    decision,trace=experienced_response(current,states[a]["records"],aid_view(a),a,"respond:$now:$a:$(m["id"])";retention=food_body ? retention_cost(current,hunger[a]) : 0.,relation=relations===nothing ? nothing : relations[a])
                    act,t,r=decision
                    if trace!==nothing
                        rs=response_stats[a];rs["decisions"]+=1;rs[act]+=1
                        (trace["weight"]>0 || (haskey(trace,"relationship") && trace["relationship"]["weight"]!=0)) && (rs["experienced"]+=1)
                        relations!==nothing && social_relation_use!(relations[a],m["sender"],"give",trace["source"],now,trace["relationship"];action=act)
                        push!(rs["records"],trace);length(rs["records"])>32 && popfirst!(rs["records"])
                    end
                else
                    act,t,r=response(current,a!="npc_b")
                end
                plan=D("action"=>act,"target"=>t,"reply_to"=>r);push!(answered[a],m["id"])
            elseif (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) && edible_on_hand && (guts===nothing || can_ingest(guts[a]))
                plan=D("action"=>"eat")
            elseif at_home && (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) && (shared_stores ? shared : stores[a])>0
                plan=D("action"=>"retrieve")
            elseif phase=="night" && local_us>=clock.quiet_night_us && !configured_overrides.bypass_scheduled_rest
                plan=D("action"=>"rest")
            elseif states[a]["pending"]!==nothing && !configured_overrides.bypass_social_wait
                plan=D("action"=>"rest")
            elseif (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80) && !configured_overrides.suppress_repeat_request
                targets=[x["ref"] for x in o["others"] if x["holding_food"]]
                target,target_trace=select_target(targets,states[a]["model"],aid_view(a);relation=relations===nothing ? nothing : relations[a],seed="target:$choice_seed:$now:$a",situation=food_social_context(w.bodies[a]))
                request_allowed=target!==nothing
                if request_allowed && (social_response || relations!==nothing)
                    request_allowed,trace=experienced_request(o,states[a]["records"],aid_view(a),a,target,"request:$now:$a:$target";relation=relations===nothing ? nothing : relations[a])
                    rs=response_stats[a];rs["request_decisions"]+=1;rs[request_allowed ? "requests" : "withheld"]+=1
                    push!(rs["records"],trace);length(rs["records"])>32 && popfirst!(rs["records"])
                    if relations!==nothing
                        social_relation_use!(relations[a],target,"request",trace["source"],now,merge(trace["relationship"],D("target_selection"=>target_trace));action=trace["selected"])
                    end
                end
                if request_allowed
                    op="op:$now:$a"
                    states[a]["pending"]=D("message_id"=>a*":"*op,"target"=>target,"deadline"=>now+5_000_000,
                        "request_observation_id"=>"ob:$now:$a","operation_id"=>op)
                    if relations!==nothing
                        situation=food_social_context(w.bodies[a])
                        prediction=social_mb_predict(relations[a],target,"aid_received";situation,H=aid_view(a).parent.H)
                        kinds=foods===nothing ? fill(meal_kind,w.inventory[a]) : foods.inventory[a]
                        aid_values=food_aid_values(w.bodies[a],guts===nothing ? nothing : guts[a],kinds)
                        social_aid_begin!(relations[a]["aid"],a*":"*op,target,now;probability=prediction["probability"],values=aid_values,
                            kind_probabilities=prediction["kind_probabilities"],source_refs=prediction["source_refs"],mb_ids=prediction["mb_ids"],context=situation)
                        states[a]["pending"]["social_context"]=situation
                    end
                    plan=D("action"=>"request","target"=>target)
                end
            end

            if plan===nothing && items!==nothing
                plan=configured_item_plan(item_actions,a,now)
            end
            if plan===nothing && trades!==nothing && !observing && phase!="night" && at_home && w.inventory[a]==0
                plan=food_trade_plan!(trades,a,get(trade_views,a,nothing),w.bodies[a],guts===nothing ? nothing : guts[a],now;relation=relations===nothing ? nothing : relations[a])
            end
            if observing && plan===nothing
                plan=configured_observation_food(moves[a],replenishing,w.inventory[a])
                plan===nothing && configured_camp_landmark && (plan=configured_camp_landmark_tour!(observation_states[a]["camp_landmark"],spec.home,w.positions[a],yaw[a],sec,camp_view,w.bodies[a].reserve,w.bodies[a].strain,local_us,clock;experience=configured_camp_experience))
                if plan===nothing && configured_camp_experience && observation_states[a]["camp_landmark"]["tour_completed"] && !mb_maps[a]["place_mb"]["complete"] && at_home
                    plan=D("action"=>"rest","method"=>"configured_camp_place_rest","configured_observation"=>true,"configured_place_rest"=>true)
                end
                plan===nothing && (plan=configured_observation_plan(observation_states[a],w.positions[a],yaw[a],sec,local_us,clock,w.bodies[a].reserve,w.bodies[a].strain))
            end
            if plan===nothing
                if returning && at_home
                    plan=D("action"=>w.inventory[a]>0 ? "deposit" : "rest")
                elseif food_body && phase=="exploration" && !returning && w.bodies[a].reserve>=80 && w.inventory[a]>=3
                    plan=D("action"=>"rest")
                elseif phase=="orientation" && !configured_overrides.bypass_scheduled_rest
                    plan=D("action"=>"rest")
                elseif w.bodies[a].strain>=.8 || w.bodies[a].reserve<=0
                    plan=D("action"=>"rest")
                elseif basic_loop
                    family=returning ? "home" : "food"
                    if incidental_items!==nothing
                        urgency=food_body ? hunger[a]["intensity"] : clamp((80-w.bodies[a].reserve)/80,0.,1.)
                        night_fear_enabled && (urgency=max(urgency,clamp(mb_maps[a]["night_fear"]["H"]/32,0.,1.)))
                        plan=incidental_item_plan!(incidental_items[a],o["items"],w.bodies[a],loops[a][family],now;
                            family=family,pressure=urgency)
                    end
                    if plan===nothing
                        visible=moves[a]["visible"];target=returning ? home : isempty(visible) ? nothing : first(visible)
                        if goal_arrival_enabled && !returning && mb_maps[a]["goal_arrival"]["food"]["mode"]=="approach"
                            held=filter(f->f["ref"]==mb_maps[a]["goal_arrival"]["food"]["target"],visible)
                            target=isempty(held) ? nothing : first(held)
                        end
                        if !returning && target!==nothing && target["distance"]<=1.25
                            plan=D("action"=>haskey(dropped["origins"],target["ref"]+1) ? "recover" : "pickup","food_ref"=>target["ref"])
                        else
                            s=loops[a][family];source="op:$now:$a"
                            navigation_H=night_fear_enabled && family=="home" ? max(s.H,mb_maps[a]["night_fear"]["H"]) : s.H
                            candidates=search_candidates(moves[a],target,s)
                            if relations!==nothing && family=="food" && food_hungry
                                kinds=foods===nothing ? fill(meal_kind,w.inventory[a]) : foods.inventory[a]
                                aid_values=food_aid_values(w.bodies[a],guts===nothing ? nothing : guts[a],kinds)
                                social_options=social_approach_candidates(social_views[a],moves[a],relations[a],s,now;
                                    food_value=sum(aid_values)/length(aid_values),food_values=aid_values,context=food_social_context(w.bodies[a]))
                                append!(candidates,social_options)
                                relations[a]["approach"]["proposed"]+=length(social_options)
                            end
                            rho_profile=="home-distance" && family=="home" && append!(candidates,home_distance_candidates(mb_maps[a]["home_distance"]))
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
                                pool=observed_cues(landmarks[a],skyline_views===nothing ? nothing : skyline_views[a],structure_view,moves[a],hazard_views===nothing ? nothing : hazard_views[a],"ob:$now:$a";level=min(2,floor(Int,s.H/s.threshold)))
                                cue_options=cue_candidates!(cue_states[a],pool,moves[a],s.H,s.threshold)
                                mb_simulation && mb_goal_cue_project!(mb_maps[a],cue_options,pool,family,s.H,now)
                                mb_simulation && mb_exploration_project!(mb_maps[a],cue_options,family,s.H,now)
                                append!(candidates,cue_options)
                            end
                            if mb_simulation && (target===nothing || mb_maps[a]["routes"]["active"]!==nothing)
                                active_candidates=mb_route_candidates!(mb_maps[a],moves[a],family,w.bodies[a].reserve,w.bodies[a].strain,now;H=s.H)
                                chunk_candidates=copy(active_candidates)
                                if isempty(active_candidates) || s.H>=s.threshold
                                    fresh=mb_chunk_candidates!(mb_maps[a],moves[a],family,w.bodies[a].reserve,w.bodies[a].strain,now;H=s.H)
                                    active=mb_maps[a]["routes"]["active"]
                                    filter!(p->active===nothing || get(p,"mb_route",nothing)!=active["id"],fresh)
                                    append!(chunk_candidates,fresh)
                                end
                                mb_sleep && append!(chunk_candidates,mb_sleep_candidates!(mb_maps[a],moves[a],family,navigation_H,s.threshold,w.bodies[a].reserve,w.bodies[a].strain,now))
                                active=mb_maps[a]["routes"]["active"]
                                filter!(p->active===nothing || get(p,"mb_route",nothing)!=active["id"] || startswith(p["method"],"mb_route:"),chunk_candidates)
                                if isempty(chunk_candidates)
                                    fresh=mb_simulate!(mb_maps[a],moves[a],family,navigation_H,s.threshold,w.bodies[a].reserve,w.bodies[a].strain,now)
                                    filter!(p->active===nothing || get(p,"mb_route",nothing)!=active["id"],fresh)
                                    append!(candidates,fresh)
                                else
                                    append!(candidates,chunk_candidates)
                                end
                                filter!(p->!(startswith(first(p),"mb_route:") || startswith(first(p),"mb_recheck:") || startswith(first(p),"mb_abandon:")) || (mb_maps[a]["routes"]["active"]!==nothing && (first(p)=="mb_route:"*mb_maps[a]["routes"]["active"]["id"] || first(p)=="mb_recheck:"*mb_maps[a]["routes"]["active"]["id"] || first(p)=="mb_abandon:"*mb_maps[a]["routes"]["active"]["id"])),s.methods)
                                filter!(p->!startswith(first(p),"mb_chunk:") || haskey(mb_maps[a]["chunks"],first(p)[10:end]),s.methods)
                                filter!(p->!startswith(first(p),"mb_sim:") || haskey(mb_maps[a]["edges"],first(p)[8:end]),s.methods)
                            end
                            reposition && project_search_review!(reposition_states[a],candidates,s,target,family)
                            if parent_breadth
                                before=length(candidates)
                                candidates=parent_candidates(s,candidates)
                                bs=breadth_stats[a];bs["decisions"]+=1;bs["offered"]+=before
                                bs["admitted"]+=length(candidates);bs["restricted"]+=Int(length(candidates)<before)
                                level=s.H>=32 ? 2 : min(2,floor(Int,s.H/s.threshold))
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
                            if configured_camp_landmark && family=="home"
                                c=configured_camp_experience ? mb_place_candidate!(mb_maps[a]["place_mb"],moves[a]) : configured_camp_landmark_candidate!(observation_states[a]["camp_landmark"],camp_view,moves[a])
                                c!==nothing && push!(candidates,c)
                            end
                            mb_simulation && (candidates=mb_parent_candidates!(mb_maps[a],candidates,family,target))
                            mb_simulation && phase=="exploration" && (candidates=mb_project_return!(mb_maps[a],candidates,moves[a],family,w.bodies[a].reserve,now))
                            mb_simulation && (candidates=mb_route_control!(mb_maps[a],candidates,s,family,now))
                            goal_arrival_enabled && goal_arrival_project!(mb_maps[a]["goal_arrival"][family],candidates,moves[a],family,now)
                            goal_arrival_enabled && mb_parent_arrival_sync!(mb_maps[a],s,family,now)
                            plan=choose_method!(s,candidates,source)
                            if haskey(plan,"social_peer")
                                stats=relations[a]["approach"];stats["selected"]+=1
                                push!(stats["records"],D("us"=>now,"peer"=>plan["social_peer"],"method"=>plan["method"],
                                    "probability"=>get(plan,"selection_probability",nothing),"expected_gain"=>get(plan,"social_expected_gain",nothing)))
                                length(stats["records"])>32 && popfirst!(stats["records"])
                            end
                            mb_simulation && mb_goal_cue_selected!(mb_maps[a],plan,now)
                            get(plan,"goal_arrival",false) && (mb_maps[a]["goal_arrival"][family]["selected"]+=1)
                            get(plan,"configured_camp_landmark",false) && (observation_states[a]["camp_landmark"]["selected"]+=1)
                            if haskey(plan,"mb_place")
                                mb_maps[a]["place_mb"]["selected"]+=1
                                get(plan,"mb_place_memory",false) && (mb_maps[a]["place_mb"]["memory_selected"]+=1)
                            end
                            get(plan,"mb_return_link",false) && (mb_maps[a]["return_outlook"]["selected"]+=1)
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
                                ref=target===nothing || returning ? nothing : target["ref"],status="unexecuted",social_peer=get(plan,"social_peer",nothing),social_capture_us=now)
                        end
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
            if basic_loop && !get(plan,"configured_observation",false) && !haskey(pending,a) && (plan["action"] in ("pickup","recover","deposit") || (at_home && plan["action"]=="rest" && loops[a]["home"].H>0))
                family=plan["action"] in ("pickup","recover") ? "food" : "home"
                question=plan["action"]=="recover" ? "recovered" : family=="food" ? "acquired" : "home_confirmed"
                source="op:$now:$a"
                plan=choose_method!(loops[a][family],[merge(plan,D("method"=>"work","priority"=>5.,"question"=>question))],source)
                pending[a]=(family=family,source=source,phase=phase,question=question,distance=nothing,ref=nothing,status="unexecuted")
            end
            if orientation && !get(plan,"configured_observation",false) && plan["action"]=="scan" && !get(plan,"goal_arrival",false) && !get(plan,"safety",false) && !get(plan,"home_distance_confirm",false) && !haskey(plan,"mb_place") && !(general_landmarks && haskey(plan,"cue_kind")) && !haskey(plan,"mb_edge")
                plan["scan_angle"]=orientation_scan!(sky[a],clock)
            end
            plan["purpose_family"]=returning ? "home" : "food"
            if mb_simulation && haskey(pending,a) && !get(plan,"configured_observation",false)
                parent_family=pending[a].family
                parent_target=parent_family=="home" ? home : isempty(moves[a]["visible"]) ? nothing : first(moves[a]["visible"])
                mb_parent_begin!(mb_maps[a],plan,parent_family,parent_target,now)
            end
            if continuous_descent && !get(plan,"configured_observation",false) && plan["action"] in ("walk","run")
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
            elseif action in ITEM_ACTIONS
                receipt=item_execute!(items,shared_stores ? nothing : foods,w,stores,spec.home,a,op,action,now;
                    item_id=get(plan,"item_id",0),target=get(plan,"target",nothing),offer_id=get(plan,"offer_id",nothing),
                    give_items=get(plan,"give_items",Int[]),want_items=get(plan,"want_items",Int[]),
                    give_food=get(plan,"give_food",[0,0,0,0]),want_food=get(plan,"want_food",[0,0,0,0]))
                # Item acquisition must never count as food acquisition.
                status="item_"*receipt["status"]
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
            elseif action in ("trade_offer","trade_accept","trade_decline")
                receipt=if action=="trade_offer"
                    food_exchange_execute!(trades["world"],foods,w,stores,spec.home,a,op,action,now;
                        target=plan["target"],give_kind=plan["give_kind"],give_count=plan["give_count"],
                        want_kind=plan["want_kind"],want_count=plan["want_count"])
                else
                    food_exchange_execute!(trades["world"],foods,w,stores,spec.home,a,op,action,now;offer_id=plan["offer_id"])
                end
                status=receipt["status"];food_trade_executed!(trades,a,plan,receipt;relation=relations===nothing ? nothing : relations[a])
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
            elseif action=="process_food"
                legal=foods!==nothing && hypot(p[1]-spec.home[1],p[2]-spec.home[2])<=1.25 && food_has_raw(foods,a)
                if legal
                    w.bodies[a],work_status,_,_=step(w.bodies[a],"process_food",w.inventory[a])
                    status=work_status=="worked" ? food_process!(foods,a) : work_status
                else
                    status="preparation_unavailable"
                end
            elseif action in ("eat","request","give","refuse","warn","withdraw","wait")
                premeal=w.bodies[a]
                meal_index=foods===nothing || action!="eat" ? 1 : food_best_edible(foods,a,guts===nothing ? nothing : guts[a],premeal.reserve)
                actual_kind=foods===nothing ? meal_kind : meal_index>0 && action=="eat" ? Int(foods.inventory[a][meal_index]) : 0
                if action=="eat" && (meal_index==0 || (guts!==nothing && !can_ingest(guts[a])))
                    r=D("status"=>meal_index==0 ? "no_edible_food" : "gut_full")
                else
                    delivered_kind=action=="give" && w.inventory[a]>0 ? (foods===nothing ? meal_kind : Int(first(foods.inventory[a]))) : nothing
                    r=communicate!(w,a,op,action,get(plan,"target",nothing),get(plan,"reply_to",nothing);food_kind=delivered_kind)
                end
                status=r["status"]
                if relations!==nothing && action in ("give","refuse") && get(plan,"target",nothing)!==nothing
                    social_relation_event!(relations[a],plan["target"],"aid_given",op,now;
                        outcome=action=="refuse" && status=="expressed" ? "refuse" : status)
                end
                if status=="ate"
                    liking=FOOD_LIKING[actual_kind]
                    if guts!==nothing
                        w.bodies[a]=premeal # food transfer stays committed; energy waits for digestion
                        liking=ingest!(guts[a],actual_kind,premeal.reserve,now)
                    end
                    deleteat!(cargo[a],meal_index)
                    if foods!==nothing
                        food_remove!(foods,a,meal_index)
                        food_record_meal!(foods,a,actual_kind,liking,now)
                    end
                elseif status=="transferred"
                    push!(cargo[plan["target"]],popfirst!(cargo[a]))
                    foods!==nothing && push!(foods.inventory[plan["target"]],food_remove!(foods,a,1))
                end
                results[a]=social_result_window(results[a],states[a]["pending"],op,r)
                if action!="eat"
                    w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
                end
            else
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
                if action in ("drop","recover")
                    status=cargo_transfer!(dropped,w,cargo,food,stock,a,op,now,action;index=action=="recover" ? plan["food_ref"]+1 : 0)
                    foods!==nothing && food_track_cargo!(foods,dropped,food,a,op,action,status,action=="recover" ? plan["food_ref"]+1 : 0)
                elseif action=="scan"
                    yaw[a]=mod(yaw[a]+get(plan,"scan_angle",60)+180,360)-180
                    get(plan,"home_distance_confirm",false) && (mb_maps[a]["home_distance"]["scan_selected"]+=1)
                elseif action=="pickup"
                    j=plan["food_ref"]+1;f=food[j]
                    legal=stock[j]>0 && hypot(f.x-p[1],f.z-p[2])<=1.25 && !any(o->segment_hit(p,(Float64(f.x),Float64(f.z)),o,0.),w.obstacles)
                    if legal;stock[j]-=1;w.inventory[a]+=1;push!(cargo[a],op);end
                    legal && foods!==nothing && push!(foods.inventory[a],foods.site_kinds[j])
                    status=legal ? "picked_up" : "not_found"
                elseif action in ("deposit","retrieve")
                    legal=hypot(p[1]-spec.home[1],p[2]-spec.home[2])<=1.25
                    if legal && action=="deposit"
                        foods!==nothing && food_deposit!(foods,a,shared_stores)
                        daily_delivery_enabled && configured_daily_delivery_deposit!(mb_maps[a]["configured_daily_delivery"],w.inventory[a],now,clock.day_us)
                        delivered=String[id for id in cargo[a] if id!==nothing];empty!(cargo[a])
                        if shared_stores
                            shared+=w.inventory[a];storage_stats["deposited"]+=w.inventory[a]
                        else
                            stores[a]+=w.inventory[a]
                        end
                        w.inventory[a]=0
                    elseif legal && (shared_stores ? shared : stores[a])>0
                        foods!==nothing && food_retrieve!(foods,a,shared_stores,guts===nothing ? nothing : guts[a],w.bodies[a].reserve)
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
            if get(plan,"incidental_item",false)
                incidental_item_result!(incidental_items[a],plan,status,max(0.,repetition_before.reserve-w.bodies[a].reserve),now)
            end
            if configured_home_rest_enabled
                h=homes[a]
                configured_home_rest_step!(mb_maps[a],loops[a]["home"],h!==nothing && h["distance"]<=1.25,
                    action,status,now,clock.day_us)
            end
            if embedded_rest_enabled
                h=homes[a]
                embedded_rest_feedback!(mb_maps[a]["embedded_rest"],h!==nothing && h["distance"]<=1.25,
                    action,status,now,clock.day_us)
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
                    mb_sleep && mb_sleep_freeze!(mb_maps[a],now)
                end
                if relations!==nothing && cycle["status"]=="pending" && cycle["rest_us"]==0 && action=="rest"
                    social_mb_sleep_freeze!(relations[a],day,now)
                end
                callback=(harvest_sleep || general_sleep || relations!==nothing) ? ((c,t)->begin
                    harvest_sleep && consolidate_harvest!(harvest[a],c,t)
                    general_sleep && review_general!(general[a],a,day,t)
                    mb_simulation && mb_compress_exploration!(mb_maps[a],day,t)
                    mb_simulation && mb_sleep_organize!(mb_maps[a],day,t)
                    mb_sleep && mb_sleep_review!(mb_maps[a],day,t)
                    experience_bundles && sleep_bundles!(bundles[a],day,general[a]["formation_us"])
                    sleep_maintenance && review_sleep_usage!(action_models[a],day,general[a]["formation_us"])
                    sleep_actions && adopt_sleep_actions!(action_models[a],last(general[a]["reviews"]),a,t)
                    sleep_maintenance && enroll_sleep_usage!(action_models[a],t)
                    relations!==nothing && social_mb_sleep_review!(relations[a],day,t;completed=true)
                end) : nothing
                receipt!(learning[a],now;phase=phase,kind=action=="rest" ? "wait" : action,status=action=="rest" ? "waited" : status,on_complete=callback)
            end
            general_sleep && remember_general!(general[a],a,op,action,status,get(plan,"target",nothing),phase,now+1_000_000;context=contexts[a],direction=get(plan,"direction",nothing),retain=sleep_retention)
            if harvest_sleep && action=="pickup"
                harvest_pending[a]=(op=op,before=deepcopy(sections[a]),status=status,executed=now+1_000_000,
                    prediction=frozen_prediction,position=p,yaw=yaw[a])
            end
            mb_simulation && mb_record!(mb_maps[a],get(plan,"configured_observation",false) ? merge(plan,D("purpose_family"=>nothing)) : plan,status,repetition_before.reserve-w.bodies[a].reserve,now;turn=wrap_angle(yaw[a]-before_yaw),distance=hypot(w.positions[a][1]-p[1],w.positions[a][2]-p[2]))
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
            configured_observation_enabled && now<clock.day_us && configured_observation_record!(observation_states[a],mb_maps[a],w.positions[a],action,now,clock.day_us)
            goal_arrival_enabled && action in ("pickup","recover") && status in ("picked_up","recovered") && goal_arrival_update!(mb_maps[a]["goal_arrival"]["food"],nothing,nothing,0.,now+1_000_000;completed=true)
            configured_camp_experience && now<clock.day_us && configured_camp_place_rest!(mb_maps[a]["place_mb"],observation_states[a]["camp_landmark"],loops[a]["home"],plan,status,homes[a]!==nothing && homes[a]["distance"]<=1.25,now)
            counts[a][action]=get(counts[a],action,0)+1
            sig=(phase,leg,action,get(plan,"target",nothing),status,get(plan,"method",nothing),get(plan,"direction",nothing),get(plan,"selection_mode",nothing))
            if get(previous,a,nothing)!=sig || get(plan,"incidental_item",false)
                push!(events,D("us"=>now,"actor"=>a,"phase"=>phase,"purpose_family"=>leg,"action"=>action,"status"=>status,"target"=>get(plan,"target",nothing),
                    "method"=>get(plan,"method",nothing),"direction"=>get(plan,"direction",nothing),"selection_mode"=>get(plan,"selection_mode",nothing),
                    "route"=>get(plan,"route",nothing),"landmark_color"=>get(plan,"landmark_color",nothing)))
                if get(plan,"incidental_item",false)
                    events[end]["incidental_item"]=true;events[end]["item_id"]=plan["item_id"]
                end
                previous[a]=sig
            end
        end
        wildlife!==nothing && LWGrazing.advance!(wildlife,sec)
        advance_physiology!(w,metabolism,guts,food_body)
        @assert shared+sum(stock)+sum(values(w.inventory))+sum(values(stores))+w.consumed==initial+replenished
        foods!==nothing && food_audit!(foods,w,stock,shared,stores)
        items!==nothing && item_audit!(items,w)
        if mod(now+1_000_000,clock.day_us)==0
            for a in IDS
                integrate(a,now+1_000_000,observe(w,a))
                cycle=learning[a]["sleep"]["cycle"]
                relations===nothing && (states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>now+1_000_000)),a))
            end
            push!(daily,D("physical"=>physical(),"sleep"=>deepcopy(learning),"counts"=>deepcopy(counts),
                "shared_stock"=>shared,"ground"=>sum(stock),"consumed"=>w.consumed,"replenished_food"=>replenished))
            wildlife!==nothing && (daily[end]["wildlife"]=LWGrazing.snapshot(wildlife;
                previous=length(daily)>1 ? get(daily[end-1],"wildlife",nothing) : nothing))
            foods!==nothing && (daily[end]["food_resources"]=food_snapshot(foods))
            trades!==nothing && (daily[end]["food_exchange"]=food_trade_snapshot(trades))
            items!==nothing && (daily[end]["portable_items"]=item_snapshot(items))
            incidental_items!==nothing && (daily[end]["incidental_items"]=incidental_snapshot())
            relations!==nothing && (daily[end]["social_relationships"]=relation_snapshot())
            checkpoint_dir!==nothing && checkpoint_save(checkpoint_dir,length(daily),@lw_capture(),checkpoint_identity,checkpoint_code)
        end
    end
    ground_wear && advance_wear!(wear,wear_offset+Int(days*clock.day_us))
    terminal=D()
    for a in IDS
        integrate(a,Int(days*clock.day_us),observe(w,a))
        cycle=learning[a]["sleep"]["cycle"]
        relations===nothing && (states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>Int(days*clock.day_us))),a))
        terminal[a]=D("body_purpose"=>body_purpose ? deepcopy(configured_body_states[a]) : nothing,"return_purpose"=>deepcopy(purposes[a]),"position"=>collect(w.positions[a]),"body"=>bodydict(w.bodies[a]),"inventory"=>w.inventory[a],
            "personal_stock"=>stores[a],"sleep"=>learning[a],"social"=>states[a],"aid"=>relations===nothing ? pressure_snapshot(live[a]) : social_aid_snapshot(relations[a]["aid"]),"distance"=>distance[a],
            "routes"=>landmark_routes ? deepcopy(routes[a]) : nothing,"max_radius_observer_only"=>max_radius[a],
            "harvest"=>harvest_sleep ? deepcopy(harvest[a]) : nothing,"model_field"=>field_stats[a])
    end
    environment=D("rule"=>"native-cohort-world-v1","day_us"=>clock.day_us,"next_us"=>world_offset+days*clock.day_us,
        "shared_stores"=>shared_stores,"shared_stock"=>shared,"regrowth_days"=>regrowth_days,"regrowth_capacity"=>regrowth_capacity,"landscape"=>land,"obstacles"=>spec.obstacles,"renewal_targets"=>spec.food,"ground_patches"=>spec.ground_patches,
        "renewable"=>renewable_food,"hazard_mode"=>dynamic_hazard_mode,"dropping"=>dropping,"wear_enabled"=>ground_wear,
        "food"=>deepcopy(food),"stock"=>copy(stock),"ground"=>ground_wear ? wear_snapshot(wear) : nothing,
        "hazards"=>dynamic_hazard_mode!="off" ? deepcopy(hazard_world) : nothing,
        "wildlife"=>wildlife===nothing ? nothing :
            (!isempty(daily) && haskey(daily[end],"wildlife") ? daily[end]["wildlife"] : LWGrazing.snapshot(wildlife)),
        "food_resources"=>foods===nothing ? nothing : food_snapshot(foods),
        "food_exchange"=>trades===nothing ? nothing : food_trade_snapshot(trades),
        "portable_items"=>items===nothing ? nothing : item_snapshot(items),
        "cargo"=>[D("index"=>i,"source"=>dropped["origins"][i]) for i in sort(collect(keys(dropped["origins"])))])
    merge(incidental_items===nothing ? D() : D("incidental_items"=>incidental_snapshot()),items===nothing ? D() : D("portable_items"=>item_snapshot(items)),relations===nothing ? D() : D("social_relationships"=>relation_snapshot()),trades===nothing ? D() : D("food_exchange"=>food_trade_snapshot(trades)),guts===nothing ? D() : D("digestion"=>D(a=>digestion_snapshot(guts[a]) for a in IDS)),lateral_side=="off" ? D() : D("lateral"=>lateral_stats),D("food_resources"=>environment["food_resources"],"wildlife"=>environment["wildlife"],"home_observation"=>configured_observation_enabled ? observation_states : nothing,"mb_map"=>mb_simulation ? mb_maps : nothing,"body_purpose"=>body_purpose ? configured_body_states : nothing,"observed_cues"=>general_landmarks ? cue_states : nothing,"shared_stock"=>shared,"shared_storage"=>shared_stores ? storage_stats : nothing,"skyline"=>skyline_mode=="off" ? nothing : skyline_states,"reposition"=>reposition ? reposition_states : nothing,"world_checkpoint"=>environment,"selection_trails"=>selection_trails ? trails : nothing,"experience_bundles"=>experience_bundles ? D(a=>bundle_snapshot(bundles[a]) for a in IDS) : nothing,"exploration_horizon"=>exploration_horizon ? horizons : nothing,"movement_inertia"=>movement_inertia ? inertia : nothing,"body_field"=>body_field ? body_fields : nothing,"relation_field"=>relation_field ? relation_fields : nothing,"orientation"=>orientation ? sky : nothing,"safety_methods"=>continuous_safety ? D(a=>loop_snapshot(safety_loops[a]) for a in IDS) : nothing,"world_hazards"=>dynamic_hazard_mode!="off" ? hazard_world : nothing,"food_body"=>food_body ? D("hunger"=>hunger,"metabolic_loss"=>metabolism) : nothing,"ground_continuity"=>ground_continuity ? ground_models : nothing,"ground_perception"=>ground_perception ? ground_views : nothing,"ground_wear"=>ground_wear ? wear_snapshot(wear) : nothing,"sleep_action_models"=>sleep_actions ? action_models : nothing,"general_sleep"=>general_sleep ? general : nothing,"social_response"=>(social_response || food_body || relations!==nothing) ? response_stats : nothing,"ended_us"=>days*clock.day_us,"initial_food"=>initial,"ground"=>sum(stock),"consumed"=>w.consumed,
        "replenished_food"=>replenished,"replenishments"=>replenishments,
        "dropped_cargo"=>dropping ? D("dropped"=>dropped["dropped"],"recovered"=>dropped["recovered"],"cross_actor"=>dropped["cross_actor"],"records"=>dropped["records"],"sites"=>[D("index"=>i,"x"=>food[i].x,"z"=>food[i].z,"stock"=>stock[i],"source"=>dropped["origins"][i]) for i in sort(collect(keys(dropped["origins"])))]) : nothing,"climbing"=>climbing ? climb_stats : nothing,"running"=>running ? run_stats : nothing,"ground_effects"=>ground_mode=="flat" ? nothing : ground_stats,"safety"=>hazard_mode ? deepcopy(safety) : nothing,"repetition_pressure"=>repetition_pressure ? repetitions : nothing,"parent_breadth"=>parent_breadth ? breadth_stats : nothing,"counts"=>counts,"events"=>events,"final_agents"=>terminal,"daily"=>daily,"day_starts"=>day_starts))
end
