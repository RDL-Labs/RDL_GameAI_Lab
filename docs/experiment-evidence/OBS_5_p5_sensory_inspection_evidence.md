# OBS-5 p5 Sensory Inspection Evidence

## Verification

Verified on 2026-09-26 against the localhost p5 Workbench and a Runtime started
with isolated sensory observation enabled.

The initial empty Runtime displayed three agent-scoped cards with `NO FRAME FOR
SELECTED AGENT`; it did not fabricate an empty sampled frame. The existing
OBS-4C real Luanti fixture was then delivered to the same Runtime. The selected
`npc_a` audition card displayed:

```text
SAMPLED / PARTIAL / OUTPUT LIMITED
seq 3 / tick 3 / capture [500000, 750000) us
pose npc_a:ear-window:3
profile fixture-audition-enabled r1
8 detections
```

The page reported no browser console warnings or errors. Live Run, Step, and
Reset controls remained disabled. No viewer mutation endpoint was added.

Automated verification:

- JavaScript syntax checks: `api.js`, `sketch.js`, `sensory_view.js` PASS
- targeted p5/server and sensory tests: 19 PASS
- agent-scoping, independent-time, output-limit, and GET-only source assertions
  are included in `tests/test_gui_p5_server.py`

This is display evidence only. RW2 life plus distant vision plus audition in one
World run remains OBS-6.

