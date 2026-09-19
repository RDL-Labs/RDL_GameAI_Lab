# Multi-Agent Rescue Reference Evidence

**Recorded:** 2026-09-19  
**Boundary:** Godot 4.7.2 mock world + opt-in localhost Rescue Runtime  
**Result:** Phase 5F reference vertical established

## Proven chain

One Godot world and one Runtime process update NPC A and NPC B independently.

```text
NPC B fails three flee resolutions
-> severe / incapacitated
-> NPC A discovers B inside bounded observation
-> A commits B once
-> approach -> rescue -> carry -> deliver to Plaza
-> B becomes bounded recovering, not a new Rescue candidate
-> safe-place ticks advance stabilizing / mobilizing / recovering / recovered
-> A and B both return idle decisions from their own bounded packets
```

The evidence specifically proves that delivery does not create a duplicate
Rescue loop while the target remains physically incapacitated during
stabilization. The observer receives `condition = recovering`; only an
unrescued target receives `condition = incapacitated` and Rescue eligibility.

## Executable evidence

```text
$env:GODOT_BIN='D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
python -m unittest tests.test_experience_godot.GodotExperienceTests.test_multi_agent_rescue_evidence_reaches_recovery_without_duplicate_rescue
```

## Boundary

This is a finite two-agent evidence path, not general cooperation. It does not
add search for missing agents, treatment choice, social Experience, gratitude,
death, permanent injury, failsafe warp, canonical M_B admission, H, or T1.
