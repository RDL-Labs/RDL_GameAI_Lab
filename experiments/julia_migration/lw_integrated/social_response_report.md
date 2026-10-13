# Julia LW own-experience social response

Code `e411f5a`; [run38342310243](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38342310243)
passed 39 assertions: safety16, local response9, integrated invariants12,
living response2. Initial run38342185190 failed a Julia numeric-literal parse;
corrected before this successful run. Not repository-wide acceptance.

## Scope

`--social-response experience` ports the respond branch of
`runtime/refusal_relation_field.py`: own explicit refusals are paired with the
actor's existing aid-method H evidence. Weight is min(2,0.6*maximum H_after).
No-response and unexecuted requests are not explicit refusal evidence. Current
bodily need is max(0,(80-reserve)/40). Giving score is 1-need-weight, refusing score
zero, with softmax and deterministic SHA256 selection per current request/time.
No inventory means no giving. Existing physical delivery authority still decides
whether transfer occurs. The seed does not require a new random draw on replay.

This removes the fixture's fixed B-refuses branch in the opt-in mode; legacy is
the default. Only currently observed partners' requests use the field; other
message handling retains the existing response function. Safety retains priority.
No inferred intent, affiliation, food-retention/hunger-H projection, or request-
again field is added. The experiment uses affiliation zero and no retention cost.
The fixed use rule is not itself learned. Whole-history scanning occurs only on
response opportunities, not every observation. Diagnostics retain32 decisions.

Existing social Sleep still forms own-request expectations after completed rest;
this does not port general Sleep, candidate discovery or canonical T1. Those remain
next integration boundaries, rather than being claimed complete here.

## Execution

Native seed20261005, three days, renewable food, other optional adapters off:
legacy/experience both have155520 operations, stocks A65/B6/C53, carried B5,
and all nine Sleep cycles complete. There are zero response opportunities in this
layout. Ledger:100+107=72 ground+124 stored+5 carried+6 consumed. No behavioral
improvement or experience-driven response is demonstrated by this comparison.

Controlled one-day configuration co-locates A (reserve30, empty-handed) with B/C
(reserve90, four units each). Same native living loop, no injected memories.
B answers four requests:three give, one refuse. A receives three units and eats
three. A's four accepted experiences enter the existing Sleep consolidation;
its expectation for B becomes(1+3)/(2+4)=2/3. All three Sleep cycles complete.
Final stocks A5/B6/C6, no ground or carried food:20=17 stored+3 consumed.

B has no prior refusal experiences of its own here, so all four response weights
are zero. The influence of own refusal history on giving probability is supported
by local tests only, not this live scenario. Cross-day use of these newly formed
expectations was not exercised in the controlled one-day run. The local tests
also check lower probability under hunger, empty inventory, owner rejection,
repeatability and no-response exclusion. Downloaded summary food ledgers were
recomputed locally. Execution times include differing compilation states and
are not a speed comparison.
