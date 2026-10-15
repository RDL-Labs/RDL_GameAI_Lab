# Latest LW thirty-day acceptance and geometry optimization

Date: 2026-10-14. Reference runtime d49e2de; optimized runtime966949d.
Both use the existing native -> run_integrated -> lw_day entry.

## Evidence

Reference Actions38376126204 and optimized Actions38423218244 each ran
seeds20261004/20261005 for30 days and replayed the frozen inputs.
Saved specs and result.json match byte-for-byte between reference and optimized
runs for both seeds; each replay also matches. Independent audit checks daily
and terminal food conservation, nonnegative quantities,1,555,200 operations per
case, finite bodies, final/night terminal correspondence and purpose bounds.
This is finite combined acceptance, not canonical T1 or complete Python parity.

| Seed | Reference call seconds | Optimized call seconds | Allocated bytes before / after | Optimized peak RSS bytes |
|---|---:|---:|---|---:|
|20261004|8284.235|1519.862|8573591544624 /361993211608|1383493632|
|20261005|9274.310|1084.617|8559522697928 /348015902608|1545805824|

Calls include compilation, exclude serialization. Different cloud jobs and one
sample each limit causal performance claims. Cumulative allocation is not live
memory. Workflow elapsed55 minutes includes setup and replay; reference315 minutes.

## Living learning

Sleep model selection changes: seed04 A21514/B4336/C18444;
seed05 A24/B895/C25695. Sleep model waking occurs3 times for seed04 B.
Experience-bundle waking totals87 and71 respectively. Counters are not independent
causal benefit trials. Dormancy remains visible and no efficiency claim is made.

Conservation: seed04 124+122=117 ground+83 shared+0 held+46 consumed;
seed05 124+82=105 ground+61 shared+0 held+40 consumed.

Local optimized seed05 also completed30 days in1517.970 wall seconds without
an access violation; its audit passes and result.json matches optimized cloud.
This one completion does not establish a fix for the Windows native crash.

Raw audits: outputs/julia_migration/cloud-38423218244/independent-audit.json
and outputs/lw-optimization/optimized-thirty-day/independent-audit.json.

## Remaining migration boundary

Goal threshold configuration is a separate change, excluded from these runs.
Optional Python lateral near-tie configuration still needs a native contract and
verification; arbitrary candidate handedness is not equivalent to component-wise
terrain eligibility. Backend-switch judgment remains open until that coverage
and packaging audit is resolved. No new living simulation loop is required.
