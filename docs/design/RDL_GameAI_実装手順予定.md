# RDL_GameAI — 実装手順予定

**文書種別:** Implementation Roadmap / DRAFT  
**版:** v0.2  
**位置づけ:** RDL_GameAI_Lab / GameAI-local implementation plan

## 0. 実装方針

最初から大規模な生活・経済・クラフトシステムを作らない。

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
Sleep Consolidation
Communication / Lexicon
Player Intervention
Neural Dynamics
Relation Formation
```

全体配置は `RDL_GameAI_全体設計地図.md` を参照する。

---

## Phase 1 — Food

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

## Cross-cutting 1 — World Time

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

## Cross-cutting 2 — Sleep Consolidation

```text
Experience History
→ neural weighting
→ selection
→ compression
→ association
→ reconstructed relation candidates
```

睡眠はBody RecoveryでもありExperience Consolidationでもある。

意味上の誤接続を許容する。

---

## Cross-cutting 3 — Communication / Lexicon

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

## Cross-cutting 4 — Player Intervention

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

## Cross-cutting 5 — Neural Dynamics

細粒度parameterを保持する。

```text
DA: D1 D2 D3 D4
5-HT: 1 2 3 4
OXT
NA: α1 α2 β
```

DNAは各parameterの基準μ/σを与える。

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
