# Current Core v2.3 Runtime Evidence

This file records the current finite acceptance evidence for the active GameAI runtime path. Older P1/P2/P3 evidence files are superseded by this consolidated record and may be removed from the working tree.

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

## Current tests

Python CI runs:

```text
python -m unittest discover -s tests -v
```

The test surface includes:

- existing bounded observation action behavior;
- RIB_B acquisition from accepted observation packets;
- missing selected coverage rejection;
- acquisition non-intervention on action decisions;
- frozen M_B immutability / exact selected dimension mapping;
- same pre-update M_B requirement for F/F';
- finite boundary-condition drift rejection;
- no cross-context E formation;
- sidecar action-decision non-intervention;
- E remains `E-only-not-reviewed` and does not contain H.

## Godot interaction evidence retained in current implementation

`MockStateProvider.resolve_action()` applies `approach(target_id)` to the world-side selected-agent position, then creates a subsequent bounded observation after the world change. Source and subsequent observations use distinct observation instance ids even when they occur inside the same tick.

This establishes the actual changed-condition chain needed before canonical comparison:

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

## Next evidence boundary

The next evidence must demonstrate an explicit finite assessment layer that distinguishes at least:

```text
zero
pending
resolved
ordinary temporal change
boundary / coverage change
unresolved
```

Only reviewed unresolved dimensions may later enter H.
