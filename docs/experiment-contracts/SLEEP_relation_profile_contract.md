# Sleep Relation Constraint Profile Contract

**Status:** S2 operational reference  
**Code level:** I1 Structural Operation + I2 Reusable Function

## Purpose

The pure S2 compiler projects every Experience referenced by a finite Sleep
window into five bounded relation roles:

```text
actor / target / context / action / outcome
```

Each relation has a deterministic identity, finite status, polarity and
strength vocabulary, and exactly one source Experience ID.

## Current vocabulary

- Status: `reported`
- Polarity: `neutral`, `supportive`, `adverse`, `unresolved`
- Strength: `single_report`
- Current source schema: admitted `approach` Experience only

`approach_no_progress` remains `unresolved`; it is not converted into failure,
dislike, negative affect, or World truth.

## Boundary

- Inputs and raw Experience remain unchanged.
- Profile output is a separate derived object.
- No unreported place, emotion, motive, or exact World state is introduced.
- Profile formation creates no similarity observation, cluster, relation
  candidate, commitment, action authority, canonical `M_B`, `H`, or `T1`.
- Rescue and other Experience schemas require explicit future adapters; S2 does
  not silently reinterpret their records as approach Experience.
