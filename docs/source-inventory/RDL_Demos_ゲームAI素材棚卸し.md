# RDL_Demos — ゲームAI素材棚卸し（2026-09-15再確認）

Source:

```text
https://github.com/HermannDegner/RDL_Demos
checked main: 40f43c9bc4d7e0f0513d3d8c2f6fe8fe3e768d80
```

`RDL_Demos` は **動いている生物・仮想世界・小型実験の鉱山**として引き続き重要である。ただし、2026-09-13時点の旧棚卸しから意味上の重要な変化がある。

## 1. 最重要更新

旧棚卸しでは `rdl_village/core.py` の `HVec / XiPool / Boundary / LeapEngine` をCore抽象概念の具体的リファレンスとして高く評価していた。

現在はこの読みを採用しない。

Village自身がCore v2.3 migrationを行い、次を明示的に分離している。

```text
LocalLoadVector != Core H
ExplorationState != Core ξ
ActionBoundary.theta_effective(...) != canonical θ law
LeapEngine != canonical H >= θ -> M_Δ authority
```

旧 `HVec / XiPool / Boundary` は固定seed互換のaliasとして残るが、Core定義根拠ではない。

## 2. 現在の採掘優先順位

### A. Village world / body / social simulation

引き続き高価値:

```text
world.py
  clock / places / resources / physical environment

perception.py
  individual perception / prediction field

relations.py
  directional multi-axis relation history

dialogue.py
  structured non-LLM dialogue events

action.py
  action candidates / movement / physical gates

npc.py
  agent decision cycle

simulation.py
  tick progression / simultaneous resolution / logs

richness.py
  non-single-scalar richness observation
```

これらはGameAIの世界・身体・関係・履歴・対話・評価の実装素材として依然有用。

### B. Village canonical v2.3 path

現在はここが特に重要。

```text
finite B / Purpose / selected dimensions / conditions
→ RIB_B
→ same frozen pre-update M_B evaluator
→ F / F'
→ E
→ explicit finite assessment
→ unresolved dimensions only
→ H_vec → H → explicit θ
→ provenance-checked M_Δ
→ SILN_SELF
→ Probe
→ Selection retain/reject/defer
→ explicit M_B' proposal
→ shadow validation
→ finite-context authority install
→ fresh live re-entry
→ operational coverage
```

GameAIへの転用価値:

- raw observationとcanonical sectionを分ける設計
- missing coverageを0へ潰さない
- Eの大きさからunresolvedを自動生成しない
- Hをreconstruction vectorにしない
- authorityをagent全体ではなくfinite context単位で切り替える
- canonical managerを入れただけでは既存挙動を変えない
- operational coverageをread-only reportで観測できる

### C. Living Field

`relational-ecology-lab` もCore v2.3 canonical migration済みで、一般観測とPredator attack-specific `B_attack` を分離している。

採掘価値:

- 一般境界とaction-specific boundaryを分離する例
- unattempted actionをfailure zeroへ変換しない例
- live operational reviewer
- canonical authority cutoverとfresh re-entry

## 3. 旧機構の現在の扱い

### LocalLoadVector / legacy HVec

村固有の負荷状態として有用だが、Core Hとして輸入しない。

### ExplorationState / legacy XiPool

探索圧・未確定結果キューとして有用だが、Core ξではない。

### LeapEngine

歴史的/村固有の再編機構として残る。canonical runtimeがactivationされたfinite contextではreconstruction authorityを持たない。

### demo coefficients

`profiles.py` 等の係数は個体差・ゲーム調整素材として有用。ただしCore定数ではない。

## 4. GameAIへの優先転用候補

High:

```text
bounded perception / world separation
directional relation history
place meaning / prediction field
structured dialogue
simultaneous world resolution
seeded deterministic experiment harness
richness metrics
v2.3 RIB_B acquisition boundary
explicit unresolved review pattern
finite-context authority / re-entry
```

Medium:

```text
local exploration / boredom mechanisms
body / reproduction / storage systems
Predator attack-specific action boundary pattern
operational coverage report pattern
```

Do not import by identity:

```text
legacy HVec -> Core H
legacy XiPool -> Core ξ
legacy Boundary -> Core B
legacy LeapEngine -> Core M_Δ/T1
all prediction error -> H
```

## 5. GameAI current use

Current GameAI P3 takes only the acquisition lesson:

```text
bounded observation packet
!= canonical RIB_B

packet
↓ explicit finite adapter
Purpose / B / selected dimensions / conditions / coverage / provenance
↓
RIB_B diagnostic section
```

It does not yet copy Village's H/T1/authority stack. Those remain later-stage mining targets once GameAI has its own `M_B / F/F' / E` evidence.

## 一文圧縮

> **現行RDL_Demosの価値は「旧Core名に似たクラス」ではなく、実際に動く世界・関係・身体と、それをCore v2.3へ段階移行した有限review・T1・authorityの実装履歴にある。**
