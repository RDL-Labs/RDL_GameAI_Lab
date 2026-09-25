# T1-C Reconstruction Evidence

**Status:** T1-C complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_t1*.py"
```

The reference path retains the parent `M_B` and one Sleep CandidateRelation,
rejects an Experience, and defers the unresolved residual. Reconstruction
produces one `RECONSTRUCTED_INACTIVE` artifact with a new model ref and one
candidate-sourced adopted relation.

The parent coefficients, biases, boundary, and `xi_status` are copied without
mutating the parent. The old model registry remains unchanged, the new model is
not active, and `M_delta` remains active. Exact replay returns the same artifact.

Reconstruction is rejected when either the parent or every candidate lacks a
RETAIN disposition. No cutover, re-entry, or action effect exists.
