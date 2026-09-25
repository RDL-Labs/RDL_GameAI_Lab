# Territory Beast Experience Contract

**Status:** R6 finite multi-agent Experience adapter operational

## Purpose

Convert accepted Territory Beast World fact events into finite local Experience
without reusing the approach-only Experience schema or assigning danger meaning.

```text
direct_participant -> retains its own physical World consequence
bounded_observer   -> retains the observed subject and event, no borrowed injury
```

Every record retains experiencer agent, subject agent, beast, territory, event,
response, proximity, outcome, source event ID/schema/authority, and adapter ID.

## Separation

```text
Territory Experience != danger belief
Territory Experience != Sleep candidate
Territory Experience != canonical review
injury Experience != H
injury Experience != theta_eff adjustment
injury Experience != M_delta entry
```

S2 Profile conversion for this new schema is deferred to an explicit future
adapter. It must not be passed through the existing approach-only compiler.

The v1 store retains at most 128 immutable records for process lifetime. Exact
replay is idempotent. Capacity rejects a new record without eviction.

## Acceptance

1. Warning/retreat and warning/chase/injury form different direct Experiences.
2. A bounded observer retains the subject's event without acquiring its injury.
3. Agent identity and source event provenance remain traceable.
4. No danger label or canonical authority is introduced.
5. Replay is idempotent and capacity does not evict.
