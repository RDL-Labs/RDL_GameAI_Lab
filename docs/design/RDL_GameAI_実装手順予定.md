# RDL_GameAI — 実装手順予定

**文書種別:** Implementation Roadmap / DRAFT  
**版:** v0.5
**位置づけ:** RDL_GameAI_Lab / GameAI-local implementation plan

**責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)のC軸。生活機能の縦実装順と、D軸の接続点を管理する。
**依存:** [Concept](RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md)、[Layer計画](RDL_GameAI_NPC_レイヤー別設計計画.md)、各横断系の正本文書。
**非責務:** canonical成熟度・内部Layerの正本ではない。canonical maturity != game feature phase。
**状態:** Phase 1の最小Food loopはoperational。現在は[Base–Food循環完成計画](RDL_GameAI_Codex_BaseFood循環完成計画.md)を優先し、Phase 1をBase–Resource参照実装へ深化する。Phase 2以降はこの循環完成まで保留。

## 0. 実装方針

最初から大規模な生活・経済・クラフトシステムを作らない。

2026-09-18からassisted-to-autonomous方針を採用する。機能を薄く横へ増やす前に、最も単純な
Base–Food循環を神の像の粗いcue・NPC自身の短期予測・Goal形成・Trajectory継続・経験・自律起動まで深く完成させる。

```text
God Statue evaluates precise Food state
→ emits coarse cue without action authority
→ NPC observes and interprets
→ NPC short directional prediction
→ replenish Goal
→ gather_and_return Trajectory
→ local phase continuation without full reselection
→ known Food Site expedition
→ harvest / site depletion
→ carry / return / deposit
→ Base stock restored
→ consumption
→ next expedition
```

この循環をFood専用品にせず、Wood / Stone / Herb / Water等へresource ruleを
差し替えて展開できる `Base–Resource` 参照実装とする。ただし早期のgeneral framework化はしない。

神の像の精密計算はNPCのM_Bではない。NPCが受け取った有限cueと解釈関係のみがNPC側の候補になる。Goalは目標状態、Trajectoryはそこへ向かう行動系列、Commitmentは維持強度として分ける。

第一開発ライン:

```text
Food
→ Rest / Sleep
→ EnergyReserve / ActiveEnergy
→ Safety / Danger
→ Incapacitation / Injury
→ Rescue / Recovery
→ Hunting
```

第二開発ライン:

```text
Materials
→ Tools
→ Crafting
→ Barter
→ Emergent Value
```

ただし、次は単純なPhase番号へ置かない横断系とする。

```text
World Time
Experience History
Sleep Consolidation
Communication / Lexicon
Player Intervention
Neural Dynamics
Relation Constraints
```

全体配置は[設計地図](RDL_GameAI_全体設計地図.md)、canonical成熟度は[experiment roadmap](../../notes/experiment-roadmap.md)を参照する。

## Vertical life features

以下のPhase 1-11はこの文書内の生活機能順だけを表す。横断系は後掲の独立した接続一覧を使い、Phase番号を割り当てない。

---

## Phase 1 — Food

### Implemented bounded slice

```text
FoodNeed
→ bounded food perception
→ approach
→ pickup
→ eat
→ food consumed
→ FoodNeed decreases
```

GodotがFoodNeed・pickup reach・world object・held foodを所有し、Runtimeはbounded observation / self-body snapshotからactionを選ぶ。[Food contract](../experiment-contracts/FOOD_minimal_loop_contract.md)で実Godot/HTTP縦断を固定する。

### Completed reference target: Base–Food reference loop

最小sliceの次は種類や栄養へ広げず、次の一本を完成させる。

```text
Base stock consumption
→ short future direction
→ replenish_base_food Goal
→ GO_TO_SITE / GATHER / RETURN_BASE / DEPOSIT Trajectory
→ known Food Site selection
→ outbound travel
→ bounded resource-band observation
→ harvest and site depletion
→ carry
→ finite return decision
→ Base deposit
→ stock recovery
→ consumption
→ repeated expedition
```

正本は[Base–Food循環完成計画](RDL_GameAI_Codex_BaseFood循環完成計画.md)。Base / Siteのworld truthとNPC observationを分け、Future Predictionは短い方向予測としてGameAI-localに留める。毎tickの全候補再選択を行わず、構造的解除条件がない限り現在phaseを継続する。既存FoodNeed shadow `M_B`、global canonical sidecar、H、T1、action authorityを変更しない。

Phase 1の次段階では、God Statue morning assessment、coarse cue、cue非権限性、Goal / Trajectory / Phase / Commitment、Base–Food完遂、従う/無視の結果、経験hook、cueなしの自律起動を順に実装対象とする。その後generic interrupt API、Threat、Novelty、極端な個体profileの順に検証する。food varieties、栄養、腐敗、sharing、individual food ID、所有、競争、狩猟、social coordination、永続化は参照循環完成後までdeferred。

