# OBS-4 Audition Observation Contract

## Status

OBS-4 operational reference for the finite Luanti fixture.

## Authority Boundary

Audition is an opt-in observation channel. World sound events are owned by the
World fixture; per-agent detections are owned by the sensory adapter. Neither
event nor detection becomes Experience, belief, danger, salience, Goal,
Trajectory, canonical input, or action authority.

The Runtime receives no sound source ID, World coordinate, exact distance,
asset name, action name, spoken text, or semantic label such as footstep,
beast, ally, or danger.

## Finite Model

The reference uses `direct_band_energy_v0`:

```text
received = emitted * 1 / (1 + (distance / 4)^2) * path_transmission
perceived = profile_gain * received
```

An opaque fixture wall applies `0.5` transmission once per crossed voxel. Two
brief mid-band events in the same receiver cell are summed before profile gain
and thresholding. The initial threshold is `0.05`; the noise floor is `0.01`
with a ratio of `2`. Values are dimensionless fixture energy, not dB or a
biological hearing model.

Each detection exposes only a frame-local ID, received interval, acquisition
pose reference, observer-local azimuth interval, coarse elevation, strength,
dominant band, and temporal form. A frame holds at most eight detections.

## Missingness And Budgets

The short-term receiver buffer accepts at most 32 World events per window.
Overflow marks the resulting frame `PARTIAL` and `output_limited = true`; an
empty partial frame is not equivalent to verified silence. Unsupported or
unavailable path voxels likewise produce partial coverage rather than assumed
full transmission or full blockage.

The common Runtime schema also accepts an explicit `UNAVAILABLE` frame with an
empty payload. OBS-4 does not add resend scheduling or long-term audio memory.

## Acceptance

1. Two same-cell events produce one detection, not two source identities.
2. One wall voxel weakens the normal-gain result to `weak`.
3. The low-gain profile remains below threshold in the same World condition.
4. A 33-event probe records overflow as empty `PARTIAL/output_limited`, not
   silence.
5. Exact source facts and semantic sound names do not enter the Runtime frame.
6. Existing legacy decisions and canonical processing remain unchanged.

