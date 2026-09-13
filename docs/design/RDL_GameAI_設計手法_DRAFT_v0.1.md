# RDL_GameAI 設計手法
## DRAFT v0.1 — T0/T1準拠・Enterprise設計規律のゲームAI向け運用

## 0. 目的

本書は `RDL_GameAI_Lab` における設計・実装・実験の進め方を定める。

目的はRDL語彙をゲームAIへ機械的に移植することではない。`RDL_Demos`、`RDL_Human`、`RDL_Enterprise` を素材鉱山として扱い、**意味論は RDL_Core の T0/T1 を基準に検査し、Enterpriseで確立した有限Boundary・段階的実装・受入証拠・停止規律を用いて、ゲームAI向けに再構成する**。

本設計手法自体も有限Boundary上の運用方針であり、自己例外化しない。

---

## 1. 権威順序

```text
RDL_Core
  T0 BASE / SPEC
      ↓ semantic authority
  T1 SILN Operations
      ↓ operational method

RDL_Enterprise
  design discipline
  reference implementation
  durability / replay / promotion mechanisms
      ↓ extraction / translation

RDL_Demos
  world / body / perception / relations / dialogue / simulation
      ↓ extraction / translation

RDL_Human
  temperament / attachment / affect / temporal-scale hypotheses
      ↓ extraction / translation

RDL_GameAI_Lab
  game-specific Boundary
  game-specific Selection criteria
  experiments
  implementations
```

原則は、**既存実装は working material、T0 BASE/SPEC は semantic authority、T1 は形成・検査・再構成の操作方法、GameAI は現在の応用Boundary** とする。

既存コードのクラス名・変数名・挙動は、それだけではRDL上の意味を保証しない。

---

## 2. T0で固定する最低意味境界

### 2.1 基底は相互作用

一方向の入力を独立した基底入力として置かない。

```text
関係ネットワーク上の相互作用
↓
有限Boundary B / 観測位置 / 時間断面 / 対象方向
↓
作用断面
```

ゲームAIでは、エンジン側の世界状態とエージェント側の観測を分離する。

```text
Engine world state / simulation reference
≠ Agent Observation
≠ Agent EFP
≠ Agent M_B
```

エンジン状態はシミュレータ上の参照状態として利用できるが、RDLの基底上の `Truth` へ昇格させない。

### 2.2 EFPは相互作用から切り出された作用断面

```text
interaction
  ↓ Section_B(...)
EFP
  ↓ interp(M_B, EFP)
F
```

`EFP` は独立外生入力である必要はない。エージェントの行動は後続する相互作用条件を変え、その結果として次の `EFP'` の生成条件へ回り込んでよい。

```text
EFP_t
→ F_t
→ response / action
→ interaction conditions change
→ EFP_t+Δ
```

### 2.3 F / F' は同じ更新前 M_B で比較する

```text
F(t)    = interp(M_B, EFP(t))
F'(t+Δ) = interp(M_B, EFP(t+Δ))
E(t+Δ)  = Δ(F, F')
```

比較途中で `M_B` を更新しない。

### 2.4 Hは感情ではない

```text
E
↓ current M_B で吸収・解消できるか
未解消分のみ
↓
H
```

したがって、

```text
H ≠ fear ≠ fun ≠ anger ≠ jealousy ≠ stress
```

感情表現は、Hの発生源・関係履歴・感度・現在文脈などから派生させる。

### 2.5 ξを消さない

```text
∀B_finite: ξ(B) ≠ 0
```

seed、snapshot、engine stateが揃っても、再現性は `bounded reproducibility / bounded equivalence` として扱う。

---

## 3. T1を学習・再構成の骨格として使う

T1では `M_B` の形成・更新経路を次の代謝として扱う。

```text
Probe
→ Expansion
→ Inspection
→ Selection
→ Reconstruction
```

### Probe
未知との相互作用へ極小接触し、現在のBoundary内で差分を得る。

```text
Probe_B(interaction) → {Δ}_B
with ξ' ≠ 0
```

### Expansion
一つの即断へ潰さず、候補構造の可能性を開く。

```text
危険かもしれない
友好的かもしれない
夜だけ危険かもしれない
特定NPCと一緒なら安全かもしれない
```

外部の有効な理論・モデル・アルゴリズムは「酵素」として借用してよい。RDL側で再発明しない。

### Inspection
候補へ検査道具を当てる。

```text
simulation
replay
counterfactual rerun
shadow behavior
canary trial
statistical comparison
scenario test
```

重要：

```text
Inspection tool ≠ Selection criterion
```

### Selection
何を残すかは各系設計の責務。GameAIでは勝率だけを基準にしない。

候補：

```text
履歴との連続性
個体差の維持
行動の可読性
関係変化の豊かさ
意外性
単調化の回避
破綻的挙動の回避
再訪時の意味変化
```

`retain / reject / defer` を区別する。

### Reconstruction
選別された構造を新しい `M_B'` として定着させる。

```text
Repair
Phase Shift
Coexistence / Parallel
```

学習を単一方針への収束に限定しない。

例：

