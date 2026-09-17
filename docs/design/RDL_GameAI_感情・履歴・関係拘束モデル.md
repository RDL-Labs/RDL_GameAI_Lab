# RDL_GameAI 感情・履歴・関係拘束モデル

*CURRENT DESIGN — Coreの同期点はsemantic referenceを参照*

**責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)のB/D軸。履歴・関係拘束と派生表現の分離を管理する。
**依存:** [神経設計](RDL_GameAI_神経パラメーター設計図.md)、[睡眠設計](RDL_GameAI_睡眠システム設計.md)、[Core reference](../semantic-reference/RDL_Core_T0_T1_reference.md)。
**非責務・状態:** Hの再定義や神経サブタイプ定義はしない。心理的AffectExpression / ActionBias / DialogueToneは候補であり、現行display-only Response Expressionと同一ではない。

## 0. 位置づけ

ゲームAIの「感情らしさ」を固定的な感情メーターではなく、**有限な相互作用履歴・現在の解釈・個体差・関係拘束・未解決不整合のprovenanceから立ち上がる表層現象**として扱う。

```text
SILN / RIB / RIB_B / B / M_B / ξ
→ Core

Sensitivity / Affect / Threat / Opportunity / Recoverability / SFO-like bias
→ GameAI-local / Human-derived hypothesis
```

`RDL_Demos`、`RDL_Enterprise`、`RDL_Human` は素材鉱山として利用するが、旧 `HVec / XiPool / HState / Human heat` 等をCore意味へ昇格させない。

## 1. Hは感情そのものではない

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

```text
Hが高い
!= 不機嫌
!= 怖い
!= 楽しい
!= 嫉妬
!= stress
```

非ゼロ `E` があっても、resolved / ordinary temporal change / boundary change 等なら `H ≈ 0` でよい。

## 2. Observation / RIB_B / Fを分ける

```text
Engine world state
!= bounded observation packet
!= canonical RIB_B
!= F
```

感情モデルはraw packetへ直接反応する前に、どのfinite B / Purposeで何が取得されたかを保持する。

## 3. 感情表現は派生層

以下は将来の派生経路。現在の固定retry profileを遡って神経由来の人格変数とは呼ばない。

```text
Neural Dynamics → derived sensitivity
+ finite interaction history
+ relation history / relation constraints
+ body state
+ current context
+ H provenance when unresolved exists
↓
AffectExpression
ActionBias
DialogueTone
```

`AffectExpression` 自体はT0 primitiveではない。

## 4. 履歴と関係拘束

強い履歴はHではない。History store全体も `M_B` ではない。一方、過去interactionから現在採用された有限なlearned relationはcurrent `M_B` を構成し得る。

```text
past interaction
→ raw Experience History
→ sourced local relation candidates / compressed constraints
→ later local behavior / affect may differ

canonical M_B formation requires a separate reviewed formation contract
```

```text
source modules / stores
→ finite adopted current relations
⊂ M_B

M_B + current RIB_B
→ interpretation / action conditions
→ derived AffectExpression
```

`AffectExpression != M_B by identity` かつ `AffectExpression != H` を維持する。現行runtimeでは履歴由来relationのcanonical admissionはまだ行わない。

同じ対象へ複数方向の履歴が共存してよい。

```text
Aと祭りで遊んだ
→ 再接近したい履歴

危険時にAに置いていかれた
→ 警戒したい履歴
```

単一好感度へ潰さない。

raw Experience History、compressed relation constraints、sleep-consolidated relation candidates、canonical M_Bを同一視しない。睡眠は横断更新windowであって自動的なT1ではない。候補にはsource record・変換規則・時点・適用条件を残す。意味上の誤一般化・誤接続は許容しても、raw履歴や参照・provenanceの破損は許さない。

GameAI-local relation descriptor候補:

```text
binding_strength
trust_support
avoidance_support
secure_base_strength
recall_bias
```

## 5. 感情評価の補助軸

出来事へ最初から `fear=true` / `fun=true` を貼らない。

| 軸 | 操作的意味 |
|---|---|
| `Threat` | 保持したい関係・資源・安全・期待が壊れる可能性 |
| `Opportunity` | 新しい関係・選択肢・探索可能性が広がる可能性 |
| `Control` | 自分の行動が状況へ影響できる見込み |
| `Recoverability` | 逸脱後に戻れる・支援を得られる見込み |
| `Novelty` | 現行解釈・予測からの新奇性 |

これらはCore `E/H/ξ` ではない。

```text
Threat 高 × Control 低 × Recoverability 低
→ fear-like expression が立ち上がりやすい
```

```text
Novelty 高 × Opportunity 高 × Control/Recoverability 十分
→ fun-like expression が立ち上がりやすい
```

混合状態も許す。

## 6. 個体差

神経状態・Body・Historyから導く観測軸の候補（固定人格変数ではない）:

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
derived sensitivity
= Neural Dynamicsを経て何を強く拾いやすいか

current fixed SensitivityProfile
= 神経由来ではない有限retry比較用profile

RelationHistory
= 何が過去に起き、どの関係が形成されたか

M_B
= finite Bのもとで現在の解釈・予測・選択・応答・更新を拘束する自己側構造

H
= 現在の比較で有限assessment後も未解決として残った部分
```

これらを混同しない。

## 7. 安全基地 / recoverability

Human由来の安全基地仮説はGameAI-local modelとして検査できる。

```text
trusted companion
safe home
familiar place
reliable player
```

これらは単純な `fear -= x` ではなく、available action space、expected support、recoverability、attention / exploration biasを変えるfinite relation conditionとして扱う。

## 8. 感情を直接Hへ書き戻さない

禁止:

```text
fear += 1 → H += 1
jealousy += 1 → H += 1
stress += 1 → H += 1
Human Attention request → H += 1
```

許される分離:

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

両者はprovenanceを共有しうるが同じ状態変数ではない。

## 9. 関係履歴の最小record候補

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

履歴は完全な世界記録ではなく、agent / experiment Boundaryで保持した有限recordである。

## 10. 面白さの評価

感情量を最大化しない。

```text
同じNPCでも履歴で反応が変わるか
異なるNPCで同じ出来事への反応が分かれるか
混合した関係が残るか
感情表現が固定周期で振動するだけになっていないか
プレイヤーが履歴から反応を理解できるか
驚きがrandomnessだけでないか
回復・仲直り・再接近が起こりうるか
```

## 11. 現在の導入順

現行runtimeは `E / explicit finite review / H / retained H` までdiagnosticとして実装済み。有限な結果履歴、固定retry sensitivity、movement_scale、派生Response Expressionもoperational。ただし心理的感情・社会関係意味論を実装したとは扱わない。層間分離を検証した後、θ / M_Δ / T1を別契約で扱う。

## 12. 破断条件

次の場合は設計を引き直す。

- Hを気分メーターとして直接使う
- observation packetをRIB_Bと無条件に同一視する
- nonzero Eをunresolvedと自動判定する
- fear / fun / jealousy等からCore Hを直接増減する
- Human側の心理的熱やSFOをCore primitiveへ昇格する
- 単一好感度ですべての関係履歴を潰す
- 一回のイベントで人格全体を上書きする
- ξをnovelty / unknown countとして数値化する

## 一文圧縮

> **GameAIの感情らしさは、Hそのものではなく、有限interactionの履歴・関係拘束・個体感度・身体・文脈・未解決provenanceが組み合わさって表層化するものとして設計する。**
