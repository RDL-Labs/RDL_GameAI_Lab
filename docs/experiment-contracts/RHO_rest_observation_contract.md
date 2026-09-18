# ρ Rest Observation Contract

**Status:** Minimal diagnostic projection operational

**Boundary:** Mock Rest observation only; no RestNeed, sleep behavior, recovery, consolidation, or action authority

## Finite projection

The existing `ObservationResolutionAdapter`, versioned profile selection, and
`observation_resolution.domains` packet sidecar are reused for `rest`:

| Level | Distinctions |
|---|---|
| LOW | `tired / not_tired` |
| MID | `rested / tiring / tired / exhausted` fatigue band |
| HIGH | fatigue band + true bounded trend + reachable rest context + safety distinction + completion margin |

The HIGH trend compares a previous finite band with the current finite band. It
does not infer trend from a generic revision counter. Rest context is derived
only from a visible mock place marked as rest-capable; it does not reveal exact
distance or an unrestricted World reference.

## Separation

`rho-rest-projection-v1` controls observation distinctions only:

```text
rho_rest != RestNeed
rho_rest != sleep pressure
rho_rest != salience
rho_rest != H
sleep behavior != Sleep Consolidation != T1
```

The fixed fatigue source is a diagnostic fixture, not an operational RestNeed.
It does not update over ticks and cannot initiate rest, recovery, history
compression, canonical admission, or any action.

Only explicitly assigned domains enter the sidecar. A Rest-only assignment does
not silently attach the default Food projection.

## Evidence

`rho_rest_projection_check.gd` verifies LOW/MID/HIGH differences, bounded
worsening trend, visible safe rest context, per-agent LOW/HIGH selection,
Rest-only packet attachment, and unchanged World/default life context.

The next Rest slice may introduce an owned RestNeed and world-changing rest
interaction, but only under a separate behavior contract. This observation
contract does not authorize that step.
