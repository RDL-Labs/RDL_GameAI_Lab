# OBS-4 Audition Observation Evidence

## Real Luanti Vertical

Command:

```powershell
./integrations/luanti/scripts/test-audition-observation.ps1 -LuantiRoot D:\luanti
```

Observed on 2026-09-26:

```text
OBS4 PASS: frames=4 A_detections=1 B_detections=0 mixed_sources=2 wall_attenuated=true overflow_partial=true
```

The same two brief mid-band World events were evaluated for two agents. Both
paths crossed one opaque fixture wall. Agent A used gain `1` and received one
mixed `weak/mid` detection. Agent B used gain `0.25` and remained below the
detection threshold. No shared World event ID was emitted to either agent.

A second 250 ms window admitted 32 of 33 finite probe events. Each agent stored
an empty frame with `coverage = PARTIAL` and `output_limited = true`, preserving
the distinction between overflow and verified silence.

The stored frames were checked for absence of source IDs, World positions,
exact distance, and semantic names. Runtime rejected no valid frame.

## Limits

This is a headless structured sound-event fixture. It is not waveform capture,
speech recognition, realistic acoustics, reflection, diffraction, delay,
source separation, or sound-driven behavior. It does not run concurrently with
RW2 life and does not perform visual-auditory identity fusion.

## Regression

- full Python suite: `325` tests passed, `46` intentionally skipped
- real Luanti RW2 multi-agent life: PASS
- real Luanti OBS-3 distant observation: PASS
- real Luanti L7 Dynamic `M_B` cycle: PASS

