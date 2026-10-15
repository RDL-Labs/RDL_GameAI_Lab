# Ground pattern analysis sharing

Baseline: `08a569d`. Local Julia 1.13.1, one Julia/BLAS thread.

The living loop previously parsed each ground observation separately for its
bounded descriptive record and its body-linked continuity model. It now computes
the patterns once and passes that result to both consumers. Existing callers can
still omit the result. Neither consumer mutates the parsed patterns. This is a
same-observation reuse, not a cross-observation cache or change of sampling rate.

## Finite experiment

`ground_sharing_checks.jl` compares both paths over 128 observations, including
occlusion, body correspondence, bounded history, and continuity changes. Four
checks cover equal final states, read-only consumption, duplicate observations,
and actor binding. Two further checks verify the baseline call-site substitution
and byte-identical one-day living outputs. All six passed (exit 0).

After warmup, 15 samples per path alternate measurement order. Each sample starts
with fresh state and includes observation construction and both consumers.

| 128 observations | Duplicate analysis | Shared analysis |
|---|---:|---:|
| Median time | 27.1539 ms | 17.9653 ms |
| Cumulative allocation | 9,057,040 bytes | 6,489,776 bytes |

This local workload is about 1.51x faster with 28.35% less allocation. This is not
a whole-LW speedup or a peak-memory measurement.

The living comparison uses seed 20261005, three agents, one full day, renewable
food, resistance patches, ground wear/perception/continuity enabled. Both paths
produce byte-identical `result.json`. Call times were 40.08s and 24.32s, but include
compilation and run in fixed old/new order: they are not a controlled speed ratio.
No 30-day run or CPU/allocation profile was performed for this isolated change.

Evidence: `outputs/lw-optimization/ground-sharing/` contains raw samples, frozen
specification, old/shared results and summaries. The first harness attempt
re-included dependent modules and failed with an ambiguous `segment_hit` binding;
the corrected harness redefines only `lw_day`. No runtime workaround was needed.

Retain this small optimization. Measure the optimized full loop before choosing
the next larger optimization; local savings alone do not establish its bottleneck.

## Subsequent 10-day integrated comparison

Using the frozen seed 20261005 riparian integrated specification from the previous
30-day experiment, changing only days to 10: both processes exited 0 and result
SHA-256 was `AD87F5EA456230CA7EF086F7C8237143C06FADE39028589066A516824D3EDED3`.
Old/shared wall times were 527.776/333.650 seconds; call times including compilation
were 517.486/325.316 seconds. Cumulative allocations were
146,367,286,247/135,363,586,719 bytes. Peak RSS was
1,189,847,040/1,219,846,144 bytes (not reduced).

This is one fixed-order local pair, not a repeat-controlled performance estimate.
The observed wall-time ratio is 1.58x; allocation fell 7.52%. Evidence is in
`outputs/lw-optimization/ground-sharing-ten-day/`.
