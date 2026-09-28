# L15A — 30-day landmark return campaign

Status: PHYSICAL RUN COMPLETE / CLEAN TIMING ACCEPTANCE FAILED.

2026-09-28. Baseline `85a6950`; run `l15campaign-cb6ab1268a7d`.
The saved artifact includes exact control-source SHA-256 hashes. This is one continuous
A/B/C World, not thirty fresh starts and not a speed comparison.

## Conditions and observed result

The predeclared limit was 30 days × 64 simulated seconds, or three returned batches
across A/B/C. Each agent/night contributes at most one batch. Only previously uncounted
actual pickup operation IDs count; holding the same inventory on later nights does not.
The observer audits a radius-10 region around the tower. Its coordinates and arrival
judgment do not enter the navigation policy. There is no teleport or inventory deposit.

- 30 days completed; `time_limit`, **1 of 3 return trips**.
- B picked up **12 units on day 9**, then returned within the audited region that night.
- A/C collected zero; remaining World resource stock: 84 of 96.
- 7,680 observations/results per agent; 23,040 total.
- The return batch was checked at 568,023,827 µs, at horizontal tower distance about 8.943.
- Requested speed: 1.5. Body-run wall time: 1,280.545 seconds; export/replay time is additional.
- Maximum World step: 247,236 µs. Maximum pending: 8 per agent.

The three-trip early-stop branch was not reached in this World run. Local counting tests
cover fresh batches, aggregate count, duplicate inventory, and the three-trip cap;
these are not an actual World three-trip completion example.

## Timing limitation

The initial strict replay exited 1: **86 expired and 5 stale commands** violated the clean
transport criterion. A: 24 expired; B: 27 expired + 3 stale; C: 35 expired + 2 stale.
The actual run is retained rather than discarded or silently replaced. A diagnostic replay
can inspect it with `require_clean_transport=False`; the default remains strict. The
campaign summary explicitly records `strict_acceptance=false`, and the runner exits 1
when this flag is false even if the remaining structural checks pass.

This run does not establish clean 30-day operation at 1.5×. Nor does the lack of later
harvest prove that the policy alone caused stagnation. Goal-budget waits and landmark
blocking are present, but transport timing is a confound. Speed/cadence was not adjusted
mid-run, and no budget was reset to manufacture additional returns.

## Validation and scope

The checker replays every HTTP request and response against Runtime and checks body
continuity, action identity, resource conservation, observation slots, individual
separation, skyline geometry, and stationary nights. Return batches are independently
reconstructed from World pickup IDs and actual night waits. Diagnostic timing exceptions
do not bypass those checks or grant expired commands action authority.

Dedicated/related regression: 68 tests (campaign, day cycle, reversal review, task
deadline, steering, finite rest, portability, goal reassessment). Full repository suite
not rerun. The previous three-day wire record produces identical decisions and state
with the campaign store-staging optimization. Existing agents keep ordinary deep-copy
staging; public snapshots remain isolated.

This preserves the previous day-cycle policy. Night record organization is not canonical
Sleep/T1, and this extension does not establish route learning, exact landmark identity,
or guaranteed return. See [contract](../experiment-contracts/LUANTI_L15A_return_campaign_contract.md).


## Saved artifact and replay

Full lossless World/Runtime record: `tests/fixtures/luanti_l15a_return_campaign.json.xz`.

```powershell
python -m integrations.luanti.tests.check_return_campaign tests/fixtures/luanti_l15a_return_campaign.json.xz --diagnostic
```

Omit `--diagnostic` to reproduce the strict timing rejection. A fresh run:

```powershell
python -m integrations.luanti.tests.run_return_campaign --periods 30 --speed 1.5 --output integrations/luanti/output/new-campaign.json.xz
```

1.5 reproduces the tested configuration; it is not a validated clean long-run speed.
No slower control was run for this result.
