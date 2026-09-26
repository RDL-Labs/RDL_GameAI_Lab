# Luanti L9 p5 Read-Only Trace Contract

## Status

L9 operational observation reference.

## Purpose

Expose the existing Luanti learning and canonical provenance in p5 without
creating, completing, or mutating semantic state in the viewer.

```text
GET /v1/luanti-outcome-snapshot
+ GET /v1/canonical-snapshot
-> agent-filtered p5 projection
```

## Selected-Agent Trace

For the selected agent, p5 displays:

```text
Experience count and latest ID
-> Local Bias count and relation-kind count
-> latest Sleep / Deep result and ID
-> shadow Candidate support and ID
-> T1 bundle count and candidate-material count
-> active M_B ID and archive count
```

Every value is read from an existing Runtime snapshot. Missing stages remain
`NONE`, `NOT RUN`, or `NOT PRESENT`; the viewer does not infer them.

## Authority Boundary

The Workbench proxy remains GET-only. L9 adds no POST endpoint, review control,
selection control, cutover control, or action control.

```text
trace visibility != review
trace visibility != T1 selection
trace visibility != M_B admission
trace visibility != action authority
```

World positions are not exposed by the current Runtime endpoint and therefore
remain absent in Live Mode.

## Acceptance

1. p5 fetches the existing Luanti outcome snapshot through the GET-only proxy.
2. A/B selection filters Experience, Bias, Sleep, Candidate, T1, and model data.
3. IDs and counts come directly from Runtime snapshots.
4. Missing stages are displayed without fabrication.
5. Fixture Mode and its playback controls remain unchanged.
6. Live Mode keeps playback controls disabled.
7. No mutating Luanti endpoint is referenced by the p5 ingestion code.
