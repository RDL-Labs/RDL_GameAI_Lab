# Local Bias Deep Similarity Evidence

## Command

```bash
python -m unittest -v tests.test_local_bias_deep_similarity tests.test_local_bias_profile tests.test_outcome_bias
```

## Result

OGB-7 compared three distinct same-agent Local Bias Sleep Profiles using all
three pair combinations. OGB-8 formed one deterministic shadow candidate from
relations repeated across every Profile.

The mixed reference retained both:

```text
reward_value / positive / STRONG
injury / negative / STRONG
```

No net score was introduced. Bias, Experience, World event, sleep-cycle, and
Profile provenance remained traceable. An opposing acquisition direction was
reported as a conflict and omitted from the common candidate relations without
automatic resolution. Cross-agent and under-sized Profile windows were rejected.

The focused OGB-6 through OGB-8 regression completed 14 tests successfully.
