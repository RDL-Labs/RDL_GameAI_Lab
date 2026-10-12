# B0 continuous day: lifecycle connected, LW navigation still missing

**Verdict: lifecycle scaffold passed; not yet an LW reproduction candidate.**
Code `71396744c35c0ea607f70f6b596a57754c07e438`.
[Cloud run 38246309298](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38246309298)
completed; 10 assertions PASS. Ubuntu24.04 / Julia1.13.1, one thread.

Both scenes ran all 17,280 simulated seconds, three agents / 51,840 actions,
without the A2 night jump or daily reserve subtraction. Every second conserved
ground + carried + private stored + consumed food. All six agents completed
accepted night rest and local social consolidation. Sleep completion does not
mean a harvest relation was learned: that branch remains insufficient evidence.

| Scene / agent | Successful pickups | Carried at end | Private stored | Distance | Final reserve |
|---|---:|---:|---:|---:|---:|
| social_shared A | 4 | 3 | 0 | 3199.5 | 83.36 |
| social_shared B | 4 | 0 | 6 | 3420.5 | 84.27 |
| social_shared C | 4 | 4 | 0 | 3132.0 | 83.09 |
| lw_sparse A | 33 | 0 | 30 | 3406.5 | 84.21 |
| lw_sparse B | 4 | 0 | 6 | 3420.5 | 84.25 |
| lw_sparse C | 4 | 0 | 6 | 3420.0 | 84.25 |

Successful pickups are reconstructed from compact action/status intervals, not
raw pickup attempt counts (social_shared B/C each attempted five times).
social_shared: initial16 = ground0 + carried7 + stored6 + consumed3.
lw_sparse: initial100 = ground55 + carried0 + stored42 + consumed3.
Only the owner can deposit/retrieve private stock. Retrieval was not exercised
in these runs; storing food is not proof of later eating from storage.

social_shared A made eight requests; B refused six times, C gave twice.
lw_sparse A made three requests, all refused by B. A retained 8 / 3 accepted
social records respectively; B/C retained no own request records. This is
experience intake and local Sleep adoption, not demonstrated next-day behavior.

## Exposed missing connection

All agents ended far from camp. B deposited once in social_shared; A/B/C deposited
5/1/1 times in lw_sparse, then resumed outward exploration. In the scheduled
return interval the unseen-home branch only scans. social_shared agents each
scanned 5,760 times; sparse agents 5,768 / 5,761 / 5,763 times over the day.
They subsequently slept where they were, with no teleport.

This is a known limitation of the B0 provisional navigator, **not evidence that
existing Python LW lost its recovery behavior**. Importing geometry and body
primitives alone does not import nested M_B navigation. Do not extend this
scaffold to 30 days or claim the old LW living system is reproduced.

Next B1 must connect actual LW goal/method pressure, lost-home exploration and
observed landmark/route selection. Current unseen-home scan cannot remain an
unbounded substitute. Then test three days and connect general Sleep/harvest
models separately. Preserve the compact recording route and continuous clock.

## Measurement and limits

Scenario call elapsed: social_shared 9.162s, sparse 1.482s. First call includes
compilation; these are not paired speed measurements. Cloud setup and artifact
transfer are excluded. No Python comparison, full suite, long campaign or
adversarial transfer test was rerun. Existing A2 defaults are unchanged.

Artifact `julia-lw-day` includes full compact transitions, final body/position/
inventory/private stock/Sleep/social/aid state, input clock/layout and source
hashes. Approximations and remaining subsystems are listed in [contract](contract.md).
