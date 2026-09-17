# RDL_GameAI — Codex M_B統合整理計画書

**文書種別:** Semantic Alignment / Documentation Refactor Plan  
**版:** v0.1  
**対象リポジトリ:** `RDL-Labs/RDL_GameAI_Lab`  
**実行主体想定:** Codex  
**主目的:** GameAI-local Layer / parameter / body / history / current context と canonical `M_B` の関係を、現行RDLの意味論へ合わせて再整理する。  
**重要変更:** 「Body / Neural / History は M_B ではない」という強い分離表現を改め、**各module/store自体はM_Bではないが、そこから現在採用されている有限なパラメーター・関係はM_Bを構成する**という整理へ統一する。  
**基本方針:** 文書・契約・テストの意味境界を更新する。runtime authority / graph mutation / T1 cutover は行わない。

---

## 0. 今回の中心命題

> **個体の現在の解釈・予測・選択・応答・更新を拘束している有限なパラメーター・関係は、すべて `M_B` の構成関係として扱う。**

ただし、

```text
Body module
Neural module
History store
World state
Current observation packet
```

そのものを `M_B` と同一視しない。

```text
module / store / world source
→ finite selected current relation / parameter
→ M_B composition
```

例:

```text
Godot body state
→ current movement capability
→ M_B relation

Food system
→ current FoodNeed
→ M_B relation

Neural profile/state
→ current D1 / D2 / OXT / NA ...
→ M_B relations

Experience store
→ currently retained learned relation
→ M_B relation

Lexicon/history
→ currently retained lexical relation
→ M_B relation
```

---

## 1. 最重要不変条件

### 1.1 M_Bはパラメーター表ではない

```text
FoodNeed
↔ food salience
↔ EnergyReserve
↔ known food place
↔ danger relation
↔ movement capability
↔ companion relation
```

のような、現在の有限な拘束ネットワークとして扱う。

> **全パラメーターはM_Bを構成し得るが、M_Bはパラメーター一覧ではない。**

### 1.2 module/storeとM_Bを同一視しない

```text
Body module != M_B
Neural module != M_B
History store != M_B
CurrentContext container != M_B
```

新しい標準表現:

```text
module/store != M_B by identity

but

finite currently adopted relations / parameters
⊂ M_B
```

### 1.3 RIB_Bとの分離を維持

```text
M_B != RIB_B
```

```text
current self-side finite relational structure
= M_B

current finite interaction section selected under B
= RIB_B
```

### 1.4 同一比較内のM_B凍結

```text
F  = interp(M_B, RIB_B(t))
F' = interp(M_B, RIB_B(t+Δ))
```

同一comparisonでは同じpre-update frozen `M_B` を使う。

### 1.5 canonical authorityは増やさない

以下は実装しない。

```text
automatic M_B reconstruction
θ
M_Δ
Probe
T1 Formation
canonical graph mutation
canonical action authority
```

---

## 2. 新しいLayer解釈

既存5 Layer:

```text
Generation / DNA
Neural Dynamics
Physical / Body
Experience / Relation History
Realtime / Current Context
```

は維持する。

新しい読まれ方:

```text
5 Layers
= M_Bを構成・更新する関係の
  出所 / 更新速度 / 保持時間 / provenance を整理するView
```

```text
Generation / DNA
Neural Dynamics
Physical / Body
Experience / Relation History
Realtime / Current Context
        ↓
finite selected parameters / relations
        ↓
               M_B
```

Layerそのものはontologyではない。

---

## 3. 各Layerの新しいM_B接続

### 3.1 Generation / DNA

DNAそのものを現在の`M_B`としない。

```text
DNA
→ baseline distribution
→ current neural/body state
→ current finite relations
→ M_B
```

### 3.2 Neural Dynamics

対象:

```text
DA
├ D1
├ D2
├ D3
└ D4

5-HT
├ 5-HT1
├ 5-HT2
├ 5-HT3
└ 5-HT4

OXT

NA
├ α1
├ α2
└ β
```

現在の個体側拘束として利用される値・関係は、

```text
current neural relations
⊂ M_B
```

とする。

### 3.3 Physical / Body

例:

```text
FoodNeed
EnergyReserve
ActiveEnergy
Injury
movement capability
fatigue
sensory capability
```

これらの現在有効値・相互関係は `M_B` を構成する。

特に、

```text
FoodNeed ⊂ M_B
```

とする。

ただし、

```text
Godot world-owned body state
!= M_B by identity
```

を維持する。

### 3.4 Experience / Relation History

History store全体をM_Bにしない。

```text
complete finite retained history store
!= current M_B
```

しかし、その履歴から現在採用されている、

```text
A may help
forest may be dangerous
this route often succeeds
this word refers to object X
```

