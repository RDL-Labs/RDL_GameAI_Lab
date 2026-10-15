# Generated numeric CPU variant. Regenerate with build.jl; source provenance in README.md.
using Main.NumericCore
include(joinpath(#= none:1 =# @__DIR__(), "../lw_day/run.jl"))
function run_integrated(input)
    #= none:2 =#
    #= none:3 =#
    cfg = input.config
    #= none:4 =#
    enabled = cfg.learning == NID(0x000000000000005c)
    #= none:5 =#
    #= none:5 =# @assert cfg.learning in (NID(0x000000000000005d), NID(0x000000000000005c)) && cfg.food in (NID(0x000000000000005e), NID(0x000000000000005f))
    #= none:6 =#
    r = lw_day(input.scene, input.clock; days = Int(cfg.days), adaptive_approach = get(cfg, :adaptive_approach, NID(0x000000000000005d)) == NID(0x0000000000000060), continuous_descent = get(cfg, :continuous_descent, NID(0x000000000000005d)) == NID(0x0000000000000060), repetition_pressure = get(cfg, :repetition_pressure, NID(0x000000000000005d)) == NID(0x0000000000000060), parent_breadth = get(cfg, :parent_breadth, NID(0x000000000000005d)) == NID(0x0000000000000060), lateral_side = get(cfg, :lateral_side, NID(0x000000000000005d)), goal_switch_threshold = get(cfg, :goal_switch_threshold, 2), shared_stores = get(cfg, :stores, NID(0x0000000000000061)) == NID(0x0000000000000062), regrowth_days = Int(get(cfg, :regrowth_days, 1)), regrowth_capacity = Int(get(cfg, :regrowth_capacity, 0)), skyline_mode = get(cfg, :skyline, NID(0x000000000000005d)), reposition = get(cfg, :reposition, NID(0x000000000000005d)) == NID(0x0000000000000060), selection_trails = get(cfg, :selection_trails, NID(0x000000000000005d)) == NID(0x0000000000000060), bundle_credit = get(cfg, :bundle_credit, NID(0x000000000000005d)) == NID(0x0000000000000060), experience_bundles = get(cfg, :experience_bundles, NID(0x000000000000005d)) == NID(0x0000000000000060), exploration_horizon = get(cfg, :exploration_horizon, NID(0x000000000000005d)) == NID(0x0000000000000060), movement_inertia = get(cfg, :movement_inertia, NID(0x000000000000005d)) == NID(0x0000000000000060), body_field = get(cfg, :body_field, NID(0x000000000000005d)) == NID(0x0000000000000060), relation_field = get(cfg, :relation_field, NID(0x000000000000005d)) == NID(0x0000000000000060), orientation = get(cfg, :orientation, NID(0x000000000000005d)) == NID(0x0000000000000060), basic_loop = true, landmark_routes = true, harvest_sleep = enabled, model_field = enabled, model_review = enabled, model_relearn = enabled, renewable_food = cfg.food == NID(0x000000000000005f), hazard_mode = cfg.hazards != NID(0x000000000000005d), continuous_safety = get(cfg, :safety_methods, NID(0x0000000000000063)) == NID(0x0000000000000064), dynamic_hazard_mode = if cfg.hazards in (NID(0x0000000000000065), NID(0x0000000000000066))
                    cfg.hazards
                else
                    NID(0x000000000000005d)
                end, ground_mode = get(cfg, :ground, NID(0x0000000000000067)), ground_wear = get(cfg, :ground_wear, NID(0x000000000000005d)) == NID(0x0000000000000060), ground_perception = get(cfg, :ground_perception, NID(0x000000000000005d)) == NID(0x0000000000000060), ground_continuity = get(cfg, :ground_continuity, NID(0x000000000000005d)) == NID(0x0000000000000060), food_body = get(cfg, :food_body, NID(0x000000000000005d)) == NID(0x0000000000000060), running = get(cfg, :running, NID(0x000000000000005d)) == NID(0x0000000000000060), climbing = get(cfg, :climbing, NID(0x000000000000005d)) == NID(0x0000000000000060), low_obstacles = get(cfg, :low_obstacles, NID(0x000000000000005d)) == NID(0x0000000000000060), dropping = get(cfg, :dropping, NID(0x000000000000005d)) == NID(0x0000000000000060), social_response = get(cfg, :social_response, NID(0x0000000000000063)) == NID(0x0000000000000068), general_sleep = get(cfg, :general_sleep, NID(0x000000000000005d)) in (NID(0x0000000000000069), NID(0x000000000000006a)), sleep_actions = get(cfg, :general_sleep, NID(0x000000000000005d)) == NID(0x000000000000006a), sleep_retention = get(cfg, :sleep_retention, NID(0x000000000000006b)) == NID(0x000000000000006c), sleep_maintenance = get(cfg, :sleep_maintenance, NID(0x000000000000005d)) == NID(0x0000000000000060))
    #= none:9 =#
    summary = D(NID(0x0000000000000015) => r[NID(0x0000000000000015)], NID(0x0000000000000016) => r[NID(0x0000000000000016)], NID(0x000000000000006d) => r[NID(0x000000000000006d)], NID(0x000000000000001e) => r[NID(0x000000000000001e)], NID(0x000000000000001f) => r[NID(0x000000000000001f)], NID(0x000000000000006e) => NID(0x000000000000006f), NID(0x0000000000000007) => cfg, NID(0x0000000000000070) => r[NID(0x0000000000000070)], NID(0x000000000000000d) => D(NID(0x0000000000000062) => r[NID(0x0000000000000071)], NID(0x0000000000000072) => r[NID(0x0000000000000073)], NID(0x0000000000000074) => r[NID(0x0000000000000075)], NID(0x0000000000000036) => r[NID(0x0000000000000036)], NID(0x0000000000000076) => r[NID(0x0000000000000076)]), NID(0x0000000000000020) => r[NID(0x0000000000000020)], NID(0x0000000000000022) => r[NID(0x0000000000000022)], NID(0x0000000000000023) => r[NID(0x0000000000000023)], NID(0x0000000000000024) => r[NID(0x0000000000000024)], NID(0x0000000000000025) => r[NID(0x0000000000000025)], NID(0x0000000000000026) => r[NID(0x0000000000000026)], NID(0x0000000000000027) => r[NID(0x0000000000000027)], NID(0x0000000000000033) => r[NID(0x0000000000000033)], NID(0x0000000000000077) => r[NID(0x0000000000000077)], NID(0x000000000000003a) => r[NID(0x000000000000003a)], NID(0x0000000000000039) => r[NID(0x0000000000000039)], NID(0x0000000000000038) => r[NID(0x0000000000000038)], NID(0x0000000000000037) => r[NID(0x0000000000000037)], NID(0x0000000000000078) => r[NID(0x0000000000000078)], NID(0x0000000000000040) => r[NID(0x0000000000000040)], NID(0x000000000000003f) => r[NID(0x000000000000003f)], NID(0x0000000000000079) => r[NID(0x0000000000000079)], NID(0x000000000000003c) => r[NID(0x000000000000003c)], NID(0x000000000000003b) => r[NID(0x000000000000003b)], NID(0x000000000000007a) => r[NID(0x000000000000007a)], NID(0x000000000000007b) => r[NID(0x000000000000007b)], NID(0x000000000000007c) => D())
    #= none:12 =#
    for a = IDS
        #= none:13 =#
        s = (r[NID(0x000000000000007d)])[a]
        #= none:13 =#
        h = s[NID(0x000000000000007e)]
        #= none:14 =#
        (summary[NID(0x000000000000007c)])[a] = D(NID(0x000000000000007f) => s[NID(0x000000000000007f)], NID(0x0000000000000080) => s[NID(0x0000000000000080)], NID(0x0000000000000081) => s[NID(0x0000000000000081)], NID(0x0000000000000082) => s[NID(0x0000000000000083)], NID(0x0000000000000084) => s[NID(0x0000000000000084)], NID(0x0000000000000085) => sum(values((r[NID(0x0000000000000086)])[a])), NID(0x0000000000000087) => [((((n[NID(0x0000000000000088)])[a])[NID(0x0000000000000088)])[NID(0x0000000000000089)])[NID(0x000000000000008a)] for n = r[NID(0x000000000000008b)]], NID(0x000000000000008c) => if h === nothing || h[NID(0x000000000000008d)] === nothing
                        nothing
                    else
                        (h[NID(0x000000000000008d)])[NID(0x000000000000008c)]
                    end, NID(0x000000000000008e) => if h === nothing
                        false
                    else
                        get(h, NID(0x000000000000008e), false)
                    end, NID(0x000000000000002b) => s[NID(0x000000000000002b)])
        #= none:19 =#
    end
    #= none:20 =#
    return (r, summary)
end
nothing
