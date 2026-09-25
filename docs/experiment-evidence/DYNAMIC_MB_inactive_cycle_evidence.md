# Dynamic M_B Inactive Cycle Evidence

**Status:** DMB-A complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_dynamic_mb_cycle.py"
```

## Observed chain

```text
dmb-experience-0..2
-> 3 accepted Experience IDs
-> dmb-night-1 Sleep window
-> Relation Profiles
-> Deep candidate with all 3 source IDs

dmb-rib-first / dmb-rib-later
-> E visible_objects_count +2
-> explicit unresolved residual 1.0
-> H 1.0 >= theta_eff 1.0
-> M_delta

explicit T1-A join
-> parent/RIB/residual/candidate/3 Experience material bundle
-> T1-B: parent + RIB pair + candidate retained; Experience/residual deferred
-> T1-C: one candidate-sourced adopted relation
-> RECONSTRUCTED_INACTIVE M_B'
```

The final artifact retains bundle, selection, and candidate provenance. The
Review Path is unchanged from the moment of `M_delta` entry, the old model
registry does not contain the new model ref, and `M_delta` remains active.

This is an end-to-end material/reconstruction trace, not evidence that
Experience generated H. Cutover and re-entry remain absent.