等は、

```text
current learned relations
⊂ M_B
```

とする。

### 3.5 Realtime / Current Context

すべてのcurrent observationを直接M_Bへコピーしない。

```text
raw current observation
→ RIB_B
```

が基本。

一方、

```text
current priority
current action commitment
current short-term retained relation
```

など、個体側拘束として成立したものはM_Bへ入る。

---

## 4. Food実装の意味論更新

最新のminimal Food loop:

```text
FoodNeed
→ bounded food perception
→ approach
→ pickup
→ eat
→ FoodNeed decreases
```

について、

```text
semantic target:
FoodNeed should participate in M_B

current implementation:
FoodNeed exists as Godot-owned GameAI-local state
canonical count-sidecar does not yet include it
```

を明記する。

今回の文書変更だけで、

```text
canonical M_B implementation now includes FoodNeed
```

とは書かない。

---

## 5. 神経パラメーター設計図の更新

`RDL_GameAI_神経パラメーター設計図.md`

新しい流れ:

```text
current Neural Dynamics
⊂ current M_B

and

Neural Dynamics
→ later M_B formation / reconstruction tendencies
```

神経parameterは、

```text
1. 現在のM_B構成関係
2. 将来のM_B形成傾向
```

の両方へ関わり得る。

---

## 6. 感情・履歴・関係拘束モデルの更新

```text
source modules / stores
↓
current finite relations
⊂ M_B

M_B + current RIB_B
→ interpretation / action conditions
→ derived AffectExpression
```

ただし、

```text
AffectExpression != M_B by identity
AffectExpression != H
```

は維持。

---

## 7. 睡眠システムの更新

```text
Experience History
→ Selection / Compression / Association
→ candidate relation changes
→ future M_B reconstruction
```

を行うwindowとして整理。

```text
sleep = T1
```

とはしない。

---

## 8. Communication / Lexiconの更新

```text
DialogueTurn store != M_B
Lexicon database != M_B
```

ただし現在その個体が採用している、

```text
word ↔ referent
speaker ↔ trust relation
warning ↔ danger relation
```

は `M_B` を構成し得る。

Player発言も、

```text
Player statement
→ observation/history
→ retained current relation
→ possibly M_B
```

とし、

```text
Player statement != World Truth
```

を維持する。

---

## 9. Cross-layer separation contractの修正

現行の、

```text
Local layers are not canonical M_B fields by identity.
```

は維持可能。

ただし次を追加する。

> Layer containers and owner modules are not canonical `M_B` by identity. However, finite current relations and parameters sourced from these layers may constitute `M_B` when explicitly admitted under a declared model/context boundary.

さらに、

```text
currently not admitted to canonical runtime M_B
```

も明示する。

```text
semantic eligibility
!= current operational admission
```

を基準にする。

---

## 10. cross-layer testの扱い

`tests/test_cross_layer_separation.py`

は削除しない。

このテストが確認するもの:

```text
current runtimeでは
local layer changes do not silently mutate frozen canonical M_B
```

証明しないもの:

```text
FoodNeed / Neural / Body / History can never enter M_B
```

runtime挙動変更が必要になった場合は停止して報告。

---

## 11. 全体設計地図の更新

`RDL_GameAI_全体設計地図.md`

推奨図:

```text
World / Interaction
        ↓
      RIB_B
        ↓
       interp
        ↑
        │
Generation / DNA
Neural Dynamics
Physical / Body
Experience / Relation History
Realtime self-side constraints
        ↓
 finite adopted current relations
        ↓
               M_B
```

補足:

```text
Layers = source/time-scale view
M_B = current finite self-side relational structure
```

---

## 12. NPC Layering Profile更新

旧:

```text
Layer Profile
!= canonical M_B decomposition
```

は残す。

追加:

```text
Layer Profile does not partition M_B into five disjoint fields.

Instead:
Layers classify provenance / update tempo / retention of relations
that may participate in M_B.
```

---

## 13. NPCレイヤー別設計計画更新

必要なら表へ、

```text
M_B participation
```

または、

```text
semantic role
```

列を追加する。

例:

| Layer | Owner/source | Current relation | M_B relation |
|---|---|---|---|
| Physical / Body | Godot | FoodNeed | eligible / intended |
| Neural Dynamics | Neural state | D1 etc. | eligible / intended |
| Experience | History store | learned relation | eligible / intended |
| Realtime | observation/self state | item dependent | split: RIB_B / M_B |
| Generation | DNA | μ/σ baseline | indirect unless expressed |

---

## 14. README更新

READMEへ簡潔に追加:

```text
All current agent-side parameters are intended to participate in M_B
as finite relations when admitted under a declared boundary.

Their owner modules are not M_B by identity.
```

