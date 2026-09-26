# OBS-7A Comparison Eligibility Contract

## Scope

Operational local diagnostic over admitted sensory snapshots. It implements the
first slice of [the interpretation plan](../design/RDL_GameAI_Sensory_Interpretation_Use_Plan.md).
The existing OBS-6E acquisition/delivery baseline is unchanged.

API: `runtime.sensory_comparison.diagnose(snapshot, request)`.
There is no HTTP endpoint, store, automatic observe hook, action, fusion,
identity verdict, candidate generation, or canonical admission.

## Purpose and input

Only purpose `coincident_azimuth_comparison`, rule `obs7a-v1`, is accepted.
It asks whether selected directional observations acquired at overlapping times
have the conditions needed for a later azimuth comparison. It does not compute
angular overlap, similarity, source identity, or temporal pattern recognition.
Consequently opposite directions and the -180/+180 boundary are not compared
numerically here. They do not make eligibility an identity or mismatch result.

The caller supplies a trusted `SensoryObservationStore.snapshot()` or a recorded
projection retaining its context, assignments, and unmodified admitted frames.
This API is not a second frame validator or a cryptographic proof of admission;
untrusted external data must pass the existing store admission boundary first.

Request fields are exactly run_id, world_epoch, agent_id, purpose, rule_version,
and pairs. Each pair has two references with frame_id and optional element_id.
For distant vision element_id denotes feature_id; for audition detection_id.
IDs are opaque. No ID substring, World truth, latest selection or delivery time
is used to reconstruct context or pose. Frame IDs must exist, belong to the
requested run/epoch/agent, and be distinct within a pair. Supplied element IDs
must resolve uniquely. An omitted element is a valid diagnostic request but
cannot become eligible: empty payload gives no_element, otherwise explicit
selection is required. No implicit first feature or detection is selected.

At most 16 submitted pairs / 32 reference occurrences are allowed, before
any deduplication. Empty requests return empty results. Reversed/duplicate pairs
are canonicalized and returned once, sorted by opaque reference tuples.
The snapshot is already finite under the store contract; no history cross-product
is formed. Duplicate frame IDs in a supplied snapshot are an input error.

## Permission table

Both sides must satisfy all these conditions; failures accumulate sorted,
unique reason codes rather than being silently converted to absence.

| Dimension | v1 permission |
| --- | --- |
| channel/model | vision_distant / sampled-surface-v0.2; audition / direct_band_energy_v0 |
| profile | revision 1 of fixture-distant-enabled, fixture-audition-enabled, fixture-audition-compact, fixture-life-sensory, fixture-life-sensory-compact |
| profile pairing | identical profile ID and revision on both sides |
| status/coverage | SAMPLED and COMPLETE_WITHIN_PLAN; output_limited=false |
| time | equal clock IDs; zero tolerance, acquisition intervals overlap |
| coordinate basis | identical channel, sensor_id, and opaque acquisition observer_frame_ref in this run/epoch/agent context |
| direction | explicitly selected element with known azimuth interval |

Mixed eye/ear channels have no permitted coordinate mapping in v1, even when
pose token spellings or tick numbers match. The diagnostic returns
pose_mapping_unavailable. It does not manufacture a cross-channel positive.
For audition both time and pose come from the selected detection, not the
frame window's generic observer reference. Distant vision uses frame capture.

Point/point requires equal times. Point/interval uses start <= point < end.
Interval/interval requires positive overlap. A zero-length interval is empty,
not an instant. Clock mismatch suppresses numerical time comparison.
The same observation replayed later cannot gain temporal overlap from delivery.

## Results and failures

Top-level output retains rule_version, purpose, run_id, world_epoch, agent_id,
authority, and results. Each result contains references, acquisition conditions,
status (`eligible` or `not_comparable`), and reasons. Output is detached from
input; neither input nor store is mutated. No confidence or support count exists.

Diagnostic reasons:

- element_selection_required, no_element
- unsupported_channel, unsupported_model, unsupported_profile, profile_mismatch
- unavailable, incomplete_coverage, output_limited
- unknown_direction, clock_mismatch, no_temporal_overlap, pose_mapping_unavailable

Input failures raise `ComparisonInputError` with a stable code and no partial
result: invalid_request, unsupported_purpose, unsupported_rule, invalid_agent,
invalid_snapshot, context_mismatch, unknown_agent, invalid_pairs, budget_exceeded,
duplicate_snapshot_frame, invalid_pair, invalid_reference, unknown_frame,
cross_agent_reference, self_pair, unknown_or_ambiguous_element.
Unknown frame references include unadmitted or rejected frames. The diagnostic
cannot tell which of those histories produced a missing ID and does not invent it.

## Acceptance and stop

Tests must cover admitted synthetic positive frames, detection pose selection,
point/interval/instant boundaries, empty intervals, missing acquisition,
partial and limited output, clocks/models/profiles, context rejection,
duplicate retry, pair order and snapshot order invariance, detached output,
budgets, and fixed packet action/Experience/canonical non-interference.

Real Luanti replay is separate from synthetic positive evidence. A real
cross-channel pair may correctly remain not_comparable. Recording it is not
a demonstration of sound-source identification or successful sensory fusion.

Stop at OBS-7A. OBS-7B, OBS-8, pose transforms, canonical F/F'/E/H admission,
long-term retention and network-failure expansion remain outside this contract.
