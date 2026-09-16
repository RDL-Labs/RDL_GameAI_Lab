# Current Core v2.3 Runtime Evidence

## Optional history influence

With `GODOT_BIN` configured, the current suite passes 46 tests. The real
Workbench/HTTP experiment passes both default and opt-in policy cases. Default:
3 progress + 9 no-progress reports. Opt-in: 3 progress + 1 no-progress, then idle
with a history source trace. Six additional controlled policy tests cover
same-packet/different-history actions, retry boundary, visible alternatives,
agent/context isolation, latest progress, and frozen replay/capacity.
This establishes local action influence, not canonical M_B learning or affect.
Earlier read-only evidence below remains valid for default mode.

## Experience read-only slice

With `GODOT_BIN` configured, the complete suite now passes 39 tests, including seven Experience unit/HTTP tests and one real Workbench HTTP test
covering result correlation, separate progress/no-progress histories, replay and
conflict handling, finite capacity, agent/context isolation, and HTTP snapshot
acceptance without changes to action or canonical state. Godot 4.7.2 headless
main-scene startup and `current_interaction_loop_check.gd` pass; the latter also
checks bounded outcome reporting for movement and already-at-target conditions.
Log-directory/certificate-store warnings occur in this test environment, with
no script parse errors. The real Godot-to-HTTP test instantiates the actual
Workbench, selects NPC B, enables Runtime mode, and completes 12 reports:
3 approach-progress and 9 approach-no-progress records, with zero pending
results or capacity rejections. All source IDs are distinct, each later ID
differs from its source, 11 canonical comparisons form, and retained H remains
zero without explicit review. Interactive GUI appearance was not inspected.
History-driven behavior is now tested separately in the optional policy above.

Reproduce on Windows PowerShell (port 8765 must be free; the test does not stop
or reuse an existing service):

```powershell
$env:GODOT_BIN = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
python -m unittest discover -s tests -v
```

Without `GODOT_BIN`, the live test is explicitly skipped. Test-owned HTTP and
Godot processes are shut down after completion.

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

Verification: `python -m unittest discover -s tests -v` passed 31 tests, including explicit unavailable output for retained-H numeric overflow. This is fixture-based finite evidence, not validation of an autonomous unresolved classifier. Godot scene/UI was not modified or visually revalidated in this change. Time decay, θ, reconstruction, and persistent review history remain unevaluated.

Retained-H evidence additionally covers two opposite-signed comparisons retaining magnitudes without cancellation, repeated review replacing a contribution, explicit resolution, retention over later ticks/zero E, frozen-model/context separation, nonadjacent replay exclusion, regressing tick rejection with same-tick distinct instances accepted, capacity preserving prior H, and a fresh process ledger starting empty. The HTTP snapshot test checks retained H as well as single-comparison H.
