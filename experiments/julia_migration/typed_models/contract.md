# Typed local model state — finite refactor

Baseline `bcbd706`. Change Julia GoalState and AidPressure only. Fields H/threshold
are Int, identity/model/dimension are String, methods store GoalState. Opaque parent
references retain their prior API, and heterogeneous trial/evidence remain owned
dictionaries. No rule, threshold, floating precision, boundary or admission changes.

An AbstractDict compatibility view preserves existing JSON output and boundary
fixtures. Calculation uses concrete fields. Deep-copy ownership is retained;
copy elimination and shared immutable evidence are separate possible experiments.
Social state, Sleep and body are not converted in this change.

Acceptance: independent Python/Julia A1 and A2 parity including nightly/final body,
A0 regression, plus Julia-native ownership tests. Updating later state must not
rewrite prior snapshots or caller input. No requirement to produce a speed gain.

Performance: restore original Julia file from pinned Git baseline. Same process,
locked Julia environment, one thread; warm both versions. Identical 3/16/64-record
incremental aid histories with successes, failures and unexecuted requests, two
targets and selection after each update. Trace parity is checked outside timings.
15 samples, maximum 2 seconds per size/backend, one evaluation/sample, baseline
and typed order alternated across sizes. Report median time and allocated bytes,
not peak resident memory, startup speed or full-LW speed. Preserve individual samples.
