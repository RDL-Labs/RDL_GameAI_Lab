# Luanti L6 Sleep / Deep Candidate Evidence

## Commands

```powershell
python -m unittest -v tests.test_luanti_outcome tests.test_local_bias_profile tests.test_local_bias_deep_similarity
& .\integrations\luanti\scripts\test-l6.ps1 -LuantiRoot D:\luanti
```

## Result

The focused suite passed 15 tests. One Runtime and one real Luanti 5.17.0 World
then completed three bounded outcome cycles for `npc_a`:

```text
attack 1 -> Experience / Gradient / Bias -> target release
attack 2 -> Experience / Gradient / Bias -> target release
attack 3 -> Experience / Gradient / Bias
explicit Sleep request
-> three Local Bias Profiles
-> pairwise Similarity Observations
-> one shadow CandidateRelation
```

Evidence result:

```text
L6 PASS: candidate=974bacb9d7e025d73d2e4fb273c83c594b41102c755d8058dbbedc09db6b8f45 support=3
```

The candidate retained three distinct World event IDs and the common negative
acquisition, return, and injury relations. Insufficient-profile rejection and
non-promotion boundaries were verified by the focused tests.
