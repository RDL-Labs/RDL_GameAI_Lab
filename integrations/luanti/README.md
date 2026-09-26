# RDL GameAI Luanti Integration

This directory contains the L0-L2 World backend reference:

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
