# 図付き・主観的移動地形システム拡張計画書 v0.2

**状態:** IMPLEMENTATION PLAN / DESIGN DRAFT
**対象:** `RDL-Labs/RDL_GameAI_Lab`
**基準:** L13 / L14 系の有限観測・探索・資源取得・個体別状態分離を前提とする
**RDL上の位置:** GameAI-local な実装表現。T0 Core primitive の追加ではない。
**目的:** 観測から身体移動までの間に「主観的移動地形」を導入し、接近・回避・複数要因の競合を一つの有限な行動生成層として扱う。

---

後続の[現行探索への接続](../experiment-contracts/LUANTI_L15A_exploration_connection_contract.md)は別契約で実装した。
以下の追加時点の記録と区別し、身体状態・未知・社会関係等の予約要因は引き続きDESIGN ONLYとする。

## リポジトリへの追加時点（2026-09-28）

本書はユーザー提供の拡張計画v0.2。身体条件・未知・社会relation・学習済み予測・広域価値の扱いを、
[元のL15A計画](RDL_GameAI_Luanti_Subjective_Movement_Terrain_Plan.md)に追加する **DESIGN ONLY** 文書である。

既存Phase 1は `f090410` で実装・受入済み。式・入力・欠測・上限は
[Phase 1契約](../experiment-contracts/LUANTI_L15A_subjective_movement_terrain_contract.md)、検証済み範囲は
[Evidence](../experiment-evidence/LUANTI_L15A_subjective_movement_terrain_evidence.md)を正とする。
今回の文書追加ではコード・schema・係数・行動権限を変更しない。

| 範囲 | 現在の状態 |
| --- | --- |
| physical / food / obstacle | 5方向の純粋計算を実装済み。合成入力と既存replayで検証 |
| body_condition / unknown / social / learned_prediction / broad_value | 設計上の予約。入力・出力フィールドもまだ追加しない |
| 局所慣性・選択・実Worldの接近/回避・再送時の身体権限 | Phase 2以降の設計。現行出力は同点の最低方向を全件残す診断のみ |
| L15B〜L15E | 後続候補名。実装・受入済みとは扱わない |

現在のtotalは、実装済み3成分が完全取得された場合の限定合成値であり、将来要因まで含んだ総評価ではない。
予約要因の欠落は「未実装」であって、観測済みの0でも非適用の判定でもない。
将来schemaを拡張するときに、未実装・未取得・非適用と、根拠を伴う実測/計算済み0を区別する。
情報不足そのものを探索誘引へ変換せず、未知への価値評価を導入する際は別の出典・許可条件を定める。

以下の一般式にあるWorldの地形・actual_slope等は、RuntimeがWorld真値を直接読めるという意味ではない。
将来のphysical/body contributionにも、本人が取得した地形・身体情報と許可された能力profileを用いる。
追加の意欲・価値寄与によって、実行不能な身体操作や観測不足を実行可能へ変更しない。
L13Sの経路モデルとL14Bの採取モデルは別modeであり、本書の列挙を統合済み経路とは読まない。

図は既存のユーザー提供画像を参照する構想図。連続曲線や実身体回避を検証した記録ではない。
19節の受入条件・20節のEvidence・21節の成立主張はWorld接続後の目標も含み、現時点のPASS宣言ではない。
末尾の実装指示は提供文書の指示として保存する。Phase 1は完了しており、今回Phase 2へは進まない。

本文の取り込みでは画像リンク、節番号、残存していたv0.1表記をv0.2へ整えた。

---

## 0. この文書の目的

現在の探索系では、観測された Food への接近、landmark を使った有限探索、学習済み relation / M_B を使った行動差、資源の継続利用と探索要求などが段階的に実装されている。

次段階では、それらをすぐ `turn / move / wait` に変換するだけでなく、

```text
有限観測
↓
主観的移動地形の形成
↓
局所勾配 / 行動傾向の形成
↓
有限な身体操作
↓
再観測
```

