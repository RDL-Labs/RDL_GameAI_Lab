# Current Core v2.3 Runtime Evidence

This file records the current finite acceptance evidence for the active GameAI runtime path. Superseded phase-specific evidence has been consolidated here and removed from the active working tree.

## Current implemented chain

```text
bounded observation
-> existing Python structured action
-> Godot world resolution
-> changed interaction conditions
-> subsequent bounded observation
-> canonical RIB_B acquisition
-> frozen diagnostic M_B
-> F / F'
-> E
```

## Runtime surfaces

- `runtime/core.py` — existing observation-to-action policy
- `runtime/bridge.py` — localhost bridge; canonical sidecar runs only after accepted decisions
- `runtime/v23_acquisition.py` — finite B / coverage / provenance / RIB_B acquisition
- `runtime/v23_interpretation.py` — frozen M_B / F / F' / E
- `godot/rdl-game-ai-workbench/scripts/mock_state_provider.gd` — actual mock-world action resolution and subsequent observation generation
- `godot/rdl-game-ai-workbench/tests/current_interaction_loop_check.gd` — current Godot changed-condition acceptance check

## Current tests

Python CI runs:

```text
python -m unittest discover -s tests -v
```

The test surface includes:

- bounded observation action behavior;
- RIB_B acquisition from accepted observation packets;
- missing selected coverage rejection;
- immutable B conditions / RIB_B values / provenance;
- acquisition non-intervention on action decisions;
- frozen M_B mapping immutability;
- same pre-update M_B requirement for F/F';
- distinct observation-instance requirement;
- duplicate observation replay does not manufacture a comparison;
- finite boundary-condition drift rejection;
- no cross-context E formation;
- sidecar action-decision non-intervention;
- E remains `E-only-not-reviewed` and does not contain H.

## Godot interaction evidence

`MockStateProvider.resolve_action()` applies `approach(target_id)` to the world-side selected-agent position, then creates a subsequent bounded observation after the world change. Source and subsequent observations use distinct observation instance ids even when they occur inside the same tick.

```text
source observation
-> action
-> world change
-> subsequent observation
```

The canonical sidecar does not read the complete engine state as agent input.

## Finite acceptance statement

Current acceptance establishes only that, inside the declared mock-workbench and Python runtime boundary:

```text
Observation != RIB_B
same frozen pre-update M_B forms F / F'
F/F' use distinct observation instances
E = Delta(F,F')
```

It does not establish:

```text
nonzero E = unresolved
E = H
H = affect
engine state = world truth
identity diagnostic M_B = universal GameAI model
passing tests = RDL theory proven
```

## Finite assessment evidence

The assessment tests now demonstrate an explicit finite assessment layer that distinguishes:

```text
zero
pending
resolved
ordinary temporal change
boundary / coverage change
unresolved
```

Only reviewed unresolved dimensions enter single-comparison diagnostic H. `tests/test_v23_assessment.py` verifies pending H=0, L2 residual (3,4) giving H=5, partial resolution, all non-residual classifications, atomic invalid-review rejection, provenance requirements, context isolation, capacity retention, replay handling, and a real localhost observe/review/snapshot roundtrip with unchanged action responses.

Verification: `python -m unittest discover -s tests -v` passed 25 tests. This is fixture-based finite evidence, not validation of an autonomous unresolved classifier. Godot scene/UI was not modified or visually revalidated in this change. Temporal H accumulation, θ, reconstruction, and persistent review history remain unevaluated.
