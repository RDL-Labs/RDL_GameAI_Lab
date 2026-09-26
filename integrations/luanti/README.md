# RDL GameAI Luanti Integration

This directory contains the L0-L4 World backend references:

```text
Luanti World
-> finite observation packet
-> existing Python Runtime /v1/observe
-> finite action response
-> Luanti resolution
-> next finite observation
```

## Requirements

- Luanti 5.17 or newer. The local default is `D:\luanti`.
- Python available as `python`.

Luanti itself is not included in this repository. The install script copies only
the small `rdl_game` fixture into the selected Luanti tree.

## Run

From the repository root, start the Runtime:

```powershell
python -m runtime.bridge
```

Then start the headless Luanti fixture:

```powershell
& .\integrations\luanti\scripts\run-luanti.ps1 -LuantiRoot D:\luanti
```

## Verify L0-L2

```powershell
& .\integrations\luanti\scripts\test-l0-l2.ps1 -LuantiRoot D:\luanti
```

The script starts both processes, waits for a real `pickup_succeeded` World
resolution, and closes them. Local world and log data are ignored by Git.

```text
visible ordinary_food
-> Runtime approach
-> Luanti position change
-> subsequent observation reports within_reach
-> Runtime pickup
-> Luanti removes the object and records held inventory
```

The adapter exposes only the configured finite radius and bounded lists. Luanti
entity references, map state, and hidden objects remain inside the World.

## Verify L3 Ordinary Food

```powershell
& .\integrations\luanti\scripts\test-l3.ps1 -LuantiRoot D:\luanti
```

This starts the Runtime with `--base-food-life` and verifies the existing
Goal/Trajectory policy against real Luanti movement, pickup, return, deposit,
and causal `/v1/life-result` admission.

## Verify L4 Risky Tasty Food

```powershell
& .\integrations\luanti\scripts\test-l4.ps1 -LuantiRoot D:\luanti
```

This starts the existing `--base-food-life` Runtime against the risky fixture.
It verifies a sourced God Statue statement, visible tasty Food and beast,
finite territory relations, and Luanti-owned `warning -> chase -> attack`
resolution ending in medium injury and forced retreat. L4 does not admit an
Experience or create a Local Bias.

## Verify L5 Outcome Learning

```powershell
& .\integrations\luanti\scripts\test-l5.ps1 -LuantiRoot D:\luanti
```

This enables the explicit Luanti outcome adapter and verifies the real attack
fact through the existing Territory Experience, Outcome Gradient, and Local Bias
stores. It forms three relation-local negative biases without changing action or
canonical authority.

## Verify L6 Sleep / Deep Candidate

```powershell
& .\integrations\luanti\scripts\test-l6.ps1 -LuantiRoot D:\luanti
```

This runs three distinct attack outcome cycles in one World and Runtime, then
explicitly invokes the existing Local Bias Profile and Deep Similarity path. It
forms one support-3 shadow CandidateRelation without T1, M_B, or action promotion.

## Verify L7 Dynamic M_B Cycle

```powershell
& .\integrations\luanti\scripts\test-l7.ps1 -LuantiRoot D:\luanti
```

This keeps the L6 candidate path separate from an independently reviewed
canonical rupture, then explicitly joins them at T1-A. It verifies T1 selection,
an inactive reconstructed `M_B'`, explicit cutover, parent archive, and a fresh
`REENTERED` comparison window. The new model is diagnostic authority only; it
does not become Goal, Trajectory, or action authority.

## L8 Multi-Agent Runtime Boundary

L8 requires explicit agent, Sleep-result, candidate, and assessment identities
for every T1/cutover request. The Runtime reference verifies independent A/B
candidate, Experience, model, archive, and `M_delta` state. This is an adapter
separation result; concurrent autonomous A/B movement in one Luanti World is not
claimed yet.

## Verify RW2 Multi-Agent Food Life

```powershell
& .\integrations\luanti\scripts\test-multi-agent.ps1 -LuantiRoot D:\luanti
```

This starts two NPC bodies in one real Luanti World. A and B send independent
bounded observations to one Runtime, observe one another, and complete their
own Food pickup, return, deposit, and causal result admission cycles. The
fixture uses dedicated Food/Base pairs and adds no resource competition,
social meaning, Sleep, learning, or M_B-informed behavior.

## Verify OBS-2 Local Sensor Profiles

```powershell
& .\integrations\luanti\scripts\test-local-sensor-profiles.ps1 -LuantiRoot D:\luanti
& .\integrations\luanti\scripts\test-invalid-sensor-profile.ps1 -LuantiRoot D:\luanti
```

The first command keeps the RW2 life loop active while A uses local radius 12
and B uses radius 8 against an equal-distance probe. The second verifies that
an unknown profile fails explicitly at Luanti startup.

## Verify OBS-3 Distant Observation

```powershell
& .\integrations\luanti\scripts\test-distant-observation.ps1 -LuantiRoot D:\luanti
```

This runs the opt-in `fixture-distant-enabled` profile in a finite voxel
corridor. It verifies observer-local coarse direction and color, opaque-node
occlusion, an empty sample after a 180-degree turn, and the absence of exact
distance, World coordinates, source IDs, and fixture names in stored frames.
It does not connect distant vision to recognition or action selection.

## Verify OBS-4 Audition Observation

```powershell
& .\integrations\luanti\scripts\test-audition-observation.ps1 -LuantiRoot D:\luanti
```

This emits two brief same-cell fixture events behind one wall voxel. The
normal-gain profile receives one mixed weak/mid detection, while the compact
profile remains below threshold. A separate 33-event probe records receiver
buffer overflow as an empty partial/output-limited frame rather than silence.
No source identity, exact position, or semantic sound name is published.

The current harness uses the OBS-4B/4C `audition_receive_window` mode. Sound is
received at emit time into agent-owned finite buffers, windows close as
half-open intervals, and frozen frames are delivered later. The test removes
the source, rotates the agents, exercises an exact window boundary, and checks
that accepted receipts still survive an overflow indication. It also splits a
boundary-crossing sound by overlap, makes duplicate close idempotent, rejects
late events for frozen windows, and reports detection-output truncation as
partial rather than complete silence.

Run the OBS-6 integrated life regression with:

```powershell
& .\integrations\luanti\scripts\test-observation-integration.ps1 -LuantiRoot D:\luanti
```

This keeps the RW2 Food loop unchanged while attaching agent-owned local,
periodic distant, and audition frames to the same observation deliveries. It
checks both agents, real feature/detection presence, independent capture
schedules, zero sensory rejection, and the ordinary sensory-disabled RW2
regression. Standalone and integrated runs share the distant-vision and
audition-window kernels. The result establishes finite life compatibility, not
exact action-sequence equality. SensorFrames remain read-only inputs to the
isolated store.

OBS-6C closes audition windows independently of HTTP exchange and stages up to
64 closed frames per agent for later delivery. It also shares voxel sound
transmission, initializes fixture geometry once, and checks wall occlusion,
target disappearance, wall attenuation, and a two-tick delivery delay.

OBS-6D queues all sensory frames, sends no more than four oldest frames per
observation, and removes in-flight frames only after an explicit accepted
Runtime sensory receipt. Its harness covers a four-tick backlog, an isolated
extension rejection, and a simulated pre-send transport failure followed by
successful retry.
