# OBS-0 to OBS-2 Reference Evidence

## Commands

```powershell
python -m unittest discover -s tests
& .\integrations\luanti\scripts\test-multi-agent.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-local-sensor-profiles.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-invalid-sensor-profile.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l0-l2.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l3.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-l7.ps1 -LuantiRoot D:\luanti
```

## Real Luanti Results

Verified with Luanti 5.17.0 on 2026-09-26.

```text
MULTI LIFE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:2,B:1
LOCAL SENSOR PROFILE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:3,B:1
INVALID SENSOR PROFILE PASS: unknown-profile rejected
```

The default run preserved RW2. In the intervention run, the additional probe
was 10 units from both agents at the final observation. A used radius 12 and
included it; B used radius 8 and excluded it. The pre-existing boundary marker
remained included for A, and the outside marker remained excluded.

Runtime tests cover extension removal before legacy consumers, unchanged
decisions, strict identity/profile/time/allowlist validation, idempotent replay,
conflicting replay, atomic capacity rejection, agent/channel snapshots, and the
read-only GET endpoint.

The invalid-profile fixture verifies that Luanti startup rejects an unregistered
assignment instead of silently falling back to radius 12.

The repository suite passed with 317 tests and 46 intentional skips. Existing
real-Luanti L0-L2, L3, and L7 verticals passed after the observation boundary
and local profile registry were added.

## Implementation Notes

The implementation started from plan baseline `a19fc28`; the only intervening
commit, `ee58368`, registered the plan and changed no runtime behavior. OBS-1
uses `runtime/sensory_observation.py` and remains disabled unless the Runtime is
started with `--sensory-observation`. OBS-2 changes the RW2 radius lookup from a
literal to the startup-validated Luanti profile assignment. No distant or
auditory frame producer exists yet.

OBS-3 distant vision, OBS-4 audition, OBS-5 p5 display, and OBS-6 integration
remain unimplemented.
