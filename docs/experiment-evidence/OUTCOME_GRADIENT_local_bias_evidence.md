# Outcome Gradient / Local Bias Evidence

## Command

```bash
python -m unittest -v tests.test_outcome_bias tests.test_risky_tasty_food
```

## Cases

```text
Strong success
  acquired + returned + HIGH reward + no injury
  -> positive STRONG acquisition / return / reward biases

Strong failure
  not acquired + not returned + severe injury + ZERO reward
  -> negative STRONG acquisition / injury biases

Mixed
  acquired + returned + HIGH reward + severe injury
  -> positive STRONG reward and negative STRONG injury coexist
```

No case emits a global reward or net score. Agent A/B projections contain only
same-agent materials. Exact replay is stable, capacity rejects without eviction,
and the canonical sidecar remains byte-for-byte unchanged.

Sleep receives an explicitly non-authoritative material projection only;
Candidate formation and action influence remain deferred.
