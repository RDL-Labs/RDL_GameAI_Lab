# T1-A Material Expansion Evidence

**Status:** T1-A complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_t1_material_expansion.py"
```

The finite reference enters `M_delta` from reviewed residual `H = 1.0` and
`theta_eff = 1.0`, then explicitly expands:

```text
current M_B
RIB_B
RIB_B'
unresolved residual H_vec
one same-agent Sleep CandidateRelation
one same-agent Experience
```

All six materials remain `UNINSPECTED`. A normal-phase model cannot expand,
foreign-agent material is rejected, exact replay is idempotent, changed replay
is rejected, and repeated snapshots do not mutate the bundle.

No retain/reject/defer result, Probe, `M_B'`, re-entry, or action effect exists.
