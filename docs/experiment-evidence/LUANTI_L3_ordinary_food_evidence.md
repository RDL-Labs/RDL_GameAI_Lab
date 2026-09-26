# Luanti L3 Ordinary Food Evidence

## Commands

```powershell
python -m unittest -v tests.test_luanti_l3_contract tests.test_luanti_bridge_contract
& .\integrations\luanti\scripts\test-l3.ps1 -LuantiRoot D:\luanti
```

## Result

The focused contract suite passed six tests. The real Luanti 5.17.0 server then
completed the same sequence over localhost HTTP:

```text
tick 0: low-stock cue + visible ordinary_food_1
-> approach Food
-> pickup Food
-> approach Base
-> deposit at Base
-> POST /v1/life-result
-> existing Runtime causality admission
```

Evidence marker:

```text
[RDL_LUANTI_L3_EVIDENCE] deposit_accepted base=base tick=7
```

The packet exposed `low` and `at_base` relations while the exact Luanti stock
value remained private to the World adapter. No Luanti-specific Runtime policy,
canonical mutation, Sleep, T1, or Dynamic M_B path was introduced.
