"""Process-fixed LW time profile. Select before importing the runtime."""
import os
PROFILE=os.environ.get('RDL_LW_TIME_PROFILE','legacy')
if PROFILE not in ('legacy','human_scale_v1'):raise ValueError('lw_time_profile')
SCALED=PROFILE=='human_scale_v1'
DAY_US=17_280_000_000 if SCALED else 64_000_000
BOUNDARIES=(60_000_000,8_640_000_000,11_520_000_000,DAY_US) if SCALED else (1_000_000,32_000_000,56_000_000,DAY_US)
QUIET_NIGHT_US=14_400_000_000 if SCALED else 60_000_000
SLEEP_REST_US=2_880_000_000 if SCALED else 1_000_000
RESERVE_SCALE=64_000_000/DAY_US
STRAIN_SCALE=1/60 if SCALED else 1.

def metadata():
    return dict(profile=PROFILE,day_us=DAY_US,phase_boundaries_us=list(BOUNDARIES),quiet_night_us=QUIET_NIGHT_US,
        sleep_rest_us=SLEEP_REST_US,real_m_per_world_m=10 if SCALED else None,
        real_seconds_per_world_second=5 if SCALED else None,reserve_rate_scale=RESERVE_SCALE,
        strain_rate_scale=STRAIN_SCALE,authority='simulation calibration, not human physiology')
