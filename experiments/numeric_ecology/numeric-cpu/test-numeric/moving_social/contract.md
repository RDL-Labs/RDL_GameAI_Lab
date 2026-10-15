# ALL Julia A2 — movement, observed contact and nightly social memory

Finite parity experiment, not a complete LW migration. Baseline `7e0548b`.
Compose A0's finite food-directed five-direction energy selection with A1's local
aid H and social consolidation. Production Python remains unchanged. No canonical
T1, full LW exploration, general Sleep admission, learned navigation or new H rule.

Three actors, three fixture days, 90 daytime one-second steps per day followed by
2880 one-second night rests. Omitted day intervals are not simulated. Positions,
food and histories persist across days: no teleportation or reset. Initial food
A=0/B=12/C=12, ground stock36; A reserve50, others100. The A1 daily reserve-minus20
stimulus is retained and declared, not natural whole-day metabolism.

Every step snapshots all actor observations first; plans are produced from these
snapshots, then actions resolve in A/B/C order at step end. One body/action per
actor/step. Resolve contact and stock again at execution. Position is a planar
point with obstacle margin. Agent collision is absent, as in A0; no rescue carrying.

Policy is explicitly experimental: reply to observed unanswered messages first,
then eat own food if hungry, await own pending request, choose an observed carrying
contact if hungry, pick up in-reach observed food, rest if provisioned, otherwise
A0 movement selection. This is not a port of the full SocialAgent priority stack.
Requests do not consume food. Given food physically moves and eating consumes it.
Targets come only from current finite contact observation; no global actor positions
are passed to policy. Food direction is finite body-relative observation.

Six preregistered layouts/conditions: enabled, no social Sleep adoption, B cannot
hear, obstacle, helpers farther away, interrupted night. No rule/threshold tuning
to force difference. The default B refuses and C shares when able, as in A1.

Record every daytime observation, candidate/choice, execution result, pose, body,
stock and local/social state. Compare Python production primitives + fixture
composition against a fully Julia-owned execution, then replay. Nightly terminal
states (including position, body and inventory), final actor states and explicit A1 Sleep boundaries are compared, not all intermediate night
states cross-language. No performance claim from correctness runtime.

Explicit contact boundary tests: within reach, outside reach, occluded, move into
reach; request then target moves away before response; old operation replay and
payload conflict. Non-contact is not evidence of refusal. Receipt replay must not
move bodies or food twice. Preserve food conservation and individual evidence.
Run A1 and A0 regressions after contact refactor. Stop at finite A2 report.
