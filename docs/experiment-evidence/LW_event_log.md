# LW observer event log

Implemented: long_ground_campaign defaults to --log-mode events; --log-mode full
retains the diagnostic format. Direct timed_harvest.run calls retain their full
default for compatibility. Observation cadence, agent memory, learning inputs and
World dynamics are unchanged.

The event format omits periodic full decision/working packets, work-start rows
and hazard/patrol/territory tick samples. It records selection changes (method,
action, phase, gate, interruption and observed hazard content), source observation
and operation references, and movement intervals with start/end times, distance,
operation endpoints and count. A changed choice or nonmovement result terminates
the interval. Final summary flushes remaining intervals. A crash can leave the
last interval unflushed, but individual completed-operation receipts remain.

Small per-operation command/result/food-ledger receipts remain to permit exact
conservation and duplicate-effect audits. Metabolism/resource/social receipts,
daily maps and final snapshots remain; this is not a lossless full sensor replay.
Full-mode per-observation safety/refusal statistics are unavailable in event mode
and reported as null, not zero. Observers still receive original rows in memory.

Validation: 26 focused tests passed. A 20-second paired run produced identical
final simulation/learning state excluding wall time, identical action counts and
conservation/dedup audit results, and smaller event output. No long-run speedup
is claimed from this test. Internal observation/history retention is not reduced.


## Metabolic intervals (event schema v2)

Consecutive metabolic samples merge while timestamps, reserve endpoints and
per-agent rates agree (rate tolerance 1e-9 relative / 1e-15 absolute per us).
Intervals retain exact measured endpoints, rates and sample count. Reserve <=80
(the current hunger boundary), zero saturation, rate changes and external reserve
jumps split intervals. Daily ground snapshots and final summary flush them.
Food/body action receipts remain separate. This changes no metabolic calculation,
hunger evaluation or agent memory. An interrupted run can lose its unflushed tail.

Five focused tests passed, including paired full/event state equality, hunger
crossing, reserve jump, changing rate, saturation and final flush. Reprocessing
the saved one-day metabolic rows reduced 69,119 rows to 7,966 intervals (88.5%
fewer metabolic records). This is offline log reprocessing, not a new World run
or a measured total-runtime improvement. Body consumption frequently interrupts
linear reserve continuity, so those boundaries are intentionally retained.
