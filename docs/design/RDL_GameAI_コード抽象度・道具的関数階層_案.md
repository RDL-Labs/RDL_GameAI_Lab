# RDL_GameAI — コード抽象度・道具的関数階層 案

**文書種別:** Architecture Design Note / DRAFT  
**版:** v0.1  
**位置づけ:** RDL_GameAI_Lab / implementation architecture  
**目的:** 機能別の分割だけでなく、実装内容の抽象度と道具的関数の責務を段階化し、GameAI機能・RDL Function・外部Adapter・将来の別言語実装を分離しやすくする。  
**非責務:** RDL CoreのTier定義、NPC内部Layer定義、canonical M_Bの構成定義、個別Feature仕様を置き換えない。

---

## 0. 基本方針

コードをFood / Safety / Rescue / Sleep / Huntingという機能名だけで分割すると、各Feature内部に数値的な小道具、関係操作、候補選択、比較Function、状態機構、Trajectory、Feature logic、複数Feature調停、HTTP / Godot接続が混在しやすい。

本案では、**何を扱う機能か**だけでなく、**どの抽象度の処理か**を別軸として整理する。

```text
低抽象度
Primitive
↓
Structural Operation
↓
Reusable Function
↓
Domain Mechanism
↓
Feature
↓
Coordination
↓
Application / Adapter
高抽象度
```

この階層はRDLのT0 / T1 / T2やNPC Layerとは別物であり、純粋にコード実装上の整理軸である。

---

## 1. I0 — Primitive / Utility

最も小さい道具。RDL固有意味をほぼ持たない。

例:

```text
clamp
normalize
distance
stable sort
bounded slice
ID lookup
finite range check
hash / cache key
deterministic ordering
basic serialization helper
```

規則:

- Feature名を知らない。
- M_B / H / Sleep / Safety等を知らない。
- 状態を直接更新しない。
- 単体テストしやすい小関数を優先する。

---

## 2. I1 — Structural Operation

RDL / GameAIで繰り返し使う、小さな構造操作。まだSleepやRescue等のFeature責務は持たない。

例:

```text
align_relations
compare_strength
check_polarity
compute_coverage
collect_unresolved
extract_conflicts
select_bounded_candidates
validate_provenance
freeze_observation_identity
check_candidate_visibility
```

Relation / Boundary / Status / Candidate / Provenance等の有限構造を扱ってよいが、「このNPCは眠るべき」「救助すべき」のようなFeature判断は行わない。

---

## 3. I2 — Reusable Function

複数のStructural Operationを組み合わせた、意味のある再利用可能Function。

例:

```text
build_relation_profile
compare_profiles
build_similarity_observation
cluster_profiles
extract_common_relations
extract_exception_relations
select_safe_target
select_rest_target
select_rescue_target
build_candidate_relation
```

I2では `input -> finite function -> output` が明確であることを重視する。

可能な限りpure functionとして保ち、Worldを直接読む、Historyを直接書き換える、canonical stateを直接変更する、HTTPを呼ぶ、Godot nodeを触ることを避ける。

---

## 4. I3 — Domain Mechanism

I2 Functionを組み合わせ、ある種の内部機構を構成する。

例:

```text
FastSimilarity
ReflectiveSimilarity
DeepSimilarity
ExperienceCompression
SleepConsolidation
SafetyTrajectory
RescueTrajectory
RestTrajectory
FoodLifePolicy
```

I3から持続状態、commitment、trajectory phase、local cache、finite history window、mode stateを持ってよい。ただし複数Feature全体の優先順位やGame全体の調停までは責務にしない。

---

## 5. I4 — Feature

Game上で一つの意味ある生活機能として成立する層。

例:

```text
Food
Rest
Sleep
Energy
Safety
Rescue / Recovery
Hunting
Communication
```

典型形:

```text
bounded observation
↓
local interpretation
↓
Goal
↓
Trajectory / Mechanism
↓
structured action
↓
World resolution
↓
Experience
```

I4は複数のI3 Mechanismを使える。Feature間優先度は次層へ送る。

---

## 6. I5 — Coordination / Life System

複数Featureの関係・優先・保留・再開を扱う。

例:

```text
Food × Safety
Food × Rest
Sleep scheduling
Need arbitration
Rescue interruption
Continuous Life
Daily routine coordination
```

責務は、どのFeatureを現在activeにするか、何をsuspend / releaseするか、current relationsから何を再評価するか。

原則:

```text
Coordinator
→ Feature contractを呼ぶ

Coordinator
!= Feature内部stateを直接書換
```

---

## 7. I6 — Application / Adapter

外界・実行環境との接続。

例:

```text
Godot adapter
HTTP bridge
CLI
JSON packet conversion
Workbench Inspector
test fixture
canonical sidecar adapter
persistence adapter
```

外部形式とGameAI内部contractの変換を担当し、GodotやHTTPの都合をI0〜I5へ逆流させない。

---

## 8. 依存方向

基本依存方向は一方向とする。

