# OBS-5 p5 Sensory Inspection Contract

## Status

Operational read-only inspection surface for isolated SensorFrames.

## Projection

The Workbench performs one additional GET:

```text
GET /v1/sensory-observation-snapshot
-> selected agent
-> latest_by_agent[selected agent]
-> independent channel cards
```

The cards are `vision_local`, `vision_distant`, and `audition`. Each card shows
only its own latest frame: sample sequence, sampled World tick, capture instant
or interval, observer frame reference, profile revision, status, coverage,
output-limit state, and a bounded payload summary.

Channels are not aligned to a shared display time. Missing channels show `NO
FRAME FOR SELECTED AGENT`; they are not rendered as empty observations.
`PARTIAL`, `UNAVAILABLE`, and `output_limited` remain explicit and are not
collapsed into zero detections.

When the sensory endpoint is unavailable, the existing Sleep Memory panel is
preserved. The viewer adds no POST, action, Experience, semantic interpretation,
canonical admission, or synchronization authority.

## Acceptance

1. The p5 API obtains sensory state only through the existing GET endpoint.
2. Selecting NPC A/B scopes every displayed channel through
   `latest_by_agent[selectedAgentId]`.
3. Each channel retains its own capture time and observer frame reference.
4. Missing, empty, partial, unavailable, and output-limited states remain
   distinguishable.
5. Fixture playback and all Live mutation controls remain unchanged/disabled.