という中間層を置く。

ここでいう「地形」は World の真の地形ではなく、**その個体が、その時点の有限観測の中で、各方向をどの程度移動しやすい／移動しにくいものとして扱うか**を表す一時的な局所面である。

---

## 1. 主観的移動地形の最小構造

### 1.1 単一オブジェクト

![単一オブジェクト版](L15A_concept_single.png)

図1では、Food のような単一対象が見えたとき、

```text
対象を観測
↓
対象周辺が局所的に低地化
↓
現在位置から勾配が形成される
↓
その勾配に沿って移動
```

という最小構造を示す。

対象自身が「こちらへ移動せよ」という命令を出すわけではない。
対象が現在の主観的移動地形を変形させ、その結果として移動が生じる。

---

## 2. 複数オブジェクトの合成

![複数オブジェクト版](L15A_concept_multiple.png)

実際の視界には複数の対象が同時に存在する。

初期概念としては、

- Food: 誘引
- 危険: 忌避
- 拠点: 誘引
- 未知領域: 弱い探索誘引

などが、それぞれ局所地形を変形させる。

概念上は、

```text
局所対象1による変形
+
局所対象2による変形
+
物理地形
+
その他の現在要因
↓
合成された主観的移動地形
↓
局所勾配
↓
移動
```

となる。

v0.2 の実装ではすべてを入れず、まず **Food + 物理地形 + 障害物** に限定する。

---

## 3. 障害物の近接反作用

![障害物の反作用場](L15A_concept_obstacle.png)

障害物は単なる「通れない場所」として扱うだけではなく、**近づくほど強くなる局所的な反作用場**を形成する。

この反作用は World の collision truth そのものではない。

```text
主観的反作用
!=
World の実衝突判定
```

World 側は最終的な身体作用の成否を従来どおり決定する。
Runtime 側では、現在観測できた障害物に対してのみ局所的な高地を作る。

これにより、

```text
Food への誘引
+
障害物の近接反作用
↓
合成地形
↓
障害物へ衝突する前から進路が曲がる
```

という自然な回避を狙う。

---

## 4. 実装対象 v0.2

v0.2 では以下だけを実装する。

### A. Food 誘引

現在の本人の観測に入っている Food を低地化要因として扱う。

要件:

- 見えている Food だけを使う
- World の hidden 座標を使わない
- 近いほど作用が強い
- 複数 Food は有限に合成する
- Food ref 名や入力配列順だけで結果が変わらない

### B. 物理移動コスト

現在取得できる局所的な地表・身体情報を基礎面として使う。

例:

- 通行可能
- 段差
- no_surface
- blocked の直近結果
- 現在の身体姿勢

### C. 障害物近接反作用

現在観測できた障害物だけを局所高地として扱う。

要件:

- 遠距離では 0 または弱い
- 近距離ほど強くなる
- 接触直前では強い反作用
- 左右固定回避ルールにしない
- hidden obstacle truth を使わない

---


## 5. 主観的移動地形は「様々な要因の合成面」である

主観的移動地形は、単一の attraction / repulsion だけで作るものではない。

より一般には、

```text
World の物理地形
+
個体の身体能力
+
現在の身体状態
+
資源・危険・障害物
+
未知への価値
+
社会 relation
+
学習済み予測
+
広域価値場
↓
その個体・その時点の主観的移動地形
```

と考える。

重要なのは、各要因を最初から一つの「性格値」や「行動スコア」に潰さず、
**異なる provenance を持つ contribution として保持したまま合成すること**である。

---

## 5.1 実地形と主観的な有効勾配を分離する

World の実際の斜面勾配と、個体が行動選択で受ける有効な勾配は同じではない。

例:

```text
World:
    slope = 20 degrees

個体A:
    高い登坂能力
    荷物が軽い
    体力十分
    -> 主観的には比較的低い移動コスト

個体B:
    低い登坂能力
    荷物が重い
    疲労している
    -> 主観的には高い移動コスト
```

