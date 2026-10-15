# Julia LW 30-day baseline

Source `4f82823`, [Actions 38352087950](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38352087950). Two seeds, each 30 continuous days and frozen-spec replay. Both result.json files independently compared byte-for-byte equal. Each execution: 1,555,200 accepted operations.

| Seed | Added | Ground | Stock A/B/C | Carried | Consumed | Completed Sleeps A/B/C | Final reserve A/B/C | First call seconds | Process peak MiB |
|---|---:|---:|---|---:|---:|---|---|---:|---:|
| 20261004 | 90 | 96 | 27/36/5 | 0 | 26 | 23/24/29 | 0.0/0.0/0.0 | 765.90 | 1110.5 |
| 20261005 | 184 | 96 | 60/2/77 | 0 | 49 | 18/29/19 | 0.0/0.0/3.523 | 765.64 | 1140.9 |

Food conservation independently checked. Completion does not establish sustainable living: depleted reserve and incomplete nights remain outcomes. The source predates limited safety release, return attribution, orientation, angular relation, request-again, body-field and movement-inertia updates. This is a baseline, not latest-head acceptance or backend-switch approval.

Timing includes compilation and excludes serialization. RSS is process lifetime high water, not retained model size. Cumulative allocations are roughly 295–306 GB per first call, not simultaneously resident memory. Replay calls took about 752–753 seconds. No matched Python speed comparison was performed.
