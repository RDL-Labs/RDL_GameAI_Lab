# RDL_GameAI NPC レイヤー別設計計画 v0.1

*DESIGN PLANNING VIEW — `Aporapeiron/RDL_General_Modules` の「RDL 横断レイヤリング_キット」GameAI応用を、GameAI Labの設計計画へ展開*

## 0. 目的

この文書は、NPC設計を一つの大きな personality / behavior system としてまとめず、更新速度・保持時間・拘束伝播の異なるLayerごとに分けて計画するための整理表である。

```text
Generation / DNA
        ↓
Neural / Sensitivity
        ↓
Physical / Body
        ↓
Experience / Relation History
        ↓
Realtime / Current Context

変化しにくい
        ↓
変化しやすい
```

これはNPCの存在論ではなく、設計・実装・試験を分割するためのProfileである。

```text
Layer Profile
!= Core primitive
!= canonical M_B decomposition
!= runtime authority
```

各Layerの内容は、現行GameAI Labの意味境界に合わせて GameAI-local condition / profile / history / state として扱う。

---

## 1. Generation / DNA Layer

### 役割

NPC生成時に与える、生涯中もっとも変化しにくい生成拘束。

初期実装では、

```text
DNA = immutable during lifetime
```

として扱う。

### 候補

```text
危険感度の初期範囲
探索傾向
学習速度レンジ
記憶減衰特性
身体サイズ範囲
移動能力上限
感覚性能範囲
```

GameAI Lab上では、例えば次のschema候補へ翻訳できる。

```text
sensitivity range
learning-rate range
memory-decay range
exploration tendency range
body-size range
movement capability range
sensory capability range
```

### 設計上の意味

DNA自体をCore `M_B` としない。

```text
DNA
→ possible SensitivityProfile range
→ possible body / morphology range
→ possible learning / reaction tendencies
```

という生成可能域の拘束として扱う。

### 現在の扱い

```text
status = deferred / design-only
```

現行vertical sliceには不要。reproduction / evolutionを扱う段階で有効化する。

---

## 2. Neural / Sensitivity Layer

### 役割

取得した相互作用や履歴に対して、何を拾いやすく、どの程度反応しやすいかを拘束する比較的低速な個体差。

### 候補

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
stability_preference
control_loss_sensitivity
recoverability_sensitivity
social_rejection_sensitivity
```

将来候補として、

```text
learning rate
forgetting / memory decay tendency
generalization strength
exploration / exploitation tendency
reaction speed tendency
```

も検査できる。

### 設計上の意味

```text
SensitivityProfile
!= personality totality
!= Core H
!= Core ξ
!= Core M_B by identity
```

同じ現在条件・同じ履歴でも、Sensitivityの差によってAffectExpressionやActionBiasが分かれるかを観察する。

### 現在の扱い

```text
status = roadmap Next 3 candidate
```

Experience / Relation History導入後に接続する。

---

## 3. Physical / Body Layer

### 役割

NPCの身体状態と、現在利用可能な行動可能域を扱う。

### 候補

```text
health
stamina
fatigue
injury
movement capability
available body parts
turning capability
attack range
current sensory capability
```

### 設計上の意味

```text
physical world itself
!= BodyState
!= Core M_B by identity
```

同じ判断傾向・同じ履歴でも、BodyStateが異なれば可能な行動やAffectExpressionが変化しうる。

Physical Layerは通常は低〜中速だが、負傷などによって急変する場合がある。

### 現在の扱い

```text
status = partial concept / later connection
```

Sensitivity / Affect導入時にCurrent Contextと合わせて接続する候補。

---

## 4. Experience / Relation History Layer

### 役割

生涯中の有限interactionから蓄積された比較的持続的な履歴・関係拘束を保持する。

### 候補

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

具体的には、

```text
この場所には餌がある
この場所では過去に襲われた
この個体は危険
この経路は成功率が高い
この行動は失敗しやすい
```

のような有限な履歴が入る。

### 設計上の意味

```text
past interaction
→ finite relation history
→ later interpretation / action conditions may differ
```

同じ相手に対する正負両方向の履歴を共存させ、単一好感度へ潰さない。

```text
RelationHistory != complete world truth
RelationHistory != Core M_B by identity
```

### 現在の扱い

```text
status = roadmap Next 2
```

現在のレイヤー計画で、最初に実装候補へ上げるLayer。

---

## 5. Realtime / Current Context Layer

### 役割

tickまたは短期windowで高速に変化する現在条件を扱う。

### 候補

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

### 設計上の意味

```text
CurrentContext
!= bounded observation packet
!= canonical RIB_B
!= Core M_B
```

現在情報は、finite B / Purpose / selected dimensions / coverage / provenance を通してcanonical pathへ入る。

### 現在の扱い

```text
status = partially present in current runtime
```

現行runtimeにはbounded observationとaction/world resolutionがあるため、最も既存実装へ近いLayer。

---

## 6. 更新速度の目安

初期Profileでは、次のように見る。

```text
Generation / DNA       : lifetime fixed
Neural / Sensitivity   : very slow
Physical / Body        : slow to medium, sometimes abrupt
Experience / History   : medium / cumulative
Realtime / Context     : fast
```

これは厳密な全順序ではない。

```text
Physical injury
→ sudden change

