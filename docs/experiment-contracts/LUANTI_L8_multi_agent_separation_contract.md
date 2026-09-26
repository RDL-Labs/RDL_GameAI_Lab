# Luanti L8 Multi-Agent Separation Contract

## Status

L8 Runtime/adapter multi-agent separation reference.

## Purpose

Remove the single-agent selection assumptions from the Luanti L7 learning and
Dynamic M_B adapter before richer multi-entity World integration.

```text
agent_id
+ deep_similarity_id
+ candidate_id
+ assessment_id
-> one explicit T1/cutover request
```

## Selection Boundary

The adapter no longer selects the most recently inserted Sleep result. Every
request must identify the target agent, Sleep result, candidate, and canonical
assessment. All identities must agree.

The Experience input is not the complete process store. It is the exact
intersection of:

```text
same agent
AND candidate.source_experience_ids
```

Missing provenance, a foreign Sleep result, or a mismatched candidate is
rejected before T1 expansion.

## Multi-Agent Reference

The finite reference runs two agent-owned cycles in one coordinator and one
canonical sidecar:

```text
npc_a: 3 outcomes -> Sleep A -> Candidate A -> rupture A -> M_B'A -> REENTERED
npc_b: 3 outcomes -> Sleep B -> Candidate B -> rupture B -> M_B'B -> REENTERED
```

Each T1 bundle contains only three Experiences from its own candidate. Projected
candidates, active model, archived parent, `M_delta`, and adopted relation
provenance remain agent-local.

## Scope Boundary

L8 validates Runtime and Luanti-adapter ownership using Luanti fact-event schema.
It does not yet claim two autonomous NPC entities moving concurrently inside one
real Luanti World. That is a later rich-World scheduling and observation test,
not a reason to weaken the Runtime identity contract.

## Acceptance

1. Explicit agent, Sleep-result, candidate, and assessment identities are required.
2. Cross-agent Sleep selection is rejected.
3. Only same-agent candidate-source Experiences enter T1-A.
4. A and B form distinct candidates and reconstructed models.
5. A and B complete cutover and `REENTERED` independently.
6. No candidate, Experience, model, archive, or `M_delta` crosses agents.
7. Cutover still grants no game action authority.
