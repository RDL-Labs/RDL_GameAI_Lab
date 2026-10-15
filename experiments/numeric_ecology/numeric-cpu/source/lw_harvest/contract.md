# B1c finite harvest Sleep intake

Baseline 6632c7c. Reuse the B1b two scenes and three-day continuous loop.
This is a local Julia adapter of runtime/harvest_sleep.py and
runtime/harvest_predictability.py, not canonical T1 reproduction.

Only an accepted actual pickup attempt creates a record, paired with its
pre-action observation and the next actual observation before another action.
The learned question is acquisition plus continued nearby observed affordance.
No resource stock, World coordinates, or site ID enters the learning record.
The scaffold's visible resources expose their appearance (default fixture
brown_capped_ovoid); near <=1.25, present visibility-only list max5 is retained.
Counts are observed list counts, not world resource counts. Complete here means
the fixed scaffold observation, not OBS coverage parity.

Keep the earliest six operation records per agent across days. No successful
subset replacement. This is a fixed experiment learning window, not long-term
memory or a universal receipt service. Same retained operation is idempotent;
conflicting/foreign/unaccepted results reject. Later operations are not retained.
Freeze materials on first actual night rest. Existing rest receipts trigger
inspection at completion, including the final second. Safety interruption resets
rest. Frozen material and explicit night snapshots do not mutate later.

First3 formation / next2 held-out validation. Incomplete observations defer;
any failed acquisition or lost affordance rejects. A real observed count change
is required, following the existing inspector's input boundary. Earliest
counterexamples remain; rejection persists. No five-independent-sites claim.

LOCAL_ADOPTED is a local model, NOT canonical ADOPTED: canonical count-difference
assessment, T1-A/B/C and cutover are not ported. General cross-action Sleep is
also unported and explicitly marked. A model predicts only under currently
observed near affordance, otherwise unknown. Prediction is evaluated during
later living observations and counted with first source/time; it has no new
action authority. This step closes material -> Sleep -> next-day interpretation,
not learned movement bias. Off/on actions must remain unchanged for this scope.

Test held-out failure, incompleteness, missing count difference, insufficient
evidence, timing, receipt ownership/replay, frozen evidence, interrupted Sleep,
near/absent/future predictions; run both scenes off/on for three continuous days.
Do not require natural model formation or adjust coefficients to manufacture it.
