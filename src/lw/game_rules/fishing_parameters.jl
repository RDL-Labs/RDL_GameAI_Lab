# Deliberate game calibration. Attempt length is worked ticks, not wall seconds.
const GAME_FISHING_TICKS=180
const GAME_FISHING_PRIOR_TRIALS=8.0
const GAME_FISHING_RECENT_TRIALS=32
const FISHING_RULES=(base_probability=0.25,skill_probability_gain=0.20,
    skill_saturation=3.0,river_skill_saturation=3.,river_skill_gain=.8,
    minimum_forecast_probability=0.01)
const GAME_SALT_SAMPLE_SALINITY=1.0 # sensory scalar; no energy/reward
