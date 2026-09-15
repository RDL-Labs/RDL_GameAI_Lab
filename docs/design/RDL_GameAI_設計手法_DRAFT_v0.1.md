# RDL_GameAI 設計手法
## DRAFT v0.2 — Core v2.3 / RIB_B準拠・更新済み鉱山を使うゲームAI運用

## 0. 目的

本書は `RDL_GameAI_Lab` における設計・実装・実験の進め方を定める。

目的はRDL語彙をゲームAIへ機械的に移植することではない。`RDL_Demos`、`RDL_Human`、`RDL_Enterprise` を素材鉱山として扱い、**意味論は `Aporapeiron/RDL_Core` T0/T1 v2.3 を基準に再検査し、有限Boundary・provenance・段階的実装・受入証拠・停止規律を使ってGameAI向けに再構成する**。

本設計手法自体も有限Boundary上の運用方針であり、自己例外化しない。

---

## 1. 権威順序

```text
RDL_Core v2.3
  T0 BASE / SPEC
      ↓ semantic authority
  T1 SILN Operations
      ↓ formation / inspection / reconstruction method

RDL_Demos
  living world + current Village v2.3 canonical implementation
      ↓ extraction / translation

RDL_Enterprise
  bounded runtime + provenance + durability + staged acceptance
      ↓ extraction / translation

RDL_Human
  T3 human/body/cognition hypotheses, now v2.3-separated from Core
      ↓ extraction / translation

RDL_GameAI_Lab
  game-specific Purpose / B
  acquisition rules
  Selection criteria
  experiments
  implementations
```

既存実装は working material であり、クラス名・変数名・過去文書の語彙だけではCore上の意味を保証しない。

---

## 2. T0で固定する最低意味境界

### 2.1 SILN / RIB / RIB_B

一方向入力を独立した基底primitiveとして置かない。

```text
nonlinear relational network
      ↕
    SILN
  ↕ {RIB_i}
      ↓ Purpose / finite B
    RIB_B
```

ゲームエンジンが持つ完全参照状態は、実験用referenceであってagent observationではない。

```text
Engine world state
!= Agent Observation packet
!= RIB_B
!= Agent M_B
```

### 2.2 Observation packet != RIB_B

P1/P2で作った bounded observation packet は重要な実装成果だが、canonical `RIB_B` そのものとは呼ばない。

```text
bounded observation packet
  ↓ acquisition adapter
Purpose / B / selected dimensions / conditions / coverage / provenance
  ↓
RIB_B
```

選択したdimensionが欠けている場合、欠測を `0` に変換してsectionを成立させない。

### 2.3 F / F' は同じ更新前 M_B

```text
F(t)    = interp(M_B, RIB_B(t))
F'(t+Δ) = interp(M_B, RIB_B(t+Δ))
E       = Δ(F, F')
```

比較途中で `M_B` を更新しない。`E` は engine truth と agent表象の誤差ではない。

### 2.4 E != H

```text
E
↓ bounded local absorption / explanation / temporal-change inspection
finite assessment
↓ unresolved only
H_vec
↓
H = ||H_vec||
```

非ゼロEの大きさだけで unresolved にしない。

```text
H != fear
H != fun
H != anger
H != jealousy
H != stress
H != Human Attention load
```

### 2.5 ξを数値runtime状態へ潰さない

```text
∀B_finite: ξ(B) != 0
```

`ξ` は novelty、unknown count、coverage gap、uncertainty score、探索圧、stress等と同一視しない。

---

## 3. T1を学習・再構成の骨格として使う

```text
H >= θ
→ M_Δ
→ current M_B becomes SILN_SELF
→ Probe
→ Expansion
→ Inspection
→ Selection
→ Reconstruction
→ M_B'
→ fresh re-entry validation
```

`H` はM_Δへの入場根拠であり、そのベクトルをそのまま `M_B'` 更新量として使わない。

### Probe

有限条件のもとで新しいinteraction evidenceを取る。ξそのものを回収する操作ではない。

### Expansion

候補を複数開く。外部モデル・心理仮説・LLM・アルゴリズムは有限用途の道具として利用できる。

### Inspection

```text
replay
counterfactual rerun
shadow behavior
canary trial
scenario test
statistical comparison
```

```text
Inspection tool != Selection criterion
```

### Selection

```text
retain / reject / defer
```

GameAIでは単一rewardだけを基準にしない。

候補基準:

```text
履歴との連続性
個体差の維持
関係変化の豊かさ
行動の可読性
意外性
単調化の回避
recoverability
破綻的挙動の回避
```

### Reconstruction

retainされた関係だけを、valid conditions / break conditions / unresolved items / provenanceとともに有限 `M_B'` へ再構成する。

---

## 4. 鉱山から継承するもの・継承しないもの

### 4.1 RDL_Demos

現在のVillageは、古い `HVec / XiPool / LeapEngine` をCore実装として採掘する対象ではない。

優先採掘対象:

```text
world / body / perception
relation history
dialogue
seeded simulation
simultaneous resolution
richness metrics

v2.3 canonical side:
finite B / RIB_B
same-frozen M_B comparison
explicit unresolved review
H / θ / M_Δ
T1 reconstruction
finite-context authority
operational coverage report
```

