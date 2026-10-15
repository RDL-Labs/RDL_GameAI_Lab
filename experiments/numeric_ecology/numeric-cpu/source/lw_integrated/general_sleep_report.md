# Julia general Sleep: finite cross-action review

Code `11f903c`; [run38343444215](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38343444215)
passed45 assertions (safety16, review17, integration8, living boundary4).
Ubuntu24.04 / Julia1.13.1. Repository-wide acceptance and performance are not claimed.

## Scope and differences from Python

`--general-sleep review` adds a finite adaptation of
`runtime/sleep_relation_review.py` to the common native living loop. Default off.
Keep at most64 accepted operation records per individual; freeze the latest of
up to six distinct action/outcome strata at the start of a pending rest sequence.
A interrupted sequence with rest count reset to zero freezes anew on resumption.
Only the existing completed-rest callback publishes the review. Final accepted
rest works without another observation. Duplicate cycle completion does not add
a second review. Selected sources are copied, actor-bound and no later than
formation time. Maximum15 pairs per review; run duration remains1..4 days.

Compare actor/action/outcome/target/context as matches, differences or missing.
The simplified Julia record does not yet carry the Python food/hazard coverage
pair or full body/social observation. Context is therefore always missing here,
never assumed clear, safe or absent. Targets are only those explicitly in the
selected command (often missing for locomotion). No full structural schema/hash
parity is claimed. Missing data prevents any assertion of a complete relation
comparison. Action labels retain Julia execution semantics (`walk/performed`,
`rest/performed`, etc.), not remapped into fabricated Python Experiences.

Reviews are stored under `general_sleep`, alongside the existing harvest Sleep
result. They do not replace harvest consolidation, create independent support,
adopt M_B, change H, or bias choices. Automatic unvalidated action-model adoption,
body-context generalization, dormant bundles and subsequent use remain unported.
This is the general comparison entrance, not the entire general Sleep subsystem.

## Native three-day result

Seed20261005, renewable food, other optional adapters off. Both modes execute
155520 operations. All nine Sleep cycles complete. B's second and third nights
contain walk/performed and rest/performed:two pairs total. The other seven nights
contain only rest/performed and report insufficient_records. There are11 selected
records across nine reviews. No goal-relevance filter or injected daytime records
was used to manufacture diversity. The short recent-history window mostly captures
late rest; broader experience retention is a separate future integration issue.

Stocks A65/B6/C53, carried B5. Food ledger:
100+107=72 ground+124 stored+5 carried+6 consumed.
Downloaded result files are exactly equal after removing the `general_sleep` key.
Thus the review hook has not altered behavior in this configuration. Timings have
different compilation states and are not a speed comparison. Safety integration
uses the existing authority; this no-hazard run is not evidence of real nighttime
hazard interruption. Local tests check boundaries, source ownership/time, no
post-freeze contamination, missing context, bounded history, snapshot independence,
insufficient records and final-rest/replay completion.
