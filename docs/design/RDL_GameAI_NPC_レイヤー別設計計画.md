# RDL_GameAI NPC レイヤー別設計計画 v0.3

*DESIGN PLANNING VIEW — `RDL 横断レイヤリング_キット` GameAI応用*

## 0. 目的

NPC設計を一つの personality / behavior system としてまとめず、更新速度・保持時間・拘束伝播の異なるLayerごとに分けて計画する。

```text
Generation / DNA
        ↓
Neural Dynamics
        ↓
Physical / Body
        ↓
Experience / Relation History
        ↓
Realtime / Current Context
```

これはNPCの存在論ではなく、設計・実装・試験を分割するProfileである。

```text
Layer Profile
!= Core primitive
!= canonical M_B decomposition
!= runtime authority
```

全体での位置づけは `RDL_GameAI_全体設計地図.md` を参照する。

---

## 1. Generation / DNA Layer

### 役割

NPC生成時に与える、生涯中もっとも変化しにくい生成拘束。

初期実装では、

```text
DNA = immutable during lifetime
```

として扱う。

### 神経系への接続

DNAは行動・人格そのものを指定しない。

各神経パラメーターについて、基準分布を与える。

```text
NeuralGeneParameter
- mean / μ
- variance or sigma / σ
- optional mutation_rate
```

例:

```text
D1 μ / σ
D2 μ / σ
D3 μ / σ
D4 μ / σ
5-HT1 μ / σ
5-HT2 μ / σ
5-HT3 μ / σ
5-HT4 μ / σ
OXT μ / σ
NA α1 μ / σ
NA α2 μ / σ
NA β μ / σ
```

概念的には、

```text
DNA
→ Neural parameter baseline distribution
→ reaction / learning / retention tendency
```

となる。

身体側についても、

```text
body-size range
movement capability range
sensory capability range
```

等の生成可能域を持たせられる。

### Coreとの分離

```text
DNA != Core M_B
DNA != personality
DNA != behavior command
```

### 現在の扱い

```text
schema / design = active
runtime reproduction / evolution = deferred
```

Generation/DNAの意味設計自体は確定方向へ進めるが、繁殖・進化runtimeは現行vertical sliceの必須条件としない。

---

## 2. Neural Dynamics Layer

### 役割

同じ現在条件・同じ履歴でも、個体によって何を拾い、どの程度反応し、どの程度保持・反復しやすいかを変える比較的低速なGameAI-local条件。

神経物質名は生物学的実在の厳密再現ではなく、操作的近似ラベルとして使う。

### 初期構造

```text
Dopamine
├ D1  : action facilitation
├ D2  : action inhibition
├ D3  : repetition / habit fixation
└ D4  : low-stimulation exploration

Serotonin
├ 5-HT1 : damping / calming
├ 5-HT2 : sensitivity amplification
├ 5-HT3 : forced interrupt
└ 5-HT4 : processing / switching speed

Oxytocin
└ OXT : relation salience / persistence

Noradrenaline
├ α1 : threat focus
├ α2 : recovery / return regulation
└ β  : emergency action output
```

### OXTの対象

OXT的な関係重みは人間関係だけへ限定しない。

```text
Person
Object
Place / Space
Concept
Community
```

への関係保持・接近・再想起等へ作用する候補とする。

```text
OXT high
!= likes everyone
!= friendship score
```

具体的な関係内容はExperience / Relation Historyや、後のM_B形成から生じる。

### 派生Sensitivity

既存の、

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
stability_preference
control_loss_sensitivity
recoverability_sensitivity
social_rejection_sensitivity
```

等は、必要に応じてNeural Dynamics・Body・Historyから導出するGameAI-localな観測軸として保持する。

```text
SensitivityProfile
!= personality totality
!= Core H
!= Core ξ
!= Core M_B by identity
```

### 現在の扱い

現行runtimeでは固定retry sensitivity等の最小sliceが存在する。

今後は、

```text
fixed profile
→ multi-dimensional neural parameters
→ context/body/history-modulated neural state
```

へ段階的に拡張する。

---

## 3. Physical / Body Layer

### 役割

NPCの身体状態と、現在利用可能な行動可能域を扱う。

候補:

```text
FoodNeed
RestNeed
EnergyReserve
ActiveEnergy
injury
movement capability
available body parts
current sensory capability
```

身体状態は低〜中速状態だが、負傷・飢餓・急激な消耗により急変しうる。

### 所有

現在の身体状態はBody Layerが所有し、Current Contextへは判断時点のsnapshotを渡す。

```text
world physical state
!= BodyState
!= CurrentContext snapshot
!= Core M_B by identity
```

### 現在の扱い

movement capabilityの最小sliceは実装済み。

今後、Food / Rest / Energy / Injury / Recoveryを生活実装ロードマップに従って追加する。

---

## 4. Experience / Relation History Layer

### 役割

有限interactionから蓄積された比較的持続的な履歴・関係拘束を保持する。

候補:

```text
InteractionHistoryRecord
RelationHistory
trust_support
avoidance_support
secure_base_support
recall_bias
place-specific history
action success / failure history
DialogueTurn history
item / exchange history
```

例:

```text
Aに助けられた
Aに物を取られた
この場所では襲われた
この場所には食料がある
この道具で救助が成功した
Playerがこの物を「石像」と呼んだ
```

複数方向・矛盾した履歴は共存できる。

```text
RelationHistory != complete world truth
RelationHistory != single friendship score
RelationHistory != Core M_B by identity
```

### 睡眠との接続

日中の詳細履歴は、睡眠時Consolidationによって選別・圧縮・一般化・誤接続され得る。

```text
Experience History
→ Selection
→ Compression
→ Association
→ compact relation candidates
```

### 現在の扱い

movement outcome historyと限定的なhistory influenceは実装済み。

社会的RelationHistory、睡眠圧縮、会話履歴への展開は今後のacceptance boundaryとする。

---

## 5. Realtime / Current Context Layer

### 役割

tickまたは短期windowで高速に変化する現在条件を扱う。

候補:

```text
current bounded observation
currently visible agents / objects / places
current action
immediate target
current place
recent sound / event
short-term priority
body snapshot
neural state snapshot
```

```text
CurrentContext
!= bounded observation packet
!= canonical RIB_B
!= Core M_B
```

現在情報はfinite B / Purpose / selected dimensions / coverage / provenance を通してcanonical pathへ入る。

---

## 6. 更新速度の目安

```text
Generation / DNA       : lifetime fixed in first implementation
Neural Dynamics        : slow baseline + fast current fluctuation
Physical / Body        : slow to medium, sometimes abrupt
Experience / History   : cumulative + consolidation
Realtime / Context     : fast
```

Neural Dynamicsは、

```text
slow genetic baseline
+
current modulation
```

を分ける。

---

## 7. Layer間の拘束伝播

一方向の階段へ固定しない。

```text
DNA
→ Neural baseline / Body possibility

