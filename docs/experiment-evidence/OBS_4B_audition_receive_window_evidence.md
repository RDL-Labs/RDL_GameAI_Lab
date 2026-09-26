# OBS-4B Audition Receive Window Evidence

## Real Luanti Vertical

```powershell
./integrations/luanti/scripts/test-audition-observation.ps1 -LuantiRoot D:\luanti
```

Observed on 2026-09-26:

```text
OBS4B PASS: frames=4 first_window_mixed=2 boundary_once=true pose_preserved=true delayed=true overflow_partial=true
```

The fixture emitted two events during `[0, 250000)`, removed the source node,
rotated both agent states, and then closed the first window. Agent A retained
one mixed weak/mid detection with `npc_a:ear-pose:before-turn` and receive
interval `[100000, 120000]`; B remained below threshold.

The second window began with an event at exactly `250000 us` and received 33
events. The first 32 receipts were processed, while overflow made both frames
partial/output-limited. A retained one detection using its `after-turn` pose;
B remained below threshold. Both frozen windows were delivered later at
`750000 us` without re-evaluating source existence or current yaw.

This is still a finite scheduled fixture. It does not provide a general World
sound bus, propagation delay, resend queue, continuous sound segmentation, or
sound-driven behavior.

Regression after the supplement:

- full Python suite: `325` tests passed, `46` intentionally skipped
- real Luanti RW2 multi-agent life: PASS
- real Luanti OBS-3 distant observation: PASS

