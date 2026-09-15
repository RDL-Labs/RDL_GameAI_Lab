# RDL_Human — ゲームAI素材棚卸し（2026-09-15再確認）

Source:

```text
https://github.com/Aporapeiron/RDL_Human
checked current line through: 4926d6e1525d77103d6d3d693a6a3cc1d53dd057
```

## 位置づけ

`RDL_Human` はGameAIへ「人間心理の真理」を移植する規範ではない。

現在のHuman本体は Core BASE / SPEC v2.3へ同期し、Human固有の心理的熱、SFO、自己境界、認知空間、流体比喩、時間層などを **T3仮説変数・比喩・操作モデル**としてCore primitiveから明示的に分離している。

このためGameAIでは、Humanを以前より安全に **感度・関係拘束・安全基地・文脈依存性・時間スケールの仮説鉱山**として利用できる。

## 1. 現行意味境界

Human側自身が次を明示している。

```text
人間 / 人格 != M_B
未知刺激 / 新奇性 / ノイズ != ξ
Human側の心理的「熱」 != Core H
Human側の「自己境界」仮説 != Core Bそのもの
RIB_B != F
Function != M_B
```

GameAIもこの境界を継承する。

## 2. 採掘価値の高い領域

### 2.1 SFO / directional tendency

固定人格タイプではなく、どの方向へ流れやすいかという仮説として使う。

GameAI-local候補:

```text
novelty_sensitivity
stability_preference
attachment_sensitivity
threat_sensitivity
```

これらはSelectionやaction biasの補助になりうるが、Core `M_B / H / ξ` ではない。

### 2.2 文脈依存の性格表現

```text
history
× relationship
× place
× body state
× current context
→ visible behavior / personality expression
```

固定ラベルではなく、finite contextによって表現が変わる設計素材として有用。

### 2.3 安全基地 / recoverability

```text
trusted companion
safe home
familiar place
reliable player
```

これらが探索・回復可能性・行動選択へどう影響するかという仮説は、GameAIのrelation-aware behaviorに有用。

ただし単純な `fear -= x` として持ち込まず、現在のinteraction / interpretation / action possibilityを変える関係条件として検証する。

### 2.4 関係拘束・再呼出し

GameAI-local候補:

```text
binding_strength
secure_base_strength
recall_bias
```

これらは `C_rel` 的な応用候補になりうるが、Core必須変数ではない。

### 2.5 複数時間スケール

固定4層として採用せず、変化速度を分離する設計道具として使う。

```text
slow
  temperament-like sensitivity / body constraints

medium-slow
  strong relational bindings / long-term preference

medium
  recent history / habit / place meaning

fast
  current interpretation / dialogue context / affect expression
```

## 3. 感情設計への利用

GameAIでは感情語をCore状態へ直接置かない。

```text
finite interaction history
+ relation history
+ sensitivity profile
+ body state
+ current context
+ unresolved provenance when present
↓
AffectExpression
ActionBias
DialogueTone
```

重要:

```text
H != emotion strength
Human heat != Core H
novelty != ξ
SFO != fixed personality type
```

## 4. 旧資料の扱い

Human repoでは `SSDからの翻訳/` や `_archive/`、PRE-v2.3 referenceが現行定義根拠から分離されている。

GameAIでHumanを採掘する場合も、各フォルダーの `CURRENT / PRE-v2.3 REFERENCE` 区分を優先する。

旧資料から概念を借りる場合は、現行Core v2.3へ再翻訳してからGameAI-local hypothesisとして扱う。

## 5. GameAIへの優先度

High:

```text
sensitivity profiles
context-dependent personality expression
secure-base / recoverability hypotheses
relation binding / recall bias
multi-timescale sedimentation
```

Medium:

```text
SFO directional hypotheses
attachment-style-like recurrent patterns
social / dialogue hypotheses
```

Deferred:

```text
neurotransmitter-like mappings
clinical models
human physiology reproduction
Human psychological heat as system state
```

## 6. GameAIでの使用原則

```text
1. Core v2.3と衝突していないか
2. Human variableをCore primitiveへ昇格させていないか
3. H/E/ξを心理値へ短絡していないか
4. history / relation / contextを残しているか
5. 個体差が感度と履歴の両方から出るか
6. Human仮説をNPC普遍真理として扱っていないか
7. finite Bと破断条件を明示しているか
```

## 一文圧縮

> **現行RDL_Humanは、Core v2.3との境界を明示した上で、気質・関係拘束・安全基地・文脈依存性・時間スケールからGameAI固有の感情らしい振る舞いを設計するためのT3仮説鉱山として使う。**
