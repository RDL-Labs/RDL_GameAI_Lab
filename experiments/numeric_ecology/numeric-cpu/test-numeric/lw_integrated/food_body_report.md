# Basal metabolism, hunger and own-food retention

Code4dea416. References: SocialWorld.advance_metabolism, hunger_review,
personal_food and food_retention. Native --food-body on, default off.

Every accepted one-second native interval charges0.25*RESERVE_SCALE basal reserve
loss, including rest. It clamps at0, does not replenish burst and does not create
food. Daily loss without depletion is16. Native ordering charges at interval end
before daily final snapshots; the Python asynchronous scheduler charges before its
completion pass. Behavioral equivalence is intended, not identical operator order.

Actor-local hunger compares reserve>80 after five seconds; unresolved H increments,
confirmed sufficiency resets H. Existing eat/retrieve/request proposals are used
when0.2+intensity+min(1,H/2)>0.5. No hidden future supply is used. Intensity equals
0.05+0.95*(80-reserve)/80 below/equal80. Diagnosis keeps32 latest comparisons and a
total count; unlike reference's retained full record dictionary, old source details
are not all retained. This explicit bounded-storage adaptation does not change H.

Food bands:none/low(1–2)/some(3–5)/many(6+). Provisioned exploration may rest when
currently satisfied and carrying at least3. Active return purpose still has priority;
a food action does not cancel it. Hunger is not canonical Core E/H or T1.

Food-body mode uses the existing experience response path, subtracting
scarcity*(1+2*need+pressure) from give score; no absolute giving prohibition.
Other priority gates (current threat/messages) precede ordinary food selection.
There is no new starvation/death physiology, predictive provisioning, causal
attribution or conjunction-bundle implementation in this increment.

Three-day comparison with social response and general Sleep apply/retention/
maintenance enabled. Cloud verification38350446585 passed40 assertions (safety16, local13,
integrated8, living3). Each condition155520 operations; all9 Sleep cycles complete.

| Metric | Off | On |
|---|---:|---:|
| Initial / added |100 /95|100 /19|
| Ground |48|83|
| Stored A/B/C |89/6/41|6/14/4|
| Carried |5|0|
| Consumed |6|12|

Both ledgers conserve. Basal loss per actor48 (floating tolerance1e-6).
Hunger comparisons A35/B6/C220; terminal H0 in all three after sufficiency.
Reserve A92.2552/B88.3292/C89.6325. Lower stored food is not a regression against
an optimization target: current sufficiency now permits resting instead of
collecting indefinitely. Metabolism,hunger,retention/provision rules are combined
here, so changes are not assigned to one coefficient. No efficiency claim.

This remains one seed/three days. The complete multi-feature30-day campaign,
measured peak memory and broader social/terrain/safety parity remain outstanding.
