# Local Bias Deep Similarity Contract

## Status

OGB-7/8 operational reference.

## Purpose

Compare three to six same-agent Local Bias Sleep Profiles and form at most one
finite shadow CandidateRelation from relations common to every source Profile.

## Processing Boundary

```text
Local Bias Sleep Profiles
-> pairwise Similarity Observations
-> common relation intersection
-> zero or one shadow CandidateRelation
```

Pairwise observations retain matches, differences, and opposing-direction
conflicts. A conflict is reported but never resolved automatically.

The candidate retains common relation signatures without collapsing positive
and negative dimensions into a net score. Repeated positive reward and repeated
negative injury may therefore coexist in one candidate.

## Provenance

The result is agent-scoped and retains:

```text
profile_ids
source_experience_ids
source_bias_ids
source_world_event_ids
sleep_cycle
formation_tick
```

Cross-agent input, duplicate Profile or Experience sources, and windows outside
the finite three-to-six Profile boundary are rejected.

## Authority Boundary

```text
SimilarityObservation != truth
SimilarityObservation != E or H
shadow CandidateRelation != adopted relation
shadow CandidateRelation != T1 selection
shadow CandidateRelation != M_B or M_B'
shadow CandidateRelation != action authority
```

OGB-7 observes finite similarity. OGB-8 forms a local shadow candidate only.
Neither phase admits the result to canonical or behavioral authority.

## Acceptance

1. Three repeated same-agent mixed outcomes form one deterministic candidate.
2. Positive reward and negative injury remain separate common relations.
3. Complete Profile, Experience, Bias, and World event provenance is retained.
4. Opposing directions are recorded as conflicts and excluded from common relations.
5. Cross-agent, duplicate-source, insufficient, and oversized windows are rejected.
6. No E, H, theta, M_delta, T1, M_B, or action output is produced.
