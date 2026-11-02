# Fixed-food day 10: first return breakdown (2026-11-03)

Source run: `outputs/navigation-nondepleting-10d-20261103`.
Replay: `outputs/navigation-breakdown-20261103`, day 9 checkpoint.
`navigation_breakdown_replay.jl` instruments an in-memory copy of frozen day.jl;
the original checkpoint/input/code validation remains enabled. Full result JSON
value-tree equality with the original run passed. No RNG calls or policy changes.

## First breakdown

Home is (0,6); coordinates below are observer diagnostics, not extra agent input.

- B at 164168 seconds: selects `mb_chunk:home:1833e639003c38d0`, observed
  `ochre:near:0`, recognition confidence 0.06164129394692649. Its 11-edge route
  is `home:e3cbb81305f1bd22`. After movement position is (12.8841,-8.1797).
- At 164169: cursor advances to 2 but next route correspondence has no eligible
  node. A recheck scan follows. Skyline-directed local repairs move it toward home
  but cursor stays 2. All these operations report `performed`, not collision failure.
- At 164172: four operations have been evaluated against progress 1 and allowance
  3 (`min(actions, progress+1)+1`). Child delay pressure becomes 1. Parent delay and
  stagnation remain zero; its child_debt grows 1,2,3,4. At 164175, H=4 and the route
  is abandoned after 7 operations, before the full-route estimate of 11 operations.
- C at 164162: selects a scan-led 8-edge return chunk from `green:far:0`, confidence
  0.5 (one shared feature). Next-step correspondence has no eligible node. Skyline
  local repair and scans leave cursor 2. H starts rising at 164166 and reaches 3;
  at 164168 it changes route after 6 operations. Initial location near (18.0177,12.8681).

The first H increases come from child progress lag, not parent's whole-goal timeout,
food depletion, or blocked physical execution. One-feature confidence is not a
probability of correct location. Weak evidence is allowed by design; this is not
proof that every selected historical route was physically wrong.

## Amplification and limits

Day 9 -> 10 detailed correspondence counts: A 1654 -> 1096, B 4325 -> 179195,
C 23087 -> 85029. Walking operations: A 134 -> 89, B 75 -> 1208, C 196 -> 437.
Final retained 64 route outcomes for B are all home: 44 changes, 19 abandonments,
1 local_repair; C: 45 changes, 18 abandonments, 1 local_repair. These are bounded
tail records, not complete daily outcome counts. Both ultimately returned.

There is a design asymmetry to investigate: initial matching permits weak partial
correspondence, but local rejoin requires agreement >= .65 and an endpoint score
margin >= .1; until it passes, progress stays fixed while recheck/repair effort
continues to count. H expands retrieval breadth and route replacement options.
The trace establishes the sequence, not a counterfactual performance attribution
to either threshold alone. Do not fix this by banning all weak matches.

Day 9 Sleep removed no nodes/edges. B's 277-node eviction happened at day 10's
end (169920 seconds), after the return breakdown and delivery, not before it.

Next investigation: retain tentative route progress/uncertainty, distinguish
verification work from observed lack of goal progress, and compare against this
same checkpoint before changing policy. No behavior fix was made in this audit.
