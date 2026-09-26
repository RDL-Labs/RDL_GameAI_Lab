# Luanti L9 p5 Read-Only Trace Evidence

## Commands

```powershell
node --check gui-p5/api.js
node --check gui-p5/views/lineage_view.js
node --check gui-p5/views/inspector_view.js
python -m unittest -v tests.test_gui_p5_server
python -m unittest discover -s tests
```

## Visual Verification

The local p5 server was opened in the in-app browser in both Fixture and Live
Runtime modes. Fixture rendering remained intact. A finite local Runtime was
seeded with three Luanti fact-event outcomes and one explicit Sleep result for
each of `npc_a` and `npc_b`.

The Live lineage showed, per selected agent:

```text
3 Experiences
9 Local Bias records / 3 relation kinds
CANDIDATE_FORMED
support 3 candidate
T1 materials NONE
active M_B NOT PRESENT
```

Pressing `1` and `2` changed the displayed agent and source IDs independently.
The absent T1 and model stages remained absent. Live playback controls stayed
disabled and the World panel reported that spatial state was not exposed.

## Agent-Scoped Canonical Regression

A second visual pass advanced both A and B through explicit review, T1,
reconstruction, cutover, and `REENTERED`. Switching `1` / `2` changed the
Inspector heading, selected review/H, T1 bundle, active model, archive count,
and Luanti source IDs together. The two active model IDs and source IDs were
distinct. No Inspector field read the process-wide last record as a fallback.
