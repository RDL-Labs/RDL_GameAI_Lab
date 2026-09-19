# Rescue Staged Recovery Contract

**Status:** Phase 5E finite recovery slice  
**Owner:** Godot World / BodyState

## Operational path

```text
safe-place delivery
-> stabilizing: severe / incapacitated / movement 0.0
-> mobilizing: medium / mobile / movement 0.35
-> recovering: light / mobile / movement 0.7
-> recovered: none / mobile / movement 1.0
```

Delivery starts a finite four-tick fixture. Progress occurs only while the
delivered agent remains within reach of the recorded safe place. Godot owns
the clock, injury state, incapacitation, and movement capability. Runtime sees
only the later bounded body snapshots.

These stages and tick counts are experimental vocabulary, not a biological,
medical, treatment, or survival model. Delivery is still distinct from
recovery completion.

## Safety trajectory boundary

A recovered body snapshot does not blindly resume the Safety trajectory that
preceded incapacitation. The opt-in Safety policy releases that commitment and
re-evaluates current bounded relations. With no current exposure it returns
`RELEASED_AFTER_RECOVERY`; with current exposure it may form a fresh Safety
trajectory from current candidates.

## Acceptance

1. Delivery initially leaves the target severe and incapacitated.
2. Four safe-place ticks produce the declared ordered stages.
3. Injury, incapacitation, and movement capability agree with each stage.
4. Recovery pauses away from the recorded safe place.
5. Old Safety commitment is released rather than resumed blindly.
6. Food, Rest, canonical sidecar, H, T1, death, permanent injury, treatment,
   and social Experience remain outside this slice.
