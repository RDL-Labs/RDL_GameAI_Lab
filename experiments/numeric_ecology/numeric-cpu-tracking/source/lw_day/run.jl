# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
using Test
include(joinpath(#= none:2 =# @__DIR__(), "hazard.jl"))
include(joinpath(#= none:3 =# @__DIR__(), "orientation.jl"))
include(joinpath(#= none:4 =# @__DIR__(), "world_hazards.jl"))
include(joinpath(#= none:5 =# @__DIR__(), "ground.jl"))
include(joinpath(#= none:6 =# @__DIR__(), "reposition.jl"))
include(joinpath(#= none:7 =# @__DIR__(), "skyline.jl"))
include(joinpath(#= none:8 =# @__DIR__(), "landscape.jl"))
include(joinpath(#= none:9 =# @__DIR__(), "ground_wear.jl"))
include(joinpath(#= none:10 =# @__DIR__(), "ground_pattern.jl"))
include(joinpath(#= none:11 =# @__DIR__(), "ground_continuity.jl"))
include(joinpath(#= none:12 =# @__DIR__(), "climbing.jl"))
include(joinpath(#= none:13 =# @__DIR__(), "dropped_cargo.jl"))
include(joinpath(#= none:14 =# @__DIR__(), "return_purpose.jl"))
include(joinpath(#= none:15 =# @__DIR__(), "social_response.jl"))
include(joinpath(#= none:16 =# @__DIR__(), "food_body.jl"))
include(joinpath(#= none:17 =# @__DIR__(), "experience_bundles.jl"))
include(joinpath(#= none:18 =# @__DIR__(), "selection_trail.jl"))
include(joinpath(#= none:19 =# @__DIR__(), "general_sleep.jl"))
include(joinpath(#= none:20 =# @__DIR__(), "sleep_action_model.jl"))
include(joinpath(#= none:21 =# @__DIR__(), "sleep_maintenance.jl"))
include(joinpath(#= none:22 =# @__DIR__(), "../moving_social/run.jl"))
include(joinpath(#= none:23 =# @__DIR__(), "basic_loop.jl"))
include(joinpath(#= none:24 =# @__DIR__(), "approach.jl"))
include(joinpath(#= none:25 =# @__DIR__(), "local_descent.jl"))
include(joinpath(#= none:26 =# @__DIR__(), "repetition_pressure.jl"))
include(joinpath(#= none:27 =# @__DIR__(), "safety_methods.jl"))
include(joinpath(#= none:28 =# @__DIR__(), "movement_inertia.jl"))
include(joinpath(#= none:29 =# @__DIR__(), "exploration_horizon.jl"))
include(joinpath(#= none:30 =# @__DIR__(), "landmark_routes.jl"))
include(joinpath(#= none:31 =# @__DIR__(), "relation_field.jl"))
include(joinpath(#= none:32 =# @__DIR__(), "lateral_bias.jl"))
include(joinpath(#= none:33 =# @__DIR__(), "harvest_learning.jl"))
include(joinpath(#= none:34 =# @__DIR__(), "harvest_field.jl"))
include(joinpath(#= none:35 =# @__DIR__(), "harvest_review.jl"))
include(joinpath(#= none:36 =# @__DIR__(), "harvest_relearn.jl"))
function home_observation(w, a, yaw, home; visual_obstacles = w.obstacles, range = 60)
    #= none:39 =#
    #= none:40 =#
    p = w.positions[a]
    #= none:40 =#
    (dx, dz) = (home[1] - p[1], home[2] - p[2])
    #= none:41 =#
    (s, c) = sincos(deg2rad(yaw[a]))
    #= none:41 =#
    (f, r) = (dx * s + dz * c, dx * c - dz * s)
    #= none:42 =#
    d = hypot(dx, dz)
    #= none:43 =#
    if d <= range && ((f >= 0 || d <= 1.25) && !(any((o->begin
                                #= none:43 =#
                                segment_hit(p, (Float64(home[1]), Float64(home[2])), o, 0.0)
                            end), visual_obstacles)))
        #= none:44 =#
        return D(NID(0x000000000000027b) => f, NID(0x000000000000027c) => r, NID(0x0000000000000084) => d)
    end
    #= none:46 =#
    nothing
end
function replenish_food!(stock, food; capacity = 0)
    #= none:49 =#
    #= none:50 =#
    added = 0
    #= none:51 =#
    for (i, f) = enumerate(food)
        #= none:52 =#
        amount = max(0, if capacity > 0
                        capacity
                    else
                        Int(f.stock)
                    end - stock[i])
        #= none:52 =#
        stock[i] += amount
        #= none:52 =#
        added += amount
        #= none:53 =#
    end
    #= none:54 =#
    added
end
function lw_day(spec, clock; days = 1, basic_loop = false, landmark_routes = false, harvest_sleep = false, model_field = false, model_review = false, model_relearn = false, renewable_food = false, hazard_mode = false, ground_mode = NID(0x0000000000000067), running = false, climbing = false, low_obstacles = false, dropping = false, social_response = false, general_sleep = false, sleep_actions = false, sleep_retention = false, sleep_maintenance = false, ground_wear = false, ground_perception = false, ground_continuity = false, food_body = false, dynamic_hazard_mode = NID(0x000000000000005d), continuous_safety = false, orientation = false, relation_field = false, body_field = false, movement_inertia = false, exploration_horizon = false, experience_bundles = false, bundle_credit = false, selection_trails = false, reposition = false, skyline_mode = NID(0x000000000000005d), shared_stores = false, regrowth_days = 1, regrowth_capacity = 0, goal_switch_threshold = 2, lateral_side = NID(0x000000000000005d), parent_breadth = false, repetition_pressure = false, adaptive_approach = false, continuous_descent = false)
    #= none:57 =#
    #= none:58 =#
    check(goal_switch_threshold isa Integer && (!(goal_switch_threshold isa Bool) && 1 <= goal_switch_threshold <= 30), NID(0x0000000000000018))
    #= none:59 =#
    check(days isa Int && 1 <= days <= 30, NID(0x000000000000027d))
    #= none:60 =#
    check(!landmark_routes || basic_loop, NID(0x000000000000027e))
    #= none:61 =#
    check(!model_field || harvest_sleep && basic_loop, NID(0x000000000000027f))
    #= none:62 =#
    check(!model_review || harvest_sleep, NID(0x0000000000000280))
    #= none:63 =#
    check(!model_relearn || model_review, NID(0x0000000000000281))
    #= none:64 =#
    check(lateral_side in (NID(0x000000000000005d), NID(0x0000000000000282), NID(0x000000000000027c)), NID(0x0000000000000017))
    #= none:65 =#
    repetitions = Dict((a => repetition_state() for a = IDS))
    #= none:66 =#
    breadth_stats = Dict((a => D(NID(0x0000000000000283) => 0, NID(0x0000000000000284) => 0, NID(0x0000000000000285) => 0, NID(0x0000000000000286) => 0, NID(0x0000000000000287) => [0, 0, 0]) for a = IDS))
    #= none:67 =#
    lateral_stats = Dict((a => D(NID(0x0000000000000288) => 0, NID(0x0000000000000289) => 0, NID(0x000000000000028a) => Any[]) for a = IDS))
    #= none:68 =#
    landmark_objects = if landmark_routes
            prepare_landmark_objects(spec.obstacles)
        else
            nothing
        end
    #= none:69 =#
    skyline_objects = if skyline_mode == NID(0x000000000000005d)
            nothing
        else
            prepare_skyline_objects(spec.obstacles)
        end
    #= none:70 =#
    history = get(spec, :world_history, nothing)
    #= none:71 =#
    world_offset = if history === nothing
            0
        else
            Int(history.next_us)
        end
    #= none:72 =#
    if history !== nothing
        #= none:73 =#
        check(history.rule == NID(0x000000000000028b) && history.day_us == clock.day_us, NID(0x000000000000028c))
        #= none:74 =#
        check(history.renewable == renewable_food && (history.hazard_mode == dynamic_hazard_mode && (history.dropping == dropping && history.wear_enabled == ground_wear)), NID(0x000000000000028d))
        #= none:75 =#
        check(get(spec, :landscape, nothing) == get(history, :landscape, nothing), NID(0x000000000000028e))
        #= none:76 =#
        check(spec.obstacles == history.obstacles && (spec.food == history.renewal_targets && spec.ground_patches == history.ground_patches), NID(0x000000000000028f))
        #= none:77 =#
        check(world_offset >= 0 && mod(world_offset, clock.day_us) == 0, NID(0x0000000000000290))
        #= none:78 =#
        check((history.ground !== nothing) == ground_wear, NID(0x0000000000000291))
        #= none:79 =#
        ground_wear && check(history.ground.now_us == world_offset, NID(0x0000000000000292))
        #= none:80 =#
        check((history.hazards !== nothing) == (dynamic_hazard_mode != NID(0x000000000000005d)), NID(0x0000000000000293))
        #= none:81 =#
        dynamic_hazard_mode != NID(0x000000000000005d) && check(world_offset - 1000000 <= history.hazards.last_us <= world_offset, NID(0x0000000000000294))
        #= none:82 =#
        check(length(history.food) >= length(spec.food) && length(history.food) == length(history.stock), NID(0x0000000000000295))
        #= none:83 =#
        check(all((x->begin
                        #= none:83 =#
                        x isa Integer && (!(x isa Bool) && x >= 0)
                    end), history.stock), NID(0x0000000000000296))
        #= none:84 =#
        check(all((history.food[i] == spec.food[i] for i = eachindex(spec.food))), NID(0x0000000000000297))
        #= none:85 =#
        cargo_ids = [Int(item.index) for item = history.cargo]
        #= none:86 =#
        check(length(cargo_ids) <= 256 && (length(unique(cargo_ids)) == length(cargo_ids) && sort(cargo_ids) == collect(length(spec.food) + 1:length(history.food))), NID(0x0000000000000298))
        #= none:87 =#
        check(dropping || isempty(cargo_ids), NID(0x0000000000000299))
    end
    #= none:89 =#
    w = moving_world(spec)
    #= none:89 =#
    w.capacity = 100000
    #= none:90 =#
    high = copy(w.obstacles)
    #= none:90 =#
    low = if low_obstacles
            spec.low_obstacles
        else
            Any[]
        end
    #= none:91 =#
    append!(w.obstacles, [RDLMigrationProbe.Circle(o.x, o.z, o.radius) for o = low])
    #= none:92 =#
    climb_stats = Dict((a => D(NID(0x000000000000029a) => 0, NID(0x000000000000029b) => 0, NID(0x0000000000000084) => 0.0, NID(0x000000000000029c) => 0, NID(0x000000000000028a) => Any[]) for a = IDS))
    #= none:93 =#
    hazard_world = dynamic_hazards()
    #= none:94 =#
    if history !== nothing && dynamic_hazard_mode != NID(0x000000000000005d)
        #= none:95 =#
        old = history.hazards
        #= none:96 =#
        for key = (NID(0x000000000000029d), NID(0x000000000000017b))
            #= none:97 =#
            for (k, v) = pairs(getproperty(old, Symbol(key)))
                #= none:98 =#
                (hazard_world[key])[NID(k)] = if k in (:position, :home, :center)
                        Tuple(Float64.(v))
                    else
                        v
                    end
                #= none:99 =#
            end
            #= none:100 =#
        end
        #= none:101 =#
        hazard_world[NID(0x00000000000000ce)] = Int(old.last_us)
        #= none:102 =#
        if (hazard_world[NID(0x000000000000029d)])[NID(0x00000000000001b0)] !== nothing
            #= none:103 =#
            (hazard_world[NID(0x000000000000029d)])[NID(0x00000000000001b0)] = nothing
            #= none:103 =#
            (hazard_world[NID(0x000000000000029d)])[NID(0x000000000000029e)] = NID(0x00000000000001da)
        end
    end
    #= none:106 =#
    sky = Dict((a => orientation_state(a) for a = IDS))
    #= none:107 =#
    safety_loops = Dict((a => BasicLoop(a * NID(0x00000000000002a0); parent = a * NID(0x000000000000029f)) for a = IDS))
    #= none:108 =#
    safety = Dict((a => safety_state() for a = IDS))
    #= none:109 =#
    horizons = Dict((a => horizon_state(a) for a = IDS))
    #= none:110 =#
    check(!exploration_horizon || landmark_routes, NID(0x00000000000002a1))
    #= none:111 =#
    inertia = Dict((a => inertia_state(a) for a = IDS))
    #= none:112 =#
    check(!movement_inertia || landmark_routes, NID(0x00000000000002a2))
    #= none:113 =#
    check(!experience_bundles || food_body && general_sleep, NID(0x00000000000002a3))
    #= none:114 =#
    check(!bundle_credit || experience_bundles, NID(0x00000000000002a4))
    #= none:115 =#
    check(!selection_trails || food_body, NID(0x00000000000002a5))
    #= none:116 =#
    check(!(selection_trails && bundle_credit), NID(0x00000000000002a6))
    #= none:117 =#
    trails = Dict((a => selection_trail_state(a) for a = IDS))
    #= none:118 =#
    bundles = Dict((a => bundle_state(a) for a = IDS))
    #= none:119 =#
    hunger = Dict((a => hunger_state(a) for a = IDS))
    #= none:120 =#
    metabolism = Dict((a => 0.0 for a = IDS))
    #= none:121 =#
    check(!body_field || food_body, NID(0x00000000000002a7))
    #= none:122 =#
    body_fields = Dict((a => D(NID(0x0000000000000289) => 0, NID(0x0000000000000256) => 0) for a = IDS))
    #= none:123 =#
    response_stats = Dict((a => D(NID(0x0000000000000283) => 0, NID(0x00000000000002a8) => 0, NID(0x00000000000002a9) => 0, NID(0x00000000000002aa) => 0, NID(0x00000000000002ab) => 0, NID(0x00000000000002ac) => 0, NID(0x00000000000002ad) => 0, NID(0x000000000000028a) => Any[]) for a = IDS))
    #= none:124 =#
    check(ground_mode in (NID(0x0000000000000067), NID(0x0000000000000104), NID(0x00000000000002ae)), NID(0x0000000000000035))
    #= none:125 =#
    patches = if ground_mode == NID(0x0000000000000067)
            Any[]
        else
            spec.ground_patches
        end
    #= none:126 =#
    check(!ground_continuity || ground_perception, NID(0x00000000000002af))
    #= none:127 =#
    check(skyline_mode in (NID(0x000000000000005d), NID(0x00000000000002b0), NID(0x000000000000019d)), NID(0x000000000000001d))
    #= none:128 =#
    skyline_states = Dict((a => skyline_state() for a = IDS))
    #= none:129 =#
    reposition_states = Dict((a => reposition_state(a) for a = IDS))
    #= none:130 =#
    ground_models = Dict((a => ground_memory(a) for a = IDS))
    #= none:130 =#
    ground_receipts = Dict{NID, Any}()
    #= none:131 =#
    inherited_ground = if history === nothing
            get(spec, :ground_history, nothing)
        else
            history.ground
        end
    #= none:132 =#
    check(inherited_ground === nothing || ground_wear, NID(0x00000000000002b1))
    #= none:133 =#
    wear = if inherited_ground === nothing
            GroundWear(Int(clock.day_us))
        else
            restore_wear(inherited_ground, Int(clock.day_us))
        end
    #= none:134 =#
    wear_offset = wear.now
    #= none:135 =#
    ground_views = Dict((a => D(NID(0x00000000000002b2) => 0, NID(0x0000000000000086) => D(), NID(0x000000000000028a) => Any[]) for a = IDS))
    #= none:136 =#
    land = get(spec, :landscape, nothing)
    #= none:137 =#
    if land !== nothing
        #= none:138 =#
        check(land.rule == NID(0x00000000000002b3) && (isfinite(land.phase) && -0.4 <= land.phase <= 0.4), NID(0x00000000000002b4))
    end
    #= none:140 =#
    dry = (p->begin
                #= none:140 =#
                land === nothing || landscape_material(land, p) != NID(0x00000000000002b5)
            end)
    #= none:141 =#
    base_resistance_at = (p->begin
                #= none:141 =#
                if land === nothing
                    ground_resistance(p, patches)
                else
                    landscape_resistance(land, p)
                end
            end)
    #= none:142 =#
    resistance_at = (p->begin
                #= none:142 =#
                1 + (base_resistance_at(p) - 1) * if ground_wear && dry(p)
                            wear_factor(wear, p)
                        else
                            1.0
                        end
            end)
    #= none:143 =#
    ground_stats = Dict((a => D(NID(0x00000000000002b6) => 0, NID(0x00000000000002b7) => 0, NID(0x00000000000002b8) => 0, NID(0x000000000000029c) => 0, NID(0x000000000000028a) => Any[]) for a = IDS))
    #= none:144 =#
    food = Any[f for f = spec.food]
    #= none:144 =#
    dropped = cargo_ground()
    #= none:145 =#
    yaw = Dict((a => 0.0 for a = IDS))
    #= none:145 =#
    stock = Int[f.stock for f = food]
    #= none:146 =#
    if history !== nothing
        #= none:147 =#
        food = Any[f for f = history.food]
        #= none:147 =#
        stock = Int[v for v = history.stock]
        #= none:148 =#
        check(length(food) == length(stock) && all((>=)(0), stock), NID(0x0000000000000295))
        #= none:149 =#
        for item = history.cargo
            #= none:150 =#
            index = Int(item.index)
            #= none:150 =#
            check(1 <= index <= length(stock), NID(0x00000000000002b9))
            #= none:151 =#
            (dropped[NID(0x00000000000002ba)])[index] = (source = item.source.source, dropper = if occursin('/', NID(item.source.dropper))
                            NID(item.source.dropper)
                        else
                            NID(0x00000000000002bb) * NID(item.source.dropper)
                        end, drop_operation = item.source.drop_operation)
            #= none:152 =#
            stock[index] == 0 && ((dropped[NID(0x00000000000002bc)])[index] = 0)
            #= none:153 =#
        end
    end
    #= none:155 =#
    check(regrowth_days isa Integer && (regrowth_days >= 1 && (regrowth_capacity isa Integer && regrowth_capacity >= 0)), NID(0x00000000000002bd))
    #= none:156 =#
    shared = if history === nothing
            get(spec, :initial_shared_stock, 0)
        else
            get(history, :shared_stock, 0)
        end
    #= none:157 =#
    check(shared isa Integer && (!(shared isa Bool) && (shared >= 0 && (shared_stores || shared == 0))), NID(0x0000000000000071))
    #= none:158 =#
    history !== nothing && check(get(history, :shared_stores, false) == shared_stores && (get(history, :regrowth_days, 1) == regrowth_days && get(history, :regrowth_capacity, 0) == regrowth_capacity), NID(0x00000000000002be))
    #= none:159 =#
    storage_stats = D(NID(0x00000000000002bf) => 0, NID(0x00000000000002c0) => 0, NID(0x000000000000028a) => Any[])
    #= none:160 =#
    stores = Dict((a => 0 for a = IDS))
    #= none:160 =#
    states = Dict((a => social_initial() for a = IDS))
    #= none:161 =#
    live = Dict((a => live_aid(a) for a = IDS))
    #= none:161 =#
    results = Dict((a => D() for a = IDS))
    #= none:162 =#
    answered = Dict((a => Set{NID}() for a = IDS))
    #= none:162 =#
    learning = Dict((a => sleeper(0) for a = IDS))
    #= none:163 =#
    counts = Dict((a => Dict{NID, Int}() for a = IDS))
    #= none:163 =#
    events = Any[]
    #= none:163 =#
    previous = Dict{NID, Any}()
    #= none:164 =#
    distance = Dict((a => 0.0 for a = IDS))
    #= none:165 =#
    run_stats = Dict((a => D(NID(0x000000000000029a) => 0, NID(0x000000000000029b) => 0, NID(0x0000000000000084) => 0.0, NID(0x000000000000029c) => 0, NID(0x000000000000028a) => Any[]) for a = IDS))
    #= none:166 =#
    routes = Dict((a => route_memory() for a = IDS))
    #= none:167 =#
    relation_fields = Dict((a => relation_field_state() for a = IDS))
    #= none:168 =#
    check(!relation_field || landmark_routes, NID(0x00000000000002c1))
    #= none:169 =#
    harvest = Dict((a => harvest_state(a) for a = IDS))
    #= none:169 =#
    harvest_pending = Dict{NID, Any}()
    #= none:170 =#
    model_relearn && foreach((a->begin
                    #= none:170 =#
                    (harvest[a])[NID(0x00000000000002c2)] = true
                end), IDS)
    #= none:171 =#
    field_stats = Dict((a => D(NID(0x0000000000000289) => 0, NID(0x00000000000002c3) => 0, NID(0x00000000000002c4) => Any[], NID(0x00000000000002c5) => D()) for a = IDS))
    #= none:172 =#
    cargo = Dict((a => Union{Nothing, NID}[] for a = IDS))
    #= none:173 =#
    max_radius = Dict((a => 0.0 for a = IDS))
    #= none:174 =#
    loops = Dict((a => Dict((f => BasicLoop(a * NID(0x00000000000000da) * f; parent = a * NID(0x00000000000002c6), threshold = Int(goal_switch_threshold)) for f = (NID(0x000000000000000d), NID(0x0000000000000096)))) for a = IDS))
    #= none:175 =#
    check(!sleep_maintenance || sleep_actions, NID(0x00000000000002c7))
    #= none:176 =#
    check(!sleep_actions || general_sleep, NID(0x00000000000002c8))
    #= none:177 =#
    action_models = Dict((a => sleep_action_state(a) for a = IDS))
    #= none:178 =#
    general = Dict((a => general_sleep_state() for a = IDS))
    #= none:179 =#
    purposes = Dict((a => return_purpose() for a = IDS))
    #= none:180 =#
    pending = Dict{NID, Any}()
    #= none:180 =#
    daily = Any[]
    #= none:180 =#
    day_starts = Any[]
    #= none:181 =#
    physical() = begin
            #= none:181 =#
            D((a => D(NID(0x000000000000007f) => collect(w.positions[a]), NID(0x0000000000000095) => yaw[a], NID(0x0000000000000080) => bodydict(w.bodies[a]), NID(0x0000000000000144) => deepcopy(purposes[a]), NID(0x0000000000000081) => w.inventory[a], NID(0x0000000000000083) => stores[a], NID(0x00000000000002c9) => length((states[a])[NID(0x000000000000028a)]), NID(0x00000000000002ca) => deepcopy((states[a])[NID(0x000000000000008d)]), NID(0x000000000000013d) => D((f => loop_snapshot(s) for (f, s) = loops[a])), NID(0x0000000000000132) => if landmark_routes
                                deepcopy(routes[a])
                            else
                                nothing
                            end, NID(0x00000000000002cb) => max_radius[a], NID(0x000000000000007e) => if harvest_sleep
                                deepcopy(harvest[a])
                            else
                                nothing
                            end) for a = IDS))
        end
    #= none:186 =#
    for (i, a) = enumerate(IDS)
        #= none:187 =#
        w.inventory[a] = spec.initial_inventory[i]
        #= none:187 =#
        w.bodies[a] = Body(10.0, 0.0, spec.reserve[i], 0.0)
        #= none:188 =#
        append!(cargo[a], fill(nothing, w.inventory[a]))
        #= none:189 =#
        hasproperty(spec, :initial_personal_stock) && (stores[a] = spec.initial_personal_stock[i])
        #= none:190 =#
    end
    #= none:191 =#
    check(!shared_stores || all((v == 0 for v = values(stores))), NID(0x00000000000002cc))
    #= none:192 =#
    initial = shared + sum(stock) + sum(values(w.inventory)) + sum(values(stores))
    #= none:192 =#
    bounds = Int.(clock.phase_boundaries_us)
    #= none:193 =#
    replenished = 0
    #= none:193 =#
    replenishments = Any[]
    #= none:194 =#
    integrate(a, now, obs) = begin
            #= none:194 =#
            #= none:195 =#
            before = length((states[a])[NID(0x000000000000028a)])
            #= none:196 =#
            if (states[a])[NID(0x0000000000000145)] !== nothing
                #= none:197 =#
                states[a] = ingest(states[a], D(NID(0x00000000000002cd) => a, NID(0x00000000000002ce) => now, NID(0x00000000000002cf) => ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a), NID(0x00000000000002d1) => obs), results[a])
            end
            #= none:200 =#
            pressure_poll!(live[a], (states[a])[NID(0x000000000000028a)], before)
        end
    #= none:202 =#
    progress_path = nothing
    #= none:203 =#
    progress_io = nothing
    #= none:204 =#
    progress_started = time_ns()
    #= none:205 =#
    function emit_progress(sec, stage)
        #= none:205 =#
        #= none:206 =#
        progress_io === nothing && return
        #= none:207 =#
        completed = sum((sum(values(counts[a])) for a = IDS))
        #= none:208 =#
        println(progress_io, time(), '\t', (time_ns() - progress_started) / 1.0e9, '\t', sec, '\t', div(sec, div(clock.day_us, 1000000)) + 1, '\t', completed, '\t', stage, '\t', Sys.maxrss())
        #= none:209 =#
        flush(progress_io)
    end
    #= none:211 =#
    for sec = 0:days * div(clock.day_us, 1000000) - 1
        #= none:212 =#
        sec % 60 == 0 && emit_progress(sec, NID(0x00000000000002d2))
        #= none:213 =#
        now = sec * 1000000
        #= none:213 =#
        w.seconds = sec
        #= none:214 =#
        (ground_wear || ground_perception) && advance_wear!(wear, wear_offset + now)
        #= none:215 =#
        if ground_perception
            #= none:216 =#
            for a = IDS
                #= none:217 =#
                view = ground_appearance(w, a, yaw, wear, now; dry = dry)
                #= none:218 =#
                patterns = ground_patterns(view)
                #= none:219 =#
                record_ground_patterns!(ground_views[a], view, patterns)
                #= none:220 =#
                ground_continuity && update_ground!(ground_models[a], view, get(ground_receipts, a, nothing), patterns)
                #= none:221 =#
            end
        end
        #= none:223 =#
        day = div(now, clock.day_us)
        #= none:223 =#
        local_us = mod(now, clock.day_us)
        #= none:224 =#
        if local_us == 0
            #= none:225 =#
            push!(day_starts, physical())
            #= none:226 =#
            if day > 0 || world_offset > 0
                #= none:227 =#
                day > 0 && (learning = Dict((a => sleeper(day) for a = IDS)))
                #= none:228 =#
                if renewable_food && mod(div(world_offset, clock.day_us) + day, regrowth_days) == 0
                    #= none:229 =#
                    added = replenish_food!(stock, spec.food; capacity = regrowth_capacity)
                    #= none:229 =#
                    replenished += added
                    #= none:230 =#
                    push!(replenishments, D(NID(0x0000000000000173) => day, NID(0x00000000000002d3) => now, NID(0x0000000000000074) => added))
                end
            end
        end
        #= none:234 =#
        phase = if local_us < bounds[1]
                NID(0x0000000000000027)
            else
                if local_us < bounds[2]
                    NID(0x00000000000002d4)
                else
                    if local_us < bounds[3]
                        NID(0x00000000000002d5)
                    else
                        NID(0x00000000000002d6)
                    end
                end
            end
        #= none:235 =#
        if food_body
            #= none:236 =#
            for a = IDS
                #= none:237 =#
                hunger_update!(hunger[a], a, now, (w.bodies[a]).reserve)
                #= none:238 =#
                selection_trails && resolve_trail!(trails[a], a, (w.bodies[a]).reserve, ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a), now)
                #= none:239 =#
                bundle_credit && resolve_bundle_credit!(bundles[a], hunger[a])
                #= none:240 =#
            end
        end
        #= none:242 =#
        if dynamic_hazard_mode != NID(0x000000000000005d)
            #= none:243 =#
            advance_hazards!(hazard_world, world_offset + now, w.positions, w.obstacles; patrol = dynamic_hazard_mode == NID(0x0000000000000066))
        end
        #= none:245 =#
        hazard_sources = if dynamic_hazard_mode == NID(0x000000000000005d)
                spec.hazards
            else
                dynamic_hazard_sources(hazard_world, sec + div(world_offset, 1000000); patrol = dynamic_hazard_mode == NID(0x0000000000000066))
            end
        #= none:246 =#
        if orientation
            #= none:247 =#
            for a = IDS
                #= none:247 =#
                observe_sky!(sky[a], sky_sample(a, ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a), now, yaw[a], clock))
                #= none:247 =#
            end
        end
        #= none:249 =#
        sec % 60 == 0 && emit_progress(sec, NID(0x00000000000002d7))
        #= none:250 =#
        obs = Dict((a => observe(w, a) for a = IDS))
        #= none:251 =#
        moves = Dict((a => movement_observation(w, a, yaw, food, stock; resistance_at = resistance_at, run_resistance_at = base_resistance_at, running = running, visual_obstacles = high) for a = IDS))
        #= none:252 =#
        homes = Dict((a => home_observation(w, a, yaw, spec.home; visual_obstacles = high, range = if skyline_mode == NID(0x000000000000005d)
                                60
                            else
                                6
                            end) for a = IDS))
        #= none:253 =#
        sections = if harvest_sleep
                Dict((a => harvest_section(moves[a], ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a), now) for a = IDS))
            else
                nothing
            end
        #= none:254 =#
        if harvest_sleep
            #= none:255 =#
            for a = IDS
                #= none:256 =#
                harvest_observe!(harvest[a], sections[a])
                #= none:257 =#
                if haskey(harvest_pending, a)
                    #= none:258 =#
                    t = pop!(harvest_pending, a)
                    #= none:259 =#
                    model_relearn && replacement_result!(harvest[a], a, t.op, t.before, t.status, t.executed, sections[a]; pose = t.position == w.positions[a] && t.yaw == yaw[a])
                    #= none:261 =#
                    harvest_result!(harvest[a], a, t.op, t.before, t.status, t.executed, sections[a])
                    #= none:262 =#
                    if model_review
                        #= none:263 =#
                        review_harvest!(harvest[a], a, t.op, t.prediction, t.before, t.status, t.executed, sections[a]; pose = t.position == w.positions[a] && t.yaw == yaw[a])
                    end
                end
                #= none:267 =#
                prediction = harvest_predict(harvest[a], sections[a])
                #= none:268 =#
                ((harvest[a])[NID(0x00000000000002d8)])[prediction[NID(0x000000000000008a)]] += 1
                #= none:269 =#
                if prediction[NID(0x000000000000008a)] == NID(0x00000000000002d9)
                    #= none:270 =#
                    bymodel = get!(harvest[a], NID(0x00000000000002da), D())
                    #= none:270 =#
                    ref = prediction[NID(0x000000000000008c)]
                    #= none:271 =#
                    bymodel[ref] = get(bymodel, ref, 0) + 1
                end
                #= none:273 =#
                if prediction[NID(0x000000000000008a)] == NID(0x00000000000002d9) && (harvest[a])[NID(0x00000000000002db)] === nothing
                    #= none:274 =#
                    (harvest[a])[NID(0x00000000000002db)] = merge(prediction, D(NID(0x00000000000002ce) => now))
                end
                #= none:276 =#
            end
        end
        #= none:278 =#
        lateral_views = if lateral_side == NID(0x000000000000005d) && !continuous_descent
                nothing
            else
                Dict((a => lateral_obstacles(spec.obstacles, w.positions[a], yaw[a], ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a)) for a = IDS))
            end
        #= none:279 =#
        landmarks = if landmark_routes
                Dict((a => landmark_fan(landmark_objects, w.positions[a], yaw[a], ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a)) for a = IDS))
            else
                nothing
            end
        #= none:280 =#
        skyline_views = if skyline_mode == NID(0x000000000000005d)
                nothing
            else
                Dict((a => skyline_fan(skyline_objects, w.positions[a], yaw[a], ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a); subrays = skyline_mode == NID(0x000000000000019d)) for a = IDS))
            end
        #= none:281 =#
        if skyline_views !== nothing
            #= none:282 =#
            for a = IDS
                #= none:282 =#
                record_skyline!(skyline_states[a], skyline_views[a])
                #= none:282 =#
            end
        end
        #= none:284 =#
        climbs = if climbing
                Dict((a => [climb_sample(w, a, yaw[a], i, low, high, base_resistance_at) for i = 0:4] for a = IDS))
            else
                nothing
            end
        #= none:286 =#
        hazard_views = if hazard_mode || (general_sleep || (movement_inertia || selection_trails))
                Dict((a => hazard_observation(w, a, yaw, if hazard_mode
                                hazard_sources
                            else
                                Any[]
                            end, sec + div(world_offset, 1000000); visual_obstacles = high) for a = IDS))
            else
                nothing
            end
        #= none:287 =#
        contexts = if general_sleep
                Dict((a => sleep_context(moves[a], hazard_views[a]; climbs = if climbs === nothing
                                    nothing
                                else
                                    climbs[a]
                                end) for a = IDS))
            else
                nothing
            end
        #= none:288 =#
        bundle_contexts = if experience_bundles || selection_trails
                Dict((a => bundle_context(w.inventory[a], w.bodies[a], moves[a], hazard_views[a]) for a = IDS))
            else
                nothing
            end
        #= none:289 =#
        plans = NumericPlans()
        #= none:290 =#
        for a = IDS
            #= none:291 =#
            integrate(a, now, obs[a])
            #= none:291 =#
            o = obs[a]
            #= none:291 =#
            plan = nothing
            #= none:291 =#
            home = homes[a]
            #= none:292 =#
            at_home = home !== nothing && home[NID(0x0000000000000084)] <= 1.25
            #= none:293 =#
            if experience_bundles
                #= none:294 =#
                form_bundle!(bundles[a], hunger[a], now)
                #= none:295 =#
                wake_bundles!(bundles[a], bundle_contexts[a], phase)
            end
            #= none:297 =#
            movement_inertia && observe_inertia!(inertia[a], a, now, inertia_view(moves[a], landmarks[a], hazard_views[a]))
            #= none:298 =#
            if basic_loop && haskey(pending, a)
                #= none:299 =#
                t = pop!(pending, a)
                #= none:299 =#
                s = (loops[a])[t.family]
                #= none:300 =#
                target = if t.family == NID(0x0000000000000096)
                        home
                    else
                        if isempty((moves[a])[NID(0x00000000000001dd)])
                            nothing
                        else
                            first((moves[a])[NID(0x00000000000001dd)])
                        end
                    end
                #= none:301 =#
                same = target !== nothing && (t.family == NID(0x0000000000000096) || (t.ref === nothing || target[NID(0x0000000000000195)] == t.ref))
                #= none:302 =#
                value = if t.question == NID(0x00000000000002dc)
                        ground_extension_result(ground_models[a], s.trial.method, t.status, t.moved)
                    else
                        if t.question == NID(0x00000000000002dd)
                            t.status == NID(0x000000000000029b) && t.moved
                        else
                            if t.question == NID(0x00000000000002de)
                                t.status == NID(0x000000000000029b)
                            else
                                if t.question == NID(0x00000000000002df)
                                    t.status == NID(0x000000000000011f)
                                else
                                    if t.question == NID(0x00000000000002e0)
                                        t.status == NID(0x00000000000002e0)
                                    else
                                        if t.question == NID(0x00000000000002e1)
                                            t.status == NID(0x000000000000029b)
                                        else
                                            if t.question == NID(0x00000000000002e2)
                                                t.status == NID(0x00000000000002e3)
                                            else
                                                if t.question == NID(0x00000000000002e4)
                                                    at_home && t.status == NID(0x000000000000029b)
                                                else
                                                    if t.question == NID(0x00000000000002e5)
                                                        target !== nothing
                                                    else
                                                        if same
                                                            target[NID(0x0000000000000084)] < t.distance
                                                        else
                                                            nothing
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                #= none:305 =#
                goal = if t.family == NID(0x0000000000000096)
                        at_home
                    else
                        t.status in (NID(0x00000000000002e3), NID(0x00000000000002e0))
                    end
                #= none:306 =#
                if reposition && t.phase == phase
                    #= none:307 =#
                    search_review_result!(reposition_states[a], t.family, s.trial.method, target !== nothing, t.status == NID(0x000000000000029b))
                end
                #= none:309 =#
                resolve_method!(s, t.source, if t.phase == phase || value === true
                        value
                    else
                        nothing
                    end, if t.phase == phase || goal
                        goal
                    else
                        nothing
                    end)
            end
            #= none:311 =#
            if ground_continuity
                #= none:312 =#
                active = Set((m[NID(0x000000000000008c)] for m = (ground_models[a])[NID(0x00000000000002e6)]))
                #= none:313 =#
                for loop = values(loops[a])
                    #= none:314 =#
                    filter!((kv->begin
                                #= none:314 =#
                                !(startswith(first(kv), NID(0x00000000000002e7))) || first(kv) in active
                            end), loop.methods)
                    #= none:315 =#
                end
            end
            #= none:317 =#
            messages = [m for m = reverse(o[NID(0x00000000000001c3)]) if !(m[NID(0x0000000000000237)] in answered[a]) && m[NID(0x000000000000024d)] in (NID(0x00000000000002e8), NID(0x00000000000002e9), NID(0x00000000000002ea))]
            #= none:318 =#
            if hazard_mode
                #= none:319 =#
                hazard_view = hazard_views[a]
                #= none:320 =#
                plan = if continuous_safety
                        safety_methods!(safety[a], safety_loops[a], hazard_view, moves[a], ncat(NID(0x00000000000002eb), now, NID(0x00000000000000da), a); running = running)
                    else
                        safety_plan!(safety[a], hazard_view, moves[a]; running = running)
                    end
            end
            #= none:322 =#
            if plan !== nothing
                #= none:322 =#
            elseif #= none:324 =# !(isempty(messages))
                #= none:325 =#
                m = first(messages)
                #= none:325 =#
                current = merge(copy(o), D(NID(0x00000000000001c3) => [m]))
                #= none:326 =#
                if social_response || food_body
                    #= none:327 =#
                    (decision, trace) = experienced_response(current, (states[a])[NID(0x000000000000028a)], (live[a]).state, a, ncat(NID(0x00000000000002ec), now, NID(0x00000000000000da), a, NID(0x00000000000000da), m[NID(0x0000000000000237)]); retention = if food_body
                                    retention_cost(current, hunger[a])
                                else
                                    0.0
                                end)
                    #= none:328 =#
                    (act, t, r) = decision
                    #= none:329 =#
                    if trace !== nothing
                        #= none:330 =#
                        rs = response_stats[a]
                        #= none:330 =#
                        rs[NID(0x0000000000000283)] += 1
                        #= none:330 =#
                        rs[act] += 1
                        #= none:331 =#
                        trace[NID(0x00000000000002ed)] > 0 && (rs[NID(0x00000000000002ad)] += 1)
                        #= none:332 =#
                        push!(rs[NID(0x000000000000028a)], trace)
                        #= none:332 =#
                        length(rs[NID(0x000000000000028a)]) > 32 && popfirst!(rs[NID(0x000000000000028a)])
                    end
                else
                    #= none:335 =#
                    (act, t, r) = response(current, a != NID(0x00000000000002ee))
                end
                #= none:337 =#
                plan = D(NID(0x000000000000021f) => act, NID(0x00000000000001b0) => t, NID(0x00000000000002ef) => r)
                #= none:337 =#
                push!(answered[a], m[NID(0x0000000000000237)])
            elseif #= none:338 =# if food_body
                        hunger_select(hunger[a])
                    else
                        (w.bodies[a]).reserve < 80
                    end && w.inventory[a] > 0
                #= none:339 =#
                plan = D(NID(0x000000000000021f) => NID(0x00000000000002f0))
            elseif #= none:340 =# at_home && (if food_body
                            hunger_select(hunger[a])
                        else
                            (w.bodies[a]).reserve < 80
                        end && if shared_stores
                                shared
                            else
                                stores[a]
                            end > 0)
                #= none:341 =#
                plan = D(NID(0x000000000000021f) => NID(0x00000000000002f1))
            elseif #= none:342 =# phase == NID(0x00000000000002d6) && local_us >= clock.quiet_night_us
                #= none:343 =#
                plan = D(NID(0x000000000000021f) => NID(0x00000000000002f2))
            elseif #= none:344 =# (states[a])[NID(0x0000000000000145)] !== nothing
                #= none:345 =#
                plan = D(NID(0x000000000000021f) => NID(0x00000000000002f2))
            elseif #= none:346 =# if food_body
                    hunger_select(hunger[a])
                else
                    (w.bodies[a]).reserve < 80
                end
                #= none:347 =#
                targets = [x[NID(0x0000000000000195)] for x = o[NID(0x00000000000002f4)] if x[NID(0x00000000000002f3)]]
                #= none:348 =#
                (target, _) = select_target(targets, (states[a])[NID(0x000000000000008d)], (live[a]).state)
                #= none:349 =#
                request_allowed = target !== nothing
                #= none:350 =#
                if request_allowed && social_response
                    #= none:351 =#
                    (request_allowed, trace) = experienced_request(o, (states[a])[NID(0x000000000000028a)], (live[a]).state, a, target, ncat(NID(0x00000000000002f5), now, NID(0x00000000000000da), a, NID(0x00000000000000da), target))
                    #= none:352 =#
                    rs = response_stats[a]
                    #= none:352 =#
                    rs[NID(0x00000000000002a8)] += 1
                    #= none:352 =#
                    rs[if request_allowed
                                NID(0x00000000000002a9)
                            else
                                NID(0x00000000000002aa)
                            end] += 1
                    #= none:353 =#
                    push!(rs[NID(0x000000000000028a)], trace)
                    #= none:353 =#
                    length(rs[NID(0x000000000000028a)]) > 32 && popfirst!(rs[NID(0x000000000000028a)])
                end
                #= none:355 =#
                if request_allowed
                    #= none:356 =#
                    op = ncat(NID(0x00000000000002eb), now, NID(0x00000000000000da), a)
                    #= none:357 =#
                    (states[a])[NID(0x0000000000000145)] = D(NID(0x00000000000002f6) => a * NID(0x00000000000000da) * op, NID(0x00000000000001b0) => target, NID(0x00000000000002f7) => now + 5000000, NID(0x00000000000002f8) => ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a), NID(0x00000000000002f9) => op)
                    #= none:359 =#
                    plan = D(NID(0x000000000000021f) => NID(0x00000000000002e8), NID(0x00000000000001b0) => target)
                end
            end
            #= none:362 =#
            returning = returning!(purposes[a], phase, w.inventory[a], at_home, now)
            #= none:363 =#
            if plan === nothing
                #= none:364 =#
                if returning && at_home
                    #= none:365 =#
                    plan = D(NID(0x000000000000021f) => if w.inventory[a] > 0
                                    NID(0x00000000000002fa)
                                else
                                    NID(0x00000000000002f2)
                                end)
                elseif #= none:366 =# food_body && (phase == NID(0x00000000000002d4) && (!returning && ((w.bodies[a]).reserve >= 80 && w.inventory[a] >= 3)))
                    #= none:367 =#
                    plan = D(NID(0x000000000000021f) => NID(0x00000000000002f2))
                elseif #= none:368 =# phase == NID(0x0000000000000027)
                    #= none:369 =#
                    plan = D(NID(0x000000000000021f) => NID(0x00000000000002f2))
                elseif #= none:370 =# (w.bodies[a]).strain >= 0.8 || (w.bodies[a]).reserve <= 0
                    #= none:371 =#
                    plan = D(NID(0x000000000000021f) => NID(0x00000000000002f2))
                elseif #= none:372 =# basic_loop
                    #= none:373 =#
                    family = if returning
                            NID(0x0000000000000096)
                        else
                            NID(0x000000000000000d)
                        end
                    #= none:374 =#
                    visible = (moves[a])[NID(0x00000000000001dd)]
                    #= none:374 =#
                    target = if returning
                            home
                        else
                            if isempty(visible)
                                nothing
                            else
                                first(visible)
                            end
                        end
                    #= none:375 =#
                    if !returning && (target !== nothing && target[NID(0x0000000000000084)] <= 1.25)
                        #= none:376 =#
                        plan = D(NID(0x000000000000021f) => if haskey(dropped[NID(0x00000000000002ba)], target[NID(0x0000000000000195)] + 1)
                                        NID(0x00000000000002fb)
                                    else
                                        NID(0x00000000000002fc)
                                    end, NID(0x00000000000002fd) => target[NID(0x0000000000000195)])
                    else
                        #= none:378 =#
                        s = (loops[a])[family]
                        #= none:378 =#
                        source = ncat(NID(0x00000000000002eb), now, NID(0x00000000000000da), a)
                        #= none:379 =#
                        rolling = if movement_inertia && !(adaptive_approach && near_target(target) || continuous_descent && target !== nothing)
                                inertia_candidate!(inertia[a], moves[a], hazard_views[a], phase, family, s.methods, source)
                            else
                                nothing
                            end
                        #= none:380 =#
                        if rolling !== nothing
                            #= none:381 =#
                            plan = choose_method!(s, [rolling], source)
                        else
                            #= none:383 =#
                            candidates = search_candidates(moves[a], target, s)
                            #= none:384 =#
                            if skyline_views !== nothing && (returning && target === nothing)
                                #= none:385 =#
                                append!(candidates, skyline_home_candidates(skyline_states[a], skyline_views[a], moves[a]))
                            end
                            #= none:387 =#
                            reposition && append!(candidates, reposition_candidates!(reposition_states[a], a, moves[a], now; purpose = family, home_unresolved = returning && (target === nothing && s.H >= s.threshold), linked = s.receipt !== nothing && s.receipt.source == ncat(NID(0x00000000000002eb), now - 1000000, NID(0x00000000000000da), a)))
                            #= none:388 =#
                            body_field && push!(candidates, D(NID(0x00000000000001b7) => NID(0x00000000000002f2), NID(0x000000000000021f) => NID(0x00000000000002f2), NID(0x00000000000002fe) => 1.0, NID(0x00000000000001b4) => NID(0x00000000000002de)))
                            #= none:389 =#
                            climbing && append!(candidates, climb_candidates(climbs[a], moves[a], target, s))
                            #= none:390 =#
                            dropping && (climbing && append!(candidates, drop_candidates(climbs[a], w.bodies[a], w.inventory[a], target)))
                            #= none:391 =#
                            if landmark_routes
                                #= none:392 =#
                                if (routes[a])[NID(0x0000000000000173)] != day
                                    #= none:393 =#
                                    empty!((routes[a])[NID(0x00000000000002ff)])
                                    #= none:393 =#
                                    (routes[a])[NID(0x0000000000000173)] = day
                                end
                                #= none:396 =#
                                if target === nothing
                                    #= none:397 =#
                                    append!(candidates, landmark_candidates(moves[a], landmarks[a], routes[a], family, (landmarks[a])[NID(0x0000000000000121)]; include_routes = !relation_field))
                                    #= none:398 =#
                                    relation_field && append!(candidates, relation_candidates!(relation_fields[a], moves[a], landmarks[a], routes[a], family, (landmarks[a])[NID(0x0000000000000121)]))
                                end
                            end
                            #= none:401 =#
                            if ground_continuity && (phase == NID(0x00000000000002d4) && (!returning && target === nothing))
                                #= none:402 =#
                                append!(candidates, ground_proposals(ground_models[a], moves[a]))
                            end
                            #= none:404 =#
                            if exploration_horizon && (phase == NID(0x00000000000002d4) && (!returning && target === nothing))
                                #= none:405 =#
                                append!(candidates, horizon_candidates(horizons[a], landmarks[a], moves[a]))
                            end
                            #= none:407 =#
                            reposition && project_search_review!(reposition_states[a], candidates, s, target, family)
                            #= none:408 =#
                            if parent_breadth
                                #= none:409 =#
                                before = length(candidates)
                                #= none:410 =#
                                candidates = parent_candidates(s, candidates)
                                #= none:411 =#
                                bs = breadth_stats[a]
                                #= none:411 =#
                                bs[NID(0x0000000000000283)] += 1
                                #= none:411 =#
                                bs[NID(0x0000000000000284)] += before
                                #= none:412 =#
                                bs[NID(0x0000000000000285)] += length(candidates)
                                #= none:412 =#
                                bs[NID(0x0000000000000286)] += Int(length(candidates) < before)
                                #= none:413 =#
                                level = if s.H >= 32
                                        2
                                    else
                                        min(2, fld(s.H, s.threshold))
                                    end
                                #= none:414 =#
                                (bs[NID(0x0000000000000287)])[level + 1] += 1
                            end
                            #= none:416 =#
                            if ground_mode == NID(0x0000000000000104)
                                #= none:417 =#
                                candidates = ground_candidates(candidates, moves[a], w.inventory[a])
                                #= none:418 =#
                                (ground_stats[a])[NID(0x00000000000002b8)] += 1
                            end
                            #= none:420 =#
                            counterfactual = nothing
                            #= none:420 =#
                            field_trace = nothing
                            #= none:421 =#
                            if model_field && family == NID(0x000000000000000d)
                                #= none:422 =#
                                (projected, field_trace) = harvest_field(candidates, moves[a], harvest[a], a, now; enabled = true)
                                #= none:423 =#
                                if field_trace[NID(0x0000000000000289)]
                                    #= none:424 =#
                                    counterfactual = method_choice(s, candidates)
                                    #= none:425 =#
                                    candidates = projected
                                    #= none:425 =#
                                    (field_stats[a])[NID(0x0000000000000289)] += 1
                                    #= none:426 =#
                                    m = get!((field_stats[a])[NID(0x00000000000002c5)], field_trace[NID(0x000000000000008c)], D(NID(0x0000000000000289) => 0, NID(0x00000000000002c3) => 0))
                                    #= none:427 =#
                                    m[NID(0x0000000000000289)] += 1
                                end
                            end
                            #= none:430 =#
                            if lateral_side != NID(0x000000000000005d) && lateral_views !== nothing
                                #= none:431 =#
                                lateral_trace = project_lateral!(candidates, moves[a], lateral_views[a], lateral_side, field_trace)
                                #= none:432 =#
                                ls = lateral_stats[a]
                                #= none:432 =#
                                ls[NID(0x0000000000000288)] += 1
                                #= none:432 =#
                                ls[NID(0x0000000000000289)] += Int(lateral_trace[NID(0x0000000000000289)])
                                #= none:433 =#
                                push!(ls[NID(0x000000000000028a)], merge(lateral_trace, D(NID(0x0000000000000121) => source)))
                                #= none:433 =#
                                length(ls[NID(0x000000000000028a)]) > 32 && popfirst!(ls[NID(0x000000000000028a)])
                            end
                            #= none:435 =#
                            sleep_maintenance && wake_sleep_usage!(action_models[a], contexts[a], phase)
                            #= none:436 =#
                            sleep_without = if sleep_actions
                                    method_choice(s, candidates)
                                else
                                    nothing
                                end
                            #= none:437 =#
                            sleep_applied = sleep_actions && project_sleep_actions!(action_models[a], candidates, contexts[a], a, now)
                            #= none:438 =#
                            sleep_selected = if sleep_actions
                                    method_choice(s, candidates)
                                else
                                    nothing
                                end
                            #= none:439 =#
                            field_selected = if sleep_actions
                                    sleep_without
                                else
                                    method_choice(s, candidates)
                                end
                            #= none:440 =#
                            body_before = if body_field
                                    (method_choice(s, candidates))[NID(0x00000000000001b7)]
                                else
                                    nothing
                                end
                            #= none:441 =#
                            body_applied = body_field && project_body_methods!(candidates, hunger[a], w.bodies[a], phase)
                            #= none:442 =#
                            body_selected = if body_field
                                    (method_choice(s, candidates))[NID(0x00000000000001b7)]
                                else
                                    nothing
                                end
                            #= none:443 =#
                            bundle_trace = if experience_bundles
                                    project_bundles!(bundles[a], candidates, s, bundle_contexts[a], phase, now; credit = bundle_credit)
                                else
                                    nothing
                                end
                            #= none:444 =#
                            trail_trace = if selection_trails
                                    project_trails!(trails[a], candidates, s, bundle_contexts[a], phase)
                                else
                                    nothing
                                end
                            #= none:445 =#
                            if repetition_pressure
                                #= none:446 =#
                                prior_choice = method_choice(s, candidates)
                                #= none:447 =#
                                project_repetition!(repetitions[a], candidates)
                                #= none:448 =#
                                after_choice = method_choice(s, candidates)
                                #= none:449 =#
                                (repetitions[a])[NID(0x0000000000000300)] += Int(prior_choice !== nothing && (after_choice !== nothing && prior_choice[NID(0x00000000000001b7)] != after_choice[NID(0x00000000000001b7)]))
                            end
                            #= none:451 =#
                            plan = choose_method!(s, candidates, source)
                            #= none:452 =#
                            skyline_mode != NID(0x000000000000005d) && (plan[NID(0x00000000000001b7)] == NID(0x0000000000000301) && ((skyline_states[a])[NID(0x0000000000000302)] += 1))
                            #= none:453 =#
                            reposition && (startswith(plan[NID(0x00000000000001b7)], NID(0x0000000000000303)) && ((reposition_states[a])[NID(0x0000000000000304)] += 1))
                            #= none:454 =#
                            selection_trails && (plan[NID(0x000000000000020f)] = trail_trace)
                            #= none:455 =#
                            experience_bundles && (plan[NID(0x000000000000020c)] = bundle_trace)
                            #= none:456 =#
                            if body_applied
                                #= none:457 =#
                                (body_fields[a])[NID(0x0000000000000289)] += 1
                                #= none:457 =#
                                (body_fields[a])[NID(0x0000000000000256)] += Int(body_before != body_selected)
                            end
                            #= none:459 =#
                            relation_field && (startswith(plan[NID(0x00000000000001b7)], NID(0x0000000000000305)) && ((relation_fields[a])[NID(0x0000000000000302)] += 1))
                            #= none:460 =#
                            ground_continuity && (startswith(plan[NID(0x00000000000001b7)], NID(0x00000000000002e7)) && ((ground_models[a])[NID(0x0000000000000302)] += 1))
                            #= none:461 =#
                            sleep_maintenance && (plan[NID(0x0000000000000306)] = sleep_applied && (sleep_without[NID(0x00000000000001b7)] != sleep_selected[NID(0x00000000000001b7)] && plan[NID(0x00000000000001b7)] == sleep_selected[NID(0x00000000000001b7)]))
                            #= none:462 =#
                            sleep_applied && (sleep_without[NID(0x00000000000001b7)] != sleep_selected[NID(0x00000000000001b7)] && ((action_models[a])[NID(0x00000000000002c3)] += 1))
                            #= none:463 =#
                            if counterfactual !== nothing && counterfactual[NID(0x00000000000001b7)] != field_selected[NID(0x00000000000001b7)]
                                #= none:464 =#
                                (field_stats[a])[NID(0x00000000000002c3)] += 1
                                #= none:465 =#
                                (((field_stats[a])[NID(0x00000000000002c5)])[field_trace[NID(0x000000000000008c)]])[NID(0x00000000000002c3)] += 1
                                #= none:466 =#
                                if length((field_stats[a])[NID(0x00000000000002c4)]) < 8
                                    #= none:467 =#
                                    push!((field_stats[a])[NID(0x00000000000002c4)], D(NID(0x0000000000000121) => ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a), NID(0x0000000000000307) => counterfactual[NID(0x00000000000001b7)], NID(0x0000000000000308) => field_selected[NID(0x00000000000001b7)], NID(0x0000000000000309) => field_trace))
                                end
                            end
                        end
                        #= none:472 =#
                        landmark_routes && (get(plan, NID(0x000000000000025b), nothing) !== nothing && ((routes[a])[NID(0x0000000000000302)] += 1))
                        #= none:473 =#
                        if continuous_descent
                            #= none:474 =#
                            steer_local_descent!(plan, target, lateral_views[a], w, a, yaw, resistance_at)
                        elseif #= none:475 =# adaptive_approach
                            #= none:476 =#
                            refine_approach!(plan, target, w, a, yaw, resistance_at)
                        end
                        #= none:478 =#
                        pending[a] = (family = family, source = source, phase = phase, question = plan[NID(0x00000000000001b4)], distance = if target === nothing
                                        nothing
                                    else
                                        target[NID(0x0000000000000084)]
                                    end, ref = if target === nothing || returning
                                        nothing
                                    else
                                        target[NID(0x0000000000000195)]
                                    end, status = NID(0x000000000000030a))
                    end
                elseif #= none:482 =# returning && home === nothing
                    #= none:483 =#
                    plan = D(NID(0x000000000000021f) => NID(0x000000000000030b))
                else
                    #= none:485 =#
                    visible = (moves[a])[NID(0x00000000000001dd)]
                    #= none:485 =#
                    target = if returning
                            home
                        else
                            if isempty(visible)
                                nothing
                            else
                                first(visible)
                            end
                        end
                    #= none:486 =#
                    if !returning && (target !== nothing && target[NID(0x0000000000000084)] <= 1.25)
                        #= none:487 =#
                        plan = D(NID(0x000000000000021f) => if haskey(dropped[NID(0x00000000000002ba)], target[NID(0x0000000000000195)] + 1)
                                        NID(0x00000000000002fb)
                                    else
                                        NID(0x00000000000002fc)
                                    end, NID(0x00000000000002fd) => target[NID(0x0000000000000195)])
                    else
                        #= none:489 =#
                        scored = [r for r = ((moves[a])[NID(0x000000000000030d)])[NID(0x000000000000030e)] if r[NID(0x000000000000030c)] !== nothing]
                        #= none:490 =#
                        if isempty(scored)
                            #= none:491 =#
                            plan = D(NID(0x000000000000021f) => NID(0x000000000000030b))
                        else
                            #= none:494 =#
                            sort!(scored, by = (r->begin
                                            #= none:494 =#
                                            #= none:495 =#
                                            ang = deg2rad(Float64(ANGLES[parse(Int, r[NID(0x0000000000000195)]) + 1]))
                                            #= none:496 =#
                                            if target === nothing
                                                r[NID(0x000000000000030c)]
                                            else
                                                hypot(target[NID(0x000000000000027b)] - cos(ang), target[NID(0x000000000000027c)] - sin(ang))
                                            end
                                        end))
                            #= none:498 =#
                            plan = D(NID(0x000000000000021f) => NID(0x000000000000030f), NID(0x0000000000000251) => parse(Int, (first(scored))[NID(0x0000000000000195)]))
                        end
                    end
                end
            end
            #= none:503 =#
            if basic_loop && (!(haskey(pending, a)) && (plan[NID(0x000000000000021f)] in (NID(0x00000000000002fc), NID(0x00000000000002fb), NID(0x00000000000002fa)) || at_home && (plan[NID(0x000000000000021f)] == NID(0x00000000000002f2) && ((loops[a])[NID(0x0000000000000096)]).H > 0)))
                #= none:504 =#
                family = if plan[NID(0x000000000000021f)] in (NID(0x00000000000002fc), NID(0x00000000000002fb))
                        NID(0x000000000000000d)
                    else
                        NID(0x0000000000000096)
                    end
                #= none:505 =#
                question = if plan[NID(0x000000000000021f)] == NID(0x00000000000002fb)
                        NID(0x00000000000002e0)
                    else
                        if family == NID(0x000000000000000d)
                            NID(0x00000000000002e2)
                        else
                            NID(0x00000000000002e4)
                        end
                    end
                #= none:506 =#
                source = ncat(NID(0x00000000000002eb), now, NID(0x00000000000000da), a)
                #= none:507 =#
                plan = choose_method!((loops[a])[family], [merge(plan, D(NID(0x00000000000001b7) => NID(0x0000000000000310), NID(0x00000000000002fe) => 5.0, NID(0x00000000000001b4) => question))], source)
                #= none:508 =#
                pending[a] = (family = family, source = source, phase = phase, question = question, distance = nothing, ref = nothing, status = NID(0x000000000000030a))
            end
            #= none:510 =#
            if orientation && (plan[NID(0x000000000000021f)] == NID(0x000000000000030b) && !(get(plan, NID(0x000000000000007b), false)))
                #= none:511 =#
                plan[NID(0x0000000000000311)] = orientation_scan!(sky[a], clock)
            end
            #= none:513 =#
            plan[NID(0x0000000000000312)] = if returning
                    NID(0x0000000000000096)
                else
                    NID(0x000000000000000d)
                end
            #= none:514 =#
            bundle_credit && (plan[NID(0x0000000000000313)] = D(NID(0x0000000000000259) => a, NID(0x0000000000000314) => (hunger[a])[NID(0x0000000000000314)], NID(0x00000000000001e8) => (hunger[a])[NID(0x00000000000001e8)]))
            #= none:515 =#
            selection_trails && (plan[NID(0x0000000000000315)] = (reserve = (w.bodies[a]).reserve, H = (hunger[a])[NID(0x00000000000001e8)]))
            #= none:516 =#
            plans[a] = plan
            #= none:517 =#
        end
        #= none:518 =#
        sec % 60 == 0 && emit_progress(sec, NID(0x0000000000000316))
        #= none:519 =#
        w.seconds = sec + 1
        #= none:520 =#
        for a = IDS
            #= none:521 =#
            plan = plans[a]
            #= none:521 =#
            action = plan[NID(0x000000000000021f)]
            #= none:521 =#
            op = ncat(NID(0x00000000000002eb), now, NID(0x00000000000000da), a)
            #= none:521 =#
            p = w.positions[a]
            #= none:521 =#
            before_yaw = yaw[a]
            #= none:521 =#
            status = NID(0x000000000000029b)
            #= none:522 =#
            repetition_before = w.bodies[a]
            #= none:523 =#
            frozen_prediction = if harvest_sleep && action == NID(0x00000000000002fc)
                    harvest_predict(harvest[a], sections[a])
                else
                    nothing
                end
            #= none:524 =#
            leg = plan[NID(0x0000000000000312)]
            #= none:525 =#
            delivered = NID[]
            #= none:527 =#
            if action == NID(0x0000000000000317)
                #= none:528 =#
                actual = climb_sample(w, a, yaw[a], plan[NID(0x0000000000000251)], low, high, base_resistance_at)
                #= none:529 =#
                expected = (climbs[a])[plan[NID(0x0000000000000251)] + 1]
                #= none:530 =#
                yaw[a] = mod(yaw[a] + ANGLES[plan[NID(0x0000000000000251)] + 1] + 180, 360) - 180
                #= none:531 =#
                (s, c) = sincos(deg2rad(yaw[a]))
                #= none:532 =#
                (w.bodies[a], status, d, delta) = step(w.bodies[a], NID(0x0000000000000317), w.inventory[a], actual[NID(0x0000000000000231)], actual[NID(0x000000000000022e)])
                #= none:533 =#
                w.positions[a] = (p[1] + s * d, p[2] + c * d)
                #= none:533 =#
                distance[a] += d
                #= none:534 =#
                g = climb_stats[a]
                #= none:534 =#
                g[NID(0x000000000000029a)] += 1
                #= none:534 =#
                g[NID(0x0000000000000084)] += d
                #= none:535 =#
                status == NID(0x000000000000029b) && (g[NID(0x000000000000029b)] += 1)
                #= none:536 =#
                comparable = expected[NID(0x0000000000000318)] == w.inventory[a] && (expected[NID(0x000000000000022e)] == actual[NID(0x000000000000022e)] && expected[NID(0x0000000000000231)] == actual[NID(0x0000000000000231)])
                #= none:537 =#
                comparable && (expected[NID(0x0000000000000319)] != delta && (g[NID(0x000000000000029c)] += 1))
                #= none:538 =#
                push!(g[NID(0x000000000000028a)], D(NID(0x0000000000000121) => op, NID(0x000000000000008a) => status, NID(0x000000000000031a) => actual[NID(0x000000000000031a)], NID(0x00000000000000ac) => actual[NID(0x00000000000000ac)], NID(0x0000000000000318) => w.inventory[a], NID(0x0000000000000231) => actual[NID(0x0000000000000231)], NID(0x0000000000000084) => d, NID(0x0000000000000319) => expected[NID(0x0000000000000319)], NID(0x000000000000031b) => delta))
                #= none:540 =#
                length(g[NID(0x000000000000028a)]) > 32 && popfirst!(g[NID(0x000000000000028a)])
            elseif #= none:541 =# action in (NID(0x000000000000030f), NID(0x000000000000031c))
                #= none:542 =#
                yaw[a] = mod(yaw[a] + get(plan, NID(0x000000000000031d), ANGLES[plan[NID(0x0000000000000251)] + 1]) + 180, 360) - 180
                #= none:543 =#
                (s, c) = sincos(deg2rad(yaw[a]))
                #= none:544 =#
                span = get(plan, NID(0x000000000000031e), if action == NID(0x000000000000031c)
                            1.5 * (1 - (w.bodies[a]).damage)
                        else
                            0.5
                        end)
                #= none:545 =#
                q = (p[1] + s * span, p[2] + c * span)
                #= none:546 =#
                clear = !(any((o->begin
                                    #= none:546 =#
                                    segment_hit(p, q, o, 0.2)
                                end), w.obstacles))
                #= none:547 =#
                sample_span = get(plan, NID(0x000000000000031e), if action == NID(0x000000000000031c)
                                1.5
                            else
                                0.5
                            end * (1 - (w.bodies[a]).damage))
                #= none:548 =#
                midpoint = (p[1] + (s * sample_span) / 2, p[2] + (c * sample_span) / 2)
                #= none:549 =#
                resistance = (if action == NID(0x000000000000031c)
                        base_resistance_at
                    else
                        resistance_at
                    end)(midpoint)
                #= none:550 =#
                expected = (if action == NID(0x000000000000031c)
                        (moves[a])[NID(0x000000000000031f)]
                    else
                        ((moves[a])[NID(0x000000000000030d)])[NID(0x000000000000030e)]
                    end)[plan[NID(0x0000000000000251)] + 1]
                #= none:551 =#
                (w.bodies[a], status, d, delta) = step(w.bodies[a], action, w.inventory[a], resistance, clear)
                #= none:552 =#
                if action == NID(0x000000000000031c)
                    #= none:553 =#
                    g = run_stats[a]
                    #= none:553 =#
                    g[NID(0x000000000000029a)] += 1
                    #= none:553 =#
                    g[NID(0x0000000000000084)] += d
                    #= none:554 =#
                    status == NID(0x000000000000029b) && (g[NID(0x000000000000029b)] += 1)
                    #= none:555 =#
                    comparable = expected[NID(0x0000000000000318)] == w.inventory[a] && (expected[NID(0x000000000000022e)] == clear && expected[NID(0x0000000000000231)] == resistance)
                    #= none:556 =#
                    comparable && (expected[NID(0x0000000000000319)] != delta && (g[NID(0x000000000000029c)] += 1))
                    #= none:557 =#
                    push!(g[NID(0x000000000000028a)], D(NID(0x0000000000000121) => op, NID(0x000000000000008a) => status, NID(0x0000000000000318) => w.inventory[a], NID(0x0000000000000231) => resistance, NID(0x0000000000000084) => d, NID(0x0000000000000319) => deepcopy(expected[NID(0x0000000000000319)]), NID(0x000000000000031b) => delta, NID(0x000000000000022a) => comparable))
                    #= none:559 =#
                    length(g[NID(0x000000000000028a)]) > 32 && popfirst!(g[NID(0x000000000000028a)])
                elseif #= none:560 =# ground_mode != NID(0x0000000000000067)
                    #= none:561 =#
                    g = ground_stats[a]
                    #= none:561 =#
                    g[NID(0x00000000000002b6)] += 1
                    #= none:562 =#
                    resistance > 1.5 && (g[NID(0x00000000000002b7)] += 1)
                    #= none:565 =#
                    comparable = !(haskey(plan, NID(0x000000000000031d))) && (expected[NID(0x000000000000022e)] == clear && (expected[NID(0x0000000000000318)] == w.inventory[a] && expected[NID(0x0000000000000231)] == resistance))
                    #= none:566 =#
                    match = comparable && (expected[NID(0x0000000000000319)] == delta && expected[NID(0x0000000000000231)] == resistance)
                    #= none:567 =#
                    comparable && (!match && (g[NID(0x000000000000029c)] += 1))
                    #= none:568 =#
                    push!(g[NID(0x000000000000028a)], D(NID(0x0000000000000121) => op, NID(0x0000000000000318) => w.inventory[a], NID(0x0000000000000231) => resistance, NID(0x000000000000008a) => status, NID(0x0000000000000319) => deepcopy(expected[NID(0x0000000000000319)]), NID(0x000000000000031b) => delta, NID(0x000000000000022a) => comparable, NID(0x0000000000000320) => match))
                    #= none:571 =#
                    length(g[NID(0x000000000000028a)]) > 32 && popfirst!(g[NID(0x000000000000028a)])
                end
                #= none:573 =#
                d = min(d, get(plan, NID(0x000000000000031e), d))
                #= none:574 =#
                w.positions[a] = (p[1] + s * d, p[2] + c * d)
                #= none:574 =#
                distance[a] += d
            elseif #= none:575 =# action in (NID(0x00000000000002f0), NID(0x00000000000002e8), NID(0x00000000000002ab), NID(0x00000000000002ac), NID(0x00000000000002e9), NID(0x0000000000000321), NID(0x0000000000000322))
                #= none:576 =#
                r = communicate!(w, a, op, action, get(plan, NID(0x00000000000001b0), nothing), get(plan, NID(0x00000000000002ef), nothing))
                #= none:576 =#
                status = r[NID(0x000000000000008a)]
                #= none:577 =#
                if status == NID(0x0000000000000323)
                    #= none:578 =#
                    popfirst!(cargo[a])
                elseif #= none:579 =# status == NID(0x0000000000000324)
                    #= none:580 =#
                    push!(cargo[plan[NID(0x00000000000001b0)]], popfirst!(cargo[a]))
                end
                #= none:582 =#
                results[a] = D(op => r)
                #= none:583 =#
                if action != NID(0x00000000000002f0)
                    #= none:584 =#
                    (w.bodies[a], _, _, _) = step(w.bodies[a], NID(0x00000000000002f2), w.inventory[a])
                end
            else
                #= none:587 =#
                (w.bodies[a], _, _, _) = step(w.bodies[a], NID(0x00000000000002f2), w.inventory[a])
                #= none:588 =#
                if action in (NID(0x0000000000000325), NID(0x00000000000002fb))
                    #= none:589 =#
                    status = cargo_transfer!(dropped, w, cargo, food, stock, a, op, now, action; index = if action == NID(0x00000000000002fb)
                                    plan[NID(0x00000000000002fd)] + 1
                                else
                                    0
                                end)
                elseif #= none:590 =# action == NID(0x000000000000030b)
                    #= none:591 =#
                    yaw[a] = mod(yaw[a] + get(plan, NID(0x0000000000000311), 60) + 180, 360) - 180
                elseif #= none:592 =# action == NID(0x00000000000002fc)
                    #= none:593 =#
                    j = plan[NID(0x00000000000002fd)] + 1
                    #= none:593 =#
                    f = food[j]
                    #= none:594 =#
                    legal = stock[j] > 0 && (hypot(f.x - p[1], f.z - p[2]) <= 1.25 && !(any((o->begin
                                                #= none:594 =#
                                                segment_hit(p, (Float64(f.x), Float64(f.z)), o, 0.0)
                                            end), w.obstacles)))
                    #= none:595 =#
                    if legal
                        #= none:595 =#
                        stock[j] -= 1
                        #= none:595 =#
                        w.inventory[a] += 1
                        #= none:595 =#
                        push!(cargo[a], op)
                    end
                    #= none:596 =#
                    status = if legal
                            NID(0x00000000000002e3)
                        else
                            NID(0x0000000000000326)
                        end
                elseif #= none:597 =# action in (NID(0x00000000000002fa), NID(0x00000000000002f1))
                    #= none:598 =#
                    legal = hypot(p[1] - spec.home[1], p[2] - spec.home[2]) <= 1.25
                    #= none:599 =#
                    if legal && action == NID(0x00000000000002fa)
                        #= none:600 =#
                        delivered = NID[id for id = cargo[a] if id !== nothing]
                        #= none:600 =#
                        empty!(cargo[a])
                        #= none:601 =#
                        if shared_stores
                            #= none:602 =#
                            shared += w.inventory[a]
                            #= none:602 =#
                            storage_stats[NID(0x00000000000002bf)] += w.inventory[a]
                        else
                            #= none:604 =#
                            stores[a] += w.inventory[a]
                        end
                        #= none:606 =#
                        w.inventory[a] = 0
                    elseif #= none:607 =# legal && if shared_stores
                                    shared
                                else
                                    stores[a]
                                end > 0
                        #= none:608 =#
                        if shared_stores
                            #= none:609 =#
                            shared -= 1
                            #= none:609 =#
                            storage_stats[NID(0x00000000000002c0)] += 1
                        else
                            #= none:611 =#
                            stores[a] -= 1
                        end
                        #= none:613 =#
                        w.inventory[a] += 1
                        #= none:614 =#
                        push!(cargo[a], nothing)
                    else
                        #= none:616 =#
                        status = NID(0x0000000000000327)
                    end
                end
            end
            #= none:620 =#
            if shared_stores && action in (NID(0x00000000000002fa), NID(0x00000000000002f1))
                #= none:621 =#
                push!(storage_stats[NID(0x000000000000028a)], D(NID(0x0000000000000259) => a, NID(0x0000000000000328) => op, NID(0x000000000000021f) => action, NID(0x000000000000008a) => status, NID(0x0000000000000329) => shared))
                #= none:622 =#
                length(storage_stats[NID(0x000000000000028a)]) > 32 && popfirst!(storage_stats[NID(0x000000000000028a)])
            end
            #= none:624 =#
            if ground_wear && (action == NID(0x000000000000030f) && status == NID(0x000000000000029b))
                #= none:625 =#
                tread!(wear, op, a, p, w.positions[a], wear_offset + now; walkable = dry)
            end
            #= none:627 =#
            if ground_continuity
                #= none:628 =#
                dx = (w.positions[a])[1] - p[1]
                #= none:628 =#
                dz = (w.positions[a])[2] - p[2]
                #= none:628 =#
                (sn, cs) = sincosd(before_yaw)
                #= none:629 =#
                ground_receipts[a] = D(NID(0x0000000000000259) => a, NID(0x0000000000000121) => ncat(NID(0x00000000000002d0), now, NID(0x00000000000000da), a), NID(0x0000000000000328) => op, NID(0x000000000000032a) => now, NID(0x000000000000032b) => now + 1000000, NID(0x000000000000027b) => dx * sn + dz * cs, NID(0x000000000000027c) => dx * cs - dz * sn, NID(0x0000000000000095) => yaw[a] - before_yaw)
            end
            #= none:632 =#
            if continuous_safety && get(plan, NID(0x000000000000007b), false)
                #= none:633 =#
                (safety[a])[NID(0x000000000000032c)] = true
                #= none:634 =#
                (safety[a])[NID(0x000000000000032d)] = (action = action, status = status, yaw = mod((yaw[a] - before_yaw) + 180, 360) - 180)
            end
            #= none:636 =#
            sleep_maintenance && record_sleep_use!(action_models[a], plan, op, status)
            #= none:637 =#
            #= none:637 =# @assert all((length(cargo[x]) == w.inventory[x] for x = IDS))
            #= none:638 =#
            max_radius[a] = max(max_radius[a], hypot((w.positions[a])[1] - spec.home[1], (w.positions[a])[2] - spec.home[2]))
            #= none:639 =#
            if landmark_routes && !(get(plan, NID(0x000000000000007b), false))
                #= none:640 =#
                near = homes[a] !== nothing && (homes[a])[NID(0x0000000000000084)] <= 1.25
                #= none:641 =#
                route_result!(routes[a], landmarks[a], op, action, status, leg, near, get(plan, NID(0x000000000000025b), nothing); delivered = delivered, relational = relation_field)
            end
            #= none:643 =#
            if phase == NID(0x00000000000002d6)
                #= none:644 =#
                cycle = ((learning[a])[NID(0x0000000000000088)])[NID(0x0000000000000089)]
                #= none:645 =#
                harvest_sleep && (action == NID(0x00000000000002f2) && freeze_harvest!(harvest[a], cycle, now))
                #= none:646 =#
                if general_sleep && (cycle[NID(0x000000000000008a)] == NID(0x0000000000000145) && (cycle[NID(0x000000000000032e)] == 0 && action == NID(0x00000000000002f2)))
                    #= none:647 =#
                    freeze_general!(general[a], a, now; retained = sleep_retention)
                end
                #= none:649 =#
                callback = if harvest_sleep || general_sleep
                        (c, t)->begin
                                #= none:649 =#
                                #= none:650 =#
                                harvest_sleep && consolidate_harvest!(harvest[a], c, t)
                                #= none:651 =#
                                general_sleep && review_general!(general[a], a, day, t)
                                #= none:652 =#
                                experience_bundles && sleep_bundles!(bundles[a], day, (general[a])[NID(0x000000000000032f)])
                                #= none:653 =#
                                sleep_maintenance && review_sleep_usage!(action_models[a], day, (general[a])[NID(0x000000000000032f)])
                                #= none:654 =#
                                sleep_actions && adopt_sleep_actions!(action_models[a], last((general[a])[NID(0x0000000000000330)]), a, t)
                                #= none:655 =#
                                sleep_maintenance && enroll_sleep_usage!(action_models[a], t)
                            end
                    else
                        nothing
                    end
                #= none:657 =#
                receipt!(learning[a], now; phase = phase, kind = if action == NID(0x00000000000002f2)
                            NID(0x0000000000000322)
                        else
                            action
                        end, status = if action == NID(0x00000000000002f2)
                            NID(0x0000000000000331)
                        else
                            status
                        end, on_complete = callback)
            end
            #= none:659 =#
            general_sleep && remember_general!(general[a], a, op, action, status, get(plan, NID(0x00000000000001b0), nothing), phase, now + 1000000; context = contexts[a], direction = get(plan, NID(0x0000000000000251), nothing), retain = sleep_retention)
            #= none:660 =#
            if harvest_sleep && action == NID(0x00000000000002fc)
                #= none:661 =#
                harvest_pending[a] = (op = op, before = deepcopy(sections[a]), status = status, executed = now + 1000000, prediction = frozen_prediction, position = p, yaw = yaw[a])
            end
            #= none:664 =#
            if repetition_pressure
                #= none:665 =#
                method = get(plan, NID(0x00000000000001b7), nothing)
                #= none:667 =#
                active = phase in (NID(0x00000000000002d4), NID(0x00000000000002d5)) && method !== nothing
                #= none:668 =#
                view = (phase, leg, Tuple(((r[NID(0x000000000000022e)], r[NID(0x000000000000008a)]) for r = ((moves[a])[NID(0x000000000000030d)])[NID(0x000000000000030e)])), Tuple(((f[NID(0x0000000000000332)], round(f[NID(0x0000000000000084)]; digits = 1)) for f = (moves[a])[NID(0x00000000000001dd)])))
                #= none:669 =#
                b = w.bodies[a]
                #= none:670 =#
                changed = w.positions[a] != p || (b.strain < repetition_before.strain - 1.0e-9 || (b.burst > repetition_before.burst + 1.0e-9 || status in (NID(0x00000000000002e3), NID(0x00000000000002e0), NID(0x000000000000011f), NID(0x0000000000000323), NID(0x0000000000000324))))
                #= none:671 =#
                repetition_result!(repetitions[a], op, now + 1000000, if active
                        method
                    else
                        nothing
                    end, view; changed = changed)
            end
            #= none:673 =#
            if haskey(pending, a)
                #= none:674 =#
                pending[a] = merge(pending[a], (status = status, moved = w.positions[a] != p))
            end
            #= none:676 =#
            if movement_inertia
                #= none:677 =#
                (inertia[a])[NID(0x00000000000001ea)] = (actor = a, source = op, executed_us = now + 1000000, phase = phase, family = leg, action = action, status = status, moved = w.positions[a] != p, method = get(plan, NID(0x00000000000001b7), nothing), route = get(plan, NID(0x000000000000025b), nothing))
            end
            #= none:680 =#
            if exploration_horizon
                #= none:681 =#
                observed_status = if status == NID(0x000000000000029b)
                        if action in (NID(0x000000000000030f), NID(0x000000000000031c), NID(0x0000000000000317)) && w.positions[a] != p
                            NID(0x00000000000001b8)
                        else
                            if action == NID(0x000000000000030b)
                                NID(0x0000000000000333)
                            else
                                if action == NID(0x00000000000002f2)
                                    NID(0x0000000000000331)
                                else
                                    status
                                end
                            end
                        end
                    else
                        status
                    end
                #= none:682 =#
                horizon_result!(horizons[a], a, op, phase, observed_status, status in (NID(0x00000000000002e3), NID(0x00000000000002e0)))
                #= none:683 =#
                startswith(get(plan, NID(0x00000000000001b7), NID(0x0000000000000334)), NID(0x0000000000000335)) && ((horizons[a])[NID(0x0000000000000302)] += 1)
            end
            #= none:685 =#
            if experience_bundles
                #= none:686 =#
                use_bundles!(bundles[a], get(plan, NID(0x000000000000020c), nothing), get(plan, NID(0x00000000000001b7), nothing), status)
                #= none:687 =#
                bundle_credit && admit_bundle_credit!(bundles[a], get(plan, NID(0x000000000000020c), nothing), get(plan, NID(0x00000000000001b7), nothing), status, plan[NID(0x0000000000000313)], op)
                #= none:688 =#
                remember_bundle!(bundles[a], D(NID(0x0000000000000259) => a, NID(0x0000000000000328) => op, NID(0x00000000000002ce) => now, NID(0x000000000000025a) => now + 1000000, NID(0x0000000000000250) => bundle_contexts[a], NID(0x0000000000000116) => phase, NID(0x000000000000021f) => action, NID(0x0000000000000336) => status, NID(0x00000000000001b7) => get(plan, NID(0x00000000000001b7), nothing)))
            end
            #= none:691 =#
            if selection_trails
                #= none:692 =#
                bt = get(plan, NID(0x000000000000020c), nothing)
                #= none:692 =#
                refs = if bt === nothing
                        NID[]
                    else
                        bt[NID(0x0000000000000337)]
                    end
                #= none:693 =#
                use_trail!(trails[a], a, op, get(plan, NID(0x000000000000020f), nothing), get(plan, NID(0x00000000000001b7), nothing), status, (plan[NID(0x0000000000000315)]).reserve, (plan[NID(0x0000000000000315)]).H, refs)
            end
            #= none:695 =#
            (counts[a])[action] = get(counts[a], action, 0) + 1
            #= none:696 =#
            sig = (phase, leg, action, get(plan, NID(0x00000000000001b0), nothing), status, get(plan, NID(0x00000000000001b7), nothing), get(plan, NID(0x0000000000000251), nothing), get(plan, NID(0x0000000000000338), nothing))
            #= none:697 =#
            if get(previous, a, nothing) != sig
                #= none:698 =#
                push!(events, D(NID(0x00000000000002d3) => now, NID(0x0000000000000259) => a, NID(0x0000000000000116) => phase, NID(0x0000000000000312) => leg, NID(0x000000000000021f) => action, NID(0x000000000000008a) => status, NID(0x00000000000001b0) => get(plan, NID(0x00000000000001b0), nothing), NID(0x00000000000001b7) => get(plan, NID(0x00000000000001b7), nothing), NID(0x0000000000000251) => get(plan, NID(0x0000000000000251), nothing), NID(0x0000000000000338) => get(plan, NID(0x0000000000000338), nothing), NID(0x000000000000025b) => get(plan, NID(0x000000000000025b), nothing), NID(0x0000000000000339) => get(plan, NID(0x0000000000000339), nothing)))
                #= none:701 =#
                previous[a] = sig
            end
            #= none:703 =#
        end
        #= none:704 =#
        if food_body
            #= none:705 =#
            for a = IDS
                #= none:706 =#
                before = (w.bodies[a]).reserve
                #= none:706 =#
                w.bodies[a] = metabolize(w.bodies[a], 1.0)
                #= none:707 =#
                metabolism[a] += before - (w.bodies[a]).reserve
                #= none:708 =#
            end
        end
        #= none:710 =#
        #= none:710 =# @assert shared + sum(stock) + sum(values(w.inventory)) + sum(values(stores)) + w.consumed == initial + replenished
        #= none:711 =#
        if mod(now + 1000000, clock.day_us) == 0
            #= none:712 =#
            for a = IDS
                #= none:713 =#
                integrate(a, now + 1000000, observe(w, a))
                #= none:714 =#
                cycle = ((learning[a])[NID(0x0000000000000088)])[NID(0x0000000000000089)]
                #= none:715 =#
                states[a] = consolidate_social(states[a], merge(copy(cycle), D(NID(0x000000000000032f) => now + 1000000)), a)
                #= none:716 =#
            end
            #= none:717 =#
            push!(daily, D(NID(0x0000000000000147) => physical(), NID(0x0000000000000088) => deepcopy(learning), NID(0x0000000000000086) => deepcopy(counts), NID(0x0000000000000071) => shared, NID(0x0000000000000036) => sum(stock), NID(0x0000000000000076) => w.consumed, NID(0x0000000000000075) => replenished))
        end
        #= none:720 =#
        if !(NumericCore.TRACK_IDS[]) && mod(sec + 1, 600) == 0
            #= none:721 =#
            NumericCore.collect_ids!(#= none:721 =# Base.@locals())
        end
        #= none:723 =#
    end
    #= none:724 =#
    emit_progress(days * div(clock.day_us, 1000000), NID(0x000000000000033a))
    #= none:725 =#
    progress_io === nothing || close(progress_io)
    #= none:726 =#
    ground_wear && advance_wear!(wear, wear_offset + Int(days * clock.day_us))
    #= none:727 =#
    terminal = D()
    #= none:728 =#
    for a = IDS
        #= none:729 =#
        integrate(a, Int(days * clock.day_us), observe(w, a))
        #= none:730 =#
        cycle = ((learning[a])[NID(0x0000000000000088)])[NID(0x0000000000000089)]
        #= none:731 =#
        states[a] = consolidate_social(states[a], merge(copy(cycle), D(NID(0x000000000000032f) => Int(days * clock.day_us))), a)
        #= none:732 =#
        terminal[a] = D(NID(0x0000000000000144) => deepcopy(purposes[a]), NID(0x000000000000007f) => collect(w.positions[a]), NID(0x0000000000000080) => bodydict(w.bodies[a]), NID(0x0000000000000081) => w.inventory[a], NID(0x0000000000000083) => stores[a], NID(0x0000000000000088) => learning[a], NID(0x00000000000002d1) => states[a], NID(0x000000000000033b) => pressure_snapshot(live[a]), NID(0x0000000000000084) => distance[a], NID(0x0000000000000132) => if landmark_routes
                        deepcopy(routes[a])
                    else
                        nothing
                    end, NID(0x00000000000002cb) => max_radius[a], NID(0x000000000000007e) => if harvest_sleep
                        deepcopy(harvest[a])
                    else
                        nothing
                    end, NID(0x000000000000002b) => field_stats[a])
        #= none:736 =#
    end
    #= none:737 =#
    environment = D(NID(0x00000000000000c6) => NID(0x000000000000028b), NID(0x00000000000000c7) => clock.day_us, NID(0x00000000000000c4) => world_offset + days * clock.day_us, NID(0x0000000000000019) => shared_stores, NID(0x0000000000000071) => shared, NID(0x000000000000001b) => regrowth_days, NID(0x000000000000001c) => regrowth_capacity, NID(0x00000000000000c9) => land, NID(0x0000000000000093) => spec.obstacles, NID(0x00000000000000ca) => spec.food, NID(0x00000000000000cb) => spec.ground_patches, NID(0x000000000000005f) => renewable_food, NID(0x000000000000002f) => dynamic_hazard_mode, NID(0x000000000000003e) => dropping, NID(0x00000000000000c8) => ground_wear, NID(0x000000000000000d) => deepcopy(food), NID(0x0000000000000082) => copy(stock), NID(0x0000000000000036) => if ground_wear
                    wear_snapshot(wear)
                else
                    nothing
                end, NID(0x0000000000000031) => if dynamic_hazard_mode != NID(0x000000000000005d)
                    deepcopy(hazard_world)
                else
                    nothing
                end, NID(0x00000000000000d6) => [D(NID(0x00000000000000d5) => i, NID(0x0000000000000121) => (dropped[NID(0x00000000000002ba)])[i]) for i = sort(collect(keys(dropped[NID(0x00000000000002ba)])))])
    #= none:743 =#
    push!(NumericCore.AUDITS, NumericCore.audit(#= none:743 =# Base.@locals()))
    #= none:744 =#
    merge(if lateral_side == NID(0x000000000000005d)
            D()
        else
            D(NID(0x000000000000033c) => lateral_stats)
        end, D(NID(0x0000000000000071) => shared, NID(0x000000000000006d) => if shared_stores
                    storage_stats
                else
                    nothing
                end, NID(0x000000000000001e) => if skyline_mode == NID(0x000000000000005d)
                    nothing
                else
                    skyline_states
                end, NID(0x000000000000001f) => if reposition
                    reposition_states
                else
                    nothing
                end, NID(0x000000000000033d) => environment, NID(0x0000000000000020) => if selection_trails
                    trails
                else
                    nothing
                end, NID(0x0000000000000022) => if experience_bundles
                    D((a => bundle_snapshot(bundles[a]) for a = IDS))
                else
                    nothing
                end, NID(0x0000000000000023) => if exploration_horizon
                    horizons
                else
                    nothing
                end, NID(0x0000000000000024) => if movement_inertia
                    inertia
                else
                    nothing
                end, NID(0x0000000000000025) => if body_field
                    body_fields
                else
                    nothing
                end, NID(0x0000000000000026) => if relation_field
                    relation_fields
                else
                    nothing
                end, NID(0x0000000000000027) => if orientation
                    sky
                else
                    nothing
                end, NID(0x0000000000000033) => if continuous_safety
                    D((a => loop_snapshot(safety_loops[a]) for a = IDS))
                else
                    nothing
                end, NID(0x0000000000000077) => if dynamic_hazard_mode != NID(0x000000000000005d)
                    hazard_world
                else
                    nothing
                end, NID(0x000000000000003a) => if food_body
                    D(NID(0x00000000000000ff) => hunger, NID(0x000000000000033e) => metabolism)
                else
                    nothing
                end, NID(0x0000000000000039) => if ground_continuity
                    ground_models
                else
                    nothing
                end, NID(0x0000000000000038) => if ground_perception
                    ground_views
                else
                    nothing
                end, NID(0x0000000000000037) => if ground_wear
                    wear_snapshot(wear)
                else
                    nothing
                end, NID(0x0000000000000078) => if sleep_actions
                    action_models
                else
                    nothing
                end, NID(0x0000000000000040) => if general_sleep
                    general
                else
                    nothing
                end, NID(0x000000000000003f) => if social_response || food_body
                    response_stats
                else
                    nothing
                end, NID(0x0000000000000070) => days * clock.day_us, NID(0x0000000000000073) => initial, NID(0x0000000000000036) => sum(stock), NID(0x0000000000000076) => w.consumed, NID(0x0000000000000075) => replenished, NID(0x0000000000000155) => replenishments, NID(0x0000000000000079) => if dropping
                    D(NID(0x000000000000011f) => dropped[NID(0x000000000000011f)], NID(0x00000000000002e0) => dropped[NID(0x00000000000002e0)], NID(0x000000000000033f) => dropped[NID(0x000000000000033f)], NID(0x000000000000028a) => dropped[NID(0x000000000000028a)], NID(0x0000000000000340) => [D(NID(0x00000000000000d5) => i, NID(0x00000000000000d1) => (food[i]).x, NID(0x00000000000000e3) => (food[i]).z, NID(0x0000000000000082) => stock[i], NID(0x0000000000000121) => (dropped[NID(0x00000000000002ba)])[i]) for i = sort(collect(keys(dropped[NID(0x00000000000002ba)])))])
                else
                    nothing
                end, NID(0x000000000000003c) => if climbing
                    climb_stats
                else
                    nothing
                end, NID(0x000000000000003b) => if running
                    run_stats
                else
                    nothing
                end, NID(0x000000000000007a) => if ground_mode == NID(0x0000000000000067)
                    nothing
                else
                    ground_stats
                end, NID(0x000000000000007b) => if hazard_mode
                    deepcopy(safety)
                else
                    nothing
                end, NID(0x0000000000000015) => if repetition_pressure
                    repetitions
                else
                    nothing
                end, NID(0x0000000000000016) => if parent_breadth
                    breadth_stats
                else
                    nothing
                end, NID(0x0000000000000086) => counts, NID(0x000000000000012f) => events, NID(0x000000000000007d) => terminal, NID(0x000000000000008b) => daily, NID(0x0000000000000146) => day_starts))
end
nothing
