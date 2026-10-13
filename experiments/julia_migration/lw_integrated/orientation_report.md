# Initial sky orientation in native LW

Code `94fecf4`; [run 38352791451](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38352791451).
863 assertions PASS: 16 safety, 4 Sleep context, 831 Python-reference orientation,
8 living invariants, 4 bounded living orientation checks.

The adapter ports `runtime.initial_orientation`: 30-degree quantized relative
bearing, half-width 15 degrees, ideal unobscured sky, sun/shadow versus stars cue
selected from the current clock. No position, home coordinate, destination or
World map enters the policy. At most 256 prior observations plus the current one
are counted; other-day samples are excluded. Unavailable samples do not invent
headings. Duplicate samples do not increase counts; owner/clock/conflict checks
reject incompatible reuse.

Only an already selected non-safety survey is affected. The native baseline's
60-degree scan becomes the Python adapter's signed 90-degree scan, choosing the
less sampled heading and right on a tie. Thus off/on differs in both scan angle
and history-driven sign, not sign alone. No extra move or survey authority is
created, and safety scans retain their separate policy.

Native three-day seed 20261005, renewable food, mixed hazards, continuous safety,
food/body, general Sleep/retention/maintenance; running disabled:

| Mode | Added food | Ground | Stock A/B/C | Consumed | Sleep A/B/C |
|---|---:|---:|---|---:|---|
| off | 23 | 84 | 12/9/6 | 12 | 1/0/0 |
| on | 19 | 81 | 14/6/6 | 12 | 0/3/2 |

Initial food 100, final carried food 0. Both conserve food. On-mode records
51,840 samples per actor, retaining 257. Survey selections A/B/C=59/24/14,
left counts=30/7/10, right=29/17/4. This establishes living use, not reliable
return or an efficiency improvement. Different actual replenishment and later
interactions prevent treating stock totals as equal-supply efficiency.

Native option `--orientation off|on` defaults off for prior specs. The 30-day
campaign already running predates this change; final acceptance must include it.