```text
旧: 森は楽しい

新経験: 夜に単独で襲われた

悪い更新: 森は危険 に全面置換

望ましい候補:
昼 + 仲間あり → 楽しい
夜 + 一人      → 警戒
```

---

## 4. Enterpriseから継承する設計規律

### 4.1 Description / Candidate / Commitment / Active を分離する

```text
Description
→ Candidate
→ Evidence / Verification
→ Commitment
→ Active Constraint
```

ゲーム向け例：

```text
Rumor
→ Belief Candidate
→ observed / tested support
→ Committed Belief
→ Behavioral Constraint
```

一度噂を聞いただけで確定信念へ変えない。

### 4.2 UNKNOWNを潰さない

最低限、以下を区別する。

```text
UNKNOWN
UNRESOLVED
NOT_EVALUATED
OPPOSE
SUPPORT
```

```text
知らない
≠ 嘘だと思う
≠ 危険だと思う
≠ 評価済み
```

### 4.3 Authority ≠ Truth

社会的役割と事実妥当性を同一化しない。

```text
村長
→ 行動許可には強いAuthority

村長
→ 森の未知生物について常に正しいとは限らない
```

### 4.4 Context / Provenanceを回収可能にする

意味遷移に影響する条件を暗黙にしない。

```text
time
location
seed
observer
perception boundary
relationship state
body state
active M_B version
action taken
response observed
relevant history refs
```

### 4.5 通常時はshallow path

```text
L0  通常行動
L1  mismatch gate
L2  local inspection
L3  relational inspection
L4  adaptive escalation
L5  reconstruction → shallow pathへ復帰
```

深く考えたこと自体を成功としない。

### 4.6 新しい型は破断が要求したときだけ追加する

判断文：

> **この型がないと、今起きている破断を再検査できないか。**

追加理由になりうるもの：

```text
T0/SPEC違反を直接防ぐ
実際の実験破断を既存型で追跡できない
Boundary / Provenanceが回収できない
複数実験で繰り返し現れる共通契約
```

---

## 5. Vertical Slice First

横に機能を増やす前に、一つの相互作用縦断を最後まで通す。

```text
world interaction
↓
bounded perception
↓
EFP
↓
interp(M_B, EFP)
↓
F
↓
action
↓
world / relation changes
↓
EFP'
↓
same pre-update M_B
↓
F'
↓
E
↓
unresolved residual
↓
H
↓
local maintenance or reconstruction
↓
later behavior changes
```

最初から感情全体系、長期文化、高度LLM会話、複雑な社会制度、繁殖、経済、全面Canary/Shadowを入れない。

---

## 6. Acceptance Evidenceを先に書く

各Phaseは「何を実装したか」ではなく、**何が観測されれば受入か**を定義する。

```text
P0 T0/T1 sync
accept:
GameAIのH・EFP・F/F'定義がT0 v2.1と衝突しない

P1 bounded perception
accept:
agent behavior does not directly read engine reference state

P2 interaction loop
accept:
agent action changes conditions generating later EFP'

P3 F/F'
accept:
F and F' are produced with identical pre-update M_B

P4 H
accept:
fear/fun/jealousy labels cannot directly increment H

P5 relation history
accept:
same present event yields different interpretation after different history

P6 sensitivity
accept:
same history can yield different behavior across temperament profiles

P7 reconstruction
accept:
selected experience changes later interpretation without erasing ξ

P8 interestingness
accept:
behavior becomes history-dependent without collapsing into one dominant optimal policy
```

```text
test green
!= RDL is true
!= model is complete
!= all game situations validated
```

---

## 7. Observation / Hypothesis / Commitmentを分ける

```text
Observation
= 起きたこと

Hypothesis
= なぜ起きたかの候補

Candidate Fix
= 修正案

Commitment
= 採用を決めた修正

Active
= 実際に有効化されている修正
```

観測だけで原因を確定しない。

---

## 8. GameAI固有のSelection基準

目的は「強いAI」ではなく「面白いAI」。単一スカラー最大化を避ける。

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

## 9. 感情設計への適用規律

感情語を基底状態にしない。

```text
SensitivityProfile
+ RelationalHistory
+ RelationConstraint
+ BodyState
+ CurrentContext
+ Prediction / Interpretation
+ H provenance
↓
AffectExpression
ActionBias
DialogueTone
```

`Threat / Opportunity / Control / Recoverability / Novelty` などを使う場合、それらはT0のCore PrimitiveではなくGameAI側の操作補助とする。

---

## 10. 各鉱山の役割

### RDL_Human
借用候補：

```text
Explore / Maintain / Connect / Defend
関係境界の粘着性
安全基地
多重境界による性格表現
複数時間スケール
```

OXT / DA / 5-HT / NAをそのままGameAI基底変数にせず、必要なら抽象化する。

### RDL_Demos
優先候補：

```text
bounded perception
world separation
movement / action
directional relations
dialogue structure
seeded simulation
event log
snapshot / replay
richness metrics
```

旧実装中の `H_vec`、`ξ`、Leap等の意味はT0 v2.1へ自動昇格させない。

### RDL_Enterprise
二種類を採掘する。

設計規律：