Realtime repetition
→ Experience sedimentation
```

のような例外を許す。

---

## 7. Layer間の拘束伝播

低速Layerは、高速Layerの可能域を拘束しうる。

```text
Generation / DNA
      ↓
Sensitivity + Body possibility
      ↓
Experience formation tendencies
      ↓
Realtime response possibilities
```

一方、高速Layerで反復した関係は、より低速なLayerへ沈降しうる。

```text
Realtime interaction repeated
      ↓
Experience / Relation History
```

さらに将来、有限な検査を通して、

```text
long-run Experience
      ↓
slow Sensitivity / learned constraint update
```

を試すこともできる。

ただし、Layer間伝播は自動でCore `M_B` reconstruction authorityを意味しない。

---

## 8. 生殖・進化への拡張

Generation / DNA Layerを他Layerから分離しておくと、生殖を後から追加しやすい。

```text
DNA_A --\
         > recombination / mutation -> DNA_child
DNA_B --/
```

概念的には、

```text
DNA_child = Recombine(DNA_A, DNA_B) + Mutation
```

新個体では、

```text
DNA_child
→ initial sensitivity ranges
→ initial body / morphology ranges
```

として初期化する。

Experience / Realtimeは原則として直接継承しない。

> **経験内容そのものではなく、学習・反応・身体形成の可能域が継承される。**

この分離により、将来的に、

```text
DNA variation
↓
Sensitivity / Body differences
↓
Experience formation differences
↓
behavior differences
↓
survival / reproduction differences
↓
next-generation DNA distribution
```

という進化的loopを追加できる。

現段階では実装しない。

---

## 9. エピジェネティクス等の中間Layer

初期Profileには入れない。

必要になった場合だけ、

```text
DNA
 ↓
Expression / Development
 ↓
Sensitivity / Body
```

のような中間Layerを追加する。

Layer数は固定しない。

---

## 10. 現行roadmapとの対応

```text
Current
E-only-not-reviewed
      ↓
Next 1
finite assessment / unresolved / H
      ↓
Next 2
Experience / Relation History
      ↓
Next 3
Neural / Sensitivity
+ Physical / Body
+ Realtime / Current Context
      ↓
Next 4+
M_Δ / T1 reconstruction
```

Generation / DNAは別系列で保持する。

```text
Generation / DNA
      ↓ later
seeded individual difference
      ↓ later
reproduction / evolution
```

したがって、5Layerを一度に実装する必要はない。

---

## 11. 設計計画としての使い方

新しいNPC機能案が出たら、まずどのLayerへ置くかを仮置きする。

例：

```text
「昨日助けてもらったことを覚える」
→ Experience / Relation History

「同じ出来事でも臆病な個体だけ逃げやすい」
→ Neural / Sensitivity

「怪我で移動が遅くなる」
→ Physical / Body

「今目の前に敵がいる」
→ Realtime / Current Context

「子に探索傾向が遺伝する」
→ Generation / DNA
```

その上で、

```text
Layer
→ required input
→ update timing
→ persistence
→ provenance
→ break condition
→ read-only observation
→ reviewed influence
```

の順に設計する。

これにより、複数の性質を一つの巨大な `personality` や `state` へ押し込めることを避ける。

---

## 12. ξ と実体化防止

このLayer分解が設計上うまく機能しても、NPC全体が本当にこの5Layerで構成されているとは扱わない。

```text
Complete_B(NPC Layer Plan) = true
and
ξ(B) != 0
```

Layer間・Layer外・重複・未回収関係は残る。

> **Layerは設計計画を切り分ける道具であって、NPCそのものではない。**

---

## 一文圧縮

> **GameAI Labでは、Generation/DNA・Neural/Sensitivity・Physical/Body・Experience/Relation History・Realtime/Current Context のLayerを、NPC機能の設計・実装・検査順序を整理する計画枠として使い、各Layerを段階的に実装する。**
