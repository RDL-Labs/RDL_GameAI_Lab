# Continuous Life Reference Evidence

**Recorded:** 2026-09-19  
**Boundary:** Godot 4.7.2 mock world + opt-in localhost Python Runtime  
**Result:** Phase F reference vertical established

## Proven chain

One NPC, one Runtime process, and one Godot world execute three Food cycles.

1. Assisted cycle 1 picks up Food, encounters a newly activated danger zone,
   suspends Food, commits East Shelter, completes Safety, re-evaluates the
   retained Food trajectory, travels back to the distinct Plaza/Base, deposits,
   and admits one causally bound success.
2. Assisted cycle 2 completes normally and admits a second real success.
3. The God Statue cue is disabled. Low observed Base stock and the two retained
   successes form a new Goal through `learned_low_stock_relation`; cycle 3 then
   reaches pickup and deposit without seeded history.

The first cycle proves that resume is not caused by Shelter and Base sharing a
location. The third proves that an interrupted but completed life result can
participate in later finite recurrence.

## Executable evidence

```text
$env:GODOT_BIN='D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
python -m unittest tests.test_experience_godot.GodotExperienceTests.test_continuous_life_interrupt_experience_and_autonomy
```

The normal CLI path is independently exercised with
`python -m runtime.bridge --food-safety-life` and the same distinct-Shelter
Godot fixture.

## Boundary

This evidence establishes one named Food/Safety coordination path. It does not
introduce general Need arbitration, Rest integration, dynamic rho, Energy
costs, injury, rescue, canonical M_B admission, H, or T1 authority.