相当の日本語表現。

同時に、

```text
current canonical runtime does not yet operationalize all such parameters
```

も明示。

---

## 15. DOCUMENT_STATUS更新

`docs/design/DOCUMENT_STATUS.md`

に、

```text
Layer docs: current, revised for M_B participation
Food contract: operational local state, canonical M_B admission deferred
Cross-layer contract: separation of current runtime authority, not permanent semantic exclusion
```

を明記。

---

## 16. Codex作業順

### Step 1 — search

全文検索:

```text
!= M_B
not M_B
M_B by identity
influence M_B
outside M_B
SensitivityProfile
BodyState
RelationHistory
CurrentContext
FoodNeed
```

対象:

```text
README.md
docs/design/
docs/experiment-contracts/
notes/experiment-roadmap.md
tests/test_cross_layer_separation.py
```

### Step 2 — mismatch inventory

各箇所を、

```text
correct separation
too-strong exclusion
ambiguous
already aligned
```

へ分類。

### Step 3 — design docs first

優先順:

```text
1 RDL_GameAI_全体設計地図.md
2 RDL_GameAI_NPC_レイヤリング_Profile.md
3 RDL_GameAI_NPC_レイヤー別設計計画.md
4 RDL_GameAI_神経パラメーター設計図.md
5 RDL_GameAI_感情・履歴・関係拘束モデル.md
6 RDL_GameAI_睡眠システム設計.md
7 Communication / Player
8 Game Feature Roadmap
```

### Step 4 — contract clarification

更新:

```text
CROSS_LAYER_separation_contract.md
FOOD_minimal_loop_contract.md
CURRENT_v23_runtime_contract.md
```

必要最小限。

### Step 5 — tests wording

挙動を変えず、

```text
test names
docstrings
comments
assertion explanation
```

のみ必要なら変更。

### Step 6 — README / status

最後に入口を同期。

---

## 17. やってはいけないこと

```text
- FoodNeedを即canonical sidecarのM_Bへ追加する
- current M_Bを同一comparison中に可変化する
- Layer moduleそのものをM_Bとする
- raw world/body stateをそのままM_Bとする
- raw observationを全部M_Bへコピーする
- RelationHistory store全体をM_Bとする
- DNAそのものをcurrent M_B stateとする
- T1 reconstructionを有効化する
- graph mutationを追加する
- canonical action authorityを追加する
- testsを仕様に合わせるためだけに弱める
```

---

## 18. Acceptance Criteria

### A. 中心命題

```text
current finite agent-side parameters / relations
⊂ M_B

owner module/store
!= M_B by identity
```

が主要文書で一貫する。

### B. Food

```text
FoodNeed
```

が、

```text
semantic M_B participant
```

として明記される。

同時に、

```text
current canonical runtime admission = deferred
```

も明記。

### C. Neural

```text
current neural parameter
⊂ M_B
```

と、

```text
neural dynamics influence later M_B reconstruction
```

の両方が表現される。

### D. Layer

5 Layerが、

```text
M_B外部の5状態系
```

ではなく、

```text
relation provenance / update-time organization view
```

として統一される。

### E. RIB_B

```text
M_B != RIB_B
```

が崩れない。

### F. Frozen comparison

```text
F/F'
same frozen pre-update M_B
```

を維持。

### G. Runtime

```text
runtime behavior unchanged
canonical authority unchanged
T1 deferred
```

を維持。

---

## 19. 推奨コミット分割

```text
1. Clarify M_B participation semantics across design docs
2. Align layer profile and neural/body/history relation sources
3. Clarify FoodNeed as intended M_B relation
4. Clarify cross-layer and food contracts
5. Refresh README and document status
```

runtimeコード変更を含めない。

---

## 20. 最終報告フォーマット

```text
## Updated semantic rule
- exact rule adopted

## Updated documents
- file
- change

## Contract clarifications
- file
- change

## Tests
- changed / unchanged
- why

## Runtime
- confirmed unchanged

## Remaining operational gap
- which parameters are semantically intended for M_B
- which are still not admitted to canonical runtime M_B

## Verification
- tests run
- markdown links checked
- runtime diff checked
```

---

## 21. 一文圧縮

> **GameAIの各LayerはM_Bの外部に独立して存在する状態系ではなく、現在のM_Bを構成する有限な関係・パラメーターの出所・更新速度・保持時間を整理するViewである。FoodNeed・Energy・Injury・Neural parameter・学習関係などは、現在の個体側拘束として採用される限りM_Bを構成する。ただしowner module/storeそのものをM_Bと同一視せず、現行canonical runtimeへの実際のadmissionは別途有限な境界で段階導入する。**

