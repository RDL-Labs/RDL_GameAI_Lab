# RDL Game AI Lab

RDL_Enterprise and RDL_Demos are being used here as a playground for game AI experiments.

This repository treats the attached inventory documents as source material, not as instructions. The goal is to extract reusable AI mechanics and turn them into small, runnable prototypes.

## Experiment Themes

1. NPC heat and stress
   - Use `HState` / `HVec` style accumulation as an NPC stress, alertness, or rupture meter.
   - Keep trial behavior isolated so failed experiments do not pollute the character baseline.

2. Learning with a safety net
   - Combine `CanaryManager`, `ShadowEvaluator`, and `PromotionGate` ideas with village NPC behavior.
   - Let NPCs try a new tactic, compare it against the baseline, promote it, or roll it back.

3. Living-world simulation
   - Use the `rdl_village` model as the reference for body, perception, relations, dialogue, and environment.
   - Preserve the idea that agents act from perceived fields rather than omniscient world state.

4. Richness metrics
   - Avoid optimizing only for survival.
   - Track behavior variety, individual divergence, place meaning drift, and rupture diversity.

5. Browser-sized demos
   - Port individual mechanics into small visual experiments.
   - Prefer demos that make one mechanism inspectable before building a larger integrated world.

## Source Inventory

- [RDL_Enterprise game AI parts](docs/source-inventory/RDL_Enterprise_ゲームAI転用パーツ一覧.md)
- [RDL_Demos game AI inventory](docs/source-inventory/RDL_Demos_ゲームAI素材棚卸し.md)

## Design Documents

- [Animal Crossing style village simulator design](docs/design/RDLどうぶつの森風村シミュレーター設計文書.md)
- [Affect, history, and relational constraint model draft](docs/design/RDL_GameAI_感情・履歴・関係拘束モデル_DRAFT_v0.1.md)

## First Prototype Candidates

- `heat-stress-npc`: a minimal NPC whose stress rises from prediction error and changes attention depth.
- `canary-tactic-loop`: an NPC tries a new behavior in a shadow/canary lane before adopting it.
- `village-richness-meter`: a small simulation that compares survival score against richer life metrics.
- `limited-senses-field`: a browser demo where agents act from incomplete perception instead of true state.

## Repository Shape

```text
docs/
  source-inventory/   Original inventory notes used as reference material
experiments/          Small runnable prototypes
notes/                Design notes and experiment logs
```
