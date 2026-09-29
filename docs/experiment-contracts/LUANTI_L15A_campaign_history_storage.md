# L15A — Shared completed campaign history

Scope: reduce Runtime allocation and GC stalls without changing an observation,
command, learning relation, day transition, physical effect, budget or JSON schema.

## Storage invariant

Only ReturnCampaign opts into sharing completed night entries and initial home
observation evidence. Existing DayCycleExploration and other resource paths keep
their original deep-copy policy through three overridable copy hooks.

A campaign day state copies current mutable fields and makes a fresh night list.
Its completed entries and home evidence are read-only after internal publication.
Entering a new night appends to the fresh list; no past entry is edited. Decision
storage follows the same rule. All creation still precedes successful admission;
failed sensory staging must not modify existing history or publish the new night.

Public snapshot decisions are deep-copied separately. A caller can mutate one
returned decision without changing other returned decisions or internal state.
The wire representation and complete public state values remain unchanged.
No forgetting, compression of semantic content, altered Sleep authority, GC policy,
queue enlargement, tick correction or agent deadline extension is introduced.
The host export grace is extended from 300 to 900 seconds, independently of
agent/world budgets; the measured run still exceeded its export deadline.

## Measurement

Extract recorded requests in a separate process, then stream them for offline
replay. Keeping the huge original World/Runtime graph resident would distort GC.
Profile old and new implementations on the same received-response prefix,
checking every response and canonical JSON hashes of all six final agent states.
Nested phase timers are inclusive; their totals must not be added together.
GC callbacks only observe automatic collection. No collection is forced or disabled.
Public snapshot hashing is outside the measured loop.

The prefix intentionally excludes accepted calls whose replies were never received
by World. This replay is not a reconstruction of their wall timing or the complete
live final Runtime. Single before/after timings are diagnostics, not guarantees.

Opt-in actual-World diagnostics also record passive GC timing in
`campaign-runtime-timing-v2`. A slow collection is associated with the currently
active serialized loop call, if any; callbacks outside a call are reported with
`call=null`. JSON, lock wait and network time remain outside the loop timer.
The callback is removed when the runner closes. Fixed-size aggregates and rings
remain outside agent inputs.

## Acceptance

- Same recorded replies and final public state before/after.
- Earlier night contents survive a later append, failed admission and retries.
- Public snapshots retain independent mutable copies.
- Existing day-cycle, campaign, learning and full-suite regressions.
- One six-agent 1x actual run, up to thirty days / six returns, with diagnostics;
  preserve failure rather than relaxing the original acceptance conditions.
