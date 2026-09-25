# RDL_GameAI — Neural Individuality / Exploration Emergence Future Roadmap

## 0. Status

**FUTURE ROADMAP / DO NOT IMPLEMENT YET**

本稿は、RDL_GameAIにおける将来の神経系・個体差・探索性の実装計画を固定するための文書である。現在の優先実装ではない。

現行系ではまず、

```text
World
→ Experience
→ Outcome Gradient
→ Local Bias
→ Sleep integration
→ Candidate
→ T1
→ Dynamic M_B
```

を完成・安定化させる。本稿の内容は、その後に接続する。

## 1. 基本方針

探索性や「性格」を直接ラベルとして実装しない。

禁止例:

```text
personality = adventurous
exploration = 0.8
risk_taker = true
```

代わりに、少数の神経系パラメータの差から、

```text
観測差
→ 感じ方の差
→ Local Bias形成差
→ Goal差
→ Trajectory差
→ Experience差
→ M_B差
```

を発生させる。その累積結果を外部観測者が「慎重」「刺激追求」「研究型」「細かい」「大胆」「飽きやすい」等と解釈できる状態を目指す。

## 2. 最初の二軸

### N1 — Error Sensitivity

暫定定義:

> 観測された関係差・変化に対して、どの程度小さい差まで反応するか。

```text
error sensitivity 高 → 小さな差を拾いやすい
error sensitivity 低 → 小さな差を無視しやすい
```

これは知能・真理性・ρそのものではない。

```text
error sensitivity != ρ
error sensitivity != intelligence
error sensitivity != H
```

GameAI-local neural parameterとする。

### N2 — Reward Threshold

暫定定義:

> 正方向のOutcome Gradientに対して、どの程度の大きさから十分な報酬反応を形成するか。

```text
reward threshold 低 → 小さな正勾配でも報酬反応
reward threshold 高 → 大きな正勾配でないと強い報酬反応を形成しにくい
```

これもcanonical変数ではない。

```text
reward threshold != theta_eff
reward threshold != H
reward threshold != M_B
```

## 3. 二軸だけで予想される個体差

### A. Error Sensitivity 高 × Reward Threshold 低

小さい差をよく拾い、小さい改善でも報酬を感じる。局所改善、細かい調整、技巧化、既知領域の精密化、早い局所満足へ寄り、外からは丁寧・細かい・改善好きに見える可能性がある。

### B. Error Sensitivity 高 × Reward Threshold 高

小さい差をよく拾うが、小さい改善では満足しない。差分を細かく拾い、さらに差分を探し、より深い条件分解と長い探索へ進み、外からは深掘り型・研究型・執拗・探究的に見える可能性がある。

この型は「危険だから避ける」だけでなく、「何が危険なのか」「どの条件なら大丈夫か」「どこまで近づけるか」という方向へ潜りやすい可能性がある。

### C. Error Sensitivity 低 × Reward Threshold 低

小さい差は拾わず、比較的小さな成功でも十分とする。粗い分類、早い判断、安定行動、局所的な満足へ寄り、外からは単純・安定・実用的・切り替えが早いように見える可能性がある。

### D. Error Sensitivity 低 × Reward Threshold 高

小さい差は拾わず、大きな正勾配でないと満足しない。通常成功への反応は薄く、大成功や大イベントを強く残すため、より大きな勾配を生む状況へ寄り、外からは刺激追求・大振り・高リスク選好に見える場合がある。

## 4. 重要原則

個性を直接作らない。

```text
neural parameters
→ perception / response difference
→ history difference
→ M_B difference
→ behavior difference
```

同じWorld eventでも個体によって感じ方が違ってよい。

```text
raw Outcome Gradient
→ neural transform
→ perceived gradient
→ Local Bias

Δ_raw != Δ_perceived
```

同じFood取得・同じ負傷でも、Agent Aは強く反応し、Agent Bはほぼ反応しないことが成立する。

## 5. Risk側にも同様の構造を置く

Rewardだけを神経調整しない。将来的には負方向にも`loss sensitivity`や`loss threshold`のような軸を検討する。ただし初期phaseでは増やしすぎず、まず`error sensitivity`と`reward threshold`の2軸のみでどれだけ差が出るか検証する。

## 6. 「危険が好き」を直接実装しない

高リスク行動を取る個体について`likes_danger = true`とはしない。小さな勾配には反応しにくい、大きな成功だけ強く報酬化する、小さな損失には反応しにくい、といった組み合わせから危険な状況を選びやすい結果が出る形を優先する。

将来的に高覚醒状態そのものが正方向へ作用する神経構造を追加する可能性はあるが、別phaseとする。

## 7. 探索性の位置付け

探索性は最初から一つの固定scalarとして持たせない。

```text
error sensitivity
reward threshold
loss sensitivity
novelty sensitivity
persistence
switch cost
```

等の組み合わせから結果として現れる行動傾向とする。`exploration tendency`を実装する場合も、上位ラベルではなく観測用derived valueを優先する。

## 8. 探索とGoal形成

探索性が作用する場所はAction selectionだけではない。より重要なのはGoal generationとTrajectory generationである。

```text
current M_B:
beast territory is associated with injury

reward history:
tasty food has high positive bias
```

単純評価ではsafe foodを選ぶだけで終わりうる。探索系では、別ルート、Beastが離れる条件、途中までの接近、他個体との協力、時間差など、新しいTrajectory候補が生成されうる。

