# Canonical Theta Effective Contract

**Status:** C3 finite diagnostic evaluation operational

## Purpose

C3 evaluates an optional finite `theta_eff` independently from reviewed `H`
and exposes their comparison without entering `M_delta`.

```text
reviewed H
+ independently evaluated theta_eff
-> H < theta_eff  : maintain
-> H >= theta_eff : rupture_boundary_met
```

`rupture_boundary_met` is a diagnostic boundary result. C4, not C3, owns any
transition into `M_delta`.

## Finite evaluator

The reference evaluator uses one declared positive base boundary and zero or
more explicit finite relation adjustments.

```text
theta_eff = base_theta + sum(declared relation deltas)
```

Every adjustment retains `relation_id`, `source`, and `delta`. The complete
evaluation retains evaluator version, theta revision, assessment ID, model
reference, and review revision. Non-finite or non-positive results are rejected
before the evaluator is accepted.

The v1 default is the finite diagnostic fixture `base_theta = 1.0`, with no
relation adjustments. It is not a universal Core constant or biological claim.

## Separation

```text
H != theta_eff
BodyState != theta_eff
SensitivityProfile != theta_eff
Need value != theta_eff
candidate score != theta_eff

rupture_boundary_met != M_delta entered
rupture_boundary_met != T1
rupture_boundary_met != M_B'
```

Pending review is not compared. C3 does not convert raw `E` into `H`, infer
relation adjustments from owner-module values, mutate the C2 Review Path, alter
Runtime decisions, or admit Sleep/Fast candidates.

## p5 projection

p5 reads `canonical_snapshot.theta_effective` through the existing GET-only
canonical endpoint and displays the latest `theta_eff` and comparison result.
It has no evaluator or transition authority.

## Acceptance

1. Pending review produces no H/theta comparison.
2. Reviewed `H` and `theta_eff` retain separate provenance.
3. Equal values satisfy the declared `H >= theta_eff` boundary.
4. The same `H` may produce different results when declared relations move
   `theta_eff`.
5. Evaluation leaves the C2 Review Path unchanged.
6. No `M_delta`, T1, `M_B'`, or action authority is created.
