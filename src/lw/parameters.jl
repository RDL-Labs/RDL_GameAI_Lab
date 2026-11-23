# Owner-side cognition settings. Separate from physical ability in body/parameters.
if !isdefined(@__MODULE__, :SUGAR_FORECAST_RULES)
    # 暫定認知近似。糖の不足をreference Eで正規化し候補費用にする。
    # 脂肪動員を予測しない保守的な食事期限であり、生存限界ではない。
    const SUGAR_FORECAST_RULES=(cost_gain=2.,)
end
# Guards support the existing component-level include entrypoints.
if !isdefined(@__MODULE__, :TASK_WAIT_RULES)
    # Seconds: mirrors the existing social observe packet visibility window.
    # This does not extend message lifetime or grant access to an unseen reply.
    const TASK_WAIT_RULES=(message_seconds=3.,)
end
if !isdefined(@__MODULE__, :FATIGUE_FORECAST_RULES)
    # Initial cognitive calibration, not a physical stop threshold. Seconds and
    # dimensionless strain: onset starts a smooth cost; completion discounts by delay.
    const FATIGUE_FORECAST_RULES=(onset=.8,scale=.2,delay_seconds=64.,unknown_seconds=128.,
        continue_prior=2.,risk_gain=8.,record_limit=64)
end
if !isdefined(@__MODULE__, :HUNGER_FORECAST_RULES)
    # Cognition calibration: reserve points, seconds, dimensionless response.
    # Smooth onset at 80; a 20-point deficit gives unit pressure. Not physiology.
    const HUNGER_FORECAST_RULES=(onset=80.,scale=20.,power=2.,delay_scale=64.,review_us=64_000_000)
end
if !isdefined(@__MODULE__, :AID_RESOURCE_RULES)
    # Owner-side initial hypotheses, not the peer's private need or intent.
    const AID_RESOURCE_RULES=(store_access_weight=.75, unknown_availability=.5,
        faded_weight=.5, distress_retention=2., reply_window_us=5_000_000)
end
if !isdefined(@__MODULE__, :ACQUISITION_TRIAL_RULES)
    # Bounded diagnostic terminal trials/actor, not a behavioral stopping limit.
    const ACQUISITION_TRIAL_RULES=(history_limit=64,)
end
if !isdefined(@__MODULE__, :TASK_ATTENTION)
    const TASK_ATTENTION=(review_us=64_000_000,reserve_change=2,motion_range=8.,motion_speed=.05)
    # Range: world distance; speed: distance/tick; reserve_change: reserve points.
    # Shared provisional calibration, not individual learning or endocrine dynamics.
    const FOOD_SECURITY_RULES=(anxiety_gain=4,anxiety_band=.25,anxiety_power=2,
        reserve_floor=70.,request_reserve_floor=70,raw_residual_band=.1,request_interval_us=64_000_000,
        forecast_interval_us=64_000_000,self_reliance_weight=4)
end
if !isdefined(@__MODULE__, :SEARCH_PLACE_RULES)
    # Provisional observation-strength priors, not world stock or a blacklist.
    # Fine scan is one evidence unit; passing/coarse/incomplete views count less.
    const SEARCH_PLACE_RULES=(prior=.5,partial=.25,coarse=.25,normal=.5,pass=.02,confirmed_empty=1.)
end
