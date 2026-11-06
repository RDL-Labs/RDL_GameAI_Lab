# Existing game physiology, not measured human constants. Per action tick unless
# noted. RS scales reserve cost; SS scales strain cost.
const BODY_ACTION = (
    reserve_scale_numerator_us=64_000_000, reserve_scale_day_us=17_280_000_000,
    strain_scale_ticks=60, load_effort=.1,
    walk_reserve=.1, blocked_reserve=.05, walk_distance=.5, walk_strain=.03,
    run_reserve=.5, run_burst=3, run_max_strain=.8, run_distance=1.5, run_strain=.18,
    climb_reserve=.4, climb_burst=4, climb_max_strain=.8, climb_strain=.15,
    work_reserve=.1, work_strain=.01, # process_food
    # Provisional shore-fishing average including casting/retrieval, not measured physiology.
    # Per worked tick: reserve cost * RS; strain recovery * SS * reserve/damage recovery factor.
    # 1/4 former work cost, 1/10 rest recovery. Basal metabolism remains separate.
    fish_reserve=.025, fish_strain_recovery=.015,
    reserve_capacity=100, meal_energy=20, rest_energy_scale=20,
    burst_capacity=10, rest_burst=2, rest_strain=.15, rest_reserve=.05,
    metabolic_reserve_per_second=.25,
)
