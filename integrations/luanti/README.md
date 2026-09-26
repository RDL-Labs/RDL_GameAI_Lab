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
