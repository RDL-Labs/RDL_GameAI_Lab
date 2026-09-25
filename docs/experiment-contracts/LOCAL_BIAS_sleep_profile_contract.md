# Local Bias Sleep Relation Profile Contract

## Status

OGB-6 operational reference.

## Purpose

Compile agent-owned Local Bias materials into a comparison-ready Sleep Profile
without changing the existing S2 Experience Profile schema and without invoking
Deep Similarity or Candidate formation.

## Structure

One profile groups all non-zero Local Bias relations derived from one source
Experience. Every relation retains:

```text
bias_id
source_gradient_id
source_experience_id
source_world_event_ids
context_signature
relation
direction
strength
magnitude
```

Mixed positive and negative relations remain separate members of the same
Profile. They are not netted or normalized into one score.

## Boundary

```text
LocalBiasRelationProfile != S2 Experience Profile
Profile != SimilarityObservation
Profile != cluster
Profile != CandidateRelation
Profile != T1 material selection
Profile != M_B or action authority
```

The adapter accepts at most 32 same-agent Local Bias materials. Input identity,
strength/magnitude integrity, Experience provenance, and World event provenance
are validated before deterministic profile construction.

## Acceptance

1. Mixed reward-positive and injury-negative biases coexist in one Profile.
2. Complete Bias, Gradient, Experience, World event, and context provenance remains traceable.
3. Cross-agent materials are rejected.
4. Compilation is pure and deterministic.
5. Over-limit input and inconsistent strength/magnitude are rejected.
6. No similarity, candidate, canonical, T1, or action output is produced.