したがって、

```text
physical_slope
!=
subjective_slope_cost
```

とする。

概念上:

```text
subjective_physical_cost
=
f(
    actual_slope,
    baseline_body_capacity,
    current_fatigue,
    carried_load,
    injury,
    other_current_body_state
)
```

ただし v0.2 ではこの全てを実装しない。
まず physical contribution と body-conditioned contribution を分離できる構造だけを確保する。

---

## 5.2 疲労は地形を急峻化させうる

同じ個体・同じ坂でも、現在体力によって主観的コストは変化しうる。

概念例:

```text
体力十分:
    実斜面 +3
    -> 普通の高地

疲労:
    同じ実斜面 +7
    -> 急な高地

限界近い:
    同じ実斜面 +15
    -> 事実上選びにくい

身体限界:
    -> 現在の身体では実行不能
```

ここでは、

```text
行きたくない
```

と

```text
行きたいが現在の身体では厳しい
```

を区別する。

疲労による高地化は、個性が変化したことを意味しない。

---

## 5.3 未知にも個体差のある勾配を許す

未知領域は単なる `unknown = no data` としてだけ扱わない。

個体によっては、

```text
未知
↓
新しい観測を得られる可能性
↓
探索価値
↓
弱い誘引
```

になりうる。

逆に別個体では、

```text
未知
↓
結果を予測できない
↓
損失可能性
↓
弱い忌避
```

になりうる。

概念上:

```text
unknown_contribution
=
unknownness
× exploration_tendency
× expected_information_value
```

ただし `expected_information_value` を World 真値から与えてはいけない。
本人の現在観測・履歴・許可された relation から形成する。

---

## 5.4 「探索的な個体は坂を登りやすい」の分解

探索的な個体が坂を登る場合、

```text
坂が物理的に低くなる
```

とは限らない。

むしろ、

```text
坂の向こうの未知が作る誘引
>
登坂に必要な主観的身体コスト
```

となりやすい、と表現する方がよい。

例:

```text
探索性が低い個体:
    slope cost      +5
    unknown value   -1
    total           +4
    -> 行きにくい

探索性が高い個体:
    slope cost      +5
    unknown value   -7
    total           -2
    -> 登ってみる
```

同じ探索個体でも疲労すれば、

```text
slope cost      +10
unknown value   -7
total           +3
-> 今は登らない
```

となりうる。

これは「好奇心が消えた」のではなく、
**身体状態によって合成地形のバランスが変わった**と解釈する。

---

## 5.5 個性は「行動命令」ではなく地形形成係数として扱える

将来的な個体差は、

```text
curious -> 右へ行く確率 0.8
```

のような直接行動パラメータだけで表す必要はない。

より一般には、

```text
個体差
├─ 未知への誘引感度
├─ 物理コスト感度
├─ 危険への反作用感度
├─ relation 投影感度
├─ 予測不確実性への反応
└─ 局所慣性
```

などの**地形形成係数の差**として表現できる。

これにより、同じ `curious` でも、

```text
A:
    未知への誘引は強い
    コスト感度は普通

B:
    未知への誘引は強い
    登坂コスト感度も強い
    -> 平坦な未知へ行きやすい

C:
    未知への誘引が非常に強い
    コスト感度が低い
    -> 坂の向こうへも行きやすい
```

と分解できる。

---

## 5.6 合成時に provenance を失わない

最終的な terrain total が同じでも、
その理由は異なりうる。

例:

```json
{
  "direction": "forward",
  "physical_slope": 3.0,
  "body_condition": 2.0,
  "food": -1.0,
  "unknown": -5.0,
  "social": 0.0,
  "obstacle": 1.0,
  "total": 0.0
}
```

別個体では:

```json
{
  "direction": "forward",
  "physical_slope": 3.0,
  "body_condition": 0.5,
  "food": -1.0,
  "unknown": -2.5,
  "social": 0.0,
  "obstacle": 0.0,
  "total": 0.0
}
```

