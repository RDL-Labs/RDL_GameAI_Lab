# Experiment Roadmap

## Phase 1: Minimal Transfer

- Build one tiny NPC loop with heat accumulation, perception, action choice, and replay logs.
- Keep dependencies light enough that experiments are easy to inspect and throw away.

## Phase 2: Safety Layer

- Add canary behavior trials.
- Compare baseline and trial behavior with shadow evaluation.
- Promote or roll back behavior based on explicit metrics.

## Phase 3: Living-World Metrics

- Add relation drift, place meaning, and daily variation metrics.
- Compare survival-only scoring against richness-oriented scoring.

## Phase 4: Visual Demos

- Convert the most legible mechanics into browser demos.
- Keep each demo focused on one mechanism unless integration is the experiment itself.
