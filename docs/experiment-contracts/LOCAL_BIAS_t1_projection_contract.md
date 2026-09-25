# Local Bias T1 Candidate Projection Contract

## Status

OGB-9 operational reference.

## Purpose

Project one mixed Local Bias shadow candidate into independently inspectable
CandidateRelation materials compatible with the existing T1-A boundary.

```text
one Local Bias shadow candidate
-> one child CandidateRelation per common bias relation
-> optional explicit T1-A expansion
-> UNINSPECTED materials
```

The projection does not combine reward, injury, acquisition, or return into one
score. Each relation receives a stable child identity and can later receive an
independent T1-B disposition.

## Provenance

Every child retains:

```text
source Local Bias candidate ID
agent ID
sleep cycle and formation tick
source Experience IDs
source Bias IDs
source World event IDs
support count
one finite common relation signature
```

The adapter accepts at most 16 unique relations. Empty identity, malformed
signatures, duplicate relations, incomplete provenance, and invalid Deep
support are rejected before projection.

## Authority Boundary

```text
T1-ready != expanded into T1-A
expanded != selected
RETAIN != adopted
projected CandidateRelation != M_B or M_B'
projected CandidateRelation != action authority
```

Projection may be passed to T1-A only by an explicit call associated with an
active same-agent `M_delta`. T1-A then freezes each child as `UNINSPECTED` and
does not infer a disposition.

## Acceptance

1. Mixed positive reward and negative injury become distinct child candidates.
2. Child IDs and output order are deterministic.
3. Complete parent, Experience, Bias, and World event provenance is retained.
4. Explicit T1-A expansion preserves every child as `UNINSPECTED`.
5. Invalid or duplicate source relations are rejected.
6. Projection does not select, adopt, reconstruct, activate, or influence action.
