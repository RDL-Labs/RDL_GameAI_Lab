# RDL_Human — ゲームAI素材棚卸し

## 位置づけ

`RDL_Human` は、GameAIに人間心理をそのまま移植するための規範ではない。
本Labでは、**気質・愛着・感情表現・時間スケール・関係依存の性格表現を考えるためのT3仮説鉱山**として扱う。

意味論の正本は `Aporapeiron/RDL_Core` の T0/T1 とする。
Human側の神経物質対応や人間固有仮説は、そのままGameAIのCore Primitiveへ昇格させない。

---

## 1. 採掘価値の高い領域

### 1.1 SFO — 固定性格ではなく流向

Human側には、性格を固定ラベルではなく、認知空間上でどちらへ流れやすいかという動的流向として扱う設計がある。

ゲーム向け抽象化候補：

```text
Explore   → 新奇・探索へ流れやすい
Maintain  → 安定・維持へ流れやすい
Connect   → 同期・接近へ流れやすい
Defend    → 警戒・距離確保へ流れやすい
```

GameAIでは、これを人格ラベルではなく `SensitivityProfile` や行動バイアス候補として扱える。

例：

```text
novelty_sensitivity
stability_preference
attachment_sensitivity
threat_sensitivity
```

---

### 1.2 多重境界とコスト地形

Human側では、同じ個体でも場所・相手・身体状態・過去履歴などによって認知空間のコスト地形が変わり、観測される性格表現が変わるという考え方がある。

GameAIへの翻訳：

```text
trait
× history
× relationship
× place
× body state
× current context
→ visible behavior / personality expression
```

これにより、

```text
NPC A = 慎重
```

という固定属性ではなく、

```text
知らない場所 + 単独
→ 慎重

安心できる仲間 + 慣れた場所
→ 活発 / 甘える
```

という状況依存の個体差を作れる。

---

### 1.3 愛着 / 安全基地

Human側の愛着翻訳には、特定他者が探索後の回復点・安全基地として機能するという構造がある。

GameAIへの翻訳候補：

```text
trusted companion
safe home
familiar place
reliable player
```

これらは `Recoverability` を高める関係的条件として利用できる。

例：

```text
未知の森 + 単独
→ fear tendency ↑

未知の森 + trusted companion
→ fear tendency ↓
→ exploration / fun tendency ↑
```

重要なのは、安心を単純な `fear -= x` とするのではなく、現在の解釈・予測・行動可能域を変える関係拘束として扱うこと。

---

### 1.4 関係境界の粘着性

愛着・嫉妬・保護・排他・信頼などを別々の感情メーターとして持つのではなく、

```text
誰を重要対象として強く結びつけるか
誰を自己圏 / 親密圏へ内側化するか
どの履歴が繰り返し再呼出しされるか
```

という上流構造として扱える。

GameAI向け候補：

```text
binding_strength
inside_weight
recall_bias
secure_base_strength
```

これらは `C_rel` の実装候補であり、T0 Core必須変数ではない。

---

### 1.5 複数時間スケール

Human側の4層時間スケールは、そのまま固定階層として採用せず、**変化速度の違いを分ける設計道具**として使える。

GameAI向け簡略化：

```text
slow
  temperament / body constraints

medium-slow
  strong relational bindings / long-term preferences

medium
  recent history / habits / learned place meanings

fast
  current prediction / dialogue context / short affect expression
```

これにより、単発イベントで人格全体が書き換わることを防ぎつつ、長期履歴が徐々に沈殿する構造を作れる。

---

## 2. 感情設計への利用

Human側の素材は、GameAIで感情値を直接持つためではなく、**なぜ同じ出来事でも個体・文脈・関係によって違う表現になるか**を考える素材として使う。

現在のGameAI側の基本方針：

```text
H
= unresolved inconsistency

AffectExpression
= H provenance
+ relation history
+ sensitivity profile
+ body state
+ current context
```

Human側の概念はこの派生層へ接続する。

---

## 3. そのまま持ち込まないもの

以下は自動移植しない。

```text
DA / 5-HT / OXT / NA の固定対応
人間の神経生理そのもの
臨床心理モデルの直接再現
H = 感情強度
愛着理論 = NPC真理モデル
SFO = 固定人格タイプ
4層 = 実在する固定階層
```

必要な場合はGameAI向けの抽象係数へ翻訳する。

---

## 4. GameAIへの接続候補

```text
RDL_Human
  ↓
SensitivityProfile
  novelty_sensitivity
  threat_sensitivity
  attachment_sensitivity
  stability_preference

RelationalBinding
  binding_strength
  secure_base_strength
  recall_bias

Contextual Personality
  place
  partner
  body state
  recent history

Temporal Layers
  slow traits
  deep history
  recent history
  current context
```

これらはT0/T1の上に置くGameAI固有の実装候補である。

---

## 5. GameAIでの使用原則

Human由来の概念を使う際は、以下を確認する。

```text
1. T0/SPECと衝突していないか
2. HやEを直接感情値へ短絡していないか
3. 固定人格ラベルへ潰していないか
4. 履歴・関係・文脈を残しているか
5. 個体差が感度と履歴の両方から出るか
6. 人間仮説をゲームNPCの普遍真理として扱っていないか
```

---

## 6. 優先度

初期導入優先度：

```text
High
- sensitivity profile
- contextual personality
- secure-base / recoverability effect
- relation binding strength

Medium
- multi-timescale sedimentation
- attachment-style-like patterns

Deferred
- neurotransmitter-like implementation
- clinical trauma reproduction
- detailed human-specific physiology
```

---

## 7. 一文圧縮

> `RDL_Human` は、GameAIに「人間らしさ」を直接移植する鉱山ではなく、**気質・関係拘束・安全基地・文脈依存性・時間スケールから、固定メーターではない感情らしい振る舞いを立ち上げるための仮説鉱山**として使う。
