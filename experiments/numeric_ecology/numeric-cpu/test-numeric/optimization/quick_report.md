# Small optimization pass after 08a569d

Local Julia 1.13.1, one Julia/BLAS thread. Baseline source is the frozen
`ground-sharing-ten-day/baseline` snapshot of 08a569d. Candidate also includes
the previously tested ground-pattern sharing change.

## Changes

- Method selection: one-pass minimum using the same tuple comparison instead
  of sorting all candidates; lazy MethodNode insertion; one shallow result copy
  instead of copy plus merge. Equal keys retain the first candidate as before.
- Skyline: calculate each horizontal ray/object intersection once, evaluate
  all three elevations independently, and emit the original elevation-major
  order. It does not keep only the nearest horizontal object; taller objects
  behind low foreground objects remain eligible. Equal-distance precedence is
  unchanged.
- Body change: immutable four-Float64 `BodyDelta`, with read-only AbstractDict
  access and JSON object serialization. Equations are unchanged. No mutable
  workspace is shared with historical records. Mutation of a delta is no longer
  supported. Observation containers remain dictionaries; this is not a complete
  typed-observation migration.

## Checks and local measurements

`quick_checks.jl`: 2,000 body/JSON comparisons; 1,501 candidate ordering, state,
input-mutation and empty-input checks; 145 skyline checks; one full integrated
one-day result comparison. **3,647 passed**, process exit 0.

Body conditions include walk/run/climb/rest/eat, blocked/clear, varying damage,
load, resistance and reserves. Skyline covers subrays, several poses, empty
geometry, foreground low objects, background tall objects and equal-distance
objects. Method comparison covers missing and existing nodes, H/threshold,
last-selection order and equal priorities.

Warmup followed by 15 alternating old/new samples (GC before each sample):

| Workload | Old median | New median | Old/new allocation bytes |
|---|---:|---:|---:|
| 10,000 body evaluations | 3.825 ms | 3.366 ms | 10,720,048 / 8,960,048 |
| 10,000 choices, 12 unregistered candidates | 93.908 ms | 13.424 ms | 127,366,704 / 13,766,704 |
| 100 skyline observations, 53 objects, subrays | 8.033 ms | 2.677 ms | 2,919,328 / 2,732,128 |

These workloads measure local costs, including harness overhead; choice timing
emphasizes missing nodes and is not representative of all living selections.
No claimed multiplication of these speed ratios into a whole-system speedup.

## Integrated check

Frozen riparian seed 20261005, three agents, one day, shared stores, general Sleep,
hazards, body/ground/route fields and other compatible long-run flags enabled.
Both result objects compare exactly after JSON decoding (including numerical
values). JSON key order may change for BodyDelta, so byte equality is not the
contract for this change. No tolerance relaxation was needed.

Old/new call time: 41.576 / 28.523 seconds. Cumulative allocations:
13,676,465,109 / 10,763,030,833 bytes. These calls include compilation and run
in fixed order within one process; this is diagnostic, not a controlled runtime
speed estimate. Process peak RSS is cumulative and unsuitable for comparison.
Food: initial 124 = ground 112 + shared 5 + held 2 + consumed 5 in both results.

Evidence: `outputs/lw-optimization/quick-pass/` and `quick-pass.log`.
The initial harness used a relative include path and was corrected. The first
BodyDelta check exposed a missing `get` method needed by AbstractDict equality;
that interface was completed before the successful run.

Retain the three small changes plus ground sharing. Full observation typing,
cross-frame caches, resolution/cadence changes, and GPU execution are not part of
this pass. This pass did not execute the Python suite or another 10/30-day run.
