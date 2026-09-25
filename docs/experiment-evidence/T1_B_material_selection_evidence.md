# T1-B Material Selection Evidence

**Status:** T1-B complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_t1_material*.py"
```

One six-material T1-A bundle is explicitly reviewed with all three dispositions.

```text
current M_B         -> RETAIN
CandidateRelation   -> REJECT
Experience          -> DEFER
remaining materials -> DEFER
```

The resulting counts are `RETAIN=1`, `REJECT=1`, `DEFER=4`. Partial and
duplicate reviews leave the ledger empty. Stale revisions are rejected; an
explicit revision-2 review can change a disposition while preserving the
bundle and model unchanged.

No retained candidate is adopted, no `M_B'` is produced, and action authority
does not change.