total が同値でも、同じ主観状態・同じ個性とはみなさない。

したがって evidence では少なくとも、

```text
physical
body_condition
resource
obstacle
unknown
social
learned_prediction
broad_value
total
```

のように contribution の出典を保持できる拡張余地を残す。

---

## 5.7 初版実装との境界

v0.2 の Phase 1 で実装するのは依然として、

```text
physical
food
obstacle
```

まででよい。

以下は **設計上の予約スロット** として扱う。

```text
body_condition
unknown
social
learned_prediction
broad_value
```

未実装要因を `0` として「観測済み」と偽装してはならない。
未実装・未取得・非適用を区別する。


## 6. 初版で実装しないもの

以下は後続設計とする。

- 意味的な危険・脅威
- 社会 relation の空間投影
- 会いたい / 会いたくない人物
- hunger / fatigue / injury
- active M_B からの非可視領域予測
- 長期地図
- A*
- global navmesh
- 群行動
- 他個体との社会的衝突回避
- 貨幣・交換価値
- 一般的な「感情場」

v0.2 で広げすぎない。

---

## 7. 実装アーキテクチャ

### 7.1 新規 pure module

候補:

```text
runtime/subjective_movement_terrain.py
```

既存探索器へ最初から複雑な地形計算を埋め込まない。

入力:

- bounded current observation
- current body state
- finite configuration

出力:

- finite directional samples
- source contributions
- total subjective height
- preferred local direction

### 7.2 有限方向だけ評価する

初版では full raster / global grid は作らない。

候補例:

```text
forward
forward_left
forward_right
left
right
wait
```

または既存身体操作へ合わせて、

```text
turn -90
turn -45
move
turn +45
turn +90
wait
```

のような有限候補にする。

一回の terrain evaluation から長距離 path を生成しない。

---

## 8. 地形値

概念上は、

```text
subjective_height(direction)
    =
      physical_cost(direction)
    + obstacle_repulsion(direction)
    + food_attraction(direction)
```

とする。

低いほど「現在の個体にとって移動しやすい」。

ただし `food_attraction` は負方向の寄与でもよい。

各 contribution を必ず分解保存する。

例:

```json
{
  "direction": "forward_left",
  "physical": 0.8,
  "food": -2.4,
  "obstacle": 1.7,
  "total": 0.1
}
```

total だけを残さない。

---

## 9. Food 誘引の有限規則

初版は高度な数理モデルを目的としない。

必要条件:

- 距離に対して単調
- 有界
- finite
- hidden World truth 不使用
- 複数 Food の有限合成可能

候補例:

```text
food_attraction(d)
    = -max(0, R_food - d) * k_food
```

または他の有界な単調関数。

複数 Food の合成は clamp / normalization を入れ、対象数だけで無限に深くならないようにする。

---

## 10. 障害物反作用の有限規則

初版は piecewise でよい。

概念例:

```text
distance > R_repulsion
    -> 0

middle range
    -> weak

near
    -> medium

very near
    -> strong
```

重要なのは、

> **近づくほど反作用が強くなること**

であり、特定の数式を再現することではない。

---

## 11. 局所慣性

最低地形方向だけを毎 frame 絶対選択すると、左右振動が発生しうる。

そのため初版では、現在 heading を有限な tie-break として使ってよい。

例:

1. 最低値方向を求める
2. 差が小さい場合は現在方向を維持
3. 十分な差がある場合だけ turn
4. 現在方向が低地なら move
5. 全方向が高い / 観測不十分なら wait

新しい長期記憶機構は追加しない。

---

## 12. RDL Core との境界

主観的移動地形は **GameAI-local な中間表現** とする。

以下と同一視しない。

```text
主観的移動地形
!= B
!= M_B
!= RIB_B
!= E
!= H
!= θ
!= M_delta
```

特に、

- 障害物の反作用値を H と呼ばない
- 地形閾値を θ と呼ばない
- 地形の差を Core E と自動的に呼ばない

