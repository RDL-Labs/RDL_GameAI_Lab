# Territory Beast World Contract

**Status:** R4-R5 finite World fixture operational

## Purpose

Provide one bounded territorial interaction without declaring a beast, place,
or outcome intrinsically dangerous.

```text
outside territory       -> ignore / outside_territory
first boundary crossing -> warning / warning_observed
continued intrusion     -> chase / chased
persistent close entry  -> attack / injured or attack_evaded
```

World owns exact positions, territory geometry, progression count, response
resolution, and physical consequence. The emitted event is a bounded fact for
later Experience adapters; it is not NPC interpretation.

## Event boundary

Events contain agent, beast, territory, event type, beast response, bounded
proximity, outcome, and optional physical consequence. They do not contain:

```text
danger
beast_is_dangerous
threat_score
fear
H
theta_eff
M_delta
```

The finite injury fixture is World-owned and currently yields `medium`, forced
retreat, and no incapacitation after a successful attack. This is not yet wired
to BodyState or action policy.

## Retention

Progress is independent per agent and beast fixture. Leaving the territory
resets intrusion steps. The v1 store holds 128 agent relations and rejects a
new relation at capacity without eviction. Snapshot access is read-only.

## Separation

```text
World event != Experience
World event != CandidateRelation
injury outcome != H
injury outcome != theta_eff
attack != automatic M_delta
```

No Runtime decision, canonical review, or T1 authority is added. An explicit
adapter and accepted Experience are required before later memory work.

## Acceptance

1. Outside presence stays neutral.
2. Intrusion deterministically progresses warning, chase, and attack.
3. Different agents retain independent interaction progress.
4. Exit and re-entry begin a new warning sequence.
5. Capacity rejects without silent eviction.
6. World events alone leave C1-C4 snapshots unchanged.
