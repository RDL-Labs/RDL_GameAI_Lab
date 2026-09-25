# Territory Beast R4-R5 Evidence

**Status:** R4-R5 complete

## Reproduction

```bash
python -m unittest discover -s tests -p "test_territory_beast_world.py"
```

## Observed path

```text
outside radius -> outside_territory / ignore
enter at outer territory -> territory_entered / warning_observed
continue inward -> intrusion_continued / chased
persist within attack distance -> close_intrusion_persisted / injured
```

The successful attack produces only a finite World consequence:

```text
injury_level = medium
forced_retreat = true
incapacitated = false
```

No danger label, threat score, Experience, H, theta adjustment, or M_delta
transition is produced. A separate canonical sidecar remains byte-for-byte
equal before and after the complete World interaction.

Independent-agent progression, exit/re-entry reset, snapshot non-mutation, and
capacity rejection without eviction are also covered.

R6, combined 3-5 agent Experience evidence, remains next.