```text
known choice evaluation != exploratory candidate generation
```

## 9. SILN / T1との関係

探索候補生成と価値判断を混ぜない。

```text
M_B
+ neural state
+ current Goal
→ exploratory expansion
→ candidate trajectories

candidate trajectories
→ evaluation / selection
```

探索時点で現在の価値基準を強く適用しすぎると未知候補そのものが生成されない可能性があるため、`exploration != selection`を維持する。

## 10. 集団内分散

全個体を同じ探索傾向にしない。

```text
全個体が高リスク探索
→ 個体損失が過大
→ 集団崩壊リスク

全個体が極端に低探索
→ 現在環境では安定
→ 未知条件・環境変化への適応力低下
```

将来的には神経特性の分布そのものを重要な集団状態として扱う。

## 11. DNAとの接続

神経個体差を完全ランダムに生成するだけで終わらせない。

```text
DNA baseline
→ neural parameter ranges / tendencies
→ developmental variation
→ individual neural state
```

ただし`DNA != initial M_B`を維持する。DNAは何を学ぶかを直接持たず、どう差を感じやすいか、どう反応しやすいかへ偏りを与える。

## 12. Evolutionとの接続

```text
DNA
→ neural tendency
→ Experience distribution
→ M_B formation
→ behavior
→ survival / reproduction
→ next-generation DNA distribution
```

探索的個体が常に優位になるとは仮定しない。高探索は高発見可能性と高損失可能性の両方を持つ。

## 13. Future Implementation Phases

### NERV-0 — Contract only

現在。実装しない。将来要求を固定し、canonicalとの混同と現行Local Bias系への先回り実装を防ぐ。

### NERV-1 — Neural parameter container

最初のGameAI-local神経状態。`agent_id`、`error_sensitivity`、`reward_threshold`のみ。まだ行動へ影響させない。

### NERV-2 — Perceived Gradient projection

```text
raw Outcome Gradient
+ neural parameters
→ perceived Outcome Gradient
```

同じeventと異なるagent neural stateから異なるperceived gradientが生じることを確認する。

### NERV-3 — Local Bias integration

```text
raw Outcome Gradient
→ neural projection
→ perceived gradient
→ Local Bias
```

へ拡張する。canonical authorityは与えない。

### NERV-4 — Individual divergence

同一World条件で複数agentを走らせ、Experience差、Local Bias差、Sleep Candidate差、M_B差が自然に発生するか確認する。

### NERV-5 — Goal sensitivity

神経差をGoal優先度へ限定的に接続する。まだ自由探索は行わない。

### NERV-6 — Exploratory Trajectory generation

既知の選択肢だけでなく、現在のM_Bで完全には保証されないTrajectoryを生成可能にする。探索とSelectionを分離する。

### NERV-7 — Risk / novelty expansion

必要に応じて`loss sensitivity`、`loss threshold`、`novelty sensitivity`、`persistence`、`switch cost`を追加する。一度に追加しない。

### NERV-8 — DNA baseline

神経パラメータをDNA由来baselineへ接続する。

### NERV-9 — Generational ecology

複数世代で、探索型・安定型・深掘り型・刺激追求型等に見える個体差の分布がどのように変化するか観察する。

## 14. Acceptance Philosophy

各phaseでは「人格らしく見えるか」をAcceptanceにしない。観測可能な有限差で判定する。

```text
same World
same event
different neural parameters
→ different perceived gradients
```

または、

```text
same M_B
same need
different neural parameters
→ different Goal / Trajectory candidates
```

を用いる。

## 15. Non-goals

当面実装しない:

```text
Big Five
MBTI
fixed personality classes
emotion labels as truth
human psychiatric categories
global intelligence score
single exploration scalar
single risk-taking scalar
```

人間心理分類をそのままGameAI内部構造へ入れない。

## 16. Canonical Boundary

以下はGameAI-localである。

```text
error sensitivity
reward threshold
perceived gradient
neural state
exploration tendency
```

これらを`B`、`M_B`、`ξ`、`ρ`、`E`、`H`、`theta_eff`、`M_delta`へ直接同一視しない。

```text
error sensitivity != ρ
reward threshold != theta_eff
perceived gradient != E
neural activation != H
```

## 17. 現段階での優先順位

現在の実装作業では、このroadmapを開始しない。まず現在の、

```text
Outcome Gradient
→ Local Bias
→ Sleep
→ Candidate
→ T1
→ Dynamic M_B
```

を閉じる。その後、`Dynamic M_B → Goal → Trajectory → Action`の最小系を確認し、さらにその後に神経系・個体差・探索性へ進む。

推奨順序:

```text
1. Current learning loop closure
2. M_B-informed behavior
3. Neural substrate
4. Neural individuality
5. Exploratory behavior
6. DNA
7. Generational evolution
```

## 18. Implementation Hold

この文書はfuture roadmap onlyである。現時点ではruntime code、behavior logic、canonical evaluator、Local Bias formation、T1 pathを変更しない。

```text
NERV-0: DEFERRED / CONTRACT ONLY
NERV-1..9: POST-NEURAL / DO NOT IMPLEMENT YET
```

本稿を理由として、現行GameAIへexploration scalar、personality type、risk-taking coefficient、neural parametersを先行実装しない。

この文書の目的は、将来、神経系構築後に「個性」や「探索性」を上位ラベルとして追加するのではなく、少数の神経感度差から創発させるための実装順序を保存することである。
