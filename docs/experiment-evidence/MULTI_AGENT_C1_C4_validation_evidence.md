# Multi-Agent C1-C4 Validation Evidence

**Status:** R1-R3 complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_multi_agent_c1_c4_validation.py"
```

The same deterministic fixture is executed with 3, 5, and 10 agents. Only the
agent count and identity set change.

For every agent the test forms three admitted Experience records, one bounded
Sleep window, one Deep shadow candidate, one same-agent Fast query, one
canonical comparison and explicit review, one theta evaluation, and one
`M_delta` entry.

## Result

```text
3 agents  -> 9 Experience,  3 candidates,  3 review paths,  3 M_delta states
5 agents  -> 15 Experience, 5 candidates,  5 review paths,  5 M_delta states
10 agents -> 30 Experience, 10 candidates, 10 review paths, 10 M_delta states
```

- Experience and candidate agent identities remain distinct.
- Fast results retain only the querying agent's provenance.
- assessment IDs and frozen model refs are unique per agent.
- Candidate material does not enter the canonical Review Path.
- Repeated read-only snapshots are equal and do not create transitions.
- No tested finite capacity is silently exceeded or evicted.

## Corrective finding

The pre-validation audit found that the HTTP Fast source catalog previously
collected raw Experience across agents. Sleep windows were already separated,
but Fast's pure comparator did not reject a foreign source. The catalog now
filters by the current agent, Profiles and candidates carry explicit
`agent_id`, and the comparator rejects mixed-agent input.

```text
semantic cross-agent leakage = 0 after correction
unexpected authority promotion = 0
silent mutation = 0
```

R4 Territory Beast remains next. T1-A remains paused until R4-R7 complete.
