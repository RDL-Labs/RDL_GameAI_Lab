# Four-actor forecast growth audit (2026-11-03)

Original, pre-override-removal run: `outputs/navigation-four-180d-20261103-fixed`.
Read-only checkpoint samples: days 10,30,60,90,120,126,127,130,150,180.
Full extracted evidence: `forecast-growth-audit.json` in that run directory.
No simulation or policy changes during this audit. These are checkpoint model
forecasts for future trials, not necessarily the frozen estimate of an active trial.

## Home/search upper actions

| Actor (sensitivity) |10|30|60|90|120|180|
|---|---:|---:|---:|---:|---:|---:|
|A (.5)|1639|13003|18939|14714|10370|14454|
|B (.5)|4864|8675|12574|31052|62997|104782|
|C (1)|643|13759|80209|91655|38142|63948|
|D (1)|4044|7210|11148|15368|26034|42528|

At 17,280 operations/day, final budgets correspond to .84,6.06,3.70,2.46 days
of charged operations. They are not predicted wall-clock arrival dates. B's final
104,782 includes its failed terminal episode; the already-frozen estimate before
that episode remained 62,997. Growth is not monotonic in A/C because observations
are retained in a rolling 128-attempt window.

Final retained home/search observations (completed / censored): A20/108,
B15/113, C19/109, D14/114. Completion medians are only 1,3,1,1 operations;
these are model episode completions, not whole outbound-and-return journeys.
Largest censored action counts are 11563,83825,51158,34022. q80 is unidentified
for every final home/search model. Upper bounds therefore use the maximum observed
time plus max(4,25% of that time), rather than an observed 80th-percentile completion.

## Structural issue

`mb_parent_arrival_sync!` suspends search/route while approach runs. On approach
success it deliberately records the suspended episode as `completed=false`, reason
`location_confirmed`. Consequently successful navigation through approach does not
become a completed observation for the earlier search/route model. Calling this a
censored observation is not itself false (the question changed), but applying its
tail to a full-home-completion forecast creates an endpoint-definition mismatch.
Merely flipping all censored observations to successful would also be incorrect.

All final home/search models' largest observations except B's terminal pause are
dominated by `location_confirmed` (A also has purpose_switch). In contrast final
home/approach models retain 125–126 completions and only 2–3 censored observations.
Home/route models also show inflated normalized effort: at baseline one, illustrative
upper values A464/B3835/C15065/D2855. Those are normalized scale examples, NOT raw
operation budgets for every route. Actual budgets depend on the current baseline.

Food/search does not grow: A168 and B/C/D128 throughout these samples, but each
retains just one censored observation. This is sparse usage, not validated accuracy.
Food/approach has 102–122 retained completions and 6–26 censored observations at
day180; unlike home/search it is not uniformly dominated by censoring.

Rest counted as goal activity can extend observations without physical progress;
scene-count stagnation stops reacting after two scenes, and estimated energy uses
immediate operation cost rather than demonstrating feasibility against remaining
body reserves. These interacting issues need separate intervention comparisons.
First align forecast endpoints and attribution across search/approach, then assess
progress, reserve feasibility, and response to unresolved uncertainty. Do not infer
that sensitivity alone explains growth: C exceeded B at days60/90, and A/B differ.
