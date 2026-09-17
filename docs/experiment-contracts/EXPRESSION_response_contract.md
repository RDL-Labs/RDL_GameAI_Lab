# Derived Response Expression

`runtime/expression.py` derives a display-only reaction from an already formed
action decision and its body/history/profile trace. It has no action authority,
does not read or change canonical E/H, and does not infer psychological emotion.
This is a minimal observable expression layer, not a complete affect model.

## Mapping

| Label | Rule, in priority order |
|---|---|
| restricted | Reported movement capability is zero |
| feeding | The selected action is eat |
| acquiring | The selected action is pickup |
| engaged | The selected action is approach |
| holding | Idle with at least one history-deferred target |
| observing | Other current idle decisions |

Factors remain separate: `movement-limited` for a reported scale below 1 and
`recent-no-progress` for history deferrals. They may coexist. Approaching a
different target may be engaged while retaining a no-progress factor. Missing
body data is unknown and does not itself imply a restriction or health.

## Provenance and Lifecycle

`inspection.expression` includes `response-expression-v1`, source observation
ID, optional body snapshot/profile IDs, and the exact deferred history record
IDs. Derivation uses only the decision trace, not a new read of mutable history.
The optional history policy derives expression after final body constraints
and caches the result with the decision. Replay therefore preserves its basis.

Expression is a pure projection: it copies the response and cannot modify the
action, history, body, profile, frozen M_B or H. It describes the decision-time
response, not whether the subsequent world resolution succeeded. No expression
is fed back into the policy, unresolved review, or H.

In Runtime mode Inspector shows `reaction` and contributing `factors` instead
of the unrelated mock mood. Decision Record exposes profile/body/history IDs.
Pending or different-agent decisions are not shown as the selected agent's
current reaction. Mock mode keeps its existing mock mood.

## Verification and Remaining Scope

Five Python tests cover basic expression mapping, history/profile differences,
coexisting body/history factors, pure non-intervening derivation, and different
expressions at equal H=0. Actual Godot/HTTP tests assert Inspector parsed text
for restricted, engaged, holding and feeding responses. Current suite status is
recorded in [runtime evidence](../experiment-evidence/CURRENT_v23_runtime_evidence.md).
Visual layout has not been inspected interactively.

This does not establish fear, joy, attachment, social affect, animation, learned
expression, or H-derived emotion. Those require additional operational criteria.
