# LW-0/1: planar World adapter

Status: finite implementation, three-agent / three-day acceptance. Different World from Luanti; not a physics or sensor equivalence claim.

## Boundary and correspondence

`integrations/lightweight/world.py` calls ReturnCampaign configure/observe/result/finish directly. Runtime, learning, steering, day budgets and model authority are unchanged. The existing wire model/profile names are compatibility vocabulary; the run manifest identifies the actual sensor implementation as `lw-planar-rays-v1`. Do not mix these records into Luanti sensor evidence as if acquired by the same implementation.

| Input | LW implementation |
| --- | --- |
| capture_us / sample_seq | integer clock, one observation per 250,000 us slot |
| body pose/revision | individual receipt chain; movement/turn/pickup increments revision |
| ground | nine local surface probes; occluded cells unknown, coverage partial |
| Food | forward half-plane, radius 12, line of sight, nearest five; overflow partial |
| distant | finite horizontal ray hits projected to four features; overflow partial; unsupported colors unknown |
| landmarks | 13 horizontal rays, 15-degree spacing, maximum range 48 |
| skyline | 13 rays at each of 0/15/30-degree elevation, height-aware occlusion, range 48 |
| movement_surface | five one-unit swept-clearance probes, seven obstacle rays of range 12 |
| action | existing move/turn/pickup/wait commands; measured planar outcome |

One distance unit corresponds to the existing one-unit move. Positive yaw is body-right; forward at yaw zero is +z. Bodies have a 0.2-radius collision margin against solid circular obstacles. No agent-agent collision in this version; shared stock still competes. World is an unbounded flat plane with finite objects. There is no gravity, slope, step, night visibility change or auditory emulation. The tall tower is physically obstructive and occludable, not an omniscient navigation beacon.

All packets for a slot are captured before any commands execute. A/B/C results execute in fixed agent order at capture+1 us and are admitted before the next slot. Discrete instantaneous body steps are an approximation, not realistic movement duration. This deterministic order can bias simultaneous resource competition and is recorded by JSONL order. No network fault claim is made.

Only visible material handles, body-relative geometry and observed feature descriptors reach Runtime; resource stock and World positions stay in experimenter logs. Material handles are per-agent opaque references assigned from World-private identity; they do not encode coordinates. Learned semantics and movement choices stay in Runtime. The statue supplies only the existing edible appearance statement.

Returns count fresh acquisitions at the first qualifying night wait within radius 10 of the base (0,6), consistent with the existing campaign audit region. Counted batches are unloaded into the experimenter-side base accounting and never counted twice. This does not introduce deposit learning. No teleportation or reverse-path navigation. The campaign ends at three returned batches or its day budget. The current Runtime's inventory-capacity rule counts cumulative acquisitions and remains unchanged.

## Storage and validation

Append JSONL manifest, observation/command/result/body rows, daily summaries and final summary. Each complete line is flushed. Interrupted logs retain a readable prefix; a missing summary is not completion. No per-tick full Runtime snapshot is exported. Runtime itself still retains finite histories, so long-run memory performance is not guaranteed by incremental output.

Tests cover occlusion, unseen stock changes, per-agent material references, swept collision, idempotent effects, conflicting operations, stale/cross-agent commands, resource competition/depletion, non-duplicated return batches, tower height/range and deterministic one-day replay through real Runtime.

p5 replay remains LW-2, not implemented here. Goal H remains LW-4. Night review is the existing local review, not canonical Sleep. Luanti acceptance remains separate.
