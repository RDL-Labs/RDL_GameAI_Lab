# OBS Common Boundary Contract

## Status

OBS-0 and OBS-1 operational reference. OBS-3 distant vision and OBS-4 audition
remain planned.

## Boundary

The Runtime may receive `observation.sensory_extension`, but removes it once at
the HTTP boundary before any existing policy, Experience, Sleep, or canonical
consumer is called.

```text
incoming packet
├-> legacy packet without sensory_extension -> existing consumers
└-> sensory_extension -> strict validation -> finite read-only store
```

The extension path is opt-in through `--sensory-observation`. When disabled,
the field is removed and grants no authority. When enabled, the v1 allowlist
checks delivery identity, agent ownership, assigned profile/revision, channel,
capture time, sample sequence, status, coverage, and payload shape before an
atomic admission. The store is bound at startup to one `run_id` and positive
`world_epoch`; a delivery from another execution context is not admitted.

An invalid extension does not reject an otherwise valid legacy observation.
The extension is removed, a bounded rejection diagnostic is recorded, and the
legacy policy/Experience/Sleep/canonical path continues. Malformed legacy data
remains an ordinary observation error.

## Storage

Frames are immutable and idempotent by `frame_id`. Conflicting replay, unknown
profile, cross-agent delivery, foreign run/epoch, future capture, unexpected
fields, and capacity overflow are rejected without partial frame mutation.
For each `(agent, sensor, channel)`, a new frame must advance both `sample_seq`
and capture-end time; a late older frame cannot become latest. Stored frames
carry their admitted run/epoch context. Capacity is finite per agent and
channel. `GET /v1/sensory-observation-snapshot` is read-only.

```text
SensorFrame != Experience
SensorFrame != canonical RIB_B admission
SensorFrame != E / H / theta_eff / M_delta
SensorFrame != T1 material
SensorFrame != action authority
```

OBS-1 establishes storage and validation only. Luanti emission of distant or
auditory frames is not implemented here.
