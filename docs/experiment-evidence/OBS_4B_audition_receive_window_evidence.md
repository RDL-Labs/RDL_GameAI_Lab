# OBS-4B/4C Audition Receive Window Evidence

## Real Luanti Vertical

```powershell
./integrations/luanti/scripts/test-audition-observation.ps1 -LuantiRoot D:\luanti
```

Observed on 2026-09-26:

```text
OBS4C PASS: frames=6 cross_window_split=true duplicate_close_idempotent=true late_rejected=true detection_limit_partial=true
```

The fixture emitted two events during `[0, 250000)`, plus one event spanning
`[245000, 255000)`, removed the source node,
rotated both agent states, and then closed the first window. Agent A retained
one mixed weak/mid detection with `npc_a:ear-pose:before-turn` and receive
interval ending exactly at `250000`; B remained below threshold. The remaining
5000-us fragment began the second window, with energy split by overlap.

The second window began with an event at exactly `250000 us` and received 33
events. The first 32 receipts were processed, while overflow made both frames
partial/output-limited. A retained one detection using its `after-turn` pose;
B remained below threshold. Duplicate close did not add a frame, and a later
event timestamped inside the closed first window was rejected for both agents.

A third window formed nine qualifying cells for A. It published eight and
recorded `PARTIAL / output_limited`; B's lower gain left all cells below
threshold and correctly remained complete. All six frozen frames were delivered
at `1000000 us` without re-evaluating source existence or current yaw.

This is still a finite scheduled fixture. It does not provide a general World
sound bus, propagation delay, resend queue, continuous sound segmentation, or
sound-driven behavior.

Regression after the supplement:

- full Python suite: `325` tests passed, `46` intentionally skipped
- real Luanti RW2 multi-agent life: PASS
- real Luanti OBS-3 distant observation: PASS

