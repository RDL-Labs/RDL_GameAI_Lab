# J3 — persistent Julia shadow batch bridge

Status: FINITE EXPERIMENT COMPLETE / CURRENT BRIDGE NOT ADOPTED.

Implementation: `95ab50c0880f950efab1bfdce1c1def095c8a4f3`.
[Cloud run](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38217670361)
completed successfully. Python remains the production backend; J4 is not implemented.

## Question and boundary

J2 measured a prepared geometry kernel. J3 measures whether that advantage survives
Python input packing, transfer to a persistent Julia process, conversion, computation,
return transfer and Python decoding. This experiment uses binary pipes, not JuliaCall.
It does not accelerate World execution or generate observations in Julia.

The Python campaign captures geometry calls inside the outer `SocialWorld.packet`
at 0, 60 and 120 simulation seconds for A/B/C: nine snapshots and 178,005 queries.
Capture wrappers return original Python results and restore patched aliases afterward.
Query selection, including short circuits, remains Python-derived. Agent policy receives
no additional World information. Snapshot provenance includes observation/time/pose,
packet hashes and owned binary inputs/results.

Baseline and instrumented 180-second campaign summaries match after excluding only
elapsed time. This is final-summary equality, not an independent per-action audit.
Baseline took 6.223 seconds and capture 7.478 seconds; capture timings are not the
bridge performance measurement.

## Correctness

All 178,005 captured queries match, with zero numeric bit differences in each of five
benchmark series. Discrete outcomes are exact; the verifier also supports the declared
1e-12 absolute/relative numeric tolerance. The original 1,146-case fixture is covered
by bridge integration tests.

The installed-Julia J3 test step passes all five tests, including input/output ownership,
shadow returning Python results, process failure, missing executable, invalid geometry,
capacity/type checks and mismatched response binding. Errors terminate the bridge;
there is no silent fallback. The full repository suite was not rerun for this experiment.

## Timing

Ubuntu 24.04, AMD EPYC 9V74, Python 3.12.15, Julia 1.13.1, one Julia/BLAS thread.
The checked-in J2 Manifest is restored unchanged. This CPU differs from J2's runner;
cross-run raw timing is not a controlled comparison.

Five fresh processes per backend alternate order on the same runner. Each loads the
same nine snapshots, warms each snapshot once and measures 30 repetitions per snapshot.
Each Julia series uses one persistent process for 280 requests. File loading is outside
warm timing. Python evaluates the prepared queries directly without an artificial
serialization requirement.

Values below are milliseconds, median of five per-series medians. Ratio is elapsed
Julia bridge time divided by Python time: larger than one is slower.

| Snapshot | Queries | Python | Julia total | Ratio |
|---|---:|---:|---:|---:|
| A / 0 s | 19,801 | 7.581 | 15.072 | 1.988 |
| B / 0 s | 19,603 | 7.403 | 14.468 | 1.954 |
| C / 0 s | 19,801 | 7.523 | 14.492 | 1.926 |
| A / 60 s | 19,900 | 7.626 | 14.707 | 1.929 |
| B / 60 s | 19,900 | 7.605 | 14.820 | 1.949 |
| C / 60 s | 19,900 | 7.605 | 14.744 | 1.939 |
| A / 120 s | 19,700 | 7.442 | 14.531 | 1.952 |
| B / 120 s | 19,700 | 7.445 | 14.572 | 1.957 |
| C / 120 s | 19,700 | 7.462 | 14.531 | 1.947 |

Per-series medians over 270 timed batches, milliseconds:

| Series | Total | Python packing | Round trip | Python decoding | Server conversion | Server kernel |
|---|---:|---:|---:|---:|---:|---:|
| 0 | 14.664 | 9.327 | 3.695 | 1.540 | 0.227 | 0.385 |
| 1 | 14.732 | 9.365 | 3.685 | 1.540 | 0.237 | 0.387 |
| 2 | 14.555 | 9.283 | 3.670 | 1.544 | 0.231 | 0.386 |
| 3 | 14.590 | 9.279 | 3.659 | 1.529 | 0.230 | 0.386 |
| 4 | 14.801 | 9.466 | 3.636 | 1.542 | 0.231 | 0.386 |

These independently computed medians must not be added as an exact decomposition.
Server conversion/kernel are inside round-trip time. Packing alone exceeds the entire
Python reference calculation. Each snapshot transfers approximately 1.4 MB of query
records and 178 KB of results; repeated starts and object geometry are packed per query.

Startup through first response, after fixture loading: Julia 0.511–0.514 seconds;
Python first calculation 0.0080–0.0084 seconds. This is not full process cold time and
must not be compared directly to J2's cold harness measurement.

## Memory and allocation

Python parent peak RSS: 138,808–138,852 KiB. Bridge controller peak RSS:
140,156–140,312 KiB; Julia server peak RSS: 311,072–311,508 KiB.
Maximum sampled simultaneous parent-plus-server RSS is 450,748–451,656 KiB
(about 441 MiB). This is an after-batch sample maximum, not an exact simultaneous
process-tree peak; independent peaks are not summed.

Server conversion plus kernel allocates 1,588,048–1,612,808 bytes per batch.
GC time is nonzero in 95 of 1,350 timed samples, with maximum 1.124 ms and median zero.
The server allocation measurement excludes response serialization; full latency and
RSS still include the bridge. Python has no directly comparable allocation counter here.

## Decision

This flat-record bridge is a no-go for production: full batch latency is approximately
twice Python, despite a fast Julia kernel. It does not justify a Julia World backend,
nor does it show that Julia itself is unsuitable.

A subsequent experiment could reduce repeated data and Python per-query rebuilding
by transferring compact snapshot/object arrays, or separately measure an embedding
boundary. Neither alternative is implemented or measured here. Preserve the current
World semantics and stop at J3 review before selecting the next experiment.

## Evidence

Local downloaded evidence directory:
`outputs/julia_migration/cloud-38217670361/` (ignored generated artifacts).

- `snapshots/manifest.json`, `baseline_summary.json`, `observed_summary.json`
- `snapshots/shadow_correctness.json` and nine binary query/expected pairs
- `benchmark/comparison.json`, `processes.json`, ten process result files
- Raw timing/resource output and cloud logs

Downloaded `artifacts0.zip` SHA-256:
`3ad32fcb0f4c8b4d5e3476f0e1272e212aa844fe0542d389723cf213b4e12a61`.
Cloud artifacts have 14-day retention; the downloaded raw evidence is retained locally.
