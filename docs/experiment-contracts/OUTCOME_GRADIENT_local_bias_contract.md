# Outcome Gradient / Local Bias Contract

## Purpose

Form finite GameAI-local relation traces from Risky Tasty Food outcomes without
creating separate success/failure learners or a global reward scalar.

## Path

```text
agent-owned Territory Experience
+ explicit physical outcome facts
-> relation-specific OutcomeGradient
-> one LocalBias per non-zero relation dimension
```

V1 dimensions are `acquisition`, `return`, `injury`, and `reward_value`.
Physical facts use booleans and finite bands; the World does not report success,
failure, good, or bad.

## Formation

```text
magnitude 0 -> ZERO, no LocalBias
magnitude 1 -> WEAK
magnitude 2 -> MEDIUM
magnitude 3 -> STRONG
```

Direction and magnitude remain dimension-local. Positive reward and negative
injury may coexist for the same Experience. No subtraction or `net_score` is
performed.

## Authority Boundary

```text
OutcomeGradient != E
LocalBias != H / theta_eff / rho / M_B / CandidateRelation
LocalBias relation != action command
strong bias != automatic T1 RETAIN
```

The Sleep projection is material-only. It filters by agent and does not produce
a Profile, CandidateRelation, review, or canonical mutation.

## Finite Store

Both stores have bounded capacity, deterministic replay, explicit rejection at
capacity, process-lifetime retention, and no silent eviction.

## Acceptance

1. Strong success forms strong positive acquisition, return, and reward biases.
2. Strong failure forms strong negative acquisition and injury biases.
3. Mixed outcomes preserve strong positive and negative relations together.
4. Gradient magnitude monotonically maps to bias strength bands.
5. Every bias retains agent, Experience, World event, context, and rule provenance.
6. Agent A materials never appear in Agent B's Sleep projection.
7. Store replay is deterministic and capacity rejection does not evict records.
8. Canonical sidecar and game action policy remain unchanged.
