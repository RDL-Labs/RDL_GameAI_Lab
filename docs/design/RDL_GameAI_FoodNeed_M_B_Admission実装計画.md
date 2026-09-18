# RDL_GameAI FoodNeed M_B Admission 実装計画

**文書種別:** Canonical Admission Experiment Plan  
**版:** v0.1  
**対象:** `RDL_GameAI_Lab`  
**状態:** PR 1-3実装済み。default-off・loopback限定shadow bridgeまでoperational。global canonical sidecar接続なし。

## 0. 目的

Godot-ownedな現在のFoodNeedを、module/state containerごとコピーせず、有限な
個体側関係としてfrozen `M_B`へ明示admitする最初の実験を定義する。

```text
Godot body snapshot
→ validated FoodNeed source
→ finite admitted relation
→ frozen pre-update M_B
→ interp(M_B, RIB_B(t)) / interp(M_B, RIB_B(t+Δ))
→ F / F' / E
```

この実験はT1 reconstruction、automatic model learning、canonical action
authorityを実装しない。

## 1. 中心命題

```text
Body module != M_B by identity
FoodNeed source field != M_B relation by mere presence

validated FoodNeed
+ declared food-perception relation
+ finite model/context identity
→ admitted M_B relation
```

`M_B` はparameter表ではない。最小実験でもFoodNeed単独値ではなく、現在の
FoodNeedがfood perceptionの解釈をどう拘束するかという有限relationとして保持する。

## 2. 現行実装からの制約

現在のcanonical sidecarは次の構造を持つ。

```text
RIB_B dimensions:
  visible_agents_count
  visible_objects_count
  visible_places_count

FrozenGameAIMB:
  coefficient[dimension]
  bias[dimension]
  model_ref

model lifetime:
  exact context_keyごとにprocess内で継続
```

このままFoodNeedを係数へ差し込むと問題がある。

1. `visible_objects_count` はfood以外も含み、FoodNeedとのrelationが曖昧。
2. FoodNeedはtickやeatで変化するが、同一F/F'比較では `M_B` を凍結する必要がある。
3. body revisionとmodel revisionを同一視するとworld/body updateが黙示的なM_B mutationになる。
4. 現行context単位の長寿命modelへ自動反映すると、window切替・fresh re-entryが不明になる。

したがって、既存sidecarを即座に置換せず、shadow admissionから開始する。

## 3. 最小relation

最初のadmission対象は一関係だけとする。

```text
relation_id: food-need-to-visible-food-salience-v1
source parameter: FoodNeed ∈ [0, 1]
RIB_B input: visible_food_count
interpreted output: visible_food_salience
rule: visible_food_salience = frozen_food_need × visible_food_count
```

これは栄養、好物、危険、在庫、既知の食料場所を扱わない。線形規則は有限実験用で、
Core定数や最終game balanceではない。

`visible_food_count` はbounded observation内で `kind == "food"` と明示されたentityだけを
数える。missing kind、unknown object、hidden world objectをfoodへ推測しない。

## 4. Identity

### 4.1 Source identity

admission sourceは次を保持する。

```text
agent_id
body_snapshot_id
body_revision
food_need
source_observation_id
source_tick
owner = Godot
```

body revisionはsource stateのrevisionであり、canonical model revisionではない。

### 4.2 Model identity

FoodNeed relationを含むmodelは新しい `model_ref` を持つ。

```text
model_ref =
  experiment id
  + agent id
  + exact boundary/context digest
  + admission policy version
  + admitted source snapshot identity
  + relation rule version
```

FoodNeedの数値そのものを平文IDへ埋め込まず、canonical serializationのdigestを使う。
同じsource snapshot・Boundary・ruleからは同じref、いずれかが違えば別refになる。

### 4.3 Window identity

```text
comparison_window_id
first observation id
later observation id
frozen model_ref
status = open / compared / rejected
```

一つのwindowは一回のF/F'比較だけを所有する。comparison後に新しいFoodNeedを使う場合は
新しいwindowとmodel_refを明示形成する。

## 5. Frozen comparison rule

同一windowでは、FとF'の両方が同じpre-update FoodNeed relationを使う。

```text
FoodNeed(t0) = 0.8

F(t0) = 0.8 × visible_food_count(t0)
F'(t1) = 0.8 × visible_food_count(t1)
```

t1で実body FoodNeedが0.2へ変わっていても、進行中windowのF'へ0.2を混入しない。
0.2は次windowのadmission candidateである。

```text
same comparison
→ same frozen FoodNeed relation

changed FoodNeed
→ candidate for a new model/window
→ never in-place mutation
```

## 6. Admission boundary

admissionは以下をすべて満たす場合だけ成功する。

- opt-in shadow experimentである。
- body snapshot ownerとobserved agentが一致する。
- snapshot idがnon-empty、revisionが非負整数。
- FoodNeedがfinite numberかつ `[0,1]`。
- source observation idとtickが明示される。
- Boundaryが `visible_food_count` を選択する。
- relation rule versionがallowlist内にある。
- 同じwindowにmodelがまだ固定されていない。

失敗時はsection/model/comparisonを部分形成しない。missingを0へ変換しない。failure recordへ
observation id、有限なreason code、field pathを残す。

## 7. 段階導入

### PR 1 — Schema and pure formation

**状態: implemented。** `visible_food_count` はopt-in Boundaryだけで取得可能。
immutable source/relation、deterministic model ref、fail-closed validationを実装済み。
既存default Boundaryとglobal sidecarは不変。