```text
I6 Application / Adapter
↓
I5 Coordination
↓
I4 Feature
↓
I3 Domain Mechanism
↓
I2 Reusable Function
↓
I1 Structural Operation
↓
I0 Primitive
```

下位層は上位層を知らない。

例:

```text
compare_strength()
→ Sleepを知らない

compare_profiles()
→ Sleep Featureを知らない

DeepSimilarity
→ Sleepから利用されてもSleep開始条件を知らない
```

---

## 9. Sleepでの具体例

現在進めているFast / Reflective / Deep similarityをこの階層へ置くと、

```text
I0
abs / sort / bounded slice

I1
align_relations
check_polarity
compare_strength
compute_coverage

I2
compare_profiles
build_similarity_observation
cluster_profiles
extract_common_relations

I3
FastSimilarity
ReflectiveSimilarity
DeepSimilarity
SleepConsolidation

I4
Sleep Feature

I5
Daily routine / Sleep scheduling
Need coordination

I6
Godot / Runtime bridge / Inspector
```

この構造ならActivity→FastSimilarity、Idle→ReflectiveSimilarity、Sleep→DeepSimilarityが同じI1 / I2の道具を共有できる。

---

## 10. RDL固有の意味状態を分離する

コード階層とは別に、以下を同じ型へ潰さない。

```text
Observation
SimilarityObservation
CandidateRelation
Commitment
WorldAction
WorldResolution
CanonicalAdmission
```

特に、

```text
SimilarityObservation != CandidateRelation
CandidateRelation != Commitment
Commitment != World change
GameAI local candidate != canonical M_B admission
```

をコード構造でも保持する。

これにより「似ている→勝手に規則になる」「candidateがある→勝手に行動する」「Worldで成功した→勝手にcanonical採用される」といった暗黙昇格を防ぐ。

---

## 11. pure function優先領域

将来の再利用・高速化を考えると、特にI0〜I2はpure function優先とする。

候補:

```text
relation alignment
similarity
distance
coverage
conflict detection
candidate ranking
graph neighborhood comparison
clustering
common relation extraction
exception extraction
finite validation
```

理想は `input data -> pure compute -> output data`。副作用はI3以上、またはI6 Adapter側へ寄せる。

---

## 12. 別言語抽出との関係

この階層は、将来Python以外へ移すための前提にもなる。

例えば負荷が集中するのが、

```text
I0〜I2
大量Experience
× relation comparison
× graph
× clustering
```

なら、

```text
Python I3〜I6
↓
stable Function contract
↓
Rust / Julia I0〜I2 implementation
```

へ差し替えられる。

速度だけでなく、RDL Functionをどれだけ直接記述できるか、型で不変条件をどこまで保持できるか、provenance / unresolved / candidate区別を壊しにくいか、FFI境界がFunction単位で切れるかも評価対象とする。

現時点では言語移行を目的にしない。

---

## 13. Repository構成への将来候補

直ちに物理フォルダを全部変更する必要はない。

将来的な例:

```text
runtime/
├ primitives/
├ structural/
├ functions/
├ mechanisms/
├ features/
├ coordination/
└ adapters/
```

ただし、抽象階層が安定するまでは既存ファイルを無理に大移動しない。

先に「この関数はどのI-levelか」をレビュー時に判断できるようにし、物理再配置は後段でよい。

---

## 14. 段階的導入

### Stage A — 新規Sleep実装で試す

新しいSleep / Similarityコードについて、relation comparison→I1/I2、Fast/Deep→I3、Sleep Feature→I4として追加する。

### Stage B — 既存コード棚卸し

Food / Safety / Rescueの主要関数をI0〜I6へ分類する。まだ移動しない。

### Stage C — 混在箇所を分離

HTTP handler内のcomparisonロジック、Feature policy内のgeneric validation、Godot adapter内のtarget selection等の混在だけを分離する。

### Stage D — 重負荷Function抽出

実測後、必要なI0〜I2 Functionのみ別言語候補にする。

---

## 15. 最小受入条件

1. 新規関数の抽象度をI0〜I6のどこかへ説明できる。
2. I0〜I2は特定Featureへの不要な依存を持たない。
3. I2 Functionは可能な限りinput/output契約を明示する。
4. I3 MechanismとI4 Featureを区別する。
5. Feature間調停をI4内部へ無制限に埋め込まない。
6. Godot / HTTP / CLI都合をI0〜I5へ漏らさない。
7. Similarity / Candidate / Commitment / World change / canonical admissionを暗黙昇格させない。
8. 別言語化はRepository全体ではなくFunction境界から可能にする。
9. 現行コードを一度に再配置しない。
10. この階層自体も実装経験に応じて改訂可能な設計案として扱う。

---

## 16. 一文圧縮

> **RDL_GameAIのコードを、Primitive → Structural Operation → Reusable Function → Domain Mechanism → Feature → Coordination → Application / Adapterの抽象度で分け、低層ほど小さく純粋で再利用可能に保つ。これによりFeature間の混線、暗黙の意味昇格、実装環境依存を抑え、将来のCore抽出やRust / Julia等への局所的な置換をFunction単位で可能にする。**