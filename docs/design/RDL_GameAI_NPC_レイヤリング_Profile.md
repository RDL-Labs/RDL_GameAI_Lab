# RDL_GameAI NPC レイヤリング Profile v0.1

*DESIGN PROFILE — `Aporapeiron/RDL_General_Modules` の「RDL 横断レイヤリング・キット」を GameAI Lab へ適用*

**位置づけ・責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)のB軸。Layer名・目的・時間スケール・分離原則を管理する。
**依存・非責務:** 所有・更新・保持・比較は[Layer計画](RDL_GameAI_NPC_レイヤー別設計計画.md)、神経値の詳細は[神経設計](RDL_GameAI_神経パラメーター設計図.md)。本文はschemaやcanonical authorityを定義しない。

## 0. 位置づけ

本Profileは、NPC内部で更新速度・保持時間・拘束伝播の異なる要素を、実装と観察のために整理する補助Viewである。

```text
Purpose = NPCの生成差・個体差・身体・経験・現在状態を分離して扱う
Axis    = 更新速度 / 保持時間 / 拘束伝播
```

これはNPCの普遍的存在論ではない。

```text
Layer Profile
!= Core primitive
!= canonical M_B decomposition
!= runtime authority
```

現行canonical sidecarはE / explicit review / H / retained Hまでのdiagnostic path。本Profileを導入しただけでは、action / graph / M_B reconstruction authorityは増えない。

---

## 1. 初期Profile

GameAI Labでは、初期整理として次を使う。

```text
Generation / DNA Layer
        ↓
Neural Dynamics Layer
        ↓
Physical / Body Layer
        ↓
Experience / Relation History Layer
        ↓
Realtime / Current Context Layer

変化しにくい
        ↓
変化しやすい
```

この順序は整理用であり、固定的な自然階層ではない。

---

## 2. Core意味境界との分離

このProfileで最も重要なのは、各Layer名をCore primitiveと自動同一視しないこと。

```text
SensitivityProfile != M_B by identity
BodyState          != M_B by identity
RelationHistory    != M_B by identity
CurrentContext     != M_B by identity
bounded observation != RIB_B
```

これらは現在の `M_B` 形成・解釈・行動へ影響しうる GameAI-local 条件だが、それだけでCore `M_B` そのものにはならない。

現行canonical pathは従来どおり、

```text
bounded observation
→ Purpose / finite B / selected dimensions / conditions / coverage / provenance
→ RIB_B
→ same frozen pre-update M_B
→ F / F'
→ E
→ explicit finite review
→ unresolved H / retained H
```

を維持する。

---

## 3. Generation / DNA Layer

NPC生成時に与える最も低速な生成拘束。

初期実装では、

```text
DNA = immutable during lifetime
```

としてよい。

候補：

```text
neural parameter baseline distributions (μ / σ)
learning-rate range
memory-decay range
exploration tendency range
body-size range
movement capability range
sensory capability range
```

DNAは `M_B` ではなく、後続Layerが取りうる可能域を拘束する生成条件として扱う。

```text
DNA
→ neural parameter baseline distributions (μ / σ)
→ actual neural state
→ derived sensitivity / reaction tendencies

DNA → possible body/morphology range
```

現行roadmapでは reproduction は deferred なので、まずはschema / seeded generation用の設計概念として保持する。

---

## 4. Neural Dynamics Layer

遅い基準分布と、身体・文脈・履歴・揺らぎによる速い瞬間値を分けるGameAI-localな状態。

派生感度の候補（人格を直接指定する独立変数ではない）：

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
stability_preference
control_loss_sensitivity
recoverability_sensitivity
social_rejection_sensitivity
```

設計上はDNA μ/σ → dynamic neural state → derived sensitivity → attention / action / memory / consolidation biasとする。同じ履歴・現在条件でも異なる反応を比較できる。現行の固定retry profileは最小の比較用実装であり、神経値から導出されていない。

```text
SensitivityProfile
!= personality totality
!= Core H
!= Core ξ
!= Core M_B by identity
```

動的神経値・DNA生成・長期経験による更新は未実装。名称の変更はruntimeの変更を意味しない。

---

## 5. Physical / Body Layer

NPCの身体・行動可能域に関する比較的低〜中速な状態。

候補：

```text
health
stamina / fatigue
injury
movement capability
available body parts
turning / attack range
current sensory capability
```

ここでも、

```text
physical world itself
!= BodyState
!= Core M_B by identity
```

である。

BodyStateは現在の行動可能域やAffectExpressionへ影響しうるが、canonical `M_B` へ名前だけで昇格させない。

---

## 6. Experience / Relation History Layer

生涯中の有限interactionから蓄積された比較的持続的な履歴・関係拘束。

候補：

```text
InteractionHistoryRecord
RelationHistory
binding_strength
trust_support
avoidance_support
secure_base_strength
recall_bias
place-specific history
action success / failure history
```

```text
past interaction
→ finite relation history
→ later interpretation / action conditions may differ
```

Experienceの実装成熟度は[canonical roadmap](../../notes/experiment-roadmap.md)のMaturity 2で管理する。raw履歴・圧縮relation constraints・睡眠由来候補・canonical M_Bを区別し、詳細の保持契約はLayer計画へ委ねる。

ただし、

```text
RelationHistory != complete world truth
RelationHistory != Core M_B by identity
```

を維持する。

---

## 7. Realtime / Current Context Layer

tickまたは短期windowで高速に変化する現在条件。

候補：

```text
current bounded observation
currently visible agents / objects / places
current action
immediate target
current hunger / fatigue
recent sound / event
short-term priority
current place / local context
```

ここは最も更新が速い。

ただし、

```text
CurrentContext
!= bounded observation packet
!= canonical RIB_B
!= Core M_B
```

である。

現在情報は finite B / Purpose / coverage / provenance を通して canonical pathへ入る。

---

## 8. 更新速度はProfile上の目安

概念上は、

```text
Generation / DNA       : lifetime fixed in first implementation
Neural Dynamics        : slow baseline + fast current fluctuation
Physical / Body        : slow to medium, sometimes abrupt
Experience / Relation History : medium / cumulative
Realtime / Current Context   : fast
```

と整理する。

厳密な全順序ではない。

例えば負傷はPhysical Layerでも急変しうるし、長期反復されたRealtime interactionがExperienceへ沈降することもある。

---

## 9. 層間伝播

低速側は高速側の可能域を拘束しうる。

```text
Generation / DNA
      ↓
