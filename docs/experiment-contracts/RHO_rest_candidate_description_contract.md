# ρ Rest Candidate Description Contract

**Status:** Opt-in causal observation-to-selection experiment operational

**Boundary:** ρ changes candidate description only; selector and trajectory rules remain fixed

## Three-stage path

```text
rho_rest
→ RestCandidateDescriptionAdapter
→ bounded candidate descriptions

RestTargetSelectionPolicy
→ chosen target

RestTrajectoryPolicy
→ fixed-target persistence
```

`rho-rest-candidate-description-v1` consumes the already bounded visible Rest
places plus the versioned Rest projection sidecar. It validates packet,
selection-profile, and projection-rule provenance before producing candidates.

| ρ level | Candidate description |
|---|---|
| LOW | all rest-capable candidates are `unknown / near` |
| MID | actual finite distance band, safety remains `unknown` |
| HIGH | actual finite distance band and bounded safety distinction |

The adapter has no selection, trajectory, action, RestNeed, or canonical
authority. Missing or unsupported provenance fails closed.

## Controlled result

The integration fixture contains the same two visible Rest candidates:

```text
plaza    = safe / near
z_grove  = uncertain / near
```

The selector remains exactly `rest-target-selection-v1`:

```text
LOW  → both become unknown / near → deterministic tie selects z_grove
HIGH → safety distinction remains → safe plaza is selected
```

This is finite evidence for:

```text
rho_rest → candidate distinction → fixed selector → chosen target
```

It does not establish that HIGH is smarter, better, or always safer. Different
world fixtures or selection rules may produce no action difference.

## Activation

The experiment is double opt-in:

```text
python -m runtime.bridge --rest-trajectory --rest-rho-candidates
```

Godot must also explicitly attach a Rest ρ profile. The default Rest trajectory
continues to use the ordinary bounded candidate fields and does not read the ρ
sidecar.

## Evidence

- Adapter tests verify LOW masking, MID distance-only detail, HIGH safety detail,
  provenance rejection, and no selection authority.
- Policy tests hold selector and World candidates constant while LOW/HIGH choose
  different targets.
- `rest_rho_selection_http_check.gd` verifies live Godot packets and Runtime
  decisions: `LOW → z_grove`, `HIGH → plaza`.

Learning, dynamic ρ, salience, Threat/Novelty, candidate safety updates after
commitment, and Food/Rest Need arbitration remain deferred.
