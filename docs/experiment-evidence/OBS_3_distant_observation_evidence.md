# OBS-3 Distant Observation Evidence

## Scope

Finite distant-vision reference using Luanti 5.17.0 and the existing isolated
sensory frame store. Audition, p5 display, identity fusion, behavior influence,
and general visual recognition remain outside this evidence.

## Real Luanti Vertical

Command:

```powershell
./integrations/luanti/scripts/test-distant-observation.ps1 -LuantiRoot D:\luanti
```

Observed result on 2026-09-26:

```text
OBS3 PASS: frames=2 visible_first=1 visible_after_turn=0 occluded_hidden=true
```

The first accepted frame contained only the unoccluded `muted_red` coarse
feature. A dark fixed object behind an opaque wall was not emitted. The fixture
then turned the same observer by 180 degrees; the second accepted frame had no
features. The stored frames contained none of `world_position`, `distance`,
`target_id`, or fixture object names, and the Runtime rejection count remained
zero.

The singlenode fixture explicitly constructs only the finite voxel corridor
needed by this test. Ray traversal treats unavailable voxels as incomplete and
does not emit such a sample as evidence.

## Automated Checks

- full Python suite: `322` tests passed, `46` intentionally skipped
- strict Runtime schema accepts only coarse observer-local feature fields
- exact coordinates, distance, and target IDs are rejected
- Luanti package/config/harness assets are tracked
- the channel remains opt-in under `fixture-distant-enabled`

Existing real-Luanti RW2, L0-L2, L3, and L7 verticals also passed after OBS-3
was added. Their action, causal result, and Dynamic `M_B` boundaries were not
changed by the new channel.

OBS-3 establishes distant observation only. It does not establish recognition,
belief, salience, goal formation, trajectory selection, or action change.

