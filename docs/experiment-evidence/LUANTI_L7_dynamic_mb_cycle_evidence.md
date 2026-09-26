# Luanti L7 Dynamic M_B Cycle Evidence

## Commands

```powershell
python -m unittest discover -s tests
& .\integrations\luanti\scripts\test-l7.ps1 -LuantiRoot D:\luanti
```

## Result

One Runtime and one real Luanti 5.17.0 World completed:

```text
three attack outcomes
-> explicit Sleep
-> support-3 shadow CandidateRelation
-> independent canonical comparison and explicit review
-> active M_delta
-> three relation-specific T1 candidates
-> explicit RETAIN / DEFER inspection
-> inactive M_B'
-> cutover
-> fresh REENTERED capture
```

Real integration result:

```text
L7 PASS: model=gameai-reconstructed-mb:efe6acd75e3ea532:v1 phase=REENTERED projected=3
```

The parent model was archived, the reconstructed model became active, and the
active `M_delta` count returned to zero. The first post-cutover capture entered
a fresh window without incrementing an inherited comparison count. Candidate
formation remained causally separate from canonical rupture formation, and no
game action authority changed.