Core の `E = Difference` は frozen pre-update M_B のもとで F / F' を比較する別責務を持つ。

主観的移動地形は、現在の有限観測から身体作用候補を形成する GameAI 実装層である。

---

## 13. M_B との将来接続

v0.2 では、active M_B を terrain へ流し込まない。

将来的には、

```text
active M_B
↓
ある方向 / 場所に対する予測
↓
弱い仮地形
↓
現在観測による局所地形と合成
```

という接続が可能。

ただし、

```text
現在見えているもの
```

と

```text
過去 relation による予測
```

を必ず provenance 上で分ける。

---

## 14. 社会 relation の空間投影 — 後続設計

### 14.1 基本構造

社会 relation は、それ自体が移動地形ではない。

しかし、人物 X と場所 P の関係が学習されている場合、

```text
X への relation
×
P に X がいる予測
×
現在文脈
↓
P 周辺への局所作用
↓
主観的移動地形
```

という投影が可能。

### 14.2 会いたい人物

```text
X に会いたい
+
P に X がいる可能性が高い
↓
P が弱く低地化
```

これは必ずしも Goal 化する必要はない。

「わざわざ会いに行くほどではないが、同程度の二経路なら少し P 側へ寄る」

程度の弱い勾配も許容する。

### 14.3 会いたくない人物

```text
X を避けたい
+
P に X がいる可能性が高い
↓
P が高地化
```

同じ場所、同じ人物存在予測でも、個体 relation により符号が変わりうる。

```text
A: 会いたい -> 低地
B: 会いたくない -> 高地
C: 無関心 -> ほぼ変形なし
```

これが主観的移動地形の個体差となる。

### 14.4 時間条件

```text
場所 P
×
時刻 t
×
人物 X
```

の relation があれば、地形変形も時間依存でよい。

例:

```text
朝 -> ほぼ変化なし
夕方 -> P が少し低地化
```

---

## 15. 社会 relation 投影概念図

```text
           社会 relation
              │
     ┌────────┴────────┐
     │                 │
  会いたい           会いたくない
     │                 │
     ▼                 ▼
遭遇予測地点        遭遇予測地点
   が低地化            が高地化
     │                 │
     └────────┬────────┘
              ▼
       主観的移動地形
              │
              ▼
          身体移動
```

これは v0.2 の実装対象外。

---

## 16. 広域価値場 — 後続設計

貨幣のような価値は、Food のような一つの局所 object として扱うだけでは不十分。

貨幣は、

- 将来の Food
- 将来の安全
- 交換可能性
- 選択可能性
- 他者との取引

など複数の将来遷移へ作用するため、**広い範囲の行動選好へ偏りを与える背景場**として扱える可能性がある。

ただし単純に

```text
金になる場所 = 巨大な低地
```

とはしない。

より慎重には、

```text
広域価値場
↓
各局所要因の重みを変える
↓
局所主観的移動地形
```

という meta-field として設計する。

---

## 17. 広域価値場概念図

```text
                 広域価値場
            （貨幣・交換可能性など）
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
       Food価値    場所価値    社会行動価値
          │           │           │
          └───────────┼───────────┘
                      ▼
             局所重みの再配分
                      ▼
              主観的移動地形
                      ▼
                  身体移動
```

広域価値場は、特定座標への単純な引力ではなく、**局所地形生成規則そのものへ持続的な偏りを与える**可能性を持つ。

これも v0.2 の実装対象外。

---

## 18. Phase 構成

### Phase 1 — pure terrain calculator

実装:

- 単一 Food
- 複数 Food
- 単一障害物
- 複数障害物
- Food + 障害物
- partial / unavailable input

World作用はまだ行わない。

### Phase 2 — single Food World acceptance

```text
Food 観測
↓
terrain valley
↓
finite turn / move
↓
Food 方向への接近
```

### Phase 3 — obstacle near-field

比較:

```text
A: Food のみ
B: Food + 左障害物
C: Food + 右障害物
D: Food + 正面障害物
```

