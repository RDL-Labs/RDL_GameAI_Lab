# L15A — Campaign timing diagnosis

Purpose: locate the wall-time interruption behind repeated missed acquisition slots,
without changing simulated clocks, learning, observations or action authority.

## Fixed run

Six agents, natural_meadow, steady profiles, eight patches of twelve units,
1x speed, thirty 64-second days maximum or six returned batches. Model-field and
current-harvest assessment enabled. One measured attempt follows a one-day smoke
check; failed attempts are retained, not replaced by a successful retry.

## Instrumentation

Opt-in `--diagnostics` / `-CampaignDiagnostics` / `rdl_campaign_diagnostics`.
The disabled path retains the original controller and sampling checks.

- Lua measures callback elapsed work in receive, return audit, sample, progress,
  send, and an unfinished phase on failure. These are intervals, not isolated CPU
  time: allocation/GC/OS scheduling inside an interval is included.
- Each of at most 32 day buckets holds counts, total and maximum phase times.
  A 128-entry recent ring samples at one-second simulation intervals or on a
  >=100ms step/work interval; a separate 128-entry ring retains slow entries.
- Lua heap is read with `collectgarbage("count")`, never forced collection. It is
  not process RSS or total engine memory. `dt` and wall gap since the previous
  callback end are distinct from measured callback work.
- Diagnostics are flushed once per day and before/after Evidence export. Flush
  cost is reported separately. Export time must not be attributed to the preceding
  agent action. Launcher waits for the after-export sidecar before terminating.
- Runtime wrapper measures only existing loop calls inside the HTTP lock, with
  bounded day/kind aggregates and a 128-entry slow ring. HTTP lock wait, JSON
  conversion and network time are outside that timer.

No measurements enter agent observations or model state. No skipped slot is filled,
no `dt` is clamped, no budget is reset, no forced GC or behavior tuning occurs.
Instrumentation has overhead; this is a diagnostic run, not an exact matched
performance comparison. A measured slow phase localizes work but does not by itself
prove a specific GC, OS, sensor or allocation cause.

## Verification

Check the real one-day smoke run, bounded records, wrapper response/state equivalence
and exception propagation. Preserve full World/Runtime even on an interrupted run;
replay the recorded prefix and distinguish it from clean campaign acceptance.
Run regression tests after World execution to avoid adding concurrent test load.