2026-09-18に[実行Evidence](../experiment-evidence/BASE_FOOD_reference_loop_evidence.md)を固定し、上記の参照循環、割り込み、極端profile比較まで完了した。Phase 2の開始条件は成立済み。次はFood固有定数を持ち込まず、同じ構造をRest / Sleepへ応用する。

最小の生存循環を作る。

```text
腹が減る
→ 食料を探す
→ 拾う
→ 食べる
→ 空腹が緩和する
```

最小実装:

```text
FoodNeed
food object
food perception
approach
pickup
eat
consume
```

受入:

- NPCが空腹になる
- 見えている食料を取得できる
- 食べることで状態が変化する
- 食料が無い時に不正取得・無限ループしない

---

## Phase 2 — Rest / Sleep

**開始条件:** 成立済み。Base–Food full-cycle evidenceと再利用境界は[Evidence](../experiment-evidence/BASE_FOOD_reference_loop_evidence.md)で固定した。

食料とは別の生活要求として休息を成立させる。

```text
疲れる
→ 休みたい
→ 安全な場所へ移動
→ 休息 / 睡眠
```

最小実装:

```text
RestNeed
rest point
safe sleeping place
short rest
sleep
```

ここではまず生活行動としての睡眠を成立させる。

Experience Consolidationは横断系として段階接続する。

---

## Phase 3 — EnergyReserve / ActiveEnergy

**現在地:** 参照実装として完了し、[Phase 3 Energy Evidence](../experiment-evidence/ENERGY_phase3_reference_evidence.md)を固定済み。`ActiveEnergy` の最小opt-in loop、独立した `EnergyReserve` の最小Sleep回復、個体別 `ActiveEnergyCapacity` 上限が実装されている。reserve移送、capacityの動的変化、枯渇時の行動拘束、Need arbitrationは未実装のまま、具体的なゲーム要件が出るまで拡張を停止する。

```text
EnergyReserve
ActiveEnergy
ActiveEnergyCapacity
```

を分ける。

```text
歩く → ActiveEnergy小消費
走る → ActiveEnergy大消費
軽い休息 → ActiveEnergy回復
睡眠 → ActiveEnergy大回復 + EnergyReserve回復
```

空腹・負傷・安全との相互拘束を許容する。

---

## Phase 4 — Safety / Danger

**現在地:** static Danger Gully内のNPC Bがbounded safety contextだけを受け、safe Plazaへ `flee` し、圏外の後続観測で `idle` へ戻る最小縦断を実装済み。predator、移動脅威、危険度比較、Energy連携、負傷は未実装。

```text
安全な拠点
→ 探索
→ 危険圏
→ 食料 / 物資
→ 帰還
```

最小実装:

```text
safe place
danger place
predator / dangerous creature
danger perception
flee
return
```

危険生物は単純な悪役ではなく、その世界の生物として扱う。

---

## Phase 5 — Incapacitation / Injury / Rescue / Recovery

主要住民NPCには原則として死亡を置かず、

```text
hunger / fatigue / injury
→ incapacitated
```

とする。

負傷:

```text
light
medium
severe
```

救助:

```text
A incapacitated
→ B discovers
→ rescue
→ return home
```

療養は段階的に進める。

全NPC行動不能時のみfailsafeを使う。

```text
system warp
!= NPC successful experience
```

危険遭遇・負傷・行動不能自体は履歴へ残せるが、救済ワープそのものは成功学習させない。

---

## Phase 6 — Hunting

狩りは独立戦闘ゲームではなく生活の延長として実装する。

```text
空腹
→ prey発見
→ 追跡
→ ActiveEnergy消費
→ 逃げられる / 反撃
→ 成功
→ meat / hide
→ 帰還
→ 食事 / 休息
```

失敗・負傷を許容する。

---

## Phase 7 — Materials

初期素材:

```text
皮
木材
ツタ
```

その他:

```text
food varieties
herb
glowing stone
field pickups
```

物体操作:

```text
拾う
持つ
置く
落とす
渡す
```

item単位でlocation / holder / history / provenanceを追えるようにする。

---

## Phase 8 — Simple Tools

候補:

```text
bag
rope
lantern
stretcher
bedding
simple hunting tool
```

道具は単なる数値バフではなく、既存行動の可能域を変える。

---

## Phase 9 — Crafting

初期は既知レシピ固定でよい。

```text
木材 + ツタ → 担架
皮 + ツタ → 袋
木材 + 皮 + ツタ → 簡易寝床
```

発明そのものは初期必須としない。

---

## Phase 10 — Barter

```text
Aが欲しい物を示す
Bが代わりに欲しい物を示す
双方が受諾
→ exchange
```