legacy-local state:

```text
LocalLoadVector
ExplorationState
LeapEngine
HVec / XiPool / Boundary compatibility aliases
```

これらをCore `H / ξ / θ / M_Δ` と名前だけで同一視しない。

### 4.2 RDL_Enterprise

現在のEnterpriseはv2.3 migration済みの範囲を優先して採掘する。

```text
bounded acquisition
RIBSection
same frozen M_B / interpretation context
provenance
coverage separation
restart durability
staged commitment
authority boundary
P10 changed-condition acceptance harness
```

```text
static StructuralConflict != E != H
Human Attention != H
coverage metric != ξ
Function != M_B
legacy *CompiledMB name != current Core M_B
```

旧 `HState` をNPCの「ストレスメーター」としてそのまま持ち込まない。

### 4.3 RDL_Human

HumanはT3仮説鉱山として使う。

```text
SensitivityProfile
secure-base / recoverability hypothesis
relation binding
context-dependent personality expression
multi-timescale sedimentation
SFO-related directional hypotheses
```

Human側の心理的熱、自己境界、SFO、認知空間等はCore primitiveではない。

---

## 5. Enterprise由来の設計規律

### Observation / Candidate / Commitment / Activeを分ける

```text
Observation
→ Candidate
→ Evidence / Inspection
→ Commitment
→ Active
```

### UNKNOWNを潰さない

```text
UNKNOWN
UNRESOLVED
NOT_EVALUATED
OPPOSE
SUPPORT
```

### Authority != Truth

行動権限と事実妥当性を分ける。

### Context / Provenanceを回収可能にする

最低候補:

```text
time / tick
location
seed
observer / agent
Purpose / boundary_id
selected dimensions
coverage
perception rule
action taken
source observation id
subsequent observation id
active M_B version
relevant history refs
```

### 通常時はshallow path

深い再構成を常態化しない。

### 新しい型は破断が要求したときだけ追加する

> **この型がないと、今起きている破断を再検査できないか。**

---

## 6. Vertical Slice First

現行GameAIでは次の順で縦断する。

```text
world interaction
↓
bounded observation
↓
canonical acquisition
↓
RIB_B
↓
interp(frozen M_B, RIB_B)
↓
F
↓
action
↓
world / relation changes
↓
subsequent bounded observation
↓
RIB_B'
↓
same pre-update M_B
↓
F'
↓
E
↓
finite unresolved review
↓
H
↓
local maintenance or M_Δ / T1
↓
fresh re-entry
↓
later behavior changes
```

P1/P2はこの縦断の前半として保持する。

---

## 7. Acceptance Evidenceを先に書く

```text
P0 v2.3 semantic + mine sync
accept:
Core語彙と鉱山評価が現行v2.3に整合する

P1 bounded perception [accepted]
accept:
agent behavior does not directly read engine reference state

P2 actual interaction loop [accepted]
accept:
action changes conditions that generate a later bounded observation

P3 RIB_B acquisition
accept:
Observation != RIB_B を保ち、Purpose/B/coverage/provenance付きfinite sectionを形成する

P4 F/F'/E
accept:
same frozen pre-update M_Bで比較し、Eをworld-truth errorにしない

P5 unresolved review / H
accept:
resolved/pending/ordinary changeはHへ入らない

P6 relation history
P7 sensitivity / affect expression
P8 M_Δ / T1 reconstruction
P9 finite-context authority + re-entry
P10 richness / long-run behavior
```

```text
test green
!= RDL is true
!= model is complete
!= all game situations validated
```

---

## 8. GameAI固有のSelection / richness

単一スカラー最大化を避ける。

```text
behavior variety
individual divergence
history dependence
relation dependence
place meaning drift
daily variation
readability
surprise
recoverability
rupture diversity
```

```text
survival ↑ != interestingness ↑
winning ↑  != lifelikeness ↑
randomness ↑ != surprise quality ↑
```

---

## 9. 感情設計

感情語を基底状態にしない。

```text
finite interaction / interpretation history
+ unresolved provenance when present
+ RelationalHistory
+ RelationConstraint
+ SensitivityProfile
+ BodyState
+ CurrentContext
↓
AffectExpression
ActionBias
DialogueTone
```

`Threat / Opportunity / Control / Recoverability / Novelty` 等はGameAI-local descriptorでありCore primitiveではない。

---

## 10. 実装方針

1. 既存P1/P2を壊さない。
2. canonical sidecarは最初はread-only。
3. observation packetをraw materialとしてacquisitionする。
4. P3では `RIB_B` formationまでで止める。
5. P4で初めて明示的なfrozen `M_B` evaluatorを置く。
6. P5まで `H` を作らない。
7. reconstruction authorityはshadow/re-entry後、finite context単位でのみ切り替える。
8. ξをnumeric runtime pressureへ変換しない。

---

## 11. 一文圧縮

> **GameAI Labは、更新済みのRDL鉱山を部品庫として使いながら、Core v2.3の有限 `B / RIB_B / M_B` 境界を崩さず、実際のinteraction chainを小さな受入証拠で縦に伸ばしていく。**
