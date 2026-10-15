# Bundle parent-trial credit connection

Source `8161368`, reference runtime/bundle_credit.py.
[Actions 38361602607](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38361602607):61 checks PASS.

Native hunger comparisons now retain trial_due_us. This identifies the current
five-second parent trial within one actor/run; no global external receipt identity
is claimed. Before action, freeze actor,due,H. A changed bundle selection with an
accepted matching operation admits at most one contribution set per trial.
Subsequent parent comparison gives min(8,frozen H) only if reserve>80,shared across
contributors; each strength caps at8. Failure gives0. Later projection uses the
same bounded strength factor as Python. No child success alone resolves parent.

Nine local checks cover sharing,replay,wrong method,expired result,failed parent
and owner mismatch. Existing46 bundle checks rerun;4 living invariants and2 credit
bounds added. Four days each: bundles off,on,and on+credit. Seed20261005.

Living credit: A five resolved parent trials,zero reinforced,zero pending.
B/C no credit trials. Success distribution is verified locally,not observed in
this living condition. Credit on/off stock and food balance remain identical:
100+37=ground78+stock44+consumed15. No claim of behavioral improvement.
All three runs completed207360 operations. Parent credit is local GameAI material,
not canonical T1 or proof of causal attribution. Selection trails remain unported.