- immutable `FoodNeedAdmissionSource` を追加。
- immutable relation recordを追加。
- canonical serializationとdeterministic `model_ref` builderを追加。
- `visible_food_count` のbounded acquisitionを追加するが、既存default Boundaryは変更しない。
- pure unit testsのみ。bridge/global sidecarへ接続しない。

停止条件:

- body snapshotとmodel identityが混同される。
- food判定がworld全体参照を必要とする。
- 既存count-only model_refが変わる。

### PR 2 — Shadow frozen comparison

**状態: implemented。** explicit single-use window、最大64件の有限保持、同じ
frozen FoodNeedによるF/F'、distinct next-model candidateを実装済み。
[Shadow contract](../experiment-contracts/FOOD_NEED_MB_shadow_contract.md)で固定する。

- opt-inな `FoodNeedShadowComparisonSidecar` を追加。
- callerが明示したsource snapshotからのみmodelを形成。
- 一つのmodel/windowでF/F'を比較。
- existing canonical sidecarと並走し、action response・assessment ledger・Godot stateへ影響しない。
- snapshotへsource/model/window/relation provenanceを公開。

停止条件:

- FとF'で異なるFoodNeedが使われる。
- current global canonical snapshotがshadow実験で変わる。
- shadow resultがaction selectionへ流入する。

### PR 3 — Controlled bridge exposure

**状態: implemented。** `--food-mb-shadow` の明示flag、loopback host制約、専用
open / compare / snapshot endpointを実装済み。server instanceごとのsidecar / lockで
global canonical sidecarから分離する。

- localhost、default-offの明示experiment flagを追加。
- bridgeはvalidated body snapshotをshadow admission requestへ変換する。
- legacy/default pathはbyte-for-byte同じ意味を維持。
- replay、duplicate observation、out-of-order tickを拒否または既存規則どおり無視する。

この段階でもcurrent production canonical `M_B` の置換とは呼ばない。

### PR 4 — Admission review

**状態: deferred pending Base–Food loop evidence。** shadowからcanonical model profileへ
昇格する前に、[Base–Food循環](RDL_GameAI_Codex_BaseFood循環完成計画.md)で神の像の粗いcue、NPC自身の短期予測、
Goal形成、Trajectory継続、従う/無視の結果、経験hook、cueなしの自律起動、site depletion、carry、return、deposit、repeatの実相互作用を観測する。FoodNeed単独の
成功だけでpromotionを判断しない。

実Godot/HTTP evidenceを確認した後、次のどちらかを明示判断する。

```text
retain as shadow experiment
or
promote as a new finite canonical model profile
```

promotionには新しいruntime contract、model profile version、fresh process/re-entry、rollback
手順が必要。PR 4はT1やautomatic reconstructionを有効化しない。

## 8. Controlled comparisons

最低限、次を固定する。

### A. Same RIB_B, different preformed M_B

```text
visible_food_count = 1
FoodNeed = 0.2 → visible_food_salience = 0.2
FoodNeed = 0.8 → visible_food_salience = 0.8
```

別model/windowとして比較し、同一window内のmodel changeとは扱わない。

### B. Same frozen M_B, changed RIB_B

```text
frozen FoodNeed = 0.8
visible_food_count: 1 → 0
F / F': 0.8 → 0.0
E: -0.8
```

### C. Body changes during comparison

```text
source FoodNeed = 0.8
later body FoodNeed = 0.2
```

F'は0.8を使い、0.2は次window候補としてのみ記録される。

### D. Legacy isolation

FoodNeed、Body、History、Sensitivityを変えても、default count-only canonical snapshotは
現行cross-layer acceptanceどおり不変。

## 9. Acceptance criteria

1. FoodNeedが単独fieldではなく `food_need → visible_food_salience` relationとして形成される。
2. `visible_food_count` はbounded observationだけから取得される。
3. source snapshot、relation、model、comparison windowのidentityが分離される。
4. F/F'が同じfrozen pre-update FoodNeedを使用する。
5. changed FoodNeedは進行中modelをmutateせず、次window候補になる。
6. invalid/missing sourceはfail closedで、zero補完しない。
7. default canonical count-sidecar、assessment/H、action、Godot worldは不変。
8. shadow pathはT1、theta、M_delta、graph mutation、action authorityを持たない。
9. provenanceからsource body snapshotとrule versionへ追跡できる。
10. existing suiteと新規unit/integration testsが成功する。

## 10. Explicit non-goals

```text
automatic M_B reconstruction
theta / M_delta / T1
FoodNeedによるcanonical action authority
body module全体のM_B化
raw observation/bodyの全コピー
nutrition / preference / starvation
history/neural relationの同時admission
model persistence / network distribution
general relation graph engine
```

## 11. Rollback

- feature flagをdefault-offに戻す。
- shadow sidecar instanceを破棄する。
- 既存count-only model profileとassessment ledgerは移行しない。
- shadow model/refを既存model_refへaliasしない。
- Evidenceは失敗結果を含めて保持し、契約を黙って弱めない。

## 12. 最初の実装判断

最初に行うのはPR 1だけである。pure schema・formation・`visible_food_count` acquisitionを
default pathから隔離して追加する。PR 2以降はPR 1のidentity/freeze acceptanceを確認してから
開始する。

> **FoodNeedをcanonical `M_B`へadmitするとは、body fieldをコピーすることではなく、明示されたsourceとBoundaryの下でfood perceptionを拘束する有限relationを形成し、同一F/F'比較の間そのrelationを凍結することである。**
