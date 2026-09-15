# RDL_GameAI 感情・履歴・関係拘束モデル
## DRAFT v0.2 — Core v2.3準拠 / 「強いAI」ではなく「面白いAI」のための最小設計

### 0. 位置づけ

本書は、ゲームAIの「感情らしさ」を固定的な感情メーターではなく、**有限な相互作用履歴・現在の解釈・個体差・関係拘束・未解決不整合のprovenanceから立ち上がる表層現象**として扱うための設計メモである。

意味論の基準は `RDL_Core` BASE / SPEC v2.3 とする。

```text
SILN / RIB / RIB_B / B / M_B / ξ
→ Core

Sensitivity / Affect / Threat / Opportunity / Recoverability / SFO-like bias
→ GameAI-local / Human-derived hypothesis
```

`RDL_Demos`、`RDL_Enterprise`、`RDL_Human` は素材鉱山として利用するが、旧 `HVec / XiPool / HState / Human heat` 等をCore意味へ昇格させない。

---

## 1. 基本原則

### 1.1 Hは感情そのものではない

Core `H` は、同じ更新前 `M_B` で形成した `F / F'` の差 `E` のうち、現在構造で吸収・解消されず、有限assessment後も未解決として残る部分である。

```text
RIB_B(t)
↓ same frozen M_B
F(t)

RIB_B(t+Δ)
↓ same frozen M_B
F'(t+Δ)
↓
E = Δ(F,F')
↓ finite assessment
unresolved only
↓
H_vec → H
```

したがって、

```text
Hが高い
!= 不機嫌
!= 怖い
!= 楽しい
!= 嫉妬
!= stress
```

非ゼロ `E` があっても、resolved / ordinary temporal change / boundary change等なら `H ≈ 0` でよい。

### 1.2 Observation / RIB_B / Fを分ける

```text
Engine world state
!= bounded observation packet
!= canonical RIB_B
!= F
```

感情モデルはraw packetへ直接反応する前に、どのfinite B / Purposeで何が取得されたかを保持する。

### 1.3 感情表現は派生層

概念的には次のように扱う。

```text
finite interaction history
+ relation history / relation constraints
+ sensitivity profile
+ body state
+ current context
+ H provenance when unresolved exists
↓
AffectExpression
ActionBias
DialogueTone
```

`AffectExpression` 自体はT0 primitiveではない。

---

## 2. 「楽しい履歴」と「怖い履歴」

### 2.1 履歴はHではない

強い履歴は、現在の `M_B` やGameAI-local relation modelの形成条件になりうる。

```text
過去のinteraction
↓
relation history / current M_B formation
↓
現在のRIB_Bをどう読むかが変わる
```

履歴そのものを `H` として保存・再放出する必要はない。

### 2.2 同じ対象に複数方向の履歴が共存してよい

例:

```text
Aと祭りで遊んだ
→ 再接近したい履歴

危険時にAに置いていかれた
→ 警戒したい履歴
```

結果:

```text
Aと一緒にいたい
+
危険時には全面的に頼りたくない
```

単一好感度へ潰さない。

### 2.3 relation constraintは方向を持つ

GameAI-local descriptor候補:

```text
binding_strength
trust_support
avoidance_support
secure_base_strength
recall_bias
```

これらは必要に応じて `C_rel` 的補助として使えるがCore必須変数ではない。

---

## 3. 感情評価の補助軸

出来事へ最初から `fear=true` / `fun=true` を貼らない。

候補となるGameAI-local descriptor:

| 軸 | 操作的意味 |
|---|---|
| `Threat` | 保持したい関係・資源・安全・期待が壊れる可能性 |
| `Opportunity` | 新しい関係・選択肢・探索可能性が広がる可能性 |
| `Control` | 自分の行動が状況へ影響できる見込み |
| `Recoverability` | 逸脱後に戻れる・支援を得られる見込み |
| `Novelty` | 現行解釈・予測からの新奇性 |

これらはCore `E/H/ξ` ではない。

### 怖い方向の仮説

```text
Threat 高
× Control 低
× Recoverability 低
→ fear-like expression が立ち上がりやすい
```

### 楽しい方向の仮説

```text
Novelty 高
× Opportunity 高
× Control / Recoverability が十分
→ fun-like expression が立ち上がりやすい
```

### 混合状態