```text
finite Boundary
Observation != Commitment
UNKNOWN != FAILURE
Authority != Truth
same pre-update M_B
Context / Provenance
bounded replay
acceptance evidence
vertical slice
stop rule
```

実装機構：

```text
Canary
Shadow
Promotion
Durability
Replay
Structure induction
Runtime snapshots
Attention / escalation
```

実装機構は必要な破断が出るまで入れない。

---

## 11. 停止規律

次の状態になったら、そのBoundaryでは一旦止めてよい。

```text
current finite Boundaryで operationally sufficient
```

これは以下を意味しない。

```text
terminally complete
universally valid
all NPC behavior evaluated
all games compatible
RDL theory proven
```

再開条件は「もっと作れるから」ではない。

```text
actual broken scenario
new operational requirement
invariant violation
new world/mechanic requirement
new observation that current model cannot explain
```

---

## 12. 実験テンプレート

```text
Experiment ID:
Question:

Boundary B:
- world:
- agents:
- sensors:
- actions:
- time horizon:
- excluded conditions:

Semantic invariants:
- EFP meaning:
- M_B version:
- F/F' freeze rule:
- H rule:

Hypothesis:
Selection criteria:
Acceptance evidence:
Failure evidence:

Context / Provenance:
- seed:
- code commit:
- config:
- scenario:
- relevant history:

Result:
- Observation:
- Interpretation:
- Candidate changes:
- Commitment:
- Active change:

Residual ξ / unresolved:
```

---

## 13. 最初のGameAI最小Boundary

```text
NPC 3
場所 4前後
食料 1系統
有限知覚
方向付き関係
簡単な身体状態
RelationHistory
SensitivityProfile
GoalTension
1日の生活周期
プレイヤーの簡単な会話 / 贈り物 / 相談
seeded simulation
replay log
```

初期段階では、死亡、繁殖、複雑経済、高度LLM会話、文化生成、全面Canary/Shadow、大規模学習を入れない。

最初の問い：

> **数日観察したとき、「このNPCは昨日のことを引きずっている」とプレイヤーが感じられるか。**

---

## 14. 典型的アンチパターン

```text
H = stress meter
fear value += 0.2
engine ground state = Truth
static conflict → direct H
LLM output → direct belief commitment
test green → model correct
authority → factual truth
one successful tactic → permanent promotion
all learning → optimization
all old beliefs → overwrite
more features → more interesting
```

代わりに、source / history / context / provenance、interaction loop、bounded observation、candidate separation、selection、reconstruction、coexistence、finite acceptanceを維持する。

---

## 15. 圧縮版

```text
T0で意味を固定する
↓
T1で形成・検査・再構成の工程を使う
↓
Enterpriseの有限Boundary・受入証拠・停止規律を使う
↓
Demos / Human / Enterpriseから素材を採掘する
↓
GameAI固有のSelection基準を置く
↓
小さなVertical Sliceを動かす
↓
破断した場所だけ深掘りする
↓
必要な型だけ追加する
↓
current finite Boundaryで十分なら止める
```

一文で言えば、

> **Demos / Human / Enterpriseから機構を採掘し、Enterpriseの設計手法で組み立て、RDL_Core T0/T1で意味を検査し、GameAI固有のSelection基準で残すものを決める。**

---

## 16. Canonical References

### RDL_Core

Canonical semantic source:

- `Aporapeiron/RDL_Core`
- `00_T0_基盤層/T0 基底措定（BASE）.md`
- `00_T0_基盤層/T0 最低動作仕様（SPEC）.md`
- `01_T1_SILN操作層/T1_SILN操作_総論.md`
- `01_T1_SILN操作層/T1_SILN展開.md`
- `01_T1_SILN操作層/T1_検査と選別.md`
- `01_T1_SILN操作層/T1_再構成.md`

確認時点：
- BASE / SPEC: v2.1
- T0 v2.1昇格 commit: `6e27275a1f6ce81fbaa47681f11a4a4a8b44231e`
- 確認時の最新 commit: `19c5eeca3f851abb428becd46c415e037a5c00d8`

### RDL_Enterprise

Design / reference implementation source:

- `RDL-Labs/RDL_Enterprise`
- `docs/RDL_Coding_Principles.md`
- `docs/RDL_Core_Route_v0.1.md`
- `docs/RDL_Core_Extraction_Gate.md`
- `docs/INTERACTION_REFLECTION_PLAN_v0.2.md`

確認時点：
- pause commit: `06420a78752ed43a9d8a3d62e939c3ebd08be067`
- status: current finite Boundaryで一旦停止

---

## 17. 非主張

本書は以下を主張しない。

- この設計手法がすべてのゲームAIに最適である。
- 面白さを完全に定式化できる。
- RDL_Humanの人間仮説をそのままNPCへ適用できる。
- RDL_Demos / Enterpriseの旧実装がT0 v2.1へ完全準拠している。
- シミュレータのengine stateが世界そのもののTruthである。
- テスト・replay・determinismが理論の正しさを証明する。
- 現在のGameAI Boundaryが終端的に閉じている。

本書自身も再検査対象である。
