# Luanti L5 Outcome Learning Evidence

## Commands

```powershell
python -m unittest -v tests.test_luanti_outcome tests.test_luanti_l4_contract tests.test_outcome_bias tests.test_territory_beast_world
& .\integrations\luanti\scripts\test-l5.ps1 -LuantiRoot D:\luanti
```

## Result

The focused suite passed 17 tests. The real Luanti 5.17.0 World then completed:

```text
tasty Food approach
-> warning
-> chase
-> attack
-> medium injury + forced retreat
-> POST /v1/luanti-territory-result
-> one direct Territory Experience
-> one Outcome Gradient
-> three Local Bias records
```

Evidence marker:

```text
[RDL_LUANTI_L5_EVIDENCE] experience_gradient_bias accepted=true biases=3
```

The read-only Runtime snapshot contained:

```text
acquisition: negative STRONG
return:      negative MEDIUM
injury:      negative MEDIUM
```

`reward_value` remained ZERO and formed no Local Bias. Replay, interpretive
label rejection, and canonical non-intervention were also verified.
