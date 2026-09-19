# Sleep Deep Similarity Shadow Contract

**Status:** S3 contract frozen / implementation pending  
**Version:** v0.1  
**Code level:** I1 Structural Operation + I2 Reusable Function + I3 DeepSimilarity mechanism  
**Input:** S1 finite Sleep window and S2 Relation Constraint Profiles

## 1. Purpose

S3 is the first boundary that compares multiple Experience-derived Profiles and
may form a new GameAI-local relation candidate.

```text
finite Relation Constraint Profiles
-> Similarity Observations
-> one bounded cluster
-> one sourced shadow CandidateRelation
```

It tests whether a repeated finite structure can be extracted. It does not
establish that the structure is true, useful, committed, or canonically adopted.

## 2. Distinct objects

The implementation must keep these as separate immutable outputs:

```text
RelationProfile
!= SimilarityObservation
!= ProfileCluster
!= CandidateRelation
!= Commitment
!= ActiveConstraint
!= WorldAction
!= CanonicalAdmission
```

Every object receives its own identity, version, purpose, boundary, source
references and authority label. A downstream object may cite an upstream object;
it must not overwrite it.

## 3. Finite comparison boundary

The first implementation is explicitly opt-in and accepts only:

- one `READY` S1 window;
- three to six S2 Profiles;
- one agent and one sleep cycle;
- exact agreement between window source IDs and Profile source IDs;
- S2 compiler version `experience-relation-profile-v1`;
- the five current relation kinds: actor, target, context, action and outcome.

At most six Profiles and fifteen unordered Profile pairs may be evaluated.
There is no recursive comparison, multi-hop graph search, random association,
cross-agent merge, unbounded cluster growth, forgetting or history rewrite.

## 4. Relation alignment

I1 alignment uses declared relation structure only. It may compare:

```text
kind
predicate
object
status
polarity
strength
```

Identity equality and value agreement are reported separately. Missing or
unsupported dimensions are not manufactured from World state or converted to
zero-valued matches.

The first version does not infer synonyms, motives, emotions, causal direction,
personality, trust or hidden place relations.

## 5. Similarity Observation

Each pair produces a read-only Similarity Observation containing at least:

```text
left / right Profile IDs
source Experience IDs
comparison purpose and evaluator version
selected relation dimensions
matched relations
different relations
coverage
conflict
unresolved
score, only where coverage permits it
```

### Coverage

Coverage states whether every selected comparison dimension was available and
eligible. Incomplete coverage is represented explicitly.

```text
missing coverage != mismatch
missing coverage != score 0
missing coverage != conflict
```

### Conflict

Conflict requires an explicit incompatible finite relation under the same
alignment boundary. Merely having different targets, contexts, or outcomes is
not automatically a conflict.

### Unresolved

An S2 relation whose polarity is `unresolved` remains unresolved evidence. It
does not become adverse, failure, conflict, canonical residual `H`, or a negative
similarity score.

### Score

Score summarizes eligible agreement only. It must be accompanied by coverage,
matched count and compared count. Score alone cannot admit a cluster or
candidate, and no threshold is presented as a biological constant.

## 6. One bounded cluster

S3 may form at most one deterministic cluster per Sleep window.

A cluster requires:

- at least three distinct Profiles;
- complete traceability to all member Profiles and source Experience IDs;
- at least one eligible common relation signature;
- no missing source and no agent/window mismatch;
- deterministic member and relation ordering.

Insufficient evidence returns `NO_CLUSTER`. It must not produce an empty cluster
that is reported as success.

A cluster is a comparison grouping only:

```text
cluster != category truth
cluster != learned rule
cluster != commitment
```

## 7. One shadow CandidateRelation

At most one candidate may be extracted from the one cluster. The candidate must
cite:

```text
candidate ID and schema version
cluster ID
Similarity Observation IDs
Profile IDs
source Experience IDs
common relation signature
support count / member count
coverage
conflict
unresolved items
formation tick / sleep cycle
evaluator identity and purpose
```

Structural scaffolding that is guaranteed by the input schema, such as "every
record has an actor" or "every current record used approach", is not sufficient
by itself. The candidate must preserve a repeated bounded content relation such
as a target, context or eligible reported outcome.

If no eligible common relation remains, S3 returns `NO_CANDIDATE` while retaining
the Similarity Observations and cluster evidence.

The candidate authority is:

```text
GameAI-local shadow candidate
not Truth
not Commitment
not action authority
not canonical M_B admission
not H
not T1
```

## 8. Determinism and replay

For identical versioned inputs, S3 returns byte-equivalent structured output.
IDs derive from versioned boundaries and ordered source identities, not process
time or random values. Later raw Experience does not alter an already formed S3
result for the same frozen S1 window.

Any missing source, changed source agent, duplicate identity, unsupported schema,
or Profile/window mismatch rejects the operation atomically.

## 9. Non-intervention

S3 must leave the following unchanged:

- raw Experience History;
- S1 window store;
- S2 Profiles;
- Runtime decision and active Trajectories;
- Godot World state and Body state;
- canonical sidecar, `M_B`, `E`, `H` and retained `H`;
- Sleep recovery and scheduling.

No HTTP, Godot, CLI or Inspector dependency is permitted inside I1/I2 compute.
Persistence and display are later Adapter responsibilities.

## 10. Minimum acceptance

1. Three matching bounded Profiles produce finite Similarity Observations, one
   cluster and at most one sourced shadow candidate.
2. Two Profiles or an `INSUFFICIENT_EVIDENCE` window produce no cluster.
3. Missing coverage remains explicit and is not converted to score zero.
4. Difference, conflict and unresolved are independently represented.
5. `approach_no_progress` does not become adverse evidence automatically.
6. Schema-only common structure cannot become the candidate by itself.
7. Every output can be traced back to S1 window, S2 Profile and raw Experience.
8. Replay is deterministic and input objects remain unchanged.
9. Source loss, duplicate identity and cross-agent mixing reject atomically.
10. Candidate formation changes no action, World or canonical state.

## 11. Deferred

- Rescue-specific Profile adapters;
- one-hop and multi-hop graph comparison;
- multiple clusters or candidates;
- Reflective and Fast retrieval;
- candidate review, retention, decay or forgetting;
- behavior influence and Commitment;
- canonical admission or T1 reconstruction;
- stochastic misassociation.
