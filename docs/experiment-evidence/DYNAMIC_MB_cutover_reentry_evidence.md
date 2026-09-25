# Dynamic M_B Cutover and Re-entry Evidence

**Status:** DMB-B complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_model_cutover_reentry.py"
```

Starting from the T1-C inactive artifact, the finite reference verifies:

```text
parent active + M_delta active
-> explicit cutover
-> parent archived byte-for-byte
-> reconstructed model becomes sole active model
-> adopted relation provenance retained
-> M_delta phase = REENTERED
-> active M_delta count = 0
```

The first observation after re-entry forms no comparison. The second forms E
under the new model ref, proving that the pre-cutover F/F' window was not reused.

A wrong expected parent is rejected without mutation. Exact replay returns the
same cutover record; changed operator provenance is rejected. No game action
authority changes.
