# Territory Beast R6-R7 Evidence

**Status:** R6 combined evidence complete; R7 regression complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_territory_beast*.py"
python -m unittest discover -s tests
```

The same fixture runs with three and five agents.

```text
Agent A: enter -> warning -> exit
Agent B: enter -> warning -> continue -> chase -> close persist -> injury
Agent C: bounded observation of B's injury; no direct injury consequence
Agent D/E: outside territory -> neutral / ignore
```

Direct and observed Experience records retain distinct experiencer and subject
identity. Exact replay is idempotent. Capacity rejects without eviction.

Territory World and Experience paths do not call acquisition, assessment,
theta evaluation, or M_delta transition. The canonical sidecar remains equal
before and after the combined interaction.

```text
cross-agent provenance leakage = 0
candidate automatic promotion = 0
Experience -> H conversion = 0
injury -> theta adjustment = 0
danger outcome -> M_delta transition = 0
read-only mutation = 0
silent eviction = 0
```

This validates responsibility separation; it does not establish danger
learning, territorial cognition, navigation, ecology, or Dynamic M_B.
