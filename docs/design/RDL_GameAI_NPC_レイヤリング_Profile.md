# RDL_GameAI NPC レイヤリング Profile v0.1

*DESIGN PROFILE — `Aporapeiron/RDL_General_Modules` の「RDL 横断レイヤリング・キット」を GameAI Lab へ適用*

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

現行runtimeの canonical sidecar は `E` までの read-only path を維持する。本Profileを導入しただけでは、action / graph / M_B reconstruction authority は増えない。

---

## 1. 初期Profile

GameAI Labでは、初期整理として次を使う。

```text
Generation / DNA Layer
        ↓
Neural / Sensitivity Layer
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
sensitivity range
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
→ possible SensitivityProfile range
→ possible body/morphology range
→ possible learning / reaction tendencies
```

現行roadmapでは reproduction は deferred なので、まずはschema / seeded generation用の設計概念として保持する。

---

## 4. Neural / Sensitivity Layer

比較的低速な個体差。

現行候補：

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
stability_preference
control_loss_sensitivity
recoverability_sensitivity
social_rejection_sensitivity
```

このLayerは、同じ履歴・同じ現在条件でも異なる拾い方・反応傾向を生むための GameAI-local Profile である。

```text
SensitivityProfile
!= personality totality
!= Core H
!= Core ξ
!= Core M_B by identity
```

将来的には、長期経験によって一部が遅く変化する可能性を検査できるが、初期段階では低速または固定寄りに扱う。

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

Experience Layerは現在のroadmap `Next 2 — relation history` と直接接続できる。

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
Neural / Sensitivity   : very slow
Physical / Body        : slow to medium, sometimes abrupt
Experience / History   : medium / cumulative
Realtime / Context     : fast
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
Sensitivity + Body possibility
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
Current runtime
E-only-not-reviewed
      ↓
Next 1: finite assessment / unresolved / H
      ↓
Next 2: relation history
      ↳ Experience Layer を実装候補化
      ↓
Next 3: individual sensitivity / affect
      ↳ Neural / Sensitivity Layer を実装候補化
      ↳ Physical / Body + Realtime / Context と接続
      ↓
Next 4+: M_Δ / T1 reconstruction
```

Generation / DNAは、現行runtimeの次のcutoverには不要。

reproduction / evolutionを扱う段階で、

```text
DNA_A + DNA_B
→ recombination / mutation
→ DNA_child
→ initial sensitivity / body possibility ranges
```

として接続できる。

---

## 11. 実装導入の段階

### Stage A — design-only

現在。

- Layer名と責務だけ定義する。
- 既存runtime action pathを変更しない。
- canonical sidecarをread-onlyのまま維持する。
- `M_B`、`RIB_B`、`H`、`ξ`へ自動変換しない。

### Stage B — observational schema

relation history / sensitivity導入時に、Layer別のread-only snapshotを追加してよい。

例：

```text
npc_profile:
  generation: ...
  sensitivity: ...
  body: ...
  experience: ...
  realtime: ...
```

このsnapshotは観察用であり、action authorityではない。

### Stage C — reviewed influence

各Layerがaction / interpretationへ影響する場合は、Layerごとに有限な入力・出力・provenance・break conditionを検査する。

一括で「NPC personality system」としてcutoverしない。

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

> **GameAI Labでは、NPCを Generation/DNA・Neural/Sensitivity・Physical/Body・Experience/Relation History・Realtime/Current Context の異なる時間スケールとして整理する。ただし各LayerをCore `M_B`へ自動同一視せず、現行canonical pathとruntime authorityを維持したまま、relation historyとindividual sensitivityから段階的に実装する。**
