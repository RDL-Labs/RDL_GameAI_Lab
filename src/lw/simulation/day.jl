include("../configured_paths/parameters.jl")
include("../decision/relational_gradient.jl")
include("../perception/home_distance.jl")
include("../decision/goal_arrival.jl")
include("../decision/gradient_roll.jl")
include("checkpoint.jl")
include("physiology.jl")
include("../configured_paths/sleep_gate.jl")
include("../configured_paths/collapse_gate.jl")
include("../configured_paths/acorn_quest.jl")
include("../configured_paths/fishing_training.jl")
include("../../ecology/lw_grazing/LWGrazing.jl")
include(joinpath(@__DIR__, "../configured_paths/daily_delivery.jl"))
include(joinpath(@__DIR__, "../configured_paths/post_return_idle.jl"))
include(joinpath(@__DIR__, "../configured_paths/trade_idle.jl"))
include(joinpath(@__DIR__, "../configured_paths/trade_work_wait.jl"))
include(joinpath(@__DIR__, "../configured_paths/trade_daily_limit.jl"))
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
include(joinpath(@__DIR__, "../configured_paths/return_purpose.jl"))
include(joinpath(@__DIR__, "../configured_paths/routine_actions.jl"))
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
include(joinpath(@__DIR__, "../game_rules/proficiency.jl"))
include(joinpath(@__DIR__, "../game_rules/fishing.jl"))
include(joinpath(@__DIR__, "../world/food_quality.jl"))
include(joinpath(@__DIR__, "../world/food_resources.jl"))
include(joinpath(@__DIR__, "../world/fishing.jl"))
include(joinpath(@__DIR__, "../world/river_fishing.jl"))
include(joinpath(@__DIR__, "../world/food_expiry.jl"))
include(joinpath(@__DIR__, "../world/food_facilities.jl"))
include(joinpath(@__DIR__, "../world/seasonal_food.jl"))
include(joinpath(@__DIR__, "../world/food_exchange.jl"))
include(joinpath(@__DIR__, "../world/portable_items.jl"))
include(joinpath(@__DIR__, "../world/item_tasting.jl"))
include(joinpath(@__DIR__, "../configured_paths/item_actions.jl"))
include(joinpath(@__DIR__, "../decision/basic_loop.jl"))
include(joinpath(@__DIR__, "../learning/food_condition.jl"))
include(joinpath(@__DIR__, "../decision/food_desire.jl"))
include(joinpath(@__DIR__, "../decision/fishing.jl"))
include(joinpath(@__DIR__, "../decision/task_focus.jl"))
include(joinpath(@__DIR__, "../perception/wildlife.jl"))
include(joinpath(@__DIR__, "../decision/acquisition.jl"))
include(joinpath(@__DIR__, "../decision/prediction_result.jl"))
include(joinpath(@__DIR__, "../decision/incidental_items.jl"))
include(joinpath(@__DIR__, "../decision/trade_necessity.jl"))
include(joinpath(@__DIR__, "../decision/item_social.jl"))
include(joinpath(@__DIR__, "../learning/social_aid.jl"))
include(joinpath(@__DIR__, "../configured_paths/legacy_trade_evaluation.jl"))
include(joinpath(@__DIR__, "../decision/food_exchange.jl"))
include(joinpath(@__DIR__, "../decision/food_security.jl"))
include(joinpath(@__DIR__, "../decision/gradient_trace.jl"))
include(joinpath(@__DIR__, "../perception/social_sight.jl"))
include(joinpath(@__DIR__, "../decision/visual_aid.jl"))
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
include(joinpath(@__DIR__, "../learning/mb_daily_plan.jl"))
include(joinpath(@__DIR__, "../learning/mb_search_resistance.jl"))
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
function home_observation(w,a,yaw,home;visual_obstacles=w.obstacles,range=60,illumination=AmbientVision.illumination(w.seconds))
    p=w.positions[a];dx,dz=home[1]-p[1],home[2]-p[2]
    s,c=sincos(deg2rad(yaw[a]));f,r=dx*s+dz*c,dx*c-dz*s
    d=hypot(dx,dz)
    if d<=range*AmbientVision.range_factor(:human,illumination) && (f>=0 || d<=1.25) && !any(o->segment_hit(p,(Float64(home[1]),Float64(home[2])),o,0.),visual_obstacles)
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
    check(days isa Int && 1<=days<=180,"lw_days")
    check(get(spec,:collapse_cognition_gate,true) isa Bool,"collapse_cognition_gate_bool")
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
    for a in IDS;mb_maps[a]["food_search_resistance_enabled"]=get(spec,:mb_food_search_resistance,false);end
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
    facilities=food_facilities(spec)
    visual_objects=vcat(collect(visual_objects),food_facility_visuals(facilities))
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
    provision_enabled=get(spec,:food_security_provision,daily_delivery_enabled && get(spec,:typed_food,false))
    check(provision_enabled isa Bool && (!provision_enabled || (daily_delivery_enabled && get(spec,:typed_food,false))),"food_security_provision_requires_typed_daily_plan")
    acorn_quest=get(spec,:configured_acorn_quest,false)
    quest_release=get(spec,:configured_quest_release,false)
    check(quest_release isa Bool && (!quest_release || (acorn_quest && daily_delivery_enabled)),"quest_release_requires_quest_daily_plan")
    acorn_tasting=get(spec,:configured_acorn_tasting,false)
    check(acorn_tasting isa Bool && (!acorn_tasting || (acorn_quest && get(spec,:food_processing,true))),"acorn_tasting_requires_quest_processing")
    check(acorn_quest isa Bool,"acorn_quest_flag")
    check(!acorn_quest || (get(spec,:configured_camp_landmark,false) && get(spec,:configured_camp_experience,false)),"acorn_quest_requires_camp_learning")
    check(!acorn_quest || (mb_simulation && basic_loop && configured_observation_enabled && (!daily_delivery_enabled || quest_release) && get(spec,:typed_food,false)),"acorn_quest_requires_observation_mb_typed_food_without_daily_goal")
    if acorn_quest
        for a in IDS;mb_maps[a]["training_quest"]=configured_acorn_quest_state(;tasting=acorn_tasting);end
    end
    food_processing_enabled=get(spec,:food_processing,true)
    food_kitchen(actor)=(;actor,foods,facilities,position=w.positions[actor],processing=food_processing_enabled)
    food_desire=get(spec,:food_desire,mb_simulation && get(spec,:typed_food,false))
    check(food_desire isa Bool && (!food_desire || (mb_simulation && basic_loop && get(spec,:typed_food,false))),"food_desire_requires_typed_mb")
    check(food_processing_enabled isa Bool,"food_processing_must_be_bool")
    post_return_idle=get(spec,:post_return_idle,false)
    post_return_meal=get(spec,:post_return_meal,false)
    trade_idle=get(spec,:configured_trade_idle,false)
    check(trade_idle isa Bool && (!trade_idle || (post_return_idle && post_return_meal && get(spec,:incidental_items,false) && get(spec,:item_exchange,true))),"trade_idle_requires_return_meal_and_exchange")
    check(post_return_meal isa Bool && (!post_return_meal || (post_return_idle && get(spec,:typed_food,false))),"post_return_meal_requires_typed_idle")
    check(post_return_idle isa Bool,"post_return_idle_must_be_bool")
    check(!post_return_idle || daily_delivery_enabled,"post_return_idle_requires_daily_plan")
    check(!post_return_idle || ((!get(spec,:social_relationships,false) || trade_idle) && !get(spec,:food_exchange,false)),"post_return_idle_requires_social_wakeup")
    if daily_delivery_enabled
        for a in IDS
            mb_maps[a]["configured_daily_delivery"]=configured_daily_delivery_state()
            mb_maps[a]["daily_plan"]=mb_daily_plan_state(a,choice_seed)
            post_return_idle && (mb_maps[a]["configured_post_return_idle"]=configured_post_return_idle_state())
        end
    end
    configured_body_states=Dict(a=>configured_body_state(a) for a in IDS)
    hunger=Dict(a=>hunger_state(a) for a in IDS)
    check(digestion_mode in ("off","ordinary","meat"),"digestion_mode")
    guts=if digestion_mode=="off"
        nothing
    else
        Dict(a=>begin
            # Stable actor identity, independent of action RNG and roster order.
            bytes=sha256("lw-taste:"*a)
            preference=ntuple(i->0.6*(2Int(bytes[i])/255-1),3)
            Digestion(;taste_preference=preference)
        end for a in IDS)
    end
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
    food_season=seasonal_food_config(spec,renewable_food,regrowth_days)
    history!==nothing && check(seasonal_food_config((food_season=get(history,:food_season,nothing),),renewable_food,regrowth_days)==food_season,"world_history_food_season")
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
    # Unharvested sites have no expiry clock. Regrowth adds world stock only;
    # carried/stored/dropped batches retain their own harvest deadlines.
    salt_training=get(spec,:configured_salt_tasting,false)
    check(salt_training isa Bool && (!salt_training || get(spec,:configured_fishing_training,false)),"salt_requires_fishing_training")
    visual_training=get(spec,:configured_salted_fish_sample,false)
    check(visual_training isa Bool && (!visual_training || (get(spec,:configured_fishing_training,false) && !salt_training)),"visual_fish_lesson_conditions")
    fishing_training=get(spec,:configured_fishing_training,false)
    check(fishing_training isa Bool,"fishing_training_flag")
    validate_river_fishing(food)
    fishing_enabled=any(fishing_site,food)
    check(!fishing_training || (fishing_enabled && !acorn_quest && !shared_stores),"fishing_training_requires_site_and_separate_personal_training")
    if fishing_training
        for a in IDS
            sample_kind=visual_training ? RDLBody.SALTED_FISH : RDLBody.FISH_FOOD
            check(foods!==nothing && (sample_kind in foods.inventory[a] || foods.personal[a][sample_kind]>=1),"fishing_training_requires_initial_tasting_sample")
            mb_maps[a]["fishing_training"]=configured_fishing_training_state(;salt=salt_training,visual=visual_training)
        end
    end
    check(!fishing_enabled || (foods!==nothing && basic_loop && mb_simulation),"fishing_requires_typed_mb")
    foods!==nothing && (foods.game.fishing["seed"]=choice_seed)
    for f in food
        fishing_site(f) && check(site_food_kind(f)==RDLBody.FISH_FOOD,"fishing_requires_fish_food_pool")
    end
    items=portable_items(spec,w)
    visual_training && check(items!==nothing && haskey(items["registry"],ROCK_SALT_ITEM),"missing_salt_display")
    salt_training && check(all(a->configured_salt_sample(items,a)!==nothing,IDS),"salt_training_requires_owned_samples")
    item_actions=configured_item_actions(spec,items!==nothing)
    incidental_enabled=get(spec,:incidental_items,false)
    item_exchange_enabled=get(spec,:item_exchange,incidental_enabled)
    trade_work_wait=get(spec,:configured_trade_work_wait,false)
    check(trade_work_wait isa Bool && (!trade_work_wait || item_exchange_enabled),"trade_work_wait_requires_exchange")
    check(item_exchange_enabled isa Bool,"item_exchange_flag")
    check(!item_exchange_enabled || incidental_enabled,"item_exchange_requires_incidental")
    item_attention_enabled=get(spec,:item_attention,false)
    check(item_attention_enabled isa Bool,"item_attention_flag")
    check(!item_attention_enabled || incidental_enabled,"item_attention_requires_incidental")
    check(incidental_enabled isa Bool,"incidental_items_flag")
    check(!incidental_enabled || (items!==nothing && basic_loop),"incidental_items_require_world_and_loop")
    incidental_items=incidental_enabled ? D(a=>incidental_item_state(a,choice_seed) for a in IDS) : nothing
    incidental_snapshot()=D(a=>incidental_item_snapshot(incidental_items[a]) for a in IDS)
    exchange_enabled=get(spec,:food_exchange,false)
    open_stores=get(spec,:open_stores,true)
    check(open_stores isa Bool,"open_stores_flag")
    check(exchange_enabled isa Bool,"food_exchange_flag")
    check(!exchange_enabled || (foods!==nothing && !shared_stores),"food_exchange_requires_personal_typed_food")
    relationship_enabled=get(spec,:social_relationships,false)
    check(relationship_enabled isa Bool,"social_relationships_flag")
    trades=exchange_enabled ? food_trade_state(choice_seed;relational=relationship_enabled) : nothing
    relations=relationship_enabled ? D(a=>social_relations_state(a;relational=true) for a in IDS) : nothing
    if relations!==nothing
        for a in IDS
            relations[a]["aid"]=social_aid_state(a;seed=choice_seed)
            relations[a]["visual_aid"]=visual_aid_state(a;seed=choice_seed)
            relations[a]["gradient_logging"]=get(spec,:gradient_logging,true)
            relations[a]["peer_rho_enabled"]=get(spec,:social_peer_rho,true)
            check(relations[a]["peer_rho_enabled"] isa Bool,"social_peer_rho_flag")
            check(relations[a]["gradient_logging"] isa Bool,"gradient_logging_flag")
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
    function process_sleep!(a,now,day,action,status)
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
                receipt!(learning[a],now;phase="night",kind=action=="rest" ? "wait" : action,status=action=="rest" ? "waited" : status,on_complete=callback)
    end
    focus_enabled=get(spec,:task_focus,true)
    focus_positions=copy(w.positions)
    wildlife_previous_positions=wildlife===nothing ? Tuple{Float64,Float64}[] : collect(zip(wildlife.animals.x,wildlife.animals.z))
    for sec in start_sec:days*div(clock.day_us,1_000_000)-1
        now=sec*1_000_000;w.seconds=sec
        visual_illumination=AmbientVision.illumination(sec;day_seconds=clock.day_us/1e6,night_start=clock.phase_boundaries_us[3]/1e6)
        foods!==nothing && (shared=food_expire_fish!(foods,w,cargo,food,stock,stores,shared,div(now,clock.day_us)))
        collapsed_ids=Tuple(a for a in IDS if configured_collapse_active(w.bodies[a];enabled=get(spec,:collapse_cognition_gate,true)))
        for a in IDS
            if !(a in collapsed_ids) && haskey(mb_maps[a],"collapse_gate")
                mb_maps[a]["collapse_gate"]["active"]=false
            end
        end
        paused_ids=post_return_idle ? Set(a for a in IDS if !(a in collapsed_ids) && (!trade_idle || configured_trade_idle_ready!(mb_maps[a],incidental_items[a],items,w,a,now,clock.day_us;social_notice=relations!==nothing && (get(relations[a],"aid_delivery",nothing)!==nothing || configured_social_notice(w,a,answered[a])))) && configured_post_return_idle!(mb_maps[a],now,clock.day_us,bounds[3];pending=haskey(pending,a),observing=configured_observation_enabled && now<clock.day_us,require_meal=post_return_meal)) : ()
        sleeping_ids=get(spec,:sleep_external_gate,true) ? Tuple(a for a in IDS if configured_sleep_gate_active(learning[a],now,clock.day_us)) : ()
        focus_phase=mod(now,clock.day_us)<bounds[1] ? "orientation" : mod(now,clock.day_us)<bounds[2] ? "exploration" : mod(now,clock.day_us)<bounds[3] ? "return" : "night"
        focused_ids=String[]
        motion_objects=Any[]
        wildlife_motion_samples=wildlife_motion_objects(wildlife,wildlife_previous_positions)
        if focus_enabled
            append!(motion_objects,wildlife_motion_samples)
            for b in IDS
                p=w.positions[b];prior=focus_positions[b]
                push!(motion_objects,(actor=b,x=p[1],z=p[2],vx=p[1]-prior[1],vz=p[2]-prior[2]))
            end
            sources=dynamic_hazard_mode=="off" ? spec.hazards : dynamic_hazard_sources(hazard_world,sec+div(world_offset,1_000_000);patrol=dynamic_hazard_mode=="mixed")
            for h in sources
                t=sec+div(world_offset,1_000_000)
                h.start<=t<h.stop || continue
                push!(motion_objects,(actor="",x=Float64(h.x+h.vx*(t-h.start)),z=Float64(h.z+h.vz*(t-h.start)),vx=Float64(h.vx),vz=Float64(h.vz)))
            end
        end
        for a in IDS
            fs=get!(task_focus_state,mb_maps[a],"task_focus")
            notice=get(fs,"active",false) && focus_enabled ? task_motion_notice(w.positions[a],yaw[a],(o for o in motion_objects if o.actor!=a);occluders=w.obstacles,illumination=visual_illumination) : nothing
            task_focus_continue!(fs,w.bodies[a],w.positions[a],yaw[a],focus_phase,now,notice;
                shield=get(spec,:task_interrupt_shield,true),
                need=notice===nothing ? 0. : food_anxiety(get(mb_maps[a],"food_security",nothing)),
                progress=notice===nothing ? 0. : configured_task_progress(foods,a,fs["plan"]["action"]),
                enabled=focus_enabled && !(a in paused_ids) && !(a in sleeping_ids) && !(a in collapsed_ids)) && push!(focused_ids,a)
        end
        focus_positions=copy(w.positions)
        wildlife!==nothing && (wildlife_previous_positions=collect(zip(wildlife.animals.x,wildlife.animals.z)))
        thinking_ids=Tuple(a for a in IDS if !(a in paused_ids) && !(a in sleeping_ids) && !(a in collapsed_ids) && !(a in focused_ids))

        # Both populations sense the pre-action world. Rabbit actions use this
        # frozen perception after human actions, before the common day boundary.
        wildlife!==nothing && LWGrazing.prepare!(wildlife,[w.positions[a] for a in IDS],sec;illumination=visual_illumination)
        (ground_wear || ground_perception) && advance_wear!(wear,wear_offset+now)
        lateral_views=lateral_side!="off" || continuous_descent || ground_continuity ? Dict(a=>lateral_obstacles(spec.obstacles,w.positions[a],yaw[a],"ob:$now:$a") for a in thinking_ids) : nothing
        rho_baselines=D()
        if ground_perception
            for a in thinking_ids
                view=ground_appearance(w,a,yaw,wear,now;dry=dry,illumination=visual_illumination)
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
                    added=food_season===nothing ? replenish_food!(stock,spec.food;capacity=regrowth_capacity) :
                        seasonal_replenish_food!(stock,spec.food,food_season,div(world_offset,clock.day_us)+day;capacity=regrowth_capacity)
                    replenished+=added
                    if foods!==nothing
                        for i in eachindex(stock);foods.added[foods.site_kinds[i]]+=stock[i]-old_stock[i];end
                    end
                    push!(replenishments,D("day"=>day,"us"=>now,"added"=>added))
                end
            end
        end
        phase=local_us<bounds[1] ? "orientation" : local_us<bounds[2] ? "exploration" : local_us<bounds[3] ? "return" : "night"
        if food_body
            for a in (thinking_ids...,focused_ids...)
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
            for a in thinking_ids;observe_sky!(sky[a],sky_sample(a,"ob:$now:$a",now,yaw[a],clock));end
        end
        obs=Dict(a=>observe(w,a) for a in thinking_ids)
        if wildlife!==nothing
            for a in thinking_ids
                wildlife_observed_features=wildlife_view(w.positions[a],yaw[a],wildlife_motion_samples;occluders=w.obstacles,illumination=visual_illumination)
                obs[a]["wildlife"]=wildlife_observed_features
                wildlife_focus_state=mb_maps[a]["task_focus"]
                wildlife_focus_state["wildlife_visible_ticks"]=get(wildlife_focus_state,"wildlife_visible_ticks",0)+!isempty(wildlife_observed_features)
                wildlife_focus_state["last_wildlife_view"]=D("us"=>now,"features"=>wildlife_observed_features)
                # Inspection evidence, not an instruction to flee or continue fishing.
            end
        end
        if items!==nothing
            item_expire!(items,now)
            for a in thinking_ids
                obs[a]["items"]=item_attention_enabled ? D("notices"=>items["notices"][a]) :
                    item_visible(items,w,spec.home,a,yaw[a],now;visual_obstacles=high,open_stores,foods=shared_stores ? nothing : foods,illumination=visual_illumination)
                item_exchange_enabled && incidental_items!==nothing && item_social_observe!(incidental_items[a],obs[a]["items"];
                    relation=relations===nothing ? nothing : relations[a])
            end
        end
        moves=Dict(a=>movement_observation(w,a,yaw,food,stock;resistance_at=resistance_at,run_resistance_at=base_resistance_at,running=running,visual_obstacles=high,
            illumination=visual_illumination,known_food_sites=daily_delivery_enabled ? mb_maps[a]["daily_plan"]["known_sites"] : ()) for a in thinking_ids)
        fishing_enabled && foreach(a->fishing_observation!(foods,a,moves[a]["visible"]),thinking_ids)
        if foods!==nothing && ((relations!==nothing && !shared_stores) || provision_enabled)
            for a in thinking_ids
                security=food_security_for!(mb_simulation ? mb_maps[a] : nothing,relations===nothing ? nothing : relations[a])
                visible=moves[a]["visible"]
                food_security_update!(security,mb_simulation ? mb_maps[a] : nothing,w.bodies[a],guts===nothing ? nothing : guts[a],
                    shared_stores ? foods.shared : foods.personal[a],foods.inventory[a],metabolism[a],now,clock.day_us;target=isempty(visible) ? nothing : first(visible))
            end
        end
        expressions=relations===nothing ? nothing : Dict(a=>configured_expression(w.bodies[a];anxiety=food_anxiety(food_security(relations[a])),fear=night_fear_enabled ? mb_maps[a]["night_fear"]["H"]/8 : 0.) for a in IDS)
        social_views=relations===nothing ? nothing : Dict(a=>social_sight(w,a,yaw[a],now;visual_obstacles=high,expressions,rho=get(rho_baselines,a,"coarse"),attention=social_attention(relations[a],now),illumination=visual_illumination) for a in thinking_ids)
        relations!==nothing && foreach(a->social_relations_observe!(relations[a],obs[a],now),thinking_ids)
        relations!==nothing && foreach(a->(relations[a]["social_view"]=social_views[a]),thinking_ids)
        trade_views=trades===nothing ? nothing : food_trade_views!(trades,foods,w,spec.home,now;relations=relations,open_stores,actors=Tuple(a for a in IDS if !(a in collapsed_ids)))

        homes=Dict{String,Any}(a=>home_observation(w,a,yaw,spec.home;visual_obstacles=high,range=skyline_mode=="off" ? 60 : 6,illumination=visual_illumination) for a in thinking_ids)
        sections=harvest_sleep ? Dict(a=>harvest_section(moves[a],"ob:$now:$a",now) for a in thinking_ids) : nothing
        if harvest_sleep
            for a in thinking_ids
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
        landmarks=landmark_routes ? Dict(a=>landmark_fan(current_landmarks,w.positions[a],yaw[a],"ob:$now:$a";night=phase=="night",all_colors=general_landmarks,illumination=visual_illumination) for a in thinking_ids) : nothing
        skyline_views=skyline_mode=="off" ? nothing : Dict(a=>(!get(spec,:predictive_skyline,false) ? skyline_fan(skyline_objects,w.positions[a],yaw[a],"ob:$now:$a";subrays=skyline_mode=="subrays",illumination=visual_illumination) : interval_skyline!(() -> skyline_fan(skyline_objects,w.positions[a],yaw[a],"ob:$now:$a";subrays=skyline_mode=="subrays",illumination=visual_illumination),skyline_states[a],get(ground_receipts,a,nothing),now,"ob:$now:$a";skyline_schedule_inputs(mb_maps[a],landmarks===nothing ? nothing : landmarks[a],moves[a],homes[a])...,fine=get(rho_baselines,a,"fine")=="fine",enabled=true,illumination=visual_illumination)) for a in thinking_ids)
        if skyline_views!==nothing
            for a in thinking_ids;record_skyline!(skyline_states[a],skyline_views[a]);end
        end
        climbs=climbing ? Dict(a=>[climb_sample(w,a,yaw[a],i,low,high,base_resistance_at) for i in 0:4] for a in thinking_ids) : nothing
        # Safety and learning share the same current, actor-local observation.
        hazard_views=(hazard_mode || general_sleep || movement_inertia || selection_trails || night_fear_enabled) ? Dict(a=>hazard_observation(w,a,yaw,hazard_mode ? hazard_sources : Any[],sec+div(world_offset,1_000_000);visual_obstacles=high,safe_home=camp_safe_zone ? spec.home : nothing,illumination=visual_illumination) for a in thinking_ids) : nothing
        contexts=general_sleep ? Dict(a=>sleep_context(moves[a],hazard_views[a];climbs=climbs===nothing ? nothing : climbs[a]) for a in thinking_ids) : nothing
        bundle_contexts=(experience_bundles || selection_trails) ? Dict(a=>bundle_context(w.inventory[a],w.bodies[a],moves[a],hazard_views[a]) for a in thinking_ids) : nothing
        # Every actor plans from observations acquired before any actor acts.
        plans=D()
        for a in focused_ids
            fs=mb_maps[a]["task_focus"];plans[a]=copy(fs["plan"]);homes[a]=fs["home"]
            selection_trails && (plans[a]["trail_parent"]=(reserve=w.bodies[a].reserve,H=hunger[a]["H"]))
        end
        trade_workers=trade_work_wait ? configured_trade_workers(previous) : ()
        if trade_work_wait
            for a in IDS
                q=get(incidental_items[a],"configured_work_wait",nothing)
                q===nothing && continue
                target=q["target"];target===nothing && continue
                if q["day"]!=day || phase in ("night","orientation") || !item_trade_contact(w,spec.home,a,target)
                    configured_trade_wait_poll!(incidental_items[a],trade_workers,String[],now,clock.day_us;eligible=false)
                end
            end
        end
        for a in thinking_ids
            integrate(a,now,obs[a]);o=obs[a];plan=nothing;home=homes[a]
            rho_profile=="home-distance" && observe_home_distance!(mb_maps[a]["home_distance"],home)
            at_home=home!==nothing && home["distance"]<=1.25
            foods!==nothing && mb_simulation && food_condition_observe!(mb_maps[a],foods.inventory[a],shared_stores ? foods.shared : foods.personal[a],at_home,now,clock.day_us;foods,actor=a,shared_stores)
            search_receipt=mb_simulation ? mb_maps[a]["receipt"] : nothing
            mb_simulation && mb_observe!(mb_maps[a],landmarks[a],now;home=at_home,food=any(f->f["distance"]<=1.25,moves[a]["visible"]))
            mb_simulation && mb_search_resistance_observe!(mb_maps[a],moves[a],landmarks[a],search_receipt,now;rho=get(rho_baselines,a,rho_profile))
            observing=configured_observation_enabled && now<clock.day_us
            food_targets=acorn_quest ? configured_acorn_quest_food_targets(mb_maps[a]["training_quest"],moves[a]["visible"]) : moves[a]["visible"]
            if mb_simulation && fishing_enabled && !acorn_quest && !(fishing_training && configured_fishing_training_active(mb_maps[a]["fishing_training"]))
                cast=get(get(foods.game.fishing,a,D()),"active",nothing)
                committed=cast!==nothing && cast["last_us"]+1_000_000==now ? cast["site"]-1 : nothing
                food_targets=acquisition_targets!(mb_maps[a],food_targets,loops[a]["food"],now;home=home,anxiety=food_anxiety(get(mb_maps[a],"food_security",nothing)),committed_ref=committed,
                    body=w.bodies[a],gut=guts===nothing ? nothing : guts[a],own_stock=shared_stores ? foods.shared : foods.personal[a],held=foods.inventory[a])
            end
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
                available=food_targets
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
            returning=observing ? false : configured_returning!(purposes[a],phase,w.inventory[a],at_home,now)
            replenishing=false;food_worried=relations!==nothing && food_anxiety(food_security(relations[a]))>0
            forecast_request_ready=relations!==nothing && food_request_ready(food_security(relations[a]),now)
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
            mb_simulation && mb_plan_context!(mb_maps[a],now,clock.day_us,w.bodies[a].reserve,metabolism[a])
            edible_on_hand=foods===nothing ? w.inventory[a]>0 : food_has_edible(foods,a)
            configured_action=food_desire ? nothing : foods===nothing ? configured_body_action(replenishing,w.inventory[a],guts===nothing || can_ingest(guts[a]),
                at_home,at_home ? (shared_stores ? shared : stores[a]) : 0) :
                configured_food_preparation(foods,a,food_hungry,guts===nothing || can_ingest(guts[a]),
                    at_home,at_home ? (shared_stores ? shared : stores[a]) : 0;
                    processing_feasible=food_processing_enabled && step(w.bodies[a],"process_food",w.inventory[a])[2]=="worked",
                    processing_enabled=food_processing_enabled && any(k->food_facility_for(facilities,w.positions[a],k)!==nothing,foods.inventory[a]))
            night_fear_enabled && !observing && (returning=night_fear_request!(mb_maps[a]["night_fear"],returning,replenishing,now,loops[a]["home"].rng))
            provision_stay=false
            if daily_delivery_enabled && !observing && !(fishing_training && configured_fishing_training_active(mb_maps[a]["fishing_training"])) && (!acorn_quest || configured_acorn_quest_released(mb_maps[a]["training_quest"],now,clock.day_us))
                if provision_enabled && phase=="night" && at_home
                    returning=true # Existing night rest, do not start a new day goal while asleep.
                else
                    provision_stay=provision_enabled && food_provision_stay!(mb_maps[a],get(mb_maps[a],"food_security",nothing),at_home,now,clock.day_us)
                    returning=provision_stay ? true : mb_daily_request!(mb_maps[a],moves[a],home,at_home,w.inventory[a],
                        w.bodies[a].reserve,w.bodies[a].strain,now,clock.day_us;replenishing=replenishing,return_hint=returning)
                end
            end
            # Forecast shortage can redirect the purpose before hunger, never force a meal.
            if food_worried && !provision_enabled && basic_loop && !observing && !(phase in ("night","orientation"))
                pressure=food_anxiety(food_security(relations[a]))
                probabilities=method_distribution(loops[a]["food"],Any[D("method"=>"security_explore","priority"=>log(pressure)),D("method"=>"security_continue","priority"=>0.)])
                rand(loops[a]["food"].rng)<probabilities[1] && (returning=false)
            end
            if acorn_quest && !observing && !(quest_release && configured_acorn_quest_released(mb_maps[a]["training_quest"],now,clock.day_us))
                quest_return=configured_acorn_quest_request!(mb_maps[a]["training_quest"],
                    observation_states[a]["completed"] && observation_states[a]["camp_landmark"]["tour_completed"] && mb_maps[a]["place_mb"]["complete"],
                    now,clock.day_us,at_home,moves[a]["visible"])
                quest_return!==nothing && (returning=quest_return)
            end
            if fishing_training && configured_fishing_training_active(mb_maps[a]["fishing_training"])
                returning=configured_fishing_training_returning(mb_maps[a]["fishing_training"])
                food_targets=configured_fishing_training_targets(moves[a]["visible"])
            end
            # Recipe constraints govern processing, not the current parent purpose.
            post_return_meal && configured_return_meal_hold(mb_maps[a],now,clock.day_us) && (returning=true)
            # Carrying raw food must not override energy-maintenance selection.
            if experience_bundles && !(a in focused_ids)
                form_bundle!(bundles[a],hunger[a],now)
                wake_bundles!(bundles[a],bundle_contexts[a],phase)
            end
            movement_inertia && observe_inertia!(inertia[a],a,now,inertia_view(moves[a],landmarks[a],hazard_views[a]))
            if basic_loop && haskey(pending,a)
                t=pop!(pending,a);s=loops[a][t.family]
                target=t.family=="home" ? home : isempty(food_targets) ? nothing : first(food_targets)
                same=target!==nothing && (t.family=="home" || t.ref===nothing || target["ref"]==t.ref)
                value=t.question=="social_contact" ? social_approach_evidence(D("social_peer"=>t.social_peer,"social_actor"=>a,"social_capture_us"=>t.social_capture_us),social_views[a]) : t.question=="ground_extension" ? ground_extension_result(ground_models[a],s.trial.method,t.status,t.moved) : t.question=="movement_progress" ? t.status=="performed" && t.moved : t.question=="rested" ? t.status=="performed" : t.question=="load_reduced" ? t.status=="dropped" : t.question=="recovered" ? t.status=="recovered" : t.question=="landmark_progress" ? t.status=="performed" : t.question=="acquired" ? t.status=="picked_up" : t.question=="home_confirmed" ? at_home && t.status=="performed" : t.question=="target_observed" ? target!==nothing :
                    same && t.distance!==nothing ? target["distance"]<t.distance : nothing
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
            aid_delivery_kinds=foods===nothing ? fill(meal_kind,w.inventory[a]) : foods.inventory[a]
            if hazard_mode
                hazard_view=hazard_views[a]
                plan=continuous_safety ? safety_methods!(safety[a],safety_loops[a],hazard_view,moves[a],"op:$now:$a";running=running,home=camp_safe_zone ? home : nothing) : safety_plan!(safety[a],hazard_view,moves[a];running=running)
            end
            if plan!==nothing
                # Safety has authority before social, food and night priorities.
            elseif (aid_delivery_plan=aid_response_continue!(relations===nothing ? nothing : relations[a],aid_delivery_kinds,o["others"],now))!==nothing
                plan=aid_delivery_plan
            elseif fishing_training && (fish_lesson=configured_fishing_training_plan(mb_maps[a]["fishing_training"],foods.inventory[a],at_home,guts===nothing || can_ingest(guts[a]),moves[a]["visible"];items=items,actor=a))!==nothing
                plan=fish_lesson
            elseif acorn_quest && (training_plan=configured_acorn_quest_training_plan(mb_maps[a]["training_quest"],foods.inventory[a],at_home,guts===nothing || can_ingest(guts[a]),step(w.bodies[a],"process_food",w.inventory[a])[2]=="worked"))!==nothing
                plan=training_plan
            elseif food_desire && (desire_plan=food_desire_plan!(mb_maps[a],loops[a]["food"],foods,a,guts===nothing ? nothing : guts[a],w.bodies[a],at_home,shared_stores ? foods.shared : foods.personal[a],facilities,w.positions[a],now;requested=food_hungry || (post_return_meal && at_home && configured_return_meal_due(mb_maps[a],now,clock.day_us)),processing=food_processing_enabled,items=items))!==nothing
                plan=desire_plan
            elseif !food_desire && post_return_meal && (meal_plan=configured_return_meal_plan(mb_maps[a],foods,a,now,clock.day_us,at_home,guts===nothing || can_ingest(guts[a]),shared_stores ? shared : stores[a];processing_enabled=food_processing_enabled && any(k->food_facility_for(facilities,w.positions[a],k)!==nothing,foods.inventory[a]),workable=step(w.bodies[a],"process_food",w.inventory[a])[2]=="worked"))!==nothing
                plan=meal_plan
            elseif configured_action!==nothing
                plan=D("action"=>configured_action)
                foods!==nothing && (plan["configured_food_preparation"]=true)
            elseif acorn_quest && (!quest_release || !configured_acorn_quest_released(mb_maps[a]["training_quest"],now,clock.day_us)) && (quest_rest=configured_acorn_quest_finished_plan(mb_maps[a]["training_quest"]))!==nothing
                plan=quest_rest
            elseif !isempty(messages)
                m=first(messages);current=merge(copy(o),D("messages"=>[m]))
                aid_reply_kind=aid_response_food(aid_delivery_kinds,foods===nothing || relations===nothing ? nothing : shared_stores ? foods.shared : foods.personal[a],at_home)
                if social_response || food_body || relations!==nothing
                    decision,trace=experienced_response(current,states[a]["records"],aid_view(a),a,"respond:$now:$a:$(m["id"])";retention=food_body ? retention_cost(current,hunger[a]) : 0.,relation=relations===nothing ? nothing : relations[a],now,available_food=aid_reply_kind>0)
                    act,t,r=decision
                    if trace!==nothing
                        rs=response_stats[a];rs["decisions"]+=1;rs[act]+=1
                        (trace["weight"]>0 || (haskey(trace,"relationship") && trace["relationship"]["weight"]!=0)) && (rs["experienced"]+=1)
                        relations!==nothing && social_relation_use!(relations[a],m["sender"],"give",trace["source"],now,trace["relationship"];action=act)
                        push!(rs["records"],trace);length(rs["records"])>32 && popfirst!(rs["records"])
                    end
                else
                    act,t,r=response(current,configured_legacy_generosity(a))
                end
                plan=D("action"=>act,"target"=>t,"reply_to"=>r)
                (m["kind"]=="request" && any(x->x["ref"]==m["sender"],o["others"])) && (plan["gradient_source"]="respond:$now:$a:$(m["id"])")
                relations!==nothing && t!==nothing && (plan["context"]=social_observed_context(relations[a],t,food_social_context(w.bodies[a])))
                if act=="give" && isempty(aid_delivery_kinds) && relations!==nothing && aid_reply_kind>0
                    plan["food_kind"]=aid_reply_kind
                    plan["deadline_us"]=round(Int,m["time"]*1_000_000)+AID_RESOURCE_RULES.reply_window_us
                    relations[a]["aid_delivery"]=copy(plan)
                    plan=merge(plan,D("action"=>"retrieve"))
                    delete!(plan,"gradient_source") # Delivery is pending, not a failed give.
                end
                push!(answered[a],m["id"])
                if act=="give" && relations!==nothing
                    visual_pending=get(get(relations[a],"visual_aid",D()),"pending",nothing)
                    visual_pending!==nothing && visual_pending["target"]==t && (plan=merge(visual_pending,plan))
                end
            elseif (routine=configured_routine_priority(!food_desire && (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80),
                    edible_on_hand,guts===nothing || can_ingest(guts[a]),at_home,shared_stores ? shared : stores[a],
                    phase,local_us,clock.quiet_night_us,states[a]["pending"]!==nothing,configured_overrides;
                    enabled=get(spec,:configured_routine_actions,true)))!==nothing
                plan=routine
            elseif (relations!==nothing ? forecast_request_ready : (food_body ? hunger_select(hunger[a]) : w.bodies[a].reserve<80)) && !configured_overrides.suppress_repeat_request && states[a]["pending"]===nothing
                forecast_request_ready && food_request_considered!(food_security(relations[a]),now)
                if relations!==nothing
                    aid_stock_view=open_stores && !shared_stores ? observed_food_stores(foods,w,spec.home,a) : D()
                    aid_condition_view=foods===nothing ? D() : observed_food_conditions(foods,D("observed_food_stocks"=>aid_stock_view))
                    aid_resource_observe!(relations[a],o["others"],aid_stock_view,aid_condition_view)
                end
                targets=[x["ref"] for x in o["others"] if x["holding_food"] || forecast_request_ready]
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
                    states[a]["pending"]=D("message_id"=>a*":"*op,"target"=>target,"deadline"=>now+AID_RESOURCE_RULES.reply_window_us,
                        "request_observation_id"=>"ob:$now:$a","operation_id"=>op)
                    if relations!==nothing
                        situation=social_aid_context(relations[a],target,food_social_context(w.bodies[a]))
                        prediction=social_mb_predict(relations[a],target,"aid_received";situation,H=aid_view(a).parent.H)
                        aid_resource_forecast=aid_resource_prediction(situation)
                        kinds=foods===nothing ? fill(meal_kind,w.inventory[a]) : foods.inventory[a]
                        aid_values=food_aid_values(w.bodies[a],guts===nothing ? nothing : guts[a],kinds;map=mb_simulation ? mb_maps[a] : nothing,kitchen=food_kitchen(a))
                        social_aid_begin!(relations[a]["aid"],a*":"*op,target,now;probability=prediction["probability"]*aid_resource_forecast["factor"],values=aid_values,deadline_us=now+AID_RESOURCE_RULES.reply_window_us,
                            kind_probabilities=prediction["kind_probabilities"],source_refs=prediction["source_refs"],mb_ids=prediction["mb_ids"],context=merge(situation,D(
                                "anxiety"=>food_anxiety(food_security(relations[a])),
                                "reserve"=>w.bodies[a].reserve,"shortfall"=>food_security(relations[a])["shortfall"],
                                "resource_prediction"=>aid_resource_forecast,
                                "self_reliance"=>get(food_security(relations[a]),"self_reliance",nothing))))
                        states[a]["pending"]["social_context"]=situation
                    end
                    plan=D("action"=>"request","target"=>target)
                end
            end

            if plan===nothing && relations!==nothing && !observing && !(phase in ("night","orientation"))
                kinds=foods===nothing ? fill(meal_kind,w.inventory[a]) : foods.inventory[a]
                plan=visual_aid_plan!(relations[a],social_views[a],w.bodies[a],guts===nothing ? nothing : guts[a],
                    shared_stores || foods===nothing ? nothing : foods.personal[a],kinds,now;at_home,contacts=o["others"])
            end
            if plan===nothing && items!==nothing
                plan=configured_item_plan(item_actions,a,now)
            end
            if plan===nothing && item_exchange_enabled && incidental_items!==nothing && !observing && !(phase in ("night","orientation")) && at_home && w.inventory[a]==0
                waiting=trade_work_wait && get(get(incidental_items[a],"configured_work_wait",D()),"target",nothing)!==nothing
                item_view=waiting && item_attention_enabled ? item_visible(items,w,spec.home,a,yaw[a],now;visual_obstacles=high,open_stores,foods=shared_stores ? nothing : foods,illumination=visual_illumination) : item_attention_enabled ? item_attention_view!(incidental_items[a],items,w,spec.home,a,yaw[a],now;
                    purpose=:trade,allow_start=trade_start_available(states[a],now,clock.day_us),visual_obstacles=high,open_stores,foods=shared_stores ? nothing : foods,illumination=visual_illumination) : get(o,"items",nothing)
                if trade_work_wait
                    plan=configured_trade_wait_poll!(incidental_items[a],trade_workers,
                        item_view===nothing ? String[] : item_view["trade_partners"],now,clock.day_us;
                        incoming=item_view!==nothing && !isempty(item_view["incoming"]))
                end
                if plan===nothing
                    plan=item_social_plan!(incidental_items[a],item_view,w.bodies[a],
                        guts===nothing ? nothing : guts[a],shared_stores || foods===nothing ? nothing : foods.personal[a],now;
                        map=mb_simulation ? mb_maps[a] : nothing,kitchen=food_kitchen(a),allow_start=trade_start_available(states[a],now,clock.day_us),
                        relation=relations===nothing ? nothing : relations[a])
                    trade_work_wait && (plan=configured_trade_wait_intercept!(incidental_items[a],plan,trade_workers,now,clock.day_us;relation=relations===nothing ? nothing : relations[a]))
                end
                trade_idle && configured_trade_idle_considered!(mb_maps[a],incidental_items[a],item_view,plan,now,clock.day_us;allow_start=trade_start_available(states[a],now,clock.day_us))
            end
            if plan===nothing && trade_work_wait && !observing && !(phase in ("night","orientation")) && at_home
                plan=configured_trade_reply_wait(incidental_items[a],items,w,spec.home,a,now)
            end
            if plan===nothing && trades!==nothing && !observing && phase!="night" && at_home && w.inventory[a]==0
                plan=food_trade_plan!(trades,a,get(trade_views,a,nothing),w.bodies[a],guts===nothing ? nothing : guts[a],now;
                    map=mb_simulation ? mb_maps[a] : nothing,kitchen=food_kitchen(a),allow_start=trade_start_available(states[a],now,clock.day_us),relation=relations===nothing ? nothing : relations[a])
            end
            if plan===nothing && provision_stay
                plan=D("action"=>"rest","method"=>"provision_stay","provision_choice"=>true)
                mb_maps[a]["provision_choice"]["stay_ticks"]+=1
            end
            if observing && plan===nothing
                plan=configured_observation_food(moves[a],replenishing,w.inventory[a])
                plan===nothing && configured_camp_landmark && (plan=configured_camp_landmark_tour!(observation_states[a]["camp_landmark"],spec.home,w.positions[a],yaw[a],sec,camp_view,w.bodies[a].reserve,w.bodies[a].strain,local_us,clock;experience=configured_camp_experience,exterior=get(spec,:configured_camp_exterior,false),landmark_view=landmarks===nothing ? nothing : landmarks[a],skyline_view=skyline_views===nothing ? nothing : skyline_views[a]))
                # Disabled camp training has no landmark/place state to read.
                plan===nothing && configured_camp_experience && (plan=configured_camp_learning_rest(configured_camp_experience,observation_states[a]["camp_landmark"]["tour_completed"],mb_maps[a]["place_mb"]["complete"],at_home))
                plan===nothing && (plan=configured_observation_plan(observation_states[a],w.positions[a],yaw[a],sec,local_us,clock,w.bodies[a].reserve,w.bodies[a].strain))
            end
            if get(spec,:gradient_roll,false) && plan===nothing && basic_loop && !observing && !at_home &&
                    phase in ("exploration","return") && w.bodies[a].strain<.8 && w.bodies[a].reserve>0
                family=returning ? "home" : "food"
                roll_target=returning ? home : isempty(food_targets) ? nothing : first(food_targets)
                roll_target=gradient_roll_observed_target(mb_maps[a],roll_target,landmarks===nothing ? nothing : landmarks[a],skyline_views===nothing ? nothing : skyline_views[a])
                plan=gradient_roll_plan!(mb_maps[a],get(ground_receipts,a,nothing),now,yaw[a],family,phase,loops[a][family].H,roll_target)
                if plan!==nothing
                    source="op:$now:$a"
                    get(mb_maps[a]["gradient_roll"],"cue_kind","")!="" && (plan["question"]="movement_progress")
                    plan=choose_method!(loops[a][family],[plan],source)
                    pending[a]=(family=family,source=source,phase=phase,question=plan["question"],
                        distance=roll_target===nothing ? nothing : roll_target["distance"],
                        ref=roll_target===nothing || returning ? nothing : get(roll_target,"ref",nothing),status="unexecuted",social_peer=nothing,social_capture_us=now)
                end
            end
            if plan===nothing
                if (routine=configured_navigation_priority(returning,at_home,w.inventory[a],phase,configured_overrides;
                        enabled=get(spec,:configured_routine_actions,true)))!==nothing
                    plan=routine
                elseif w.bodies[a].strain>=CONFIGURED_LIMITS.navigation_rest_strain || w.bodies[a].reserve<=0
                    plan=D("action"=>"rest")
                elseif basic_loop
                    family=returning ? "home" : "food"
                    if incidental_items!==nothing
                        urgency=food_body ? hunger[a]["intensity"] : clamp((80-w.bodies[a].reserve)/80,0.,1.)
                        night_fear_enabled && (urgency=max(urgency,clamp(mb_maps[a]["night_fear"]["H"]/32,0.,1.)))
                        item_view=item_attention_enabled ? item_attention_view!(incidental_items[a],items,w,spec.home,a,yaw[a],now;
                            purpose=:pickup,H=loops[a][family].H,pressure=urgency,visual_obstacles=high) : o["items"]
                        plan=incidental_item_plan!(incidental_items[a],item_view,w.bodies[a],loops[a][family],now;
                            family=family,pressure=urgency,stock=shared_stores || foods===nothing ? nothing : foods.personal[a],
                            gut=guts===nothing ? nothing : guts[a],map=mb_simulation ? mb_maps[a] : nothing,kitchen=food_kitchen(a))
                    end
                    if plan===nothing
                        visible=food_targets;target=returning ? home : isempty(visible) ? nothing : first(visible)
                        if goal_arrival_enabled && !returning && mb_maps[a]["goal_arrival"]["food"]["mode"]=="approach"
                            held=filter(f->f["ref"]==mb_maps[a]["goal_arrival"]["food"]["target"],visible)
                            target=isempty(held) ? nothing : first(held)
                        end
                        if !returning && target!==nothing && get(target,"acquisition","pickup")=="fishing" && target["distance"]<=1.25
                            plan=fishing_plan!(foods,a,loops[a]["food"],target,now)
                        elseif (routine=configured_near_food(returning,target,dropped["origins"];enabled=get(spec,:configured_routine_actions,true)))!==nothing
                            plan=routine
                        else
                            s=loops[a][family];source="op:$now:$a"
                            navigation_H=night_fear_enabled && family=="home" ? max(s.H,mb_maps[a]["night_fear"]["H"]) : s.H
                            candidates=search_candidates(moves[a],target,s)
                            if relations!==nothing && family=="food" && (food_hungry || food_worried)
                                kinds=foods===nothing ? fill(meal_kind,w.inventory[a]) : foods.inventory[a]
                                aid_values=food_aid_values(w.bodies[a],guts===nothing ? nothing : guts[a],kinds;map=mb_simulation ? mb_maps[a] : nothing,kitchen=food_kitchen(a))
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
                            if repetition_pressure && !(a in focused_ids)
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
                            mb_simulation && mb_search_resistance_project!(mb_maps[a],candidates,family,moves[a],now)
                            plan=choose_method!(s,candidates,source)
                            mb_simulation && mb_search_resistance_selected!(mb_maps[a],plan,now)
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
                else
                    plan=configured_legacy_navigation(returning,home,moves[a],dropped["origins"] )
                end
            end
            if basic_loop && !(get(plan,"configured_rule",nothing) in ("wait_before_trade_offer","wait_for_trade_reply")) && !get(plan,"configured_observation",false) && !haskey(pending,a) && (plan["action"] in ("pickup","recover","deposit") || (at_home && plan["action"]=="rest" && loops[a]["home"].H>0))
                family=plan["action"] in ("pickup","recover") ? "food" : "home"
                question=plan["action"]=="recover" ? "recovered" : family=="food" ? "acquired" : "home_confirmed"
                source="op:$now:$a"
                plan=choose_method!(loops[a][family],[configured_work_candidate(plan,question)],source)
                pending[a]=(family=family,source=source,phase=phase,question=question,distance=nothing,ref=nothing,status="unexecuted")
            end
            if orientation && !get(plan,"configured_observation",false) && plan["action"]=="scan" && !get(plan,"goal_arrival",false) && !get(plan,"safety",false) && !get(plan,"home_distance_confirm",false) && !haskey(plan,"mb_place") && !(general_landmarks && haskey(plan,"cue_kind")) && !haskey(plan,"mb_edge")
                plan["scan_angle"]=orientation_scan!(sky[a],clock)
            end
            plan["purpose_family"]=returning ? "home" : "food"
            if mb_simulation && haskey(pending,a) && !get(plan,"configured_observation",false)
                parent_family=pending[a].family
                parent_target=parent_family=="home" ? home : isempty(food_targets) ? nothing : first(food_targets)
                mb_parent_begin!(mb_maps[a],plan,parent_family,parent_target,now)
            end
            if continuous_descent && !get(plan,"configured_observation",false) && plan["action"] in ("walk","run")
                visible=food_targets
                goal=returning ? home : isempty(visible) ? nothing : first(visible)
                structure_state=ground_continuity ? ground_models[a]["structures"] : nothing
                if get(plan,"gradient_roll",false)
                    roll=mb_maps[a]["gradient_roll"]
                    goal=D("forward"=>roll["target_forward"],"right"=>roll["target_right"],"distance"=>hypot(roll["target_forward"],roll["target_right"]))
                end
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
            if get(spec,:gradient_roll,false) && basic_loop
                family=returning ? "home" : "food"
                roll_target=returning ? home : isempty(food_targets) ? nothing : first(food_targets)
                gradient_roll_enroll!(mb_maps[a],plan,now,yaw[a],family,phase,loops[a][family].H,roll_target;direction_distance=get(spec,:gradient_direction_distance,0.))
            end
            bundle_credit && (plan["bundle_parent"]=D("actor"=>a,"due"=>hunger[a]["due"],"H"=>hunger[a]["H"]))
            selection_trails && (plan["trail_parent"]=(reserve=w.bodies[a].reserve,H=hunger[a]["H"]))
            plans[a]=plan
        end
        # Ordered action resolution: receipts are stamped at the end of this second.
        trade_work_wait && configured_trade_departure_guard!(plans,incidental_items,trade_workers,now,clock.day_us;relations)
        w.seconds=sec+1
        for a in IDS
            if a in collapsed_ids
                acquisition_finish!(mb_maps[a],"interrupted","collapsed")
                fishing_enabled && fishing_cancel!(foods,a,now,"collapsed")
                configured_collapse_tick!(mb_maps[a],w,a,counts,events,previous,now)
                continue
            end
            if a in sleeping_ids
                acquisition_finish!(mb_maps[a],"interrupted","sleep")
                fishing_enabled && fishing_cancel!(foods,a,now,"sleep")
                configured_sleep_gate_tick!(learning[a],w,a,counts,events,previous,now)
                embedded_rest_enabled && embedded_rest_feedback!(mb_maps[a]["embedded_rest"],get(learning[a]["sleep"]["external_gate"],"at_home",false),"rest","performed",now,clock.day_us)
                process_sleep!(a,now,day,"rest","performed")
                continue
            end
            if a in paused_ids
                acquisition_finish!(mb_maps[a],"interrupted","cognition_pause")
                fishing_enabled && fishing_cancel!(foods,a,now,"cognition_pause")
                configured_post_return_idle_tick!(mb_maps[a],w,a,counts,events,previous,phase,now)
                continue
            end
            plan=plans[a];action=plan["action"];op="op:$now:$a";p=w.positions[a];before_yaw=yaw[a];status="performed"
            get(plan,"purpose_family",nothing)!="food" && acquisition_finish!(mb_maps[a],"interrupted","parent_purpose_changed")
            if wildlife!==nothing && !(a in focused_ids)
                wildlife_focus_state=mb_maps[a]["task_focus"];task_interrupt_record=get(wildlife_focus_state,"last_interrupt",nothing)
                if task_interrupt_record!==nothing && task_interrupt_record["us"]==now && task_interrupt_record["wake"] && !isempty(get(obs[a],"wildlife",Any[]))
                    wildlife_inspection_action_counts=get!(() -> D(),wildlife_focus_state,"motion_inspection_with_wildlife_actions")
                    wildlife_inspection_action_counts[action]=get(wildlife_inspection_action_counts,action,0)+1
                end
            end
            fishing_enabled && action!="fish" && fishing_cancel!(foods,a,now,"other_action")
            daily_cargo_before=w.inventory[a]
            food_remaining_observed=nothing
            repetition_before=w.bodies[a]
            frozen_prediction=harvest_sleep && action=="pickup" ? harvest_predict(harvest[a],sections[a]) : nothing
            leg=plan["purpose_family"] # Frozen selection-time parent, not post-drop load.
            delivered=String[]
            eaten_kind=0;meal_liking=nothing
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
            elseif action=="discard_food"
                disposal_home=hypot(p[1]-spec.home[1],p[2]-spec.home[2])<=1.25
                status=food_discard!(foods,w,cargo,stores,facilities,a,plan["food_kind"],plan["food_quality"],disposal_home,shared_stores,op,now)
                shared_stores && (shared=sum(foods.shared))
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
            elseif action=="inspect_food"
                k=plan["food_kind"]
                available=k in foods.inventory[a]
                status=available ? (RDLBody.food_edible(k) ? "food_usable" : "food_rejected") : "no_ingredient"
                available && food_condition_result!(mb_maps[a],k,RDLBody.food_edible(k),now)
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
            elseif action=="observe_salt_sample"
                status=configured_observe_salt_sample!(mb_maps[a],items)
            elseif action=="taste_item"
                status=item_taste!(items,mb_maps[a],w,spec.home,a,plan["item_id"],now)
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
            elseif action in ITEM_ACTIONS
                receipt=item_execute!(items,shared_stores ? nothing : foods,w,stores,spec.home,a,op,action,now;
                    item_id=get(plan,"item_id",0),target=get(plan,"target",nothing),offer_id=get(plan,"offer_id",nothing),
                    give_items=get(plan,"give_items",Int[]),want_items=get(plan,"want_items",Int[]),
                    give_food=get(plan,"give_food",[0,0,0,0]),want_food=get(plan,"want_food",[0,0,0,0]))
                # Item acquisition must never count as food acquisition.
                status="item_"*receipt["status"]
                trade_start_record!(states[a],action,receipt["status"],now,clock.day_us,op)
                haskey(plan,"item_social_role") && item_social_executed!(incidental_items[a],plan,receipt;
                    relation=relations===nothing ? nothing : relations[a])
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
                trade_start_record!(states[a],action,receipt["status"],now,clock.day_us,op)
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
            elseif action=="fish"
                w.bodies[a],work_status,_,_=step(w.bodies[a],"fish",w.inventory[a])
                if work_status=="worked"
                    status=fishing_tick!(foods,w,cargo,food,stock,a,plan["food_ref"]+1,now,op)
                    if mb_simulation
                        mb_maps[a]["game_skill_mbs"]=get(foods.game.skills,a,D())
                    end
                else
                    fishing_cancel!(foods,a,now,"body_limited");status=work_status
                end
            elseif action=="process_food"
                raw_index=foods===nothing ? nothing : findfirst(k->RDLBody.FOOD_PROCESS_OUTPUT[k]!=0 && (get(plan,"food_kind",0)==0 || k==plan["food_kind"]),foods.inventory[a])
                facility=raw_index===nothing ? nothing : food_facility_for(facilities,p,foods.inventory[a][raw_index])
                legal=food_processing_enabled && facility!==nothing
                if legal
                    plan["food_facility_id"]=facility.id
                    w.bodies[a],work_status,_,_=step(w.bodies[a],"process_food",w.inventory[a])
                    status=work_status=="worked" ? food_process!(foods,a;kind=Int(foods.inventory[a][raw_index]),salt_id=get(plan,"salt_id",nothing),items,now) : work_status
                    if mb_simulation && foods.game.enabled
                        mb_maps[a]["game_skill_mbs"]=get(foods.game.skills,a,D())
                    end
                else
                    status="preparation_unavailable"
                end
            elseif action in ("eat","request","give","refuse","warn","withdraw","wait")
                premeal=w.bodies[a]
                meal_index=foods===nothing || action!="eat" ? 1 : food_meal_index(foods,a,guts===nothing ? nothing : guts[a],premeal.reserve,get(plan,"food_kind",0);quality=get(plan,"food_quality",0))
                actual_kind=foods===nothing ? meal_kind : meal_index>0 && action=="eat" ? Int(foods.inventory[a][meal_index]) : 0
                if action=="eat" && (meal_index==0 || (guts!==nothing && !can_ingest(guts[a])))
                    r=D("status"=>meal_index==0 ? "no_edible_food" : "gut_full")
                else
                    delivered_kind=action=="give" && w.inventory[a]>0 ? (foods===nothing ? meal_kind : Int(first(foods.inventory[a]))) : nothing
                    r=communicate!(w,a,op,action,get(plan,"target",nothing),get(plan,"reply_to",nothing);food_kind=delivered_kind,unsolicited=get(plan,"visual_aid",false) && get(plan,"reply_to",nothing)===nothing)
                end
                status=r["status"]
                if relations!==nothing && action in ("give","refuse") && get(plan,"target",nothing)!==nothing
                    social_relation_event!(relations[a],plan["target"],"aid_given",op,now;
                        outcome=action=="refuse" && status=="expressed" ? "refuse" : status,context=get(plan,"context",nothing))
                    if get(plan,"visual_aid",false) && get(plan,"reply_to",nothing)===nothing && status=="transferred"
                        receiver=plan["target"]
                        received_values=food_aid_values(w.bodies[receiver],guts===nothing ? nothing : guts[receiver],foods===nothing ? Int[] : foods.inventory[receiver];map=mb_simulation ? mb_maps[receiver] : nothing,kitchen=food_kitchen(receiver))
                        social_relation_event!(relations[receiver],a,"aid_received",a*":"*op,now;
                            outcome="given",value=received_values[delivered_kind],food_kind=delivered_kind,context=food_social_context(w.bodies[receiver]))
                    end
                end
                if status=="ate"
                    quality=foods===nothing ? 2 : food_quality(foods,a,meal_index)
                    quality_bonus=game_food_bonus(actual_kind,quality)
                    liking=FOOD_LIKING[actual_kind]+quality_bonus
                    if guts!==nothing
                        w.bodies[a]=premeal # food transfer stays committed; energy waits for digestion
                        liking=ingest!(guts[a],actual_kind,premeal.reserve,now;quality_bonus)
                    end
                    deleteat!(cargo[a],meal_index)
                    if foods!==nothing
                        food_remove!(foods,a,meal_index)
                        food_record_meal!(foods,a,actual_kind,liking,now;quality)
                    end
                    eaten_kind=actual_kind;meal_liking=liking
                    if mb_simulation
                        food_remember_taste!(mb_maps[a],actual_kind,quality,liking,now)
                    end
                elseif status=="transferred"
                    push!(cargo[plan["target"]],popfirst!(cargo[a]))
                    foods!==nothing && food_give!(foods,a,plan["target"])
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
                    legal=!fishing_site(f) && stock[j]>0 && hypot(f.x-p[1],f.z-p[2])<=1.25 && !any(o->segment_hit(p,(Float64(f.x),Float64(f.z)),o,0.),w.obstacles)
                    if legal;stock[j]-=1;w.inventory[a]+=1;push!(cargo[a],op);end
                    legal && foods!==nothing && food_push!(foods,a,foods.site_kinds[j],get(foods.game.sites,j,2);deadline=food_acquisition_deadline(foods,j))
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
                    elseif legal && (shared_stores ? shared : stores[a])>0 && (get(plan,"food_kind",0)==0 || (foods!==nothing && get(plan,"food_kind",0) in RDLBody.FOOD_KIND_IDS && (shared_stores ? foods.shared : foods.personal[a])[plan["food_kind"]]>0))
                        foods!==nothing && food_retrieve!(foods,a,shared_stores,guts===nothing ? nothing : guts[a],w.bodies[a].reserve;kind=get(plan,"food_kind",0),quality=get(plan,"food_quality",0))
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
            get(plan,"visual_aid",false) && visual_aid_executed!(relations[a],plan,status;now)
            haskey(plan,"gradient_source") && gradient_result!(relations===nothing ? nothing : relations[a],plan["gradient_source"],status;actual=status=="transferred" ? 1. : 0.,now)
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
            if landmark_routes && !(a in focused_ids) && !get(plan,"safety",false)
                near=homes[a]!==nothing && homes[a]["distance"]<=1.25
                route_result!(routes[a],landmarks[a],op,action,status,leg,near,get(plan,"route",nothing);delivered=delivered,relational=relation_field)
            end
            if phase=="night"
                process_sleep!(a,now,day,action,status)
                get(spec,:sleep_external_gate,true) && action=="rest" && status=="performed" && configured_sleep_gate_enter!(learning[a],now,clock.day_us;at_home=homes[a]!==nothing && homes[a]["distance"]<=1.25)
            end
            general_sleep && !(a in focused_ids) && remember_general!(general[a],a,op,action,status,get(plan,"target",nothing),phase,now+1_000_000;context=contexts[a],direction=get(plan,"direction",nothing),retain=sleep_retention)
            if harvest_sleep && action=="pickup"
                harvest_pending[a]=(op=op,before=deepcopy(sections[a]),status=status,executed=now+1_000_000,
                    prediction=frozen_prediction,position=p,yaw=yaw[a])
            end
            mb_simulation && mb_record!(mb_maps[a],get(plan,"configured_observation",false) ? merge(plan,D("purpose_family"=>nothing)) : plan,status,repetition_before.reserve-w.bodies[a].reserve,now;turn=wrap_angle(yaw[a]-before_yaw),distance=hypot(w.positions[a][1]-p[1],w.positions[a][2]-p[2]))
            if repetition_pressure && !(a in focused_ids)
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
            if experience_bundles && !(a in focused_ids)
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
            goal_arrival_enabled && action in ("pickup","recover","fish") && status in ("picked_up","recovered") && goal_arrival_update!(mb_maps[a]["goal_arrival"]["food"],nothing,nothing,0.,now+1_000_000;completed=true)
            configured_camp_experience && now<clock.day_us && configured_camp_place_rest!(mb_maps[a]["place_mb"],observation_states[a]["camp_landmark"],loops[a]["home"],plan,status,homes[a]!==nothing && homes[a]["distance"]<=1.25,now)
            counts[a][action]=get(counts[a],action,0)+1
            # Contact sensing happens immediately after this actor's action, before
            # the next actor can change stock. Never read distant/occluded stock.
            if mb_simulation && action in ("pickup","recover")
                j=get(plan,"food_ref",-1)+1
                if 1<=j<=length(food)
                    f=food[j]
                    if !fishing_site(f) && hypot(f.x-p[1],f.z-p[2])<=1.25 && !any(o->segment_hit(p,(Float64(f.x),Float64(f.z)),o,0.),w.obstacles)
                        food_remaining_observed=stock[j]
                    end
                end
            end
            fishing_training && configured_fishing_training_result!(mb_maps[a]["fishing_training"],action,status,eaten_kind,
                hypot(w.positions[a][1]-spec.home[1],w.positions[a][2]-spec.home[2])<=1.25,now+1_000_000;liking=meal_liking)
            acorn_quest && configured_acorn_quest_result!(mb_maps[a]["training_quest"],action,status,now+1_000_000;
                kind=action=="pickup" && status=="picked_up" ? foods.site_kinds[plan["food_ref"]+1] : eaten_kind,
                source=action=="pickup" && status=="picked_up" ? op : nothing,delivered=delivered,liking=meal_liking)
            if mb_simulation && fishing_enabled && !(fishing_training && configured_fishing_training_active(mb_maps[a]["fishing_training"]))
                acquisition=get(get(mb_maps[a],"acquisition",D()),"choice",nothing)
                if acquisition!==nothing && get(plan,"purpose_family",nothing)=="food" && (!(action in ("fish","pickup")) || get(plan,"food_ref",nothing)==acquisition["ref"]) && action in ("fish","pickup","walk","run","scan")
                    acquisition_result!(mb_maps[a],acquisition["technique"],acquisition["ref"],get(acquisition,"acquire_seconds",acquisition["seconds"]),1.,status=="picked_up";sensitivity=mb_maps[a]["sensitivity"]["delay"],now,
                        energy=repetition_before.reserve-w.bodies[a].reserve)
                end
            end
            daily_delivery_enabled && mb_daily_result!(mb_maps[a],plan,status,now,
                repetition_before.reserve-w.bodies[a].reserve,daily_cargo_before;
                acquired_source=isempty(cargo[a]) ? nothing : last(cargo[a]),delivered_sources=delivered)
            post_return_meal && configured_return_meal_record!(mb_maps[a],action,status,hypot(w.positions[a][1]-spec.home[1],w.positions[a][2]-spec.home[2])<=1.25,now+1_000_000,clock.day_us)
            trade_idle && status=="ate" && haskey(mb_maps[a],"configured_trade_idle") && (mb_maps[a]["configured_trade_idle"]["ready"]=false)
            food_desire && food_desire_result!(mb_maps[a],plan,status,eaten_kind,meal_liking,now+1_000_000)
            mb_simulation && action in ("pickup","recover") && mb_food_contact!(mb_maps[a],plan,status,
                food_remaining_observed,now+1_000_000,op)
            task_focus_record!(mb_maps[a]["task_focus"],plan,status,w.bodies[a],w.positions[a],yaw[a],phase,now,w.inventory[a],homes[a];enabled=focus_enabled)
            sig=(phase,leg,action,get(plan,"target",nothing),status,get(plan,"method",nothing),get(plan,"direction",nothing),get(plan,"selection_mode",nothing),get(plan,"configured_rule",nothing))
            if get(previous,a,nothing)!=sig || get(plan,"incidental_item",false)
                push!(events,D("us"=>now,"actor"=>a,"phase"=>phase,"purpose_family"=>leg,"action"=>action,"status"=>status,"target"=>get(plan,"target",nothing),
                    "method"=>get(plan,"method",nothing),"direction"=>get(plan,"direction",nothing),"selection_mode"=>get(plan,"selection_mode",nothing),
                    "route"=>get(plan,"route",nothing),"landmark_color"=>get(plan,"landmark_color",nothing),"configured_rule"=>get(plan,"configured_rule",nothing)))
                action=="process_food" && (events[end]["food_facility_id"]=get(plan,"food_facility_id",nothing))
                if get(plan,"incidental_item",false)
                    events[end]["incidental_item"]=true;events[end]["item_id"]=plan["item_id"]
                end
                previous[a]=sig
            end
        end
        wildlife!==nothing && LWGrazing.advance!(wildlife,sec)
        advance_physiology!(w,metabolism,guts,food_body)
        @assert shared+sum(stock)+sum(values(w.inventory))+sum(values(stores))+w.consumed+food_waste_total(foods)==initial+replenished
        foods!==nothing && food_audit!(foods,w,stock,shared,stores)
        items!==nothing && item_audit!(items,w)
        if mod(now+1_000_000,clock.day_us)==0
            foods!==nothing && (shared=food_expire_fish!(foods,w,cargo,food,stock,stores,shared,div(now+1_000_000,clock.day_us)))
            for a in IDS
                (a in collapsed_ids || configured_collapse_active(w.bodies[a];enabled=get(spec,:collapse_cognition_gate,true))) && continue
                configured_observation_enabled && now+1_000_000==clock.day_us && configured_observation_finish!(observation_states[a],mb_maps[a])
                !(a in sleeping_ids) && integrate(a,now+1_000_000,observe(w,a))
                cycle=learning[a]["sleep"]["cycle"]
                relations===nothing && (states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>now+1_000_000)),a))
            end
            push!(daily,D("physical"=>physical(),"sleep"=>deepcopy(learning),"counts"=>deepcopy(counts),
                "shared_stock"=>shared,"ground"=>sum(stock),"consumed"=>w.consumed,"discarded_food"=>food_waste_total(foods),"replenished_food"=>replenished))
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
        collapsed=configured_collapse_active(w.bodies[a];enabled=get(spec,:collapse_cognition_gate,true))
        !collapsed && !(get(spec,:sleep_external_gate,true) && configured_sleep_gate_active(learning[a],Int(days*clock.day_us)-1_000_000,clock.day_us)) && integrate(a,Int(days*clock.day_us),observe(w,a))
        cycle=learning[a]["sleep"]["cycle"]
        !collapsed && relations===nothing && (states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>Int(days*clock.day_us))),a))
        terminal[a]=D("body_purpose"=>body_purpose ? deepcopy(configured_body_states[a]) : nothing,"return_purpose"=>deepcopy(purposes[a]),"position"=>collect(w.positions[a]),"body"=>bodydict(w.bodies[a]),"inventory"=>w.inventory[a],
            "personal_stock"=>stores[a],"sleep"=>learning[a],"social"=>states[a],"aid"=>relations===nothing ? pressure_snapshot(live[a]) : social_aid_snapshot(relations[a]["aid"]),"distance"=>distance[a],
            "routes"=>landmark_routes ? deepcopy(routes[a]) : nothing,"max_radius_observer_only"=>max_radius[a],
            "harvest"=>harvest_sleep ? deepcopy(harvest[a]) : nothing,"model_field"=>field_stats[a])
    end
    environment=D("rule"=>"native-cohort-world-v1","day_us"=>clock.day_us,"next_us"=>world_offset+days*clock.day_us,
        "shared_stores"=>shared_stores,"shared_stock"=>shared,"regrowth_days"=>regrowth_days,"regrowth_capacity"=>regrowth_capacity,"landscape"=>land,"obstacles"=>spec.obstacles,"renewal_targets"=>spec.food,"ground_patches"=>spec.ground_patches,
        "renewable"=>renewable_food,"food_season"=>food_season,"open_stores"=>open_stores,"hazard_mode"=>dynamic_hazard_mode,"dropping"=>dropping,"wear_enabled"=>ground_wear,
        "food"=>deepcopy(food),"stock"=>copy(stock),"ground"=>ground_wear ? wear_snapshot(wear) : nothing,
        "hazards"=>dynamic_hazard_mode!="off" ? deepcopy(hazard_world) : nothing,
        "wildlife"=>wildlife===nothing ? nothing :
            (!isempty(daily) && haskey(daily[end],"wildlife") ? daily[end]["wildlife"] : LWGrazing.snapshot(wildlife)),
        "food_resources"=>foods===nothing ? nothing : food_snapshot(foods),"food_facilities"=>facilities,
        "food_exchange"=>trades===nothing ? nothing : food_trade_snapshot(trades),
        "portable_items"=>items===nothing ? nothing : item_snapshot(items),
        "cargo"=>[D("index"=>i,"source"=>dropped["origins"][i]) for i in sort(collect(keys(dropped["origins"])))])
    merge(incidental_items===nothing ? D() : D("incidental_items"=>incidental_snapshot()),items===nothing ? D() : D("portable_items"=>item_snapshot(items)),relations===nothing ? D() : D("social_relationships"=>relation_snapshot()),trades===nothing ? D() : D("food_exchange"=>food_trade_snapshot(trades)),guts===nothing ? D() : D("digestion"=>D(a=>digestion_snapshot(guts[a]) for a in IDS)),lateral_side=="off" ? D() : D("lateral"=>lateral_stats),D("ambient_vision"=>AmbientVision.RULE,"food_resources"=>environment["food_resources"],"wildlife"=>environment["wildlife"],"home_observation"=>configured_observation_enabled ? observation_states : nothing,"mb_map"=>mb_simulation ? mb_maps : nothing,"body_purpose"=>body_purpose ? configured_body_states : nothing,"observed_cues"=>general_landmarks ? cue_states : nothing,"shared_stock"=>shared,"shared_storage"=>shared_stores ? storage_stats : nothing,"skyline"=>skyline_mode=="off" ? nothing : skyline_states,"reposition"=>reposition ? reposition_states : nothing,"world_checkpoint"=>environment,"selection_trails"=>selection_trails ? trails : nothing,"experience_bundles"=>experience_bundles ? D(a=>bundle_snapshot(bundles[a]) for a in IDS) : nothing,"exploration_horizon"=>exploration_horizon ? horizons : nothing,"movement_inertia"=>movement_inertia ? inertia : nothing,"body_field"=>body_field ? body_fields : nothing,"relation_field"=>relation_field ? relation_fields : nothing,"orientation"=>orientation ? sky : nothing,"safety_methods"=>continuous_safety ? D(a=>loop_snapshot(safety_loops[a]) for a in IDS) : nothing,"world_hazards"=>dynamic_hazard_mode!="off" ? hazard_world : nothing,"food_body"=>food_body ? D("hunger"=>hunger,"metabolic_loss"=>metabolism) : nothing,"ground_continuity"=>ground_continuity ? ground_models : nothing,"ground_perception"=>ground_perception ? ground_views : nothing,"ground_wear"=>ground_wear ? wear_snapshot(wear) : nothing,"sleep_action_models"=>sleep_actions ? action_models : nothing,"general_sleep"=>general_sleep ? general : nothing,"social_response"=>(social_response || food_body || relations!==nothing) ? response_stats : nothing,"ended_us"=>days*clock.day_us,"expired_fish"=>(foods===nothing ? 0 : foods.game.expired_fish),"initial_food"=>initial,"ground"=>sum(stock),"consumed"=>w.consumed,
        "discarded_food"=>food_waste_total(foods),"replenished_food"=>replenished,"replenishments"=>replenishments,
        "dropped_cargo"=>dropping ? D("dropped"=>dropped["dropped"],"recovered"=>dropped["recovered"],"cross_actor"=>dropped["cross_actor"],"records"=>dropped["records"],"sites"=>[D("index"=>i,"x"=>food[i].x,"z"=>food[i].z,"stock"=>stock[i],"source"=>dropped["origins"][i]) for i in sort(collect(keys(dropped["origins"])))]) : nothing,"climbing"=>climbing ? climb_stats : nothing,"running"=>running ? run_stats : nothing,"ground_effects"=>ground_mode=="flat" ? nothing : ground_stats,"safety"=>hazard_mode ? deepcopy(safety) : nothing,"repetition_pressure"=>repetition_pressure ? repetitions : nothing,"parent_breadth"=>parent_breadth ? breadth_stats : nothing,"counts"=>counts,"events"=>events,"final_agents"=>terminal,"daily"=>daily,"day_starts"=>day_starts))
end