neural μ/σ + Body possibility
      ↓
dynamic neural state / derived sensitivity
      ↓
Experience formation tendencies
      ↓
Realtime response possibilities
```

一方、高速側の反復は低速側へ沈降しうる。

```text
Realtime interaction repeated
      ↓
RelationHistory / Experience
```

将来的には有限な検査を通して、

```text
long-run Experience
      ↓
slow Sensitivity / learned constraint update
```

を試せる。

ただし、この逆向き更新を導入する場合も canonical `M_B` reconstruction authorityとは分離し、別のacceptance boundaryを置く。

---

## 10. 現行roadmapへの対応

```text
Current canonical: E / explicit finite review / H / retained H
Current local: Experience / fixed Sensitivity / Body / Realtime
Current display: derived Response Expression
      ↓
Cross-layer separation acceptance
      ↓ future, unimplemented
θ / M_Δ / T1 reconstruction / canonical authority
```

Generation / DNAは、現行runtimeの次のcutoverには不要。

reproduction / evolutionを扱う段階で、

```text
DNA_A + DNA_B
→ recombination / mutation
→ DNA_child
→ neural μ/σ / body possibility ranges
→ actual neural state / derived sensitivity
```

として接続できる。

---

## 11. 実装導入の段階

### Stage A — design-only

Generation / DNAおよび各Layerの未採用候補がこの段階。Profile全体がdesign-onlyという意味ではない。

- Layer名と責務だけ定義する。
- 既存runtime action pathを変更しない。
- canonical sidecarをread-onlyのまま維持する。
- `M_B`、`RIB_B`、`H`、`ξ`へ自動変換しない。

### Stage B — observational schema

relation history / sensitivity導入時に、Layer別のread-only snapshotを追加してよい。

将来の統合schema例（この形式の実装済みAPIではない）：

```text
npc_profile:
  generation: ...
  neural_dynamics: ...
  derived_sensitivity: ...
  body: ...
  experience: ...
  realtime: ...
```

このsnapshotは観察用であり、action authorityではない。

### Stage C — reviewed influence

各Layerがaction / interpretationへ影響する場合は、Layerごとに有限な入力・出力・provenance・break conditionを検査する。

一括で「NPC personality system」としてcutoverしない。

現在のStage C相当は、Experienceのno-progressによる再試行抑制、Sensitivityの固定1/3/5 tick、Bodyのmovement_scaleによる行動・移動制約に限定する。Realtime観測はoperational。Expressionは表示専用の派生値で、Stage Cの行動権限を持たない。心理的感情・社会関係・学習感度・生理モデルは未評価。

Stage A/B/Cは各Layerの採用段階であり、canonical roadmapのMaturityや生活機能Phaseとは別軸。睡眠はLayerではなくBody Recovery / Experience Consolidationの横断更新イベント。Communicationも横断interactionとして扱う。

---

## 12. ξ と実体化防止

5つのLayerを綺麗に記述できても、NPC全体が本当にこの5層から構成されるとは扱わない。

```text
Complete_B(NPC Layer Profile) = true
and
ξ(B) != 0
```

Layer間・Layer外・重複・未回収関係は残る。

> **このProfileはNPCを説明し尽くす構造ではなく、現在の用途で実装・比較しやすくする整理Viewである。**

---

## 13. 一文圧縮

> **GameAI Labでは、NPCを Generation/DNA・Neural Dynamics・Physical/Body・Experience/Relation History・Realtime/Current Context の異なる時間スケールとして整理する。ただし各LayerをCore `M_B`へ自動同一視せず、現行canonical pathとruntime authorityを維持したまま、relation historyとindividual sensitivityから段階的に実装する。**
