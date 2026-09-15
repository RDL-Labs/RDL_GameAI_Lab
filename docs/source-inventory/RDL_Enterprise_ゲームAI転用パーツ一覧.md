# RDL_Enterprise — ゲームAI素材棚卸し（2026-09-15再確認）

Source:

```text
https://github.com/RDL-Labs/RDL_Enterprise
checked current line through: 40433c51d3b5ff517f4486d7c53e4a6b25f93d5a
```

`RDL_Enterprise` は引き続き、**有限Boundary・provenance・段階的commitment・durability・runtime acceptanceの鉱山**として高価値である。

ただし旧棚卸しから重要な読み替えがある。

## 1. 最重要更新

現在のEnterprise本体は Core v2.3 staged migration を進めており、旧 `EFP`、`CompiledMB`、`xi_obs` 等をcanonical語彙として扱っていない。

現行の主経路:

```text
raw request / later observation
↓ acquisition under Purpose / B
RIB_B(t) / RIB_B(t+Δ)
↓ same frozen pre-update M_B
F / F'
↓
E = Δ(F,F')
↓ unresolved only
H
```

意味境界:

```text
raw BusinessInput / FeedbackResult != RIB_B
RIB_B != F
static structural conflict != E != H
acquisition / coverage gap != E != H
coverage metric != ξ
Human Attention != H
Function != M_B
```

この区別をGameAIへ持ち込む。

## 2. 旧棚卸しで修正が必要な点

### `HState`をNPCストレスメーターとして直接転用しない

旧棚卸しでは `h_state.HState` を「NPCのストレス/苛立ち/警戒度」にほぼそのまま使えると評価していた。

現在はこの読みを採用しない。

```text
Enterprise operational H
!= fear / stress / anger
!= Human Attention load
```

GameAIで感情表現を作る場合は、interaction history、relation history、body state、sensitivity、context、unresolved provenance等から派生させる。

### `CompiledMB` 系名称を M_B とみなさない

Enterpriseは正規Function名へ移行している。

```text
CompiledFunction
ActiveFunction
ConditionalCompiledFunction
...
```

旧 `*CompiledMB` 名は互換面で残りうるが、`Function = M_B` を意味しない。

## 3. 現在の採掘優先順位

### A. Acquisition / canonical comparison boundary

High value:

```text
Purpose / B acquisition
RIBSection
coverage separation
frozen interpretation context
same pre-update M_B comparison
canonical mismatch observation
unresolved-state separation
```

GameAI P3/P4へ直接参考になる。

### B. Provenance / persistence / restart durability

Enterpriseは現在、request/subsequent sections、F/F' lineage、mismatch、coverage、operational H adapter stateなどを有限single-writer boundary内でrestart越しに保持する。

GameAIへの転用候補:

```text
source observation id
subsequent observation id
boundary id / Purpose
active model version
interpretation context version
selected dimensions / coverage
provenance refs
restart-safe inspection snapshots
```

### C. Staged commitment / authority

有用:

```text
Observation != Candidate != Commitment != Active
Authority != Truth
UNKNOWN != UNRESOLVED != NOT_EVALUATED
Promotion / activation / deactivation
bounded authority scope
```

GameAIのbelief、learned relation、action policy、reconstruction authorityの段階化に使える。

### D. P10 changed-condition acceptance harness

Enterpriseの現在の重要未完了/前進領域は、real interactionでactual response/actionが外部条件を変え、その後のreal `RIB_B`へ戻るchain。

GameAIはGodot P2ですでに小型のactual changed-condition loopを持つため、**Enterpriseのacceptance disciplineとGameAIの実world loopは相補的**。

## 4. 引き続き有用な実装機構

必要な破断が出た場合に採掘:

```text
replay
canary
shadow
promotion gate
durability harness
structure induction
authority boundary
action feasibility
dialogue probe
simulation / scenario harness
```

これらはT0 primitiveではなく、Inspection / durability / deployment toolとして読む。

## 5. ゲームに直接持ち込まないもの

```text
Jira / workflow provider specifics
real-world authentication details
Slack/webhook compensation adapters
business ticket semantics
Human Attention workflow as NPC emotion
coverage score as ξ
old HState as mood meter
legacy *CompiledMB names as Core M_B
```

## 6. GameAIへの優先転用候補

High:

```text
finite acquisition contracts
provenance
coverage != zero / coverage != ξ
frozen comparison context
restart-safe records
Observation/Candidate/Commitment/Active split
Authority != Truth
acceptance harness discipline
```

Medium, break-driven:

```text
canary
shadow
promotion
durability
structure induction
replay persistence
```

Deferred until justified:

```text
Human Attention workflow
complex external-provider authority
irreversible action approval stack
```

## 一文圧縮

> **現行RDL_Enterpriseは「HStateやCompiledMBをそのままゲームへ持ち込む鉱山」ではなく、Core v2.3に沿ったacquisition・provenance・durability・staged authority・acceptance disciplineの鉱山として使う。**
