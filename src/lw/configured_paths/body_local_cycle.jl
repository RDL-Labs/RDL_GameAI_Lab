# 暫定固定: isolated body experiment ONLY; normal LW never includes this file.
# Enable by running experiments/body_macronutrients/run.jl. Default OFF in LW.
# No map/MB observations: a 24-hour clock supplies activity and a prescribed meal.
# Record phase/intensity/meal in timeline. Replace with actual chosen actions and
# ingestion when connecting the body model to LW; do not call this learned behavior.
const CONFIGURED_BODY_CYCLE=(days=10,step_hours=1/12,start_clock_hour=6,
    wake_end=2.0,explore_end=8.0,return_end=10.0,sleep_start=16.0,day_hours=24.0,
    wake_intensity=0.1,explore_intensity=0.65,return_intensity=0.8,home_intensity=0.1,
    meal_energy=90.0,meal_shares=(0.50,0.25,0.25)) # C/P/F energy shares, NOT grams

function configured_body_phase(hour;cycle=CONFIGURED_BODY_CYCLE)
    h=mod(hour,cycle.day_hours)
    h<cycle.wake_end && return (phase="wake",intensity=cycle.wake_intensity,sleeping=false)
    h<cycle.explore_end && return (phase="explore",intensity=cycle.explore_intensity,sleeping=false)
    h<cycle.return_end && return (phase="return",intensity=cycle.return_intensity,sleeping=false)
    h<cycle.sleep_start && return (phase="home",intensity=cycle.home_intensity,sleeping=false)
    (phase="sleep",intensity=0.0,sleeping=true)
end
