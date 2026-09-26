# Luanti L0-L2 Bridge Evidence

## Environment

```text
Luanti 5.17.0
LuaJIT 2.1
Windows 11
Python Runtime bridge on 127.0.0.1:8765
```

## Commands

```powershell
python -m unittest -v tests.test_luanti_bridge_contract
& .\integrations\luanti\scripts\test-l0-l2.ps1 -LuantiRoot D:\luanti
```

## Result

The contract suite passed four checks: initial observation to `approach`, changed
within-reach observation to `pickup`, finite/no-interpretive-label packet shape,
and source packet immutability.

The real headless Luanti test then produced:

```text
L0 fixture ready
-> finite HTTP observation
-> Runtime approach ordinary_food_1
-> Luanti movement resolution
-> subsequent within_reach observation
-> Runtime pickup ordinary_food_1
-> Luanti pickup_succeeded at tick 3
```

Evidence marker:

```text
[RDL_LUANTI_EVIDENCE] pickup_succeeded target=ordinary_food_1 tick=3
```

The first run exposed a Lua empty-table JSON type mismatch. Luanti 5.17 encoded
empty tables as `null`; the adapter now preserves schema-declared empty arrays
and the empty rescue-delivery object before transport. The successful run used
the corrected packet on the real HTTP path.
