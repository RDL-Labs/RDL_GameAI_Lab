# Finite History Influence: Approach Retry Window

Enable explicitly with `python -m runtime.bridge --history-influence`.
Without this flag the existing first-visible-food policy is unchanged.
In Godot select Runtime mode. The existing Decision Record shows the reason;
the response also includes `inspection.history_influence` with source record
IDs, deferred targets, retry ticks, policy version, and whether action changed.

## Finite Rule

For the same agent and perception-rule context, inspect each currently visible
food target's latest completed approach result at or before the current tick.
Ties at the same tick use result admission order. A record from the current
source observation is excluded. An `approach_no_progress` result defers that
target while `0 <= current_tick - result_tick < 3`. Select the first remaining
visible food in observation order, or idle if none remains. A newer progress
result removes that deferral. At exactly result_tick+3 retry becomes possible.

Three ticks is the default GameAI-local experimental parameter, not a Core constant.
The [fixed sensitivity profiles](SENSITIVITY_retry_profile_contract.md) now allow
per-agent 1/3/5 tick windows via `--retry-profile`, using policy version v2.
In the formulas above, substitute the configured duration for 3.
No-progress includes already reaching the target; it does not establish danger,
dislike, failed survival, or unresolved E. The hypothesis is simply that repeating
an approach with no displacement can briefly be deferred. This policy is not
appropriate for every task and is therefore opt-in.

## Authority and Reproducibility

Experience remains the owner of finite event history. This policy reads a
snapshot and owns only the local action decision. It does not mutate records,
canonical M_B, interpretation coefficients, review results, H, or theta.
It never introduces a target absent from the current bounded observation.
Changing physical actions can naturally change subsequent observations; the
policy does not promise identical future E across different world trajectories.

Every experimental decision, including idle, is frozen under agent/observation
ID with the original packet. Exact replay returns the same response even after
history changes. Conflicting packet reuse is rejected. The cache admits at most
128 distinct decisions per process, then rejects further experimental observes
with HTTP 422. Restart establishes a fresh experiment; there is no eviction or
cross-run namespace. This limit is separate from history's approach-admission
limit. New observations, not replayed IDs, are required to test changed history.

## Evidence

Controlled tests hold the current packet fixed and vary history only:
no history or prior progress -> approach; recent no-progress -> idle.
Further tests cover visible alternatives, hidden-target exclusion, retry timing,
future-history exclusion, agent/context isolation, latest-progress replacement,
immutable replay, and capacity. Body and sensitivity models are absent in this
slice, so no such parameter changes are introduced by the comparison.

Actual Godot headless Workbench + Python HTTP checks confirm:
- default policy: 3 progress and 9 no-progress reports over 12 decisions;
- enabled policy: 3 progress and 1 no-progress report, then history-backed idle.

This establishes a bounded history-to-action effect. Canonical history-dependent
F formation, social positive/negative histories, learned sensitivity, affect,
and M_B reconstruction remain deferred.