Food 接近を維持しつつ、配置に応じて軌跡が曲がることを見る。

### Phase 4 — multiple composition

複数 Food + 複数障害物。

各 decision について、

```text
sources
contributions
total terrain
selected gradient
actual result
```

を保存する。

---

## 19. 受入条件

最低限以下を PASS させる。

1. 単一 Food で Food 方向が低地化する。
2. Food の左右を反転すると地形も対応して反転する。
3. ref 名や object 配列順だけでは結果が変わらない。
4. 複数 Food を有限に合成できる。
5. 障害物は遠距離では弱く、近距離ほど反作用が強い。
6. Food と障害物が競合したとき、直進固定ではなく有限な回避が生じうる。
7. 左右対称対照により固定右折を排除する。
8. partial / unavailable を 0-cost として補完しない。
9. Runtime の主観的地形と World collision truth を分離する。
10. 同じ観測の再送で新しい作用を増やさない。
11. agent / body provenance を越境しない。
12. terrain 計算から Core E/H/θ/M_delta を自動生成しない。
13. 既存 L13 / L14 replay を壊さない。
14. 新 mode を無効化すれば既存挙動を維持する。

---

## 20. Evidence

各 decision について最低限保存する。

```text
observation_id
agent_id
pose_ref
body_revision

visible_food
visible_obstacles
ground_coverage

directional_samples:
    direction
    physical
    food
    obstacle
    total

selected_gradient
selected_action
selected_reason

operation_id
actual_world_result
next_observation_id
```

World audit は別記録:

```text
true object positions
true obstacle geometry
actual trajectory
collision result
```

audit truth を Runtime 入力へ返さない。

---

## 21. 停止境界

v0.2 で成立を主張してよいのは、

> 現在見えている Food・局所物理地形・障害物から、有限な主観的移動地形を形成し、その合成勾配によって接近と回避が生じる。

まで。

以下は主張しない。

- 一般 navigation の完成
- 最短経路学習
- 障害物概念の一般学習
- 社会関係移動の完成
- 感情の実装
- 貨幣価値理解
- M_B = 地形
- H / θ = 行動圧
- World 全体の地図理解

---

## 22. 後続候補

### L15B — relation projection

社会 relation / learned relation を、弱い局所地形として投影する。

### L15C — body-conditioned terrain

hunger / fatigue / injury などで同じ World の地形が個体状態に応じて変わる。

### L15D — individual tendency

探索性などの個体差が、未知領域・既知資源への地形重みを変える。

### L15E — broad value field

貨幣・交換価値などが局所地形の重みづけへ広域的に作用する。

---

# Codex への実装指示（提供時。Phase 1完了済み）

**まず Phase 1 だけを実装すること。**

既存探索器を直接置換しない。

追加するもの:

```text
runtime/subjective_movement_terrain.py
tests/test_subjective_movement_terrain.py
```

必要に応じて専用 contract / evidence の skeleton を追加してよい。

Phase 1 で実証するもの:

1. 単一 Food による低地
2. 複数 Food の有限合成
3. 障害物の距離依存反作用
4. Food + 障害物の合成
5. partial / unavailable input の非補完
6. object ID / 配列順への非依存

**World 身体作用へまだ接続しないこと。**

Phase 1 完了時に停止し、以下を報告すること。

- 変更ファイル
- 採用した有限計算規則
- dedicated test 結果
- full regression 結果
- 既存探索器へ非介入であること
- hidden World truth を参照していないこと
- 次の Phase 2 接続点

---

## 最終原則

このシステムの狙いは、移動を「対象 → 命令」として処理するのではなく、

```text
対象・身体・関係
↓
その個体にとっての局所的な遷移しやすさ
↓
地形として圧縮
↓
勾配
↓
行動
```

として扱うことである。

まずは物理移動で有限に成立させる。

社会 relation、概念、価値制度へ同じ構造が拡張可能であるかは、その後の独立した検査対象とする。
