# Local Bias Sleep Relation Profile Evidence

## Command

```bash
python -m unittest -v tests.test_local_bias_profile tests.test_outcome_bias
```

## Result

The OGB-6 compiler produced one deterministic same-agent Profile from a mixed
Risky Tasty Food outcome. Its relation members retained both:

```text
reward_value / positive / STRONG
injury / negative / STRONG
```

No net score or CandidateRelation was created. The output preserved Bias,
Gradient, Experience, World event, and Food/Beast/Territory context provenance.
Cross-agent input, inconsistent strength bands, and inputs above the finite
32-material limit were rejected without mutating the source projection.
