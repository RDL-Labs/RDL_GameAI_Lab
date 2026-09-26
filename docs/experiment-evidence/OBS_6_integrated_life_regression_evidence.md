# OBS-6 Integrated Life Regression Evidence

## Real Luanti Vertical

```powershell
./integrations/luanti/scripts/test-observation-integration.ps1 -LuantiRoot D:\luanti
```

Observed on 2026-09-26:

```text
OBS6 SENSORY: agents=2 channels=3 rejection_recovered=1 transport_retry=1 response_loss_retry=1 duplicate_new_frames=0 ack_only_removal=true life_compatible=true
OBS6 LIFE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:2,B:1
```

The same World run produced separate `vision_local`, `vision_distant`, and
`audition` histories for both agents. Each agent retained at least one finite
distant feature and one action-sound detection. Local every-tick samples and
distant four-tick samples included nonmatching capture times. Every stored
frame matched its delivery agent. One intentionally mismatched delivery tick
was rejected and recovered; no capture end advanced beyond its sampled World
tick boundary.

The ordinary sensory-disabled RW2 harness was rerun afterward:

```text
MULTI LIFE PASS: agents=2 pickups=2 deposits=2 results=2 radius_counts=A:2,B:1
```

Therefore the integrated SensorFrames preserved completion of the existing
finite Food acceptance and accepted results. The harness does not compare full
action sequences, so it does not establish exact decision equality. This
evidence does not establish sensory fusion,
meaning attribution, sound-driven orientation, long-running retention, or
sensor-informed action.

The integrated run and standalone fixtures now call the same reusable kernels:

- `distant_sensor.lua` verifies World-node identity, observer-relative field of
  view, voxel coverage, occlusion through the target boundary, and the four-
  feature limit.
- `audition_window_sensor.lua` owns event-time receipt data, cross-window
  splitting, per-window buffering, idempotent close, late rejection, mixing,
  and the eight-detection limit.
- `audition_transmission.lua` applies the same voxel coverage and wall
  attenuation before both standalone and integrated reception.

OBS-6C additionally forced `npc_b` to skip sensory attachment for two ticks.
The later delivery retained exactly one audition frame sampled at tick 1 with
capture window `[0, 250000)`, while no local-vision frame existed for that
skipped delivery tick. The in-World probe also recorded:

```text
world_probe=PASS visible=1 hidden=0 absent=0 wall_preserved=true sound=1.0/0.5
```

This verifies one-time fixture initialization, integrated wall occlusion,
target disappearance, shared wall attenuation, and delayed delivery without
capture-time replacement.

OBS-6D extends the delay to four ticks. Every emitted batch is checked as at
most four frames; `npc_b` resumes with a four-frame batch while additional
frames remain queued. The Runtime now returns a `sensory_receipt` beside the
unchanged action response. One deliberately mismatched delivery tick produces
an isolated sensory rejection while the action path continues; the same queued
frames are accepted on a later observation. A separate pre-send transport
failure releases in-flight state without removing its queued frames. The final
snapshot contains both agents and all three channels, with one expected and
recovered rejection rather than an unexplained zero-rejection claim.

OBS-6E ran on 2026-09-26 with real Luanti and Runtime. After the OBS-6D
rejection and pre-send failure, the Luanti HTTP callback observed an accepted
receipt for four new frames, then discarded the entire response before ack or
action resolution. This is callback-level response-loss injection, not a real
network disconnection. The next observation selected exactly the lost batch,
leaving newly sampled frames queued separately.

Run log: `integrations/luanti/output/luanti-multi-20260926-085946-721.log`
(local generated artifact). All four IDs share `fixture-run-1:1:npc_a:`:

- `ears:audition:1`
- `eye:vision_local:2`
- `ears:audition:2`
- `eye:vision_local:3`

| Probe phase | accepted | new_frames | pending count | lost IDs still pending | in-flight |
| --- | --- | --- | --- | --- | --- |
| response_lost | true | 4 | 7 | all four | false |
| before_ack | true | 0 | 10 | all four | true |
| after_ack | true | 0 | 6 | none | false |

The harness compares the ordered IDs across all three phases, checks each ID
occurs exactly once in the Runtime snapshot, and verifies that ack removes only
those IDs while preserving every unrelated pending frame. Both agents still
complete the finite Food life acceptance; the lost action response is not
replayed.

Regression after OBS-6E:

- full Python suite: `328` tests run successfully (`282` passed, `46` intentionally skipped)
- real Luanti OBS-3 distant observation: PASS
- real Luanti OBS-4C audition window boundaries: PASS

