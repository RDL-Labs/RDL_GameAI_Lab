# Luanti L5 Outcome Learning Contract

## Status

L5 operational local-learning reference on Luanti 5.17.0.

## Purpose

Connect one accepted Luanti physical consequence to the existing finite
Experience, Outcome Gradient, and Local Bias stores.

```text
Luanti attack fact
+ explicit physical outcome facts
-> TerritoryExperienceStore
-> OutcomeGradientStore
-> LocalBiasStore
```

L5 adds an explicit opt-in adapter and no new learning rule.

## Input Boundary

Luanti reports the frozen `territory-beast-fact-event-v1` event with:

```text
agent / beast / territory
warning-chase-attack provenance
medium injury
forced retreat
tasty Food interaction context
```

The companion outcome facts are finite and physical:

```text
food_acquired = false
returned_to_base = false
injury_level = medium
reward_value = ZERO
```

Interpretive `danger`, `dangerous`, and `threat_score` labels remain rejected.

## Result

The existing relation-local rule produces:

```text
acquisition -> negative STRONG
return      -> negative MEDIUM
injury      -> negative MEDIUM
reward      -> ZERO, no Local Bias
```

No positive and negative dimensions are subtracted into a net score.

## Runtime Surface

L5 is enabled with:

```powershell
python -m runtime.bridge --base-food-life --luanti-outcome-learning
```

The L5 Luanti config separately enables `rdl_outcome_learning = true`; L4 keeps
it disabled. Luanti submits the attack result once to
`POST /v1/luanti-territory-result`.
`GET /v1/luanti-outcome-snapshot` exposes a read-only inspection snapshot.

## Separation

```text
Luanti World event != Experience until explicit admission
Experience != Outcome Gradient
Outcome Gradient != E
Local Bias != H / theta_eff / rho / M_B / CandidateRelation
Local Bias != Goal / Trajectory / action
L5 learning result != canonical authority
```

Exact replay is deterministic and does not duplicate records.

## Acceptance

1. Real Luanti attack produces one direct-participant Experience.
2. The Experience retains World event and tasty Food context provenance.
3. Existing Outcome Gradient rules produce finite relation dimensions.
4. Existing Local Bias rules produce exactly three non-zero failure biases.
5. Replay does not duplicate Experience, Gradient, or Bias records.
6. Interpretive danger labels are rejected.
7. Existing action and canonical results remain unchanged.
