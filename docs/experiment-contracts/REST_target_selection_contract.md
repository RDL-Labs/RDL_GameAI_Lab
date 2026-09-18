# Rest Target Selection Contract

**Status:** Finite multi-candidate selection operational

**Boundary:** Candidate comparison only; no trajectory mutation or ρ authority

## Responsibility

`RestTargetSelectionPolicy` compares bounded Rest candidate descriptions once,
when a Rest Goal needs a target. It does not own RestNeed, observation
projection, movement, trajectory persistence, or world resolution.

The version 1 rule is finite:

```text
safe > uncertain > unknown

same safety:
within_reach > near > far

exact tie:
deterministic target ID order
```

Candidates marked `unreachable` are excluded. Unsupported safety or distance
distinctions fail closed.

## Separation from trajectory

The selector returns the chosen target plus all compared finite candidate
descriptions and rule provenance. `RestTrajectoryPolicy` stores that result and
does not call selection again while the target remains structurally available.

Consequently, a later observation may make another candidate nearer or safer
without changing the committed target. Reselection requires release and a new
Goal formation boundary.

Release occurs when the fixed target:

- disappears from the bounded candidate set;
- is no longer rest-capable; or
- is marked structurally `unreachable`.

## Separation from ρ

The selector itself consumes only bounded `rest_safety` and
`rest_distance_band` fields. It never inspects `observation_resolution`, ρ
profile IDs, or ρ levels. An independent
[ρ candidate-description adapter](RHO_rest_candidate_description_contract.md)
may now produce those same fields before selection in a double-opt-in experiment.

```text
rho_rest → candidate distinction          # later experiment
selection rule → chosen target             # this contract
trajectory → persistence                   # separate contract
```

The current World exposes Plaza as `safe` and `z_grove` as `uncertain`; both are in
the same coarse `near` band for the integration fixture. The selector chooses
Plaza, after which the trajectory remains fixed through interruption and
candidate-rank changes.

## Deferred

Learned safety, dynamic ρ, exact-distance optimization, dynamic pathfinding,
Threat/Novelty response, and Food/Rest Need arbitration remain outside this
contract.