Neural + Body + Experience + CurrentContext
→ current action / attention / interpretation conditions

world resolution
→ new CurrentContext / Body state

accepted interaction
→ Experience History

Sleep / repeated experience
→ compact relation structure
```

各接続は個別に導入・検証する。

Layer間伝播はcanonical `M_B` reconstruction authorityを自動的に意味しない。

---

## 8. 睡眠はLayerではなく更新契機

Sleepを6番目の内部Layerにはしない。

```text
Sleep
├ Body Recovery
└ Experience Consolidation
```

として、Body / Experience / Neural weighting / 関係形成を横断する更新イベントとする。

誤一般化や誤接続を許容するが、provenance・参照整合性は保持する。

---

## 9. Communicationも横断interaction

Communication / Lexiconも内部Layerとして固定しない。

```text
Realtime interaction
→ DialogueTurn
→ Experience History
→ Relation / Lexicon candidate
→ later behavior / sleep consolidation
```

Player介入もこの経路へ入れる。

```text
Player utterance
!= World Truth
```

---

## 10. 生殖・進化への拡張

将来的には、

```text
DNA_A --\
         > recombination / mutation → DNA_child
DNA_B --/
```

とする。

```text
DNA_child
→ neural parameter μ / σ
→ body possibility
→ later experience formation difference
```

Experience / Realtimeの内容自体は原則として直接遺伝しない。

---

## 11. 状態の所有・更新・保持

| Layer | 主な所有状態 | 更新契機 | 保持 | 主な影響先 |
|---|---|---|---|---|
| Generation / DNA | gene parameter μ/σ, morphology range | generation | lifetime | Neural / Body baseline |
| Neural Dynamics | baseline/current neural parameters | generation + current modulation | slow/short mixed | attention, action, retention bias |
| Physical / Body | hunger, energy, injury, capability | world/body resolution | until body update | action possibility |
| Experience / History | finite interaction/dialogue/relation history | accepted event + consolidation | finite/cumulative | later interpretation/action |
| Realtime / Context | current observation/target/place/snapshots | each new observation | tick/window | current decision |

各状態にはownerを一つ定め、他Layerではsource付きsnapshotまたは派生値として参照する。

---

## 12. Controlled Comparison

新しい影響経路を導入する場合、可能な限り一つずつ条件を変える。

例:

```text
same observation
same history
same body
Neural parameter only differs
→ behavior comparison
```

```text
same observation
same neural profile
same body
different finite history
→ behavior comparison
```

変化が起きなかった結果も保持する。

---

## 13. canonical接続

canonical比較へ接続する場合、同じF/F'比較では同一の凍結M_Bを使用する。

```text
Layer value
→ direct E/H increment
```

は禁止する。

Layer状態や履歴をcanonical形成へ接続する場合は、T1の有限な形成・検査・選別・再構成経路を別途通す。

---

## 14. ξ と実体化防止

このLayer分解が実装上十分に機能しても、NPC全体を説明し尽くしたとは扱わない。

```text
Complete_B(NPC Layer Plan) = true
and
ξ(B) != 0
```

> **Layerは設計計画を切り分ける道具であって、NPCそのものではない。**

---

## 15. 文書接続

```text
RDL_GameAI_全体設計地図.md
→ 全体配置

RDL_GameAI_神経パラメーター設計図.md
→ Neural Dynamics詳細

RDL_GameAI_睡眠システム設計.md
→ Sleep / Consolidation詳細

RDL_GameAI_実装手順予定.md
→ Body / life featureの実装順

notes/experiment-roadmap.md
→ canonical成熟度
```

---

## 一文圧縮

> **GameAI Labでは、NPCを Generation/DNA・Neural Dynamics・Physical/Body・Experience/Relation History・Realtime/Current Context の異なる時間スケールとして整理する。DNAは神経力学分布の基準を与え、神経力学・身体・履歴・現在文脈の相互作用が個体差を生む。睡眠・会話は複数Layerを横断する更新・interactionとして扱い、各LayerをCore `M_B`へ自動同一視しない。**

## 改訂履歴

- v0.3: Neural/SensitivityをNeural Dynamicsへ具体化。DNAを神経パラメーターμ/σの基準分布として更新。Sleep / Communicationを横断系として明示。既存runtimeのExperience・Body・Sensitivity最小sliceへ同期。
- v0.2: 状態の所有・更新・保持、影響契約、条件を一つずつ変える比較実験を追加。
- v0.1: レイヤー別設計計画を作成。