# Cruise-cost diagnostic

Baseline `8bfe2db`. Do not change production or experimental model rules, state
representation or copy ownership. Measure the existing typed pressure_update.

Prepare 3/16/64 accepted records outside timing, using the prior mixed-result
workload and two targets. Compare one update with the same full input (zero new)
against one update with that history plus one explicit refusal for target b.
Both start from the same previously accepted state. Each sample starts from this
unchanged state; it is not a growing series of repeated new events.

Count actual yielded input records through an AbstractDict wrapper outside the
timing region, then compare its result with ordinary uninstrumented input. Verify
old input/state preservation and returned-state independence for both cases.
Benchmark the ordinary input only, 30 samples, evals=1, two-second cap, warmed
single-thread Julia. Alternate zero/one order for the middle history size.
Record median time, all samples, cumulative allocation bytes and scan count.
No full-loop, RSS or copy-time percentage claim. Setup and JSON output excluded.

Run existing A1/A2/terminal/A0 checks in the same cloud workflow. Stop at diagnosis;
returning the original mutable state or sharing mutable history is not authorized
by this measurement contract.
