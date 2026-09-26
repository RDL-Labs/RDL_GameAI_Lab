# Luanti L8 Multi-Agent Separation Evidence

## Commands

```powershell
python -m unittest -v tests.test_luanti_outcome
python -m unittest discover -s tests
& .\integrations\luanti\scripts\test-l7.ps1 -LuantiRoot D:\luanti
```

## Result

The focused suite ran two agent-owned Luanti fact-event cycles in one outcome
coordinator and one canonical sidecar:

```text
npc_a -> Experience A x3 -> Sleep A -> Candidate A -> M_B'A -> REENTERED
npc_b -> Experience B x3 -> Sleep B -> Candidate B -> M_B'B -> REENTERED
```

Each expanded bundle contained exactly three same-agent Experiences and three
same-agent projected candidates. Both `M_delta` states resolved independently,
and each active model retained only its own candidate provenance. An explicit
cross-agent Sleep-result request was rejected.

The real single-agent L7 Luanti 5.17.0 regression was rerun after the API became
explicitly keyed. Concurrent autonomous A/B movement inside one Luanti World is
outside this Runtime/adapter evidence.