```text
Novelty 高
+ Threat あり
+ Recoverability 十分
→ 「怖いけど楽しい」も可能
```

排他的emotion state machineへ固定しない。

---

## 4. 個体差

### 4.1 sensitivityとhistoryを分ける

候補:

```text
threat_sensitivity
novelty_sensitivity
attachment_sensitivity
stability_preference
control_loss_sensitivity
recoverability_sensitivity
social_rejection_sensitivity
```

```text
SensitivityProfile
= 何を強く拾いやすいか

RelationHistory
= 何が過去に起き、どの関係が形成されたか

M_B
= finite Bのもとで現在の解釈・予測・選択・応答・更新を拘束する自己側構造

H
= 現在の比較で未解決として残った部分
```

これらを混同しない。

### 4.2 同じ出来事への違い

```text
未知の洞窟

NPC A: threat_sensitivity 高
→ 警戒表現

NPC B: novelty_sensitivity 高
→ 探索表現

NPC C: control_loss_sensitivity 高
→ 一人なら警戒
→ trusted companion同伴なら探索可能
```

「性格」は固定ラベルではなく、感度・履歴・関係・場所・身体状態・現在文脈の組み合わせから表層化するものとして扱う。

---

## 5. 安全基地 / recoverability

Human由来の安全基地仮説はGameAIで有用。

候補:

```text
trusted companion
safe home
familiar place
reliable player
```

これらは単純な `fear -= x` ではなく、

```text
available action space
expected support
recoverability
attention / exploration bias
```

を変えるfinite relation conditionとして検証する。

---

## 6. 履歴依存の再活性

現実の臨床概念を再現するモデルとはしない。

ゲームAI上の極端な履歴依存例として、次の形を考えられる。

```text
past interaction
↓
relation / M_B formation changes
↓
later similar finite RIB_B
↓
current interpretation differs because history differs
↓
behavior / affect expression differs
```

重要:

```text
過去Hを保存して再放出する
```

ことを必須にしない。

---

## 7. 感情を直接Hへ書き戻さない

禁止する短絡:

```text
fear += 1 → H += 1
jealousy += 1 → H += 1
stress += 1 → H += 1
Human Attention request → H += 1
```

許される流れ:

```text
interaction
→ RIB_B
→ interpretation under M_B
→ E
→ finite assessment
→ unresolved H if any

separately:
interaction/history/context/body/sensitivity
→ AffectExpression
```

両者はprovenanceを共有しうるが、同じ状態変数ではない。

---

## 8. 関係履歴の最小表現候補

初期GameAIでは以下のようなfinite recordで十分。

```text
InteractionHistoryRecord
  tick / time
  actor
  counterpart
  place
  action
  observed response
  source observation id
  subsequent observation id
  relation effects
  relevant body/context state
```

履歴は「真実の完全記録」ではなく、そのagent / experiment Boundaryで保持した有限record。

---

## 9. 面白さの評価

感情量を最大化しない。

観測候補:

```text
同じNPCでも履歴で反応が変わるか
異なるNPCで同じ出来事への反応が分かれるか
混合した関係が残るか
感情表現が固定周期で振動するだけになっていないか
プレイヤーが履歴から反応を理解できるか
驚きがrandomnessだけでないか
回復・仲直り・再接近が起こりうるか
```

---

## 10. 現在の導入順

```text
P3  RIB_B acquisition
P4  explicit frozen M_B / F / F' / E
P5  finite unresolved review / H
P6  relation history
P7  sensitivity + affect expression
P8  M_Δ / T1 reconstruction
```

したがって、感情実装を先に本格化しない。

---

## 11. 破断条件

次の場合は設計を引き直す。

- Hを気分メーターとして直接使う
- observation packetをRIB_Bと無条件に同一視する
- nonzero Eをunresolvedと自動判定する
- fear / fun / jealousy等からCore Hを直接増減する
- Human側の心理的熱やSFOをCore primitiveへ昇格する
- 単一好感度ですべての関係履歴を潰す
- 一回のイベントで人格全体を上書きする
- ξをnovelty / unknown countとして数値化する

---

## 一文圧縮

> **GameAIの感情らしさは、Hそのものではなく、有限interactionの履歴・関係拘束・個体感度・身体・文脈・未解決provenanceが組み合わさって表層化するものとして設計する。**