固定価格表を置かない。

価値は、

```text
Object
× current context
× Body need
× Experience
× Relation
```

によって変わる。

REQUEST / OFFER等のCommunication基盤へ接続する。

---

## Phase 11 — Glowing Stone / Emergent Value

光る石には初期状態から、

```text
少し珍しい
目立つ
きれい
何故か少し欲しくなる
```

程度の弱い誘引を与える。

```text
currency = true
```

は設定しない。

可能性:

```text
自分が欲しい
→ 他個体も欲しがる
→ barterに使われる
→ 他者需要を学ぶ
→ 自分に不要でも保持
→ exchange medium candidate
```

収集・贈答・装飾・執着など別の結果も許容する。

---

## Cross-cutting systems

World Time・Experience History・Neural Dynamics・Relation Constraints・Sleep Consolidation・Communication / Vocabulary・Player Interventionは、複数の生活Phaseへ必要時に接続する。各系は次の正本で定義し、本書では生活機能との接続点だけを管理する。

| 横断系 | 正本 / 現在の境界 | 生活機能への接続例 |
|---|---|---|
| World Time | 本書。現行tickと日周期モデルは別 | 食事・休息・帰還・不在検出 |
| Experience History | [Layer計画](RDL_GameAI_NPC_レイヤー別設計計画.md)。現行は有限approach結果のみ | 採食・救助・失敗・会話の記録候補 |
| Neural Dynamics | [神経設計](RDL_GameAI_神経パラメーター設計図.md)。動的状態は未実装 | 注意・行動・保持の偏り |
| Relation Constraints | [履歴モデル](RDL_GameAI_感情・履歴・関係拘束モデル.md)。社会的圧縮関係は未実装 | 人・物・場所への関係候補 |
| Sleep Consolidation | [睡眠設計](RDL_GameAI_睡眠システム設計.md)。未実装 | Restを契機に回復・履歴整理を別々に検証 |
| Communication / Vocabulary | [会話設計](RDL_GameAI_簡易会話からプレイヤー介入まで.md)。未実装 | 救助・交換・命名の局所伝播 |
| Player Intervention | [Player Role](RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md)。未実装 | 会話を介した語彙・情報入力のみ |

### World Time

```text
morning
→ daytime activity
→ evening return
→ night
→ sleep
→ next morning
```

時間はFood / Fatigue / Sleep / Predator activity / Routine / Missing detectionへ接続する。

---

### Sleep Consolidation

```text
Experience History
→ neural weighting
→ selection
→ compression
→ association
→ reconstructed relation candidates
```

睡眠はBody RecoveryでもありExperience Consolidationでもある。

Sleep != Layer、sleep != T1。GameAI-side trigger/windowとしてlocal候補を形成する。意味上の誤接続は許容するが、元履歴・参照・provenanceを破壊しない。canonical採用は別契約。

---

### Communication / Lexicon

初期intent:

```text
GREET
CALL
POINT
WARN
HELP
REQUEST
OFFER
ACK
```

救助・物の受け渡し・狩り・交換・語彙伝播へ接続する。

---

### Player Intervention

暫定的には拠点内のしゃべる神の像をPlayer Interfaceとする。

主な初期役割:

```text
NPCが未知対象について質問
→ Playerが名称を与える
→ NPCが語との関係候補を形成
→ 他NPCへ伝播
```

PlayerはTruth Sourceではない。

---

### Neural Dynamics

設計経路はDNA → neural μ/σ → actual dynamic state → derived sensitivity。サブタイプと操作的意味は神経設計を正本とし、ここでは再定義しない。現行の固定retry profileはこの経路とは別の最小実験。

神経状態は行動命令ではなく、注意・行動・保持・再構成への偏りとして使う。

---

## Future — Missing / Search

```text
usual bedtime
→ A absent
→ routine deviation detected
→ last-known place / history
→ search
→ discover incapacitated A
→ rescue
```

全体通知ではなく生活ルーチンの破れから異常を発見する。

---

## Future — Social Expansion

候補:

```text
shared stockpile
gift
loan
ownership
favorite object / place
role division
specialization
reciprocity
community norms
```

可能な限り既存interactionから形成される余地を残す。

---

## 停止規則

各機能は、

```text
単体で動く
+
既存機能との相互作用が観察可能
+
既存canonical sidecar / M_B / H等を意図せず破壊しない
```

ことを確認してから次へ進む。

GameAI-local状態を追加しただけでCore primitiveへ昇格させない。

---

## 現在の一文圧縮

> **生活機能は Food→Rest→Energy→Safety→Injury/Rescue→Hunting→Materials→Tools→Crafting→Barter→Emergent Value の縦線で増やし、World Time・Sleep・Communication・Player・Neural Dynamics・Relation Formationは横断系として必要なPhaseへ接続する。**
