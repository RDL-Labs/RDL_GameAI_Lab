# L15A案 — 主観的移動地形システム 実装計画

**状態:** Phase 1 IMPLEMENTED / ACCEPTANCE COMPLETE、Phase 2〜5 DESIGN ONLY
**提案時基準:** `RDL-Labs/RDL_GameAI_Lab@faf1fc42`
**Phase 1実装基準:** `52b09d5c`（L14B探索seed比較後）
**依存:** L13U/L13V/L13S、L14A/L14B の有限観測・相対身体操作・個体別権限
**Core意味基準:** `RDL_Core@86a0d4f3` / BASE v2.3.1 / SPEC v2.5

---

## 実装の区切り

本書はユーザー提供のL15A案を保存し、Phase 1だけ具体化する。
実装の式・入力・欠測・上限の正本は[Phase 1契約](../experiment-contracts/LUANTI_L15A_subjective_movement_terrain_contract.md)、
結果は[Evidence](../experiment-evidence/LUANTI_L15A_subjective_movement_terrain_evidence.md)。
現在のL13S経路モデルとL14B採取モデルは別modeであり、以下の列挙を一つの統合済み経路と解釈しない。
図はユーザー提供の構想図。危険・拠点・未知領域・連続曲線・実身体回避はPhase 1の実装・実機結果ではない。

## 0. 目的

現在の探索系は、

- 観測されたFoodへの接近
- 観測されたlandmarkへの有限subgoal
- 学習済みM_Bによる経路選択
- L14Bの局所exploration request

まで動作している。

次段階では、これらを直接的な

`対象を選ぶ → turn / move`

だけで処理するのではなく、

**現在見えている範囲から、個体ごとの「主観的移動地形」を形成し、その局所勾配から移動を生成する**

中間層を追加する。

基本経路:

    bounded observation
    ↓
    主観的移動地形を形成
    ↓
    現在位置近傍の勾配を取得
    ↓
    turn / move / wait
    ↓
    World作用
    ↓
    再観測
    ↓
    地形を再形成

これはWorld全体の地図生成ではない。

---

## 1. 概念

### 1.1 主観的移動地形

主観的移動地形とは、

**現在の有限観測のもとで、個体にとって各局所方向がどの程度「移動しやすい／移動しにくい」かを表す一時的な局所面**

とする。

以下とは区別する。

    Worldの物理地形
    != Sensor observation
    != 主観的移動地形
    != canonical RIB_B
    != M_B

主観的移動地形はGameAI-localな行動生成用表現であり、
Core primitiveには追加しない。

---

## 2. 図示する三段階

文書には以下の既存図を添える。

### 図1 — 単一オブジェクト

![ユーザー提供の構想図](L15A_concept_single.png)

1つのFood等が見えた場合、

    Object
    ↓
    局所的な低地形成
    ↓
    勾配
    ↓
    接近

対象そのものがmove命令を出すのではない。

---

### 図2 — 複数オブジェクト

![ユーザー提供の構想図](L15A_concept_multiple.png)

複数対象が同時に見える場合、

    Food
    Danger
    Base
    Unknown region
    ...
       ↓
    各局所変形
       ↓
    合成された主観的移動地形
       ↓
    局所勾配
       ↓
    移動

「一番重要な対象を1つ選ぶ」方式に限定しない。

---

### 図3 — 障害物の近接反作用

![ユーザー提供の構想図](L15A_concept_obstacle.png)

障害物は固定的な禁止領域だけでなく、

**近いほど強くなる反作用的な局所高地**

として扱う。

    目標による誘引
    +
    障害物による近接反作用
    ↓
    合成地形
    ↓
    障害物へ衝突する前から進路が曲がる

---

## 3. 初版で扱う変形要因

初版は3種類だけに限定する。

### A. Food attraction

現在の完全取得範囲で観測されたFood。

- Foodに近い方向を低くする
- 距離が遠いほど作用を弱くする
- 未観測FoodをWorld座標から補完しない
- Food refそのものに恒久価値を付与しない

### B. Obstacle repulsion

現在観測できる身体障害物。

- 遠距離では弱い
- 近距離ほど強くする
- 接触直前では非常に高い
- 「blocked結果が出てから右折」だけに依存しない

### C. Base physical traversal cost

現在取得できる局所地表情報。

- 通行可能な平地
- 高低差
- blocked / no_surface
- その他既存の有限身体条件

を基礎面として用いる。

---

## 4. 初版では入れないもの

以下は後続。

- 危険生物による意味的忌避
- 仲間・親密さ
- Homeへの帰還圧
- fatigue / hungerによる地形変形
- active M_Bによる非可視領域の地形生成
- L14B `steady / curious / restless` の直接接続
- 長期地図
- 絶対World座標によるnavigation
- A*
- global navmesh
- 一般的potential-field planner
- 他個体との衝突回避
- 群行動

初版はまず

**Food誘引 + 物理地形 + 障害物近接反作用**

だけで成立を確認する。

---

## 5. 実装表現

新規pure module候補:

    runtime/subjective_movement_terrain.py

既存の `runtime/exploration.py` 自体へ直接複雑な計算を埋め込まない。

概念上:

    terrain_score(direction)
      = physical_cost(direction)
      + obstacle_repulsion(direction)
      + attraction_cost(direction)

低いほど進みやすい。

名称は `pressure` より `movement terrain` を正とする。
pressure / gradient は地形から導出される説明語として使う。

Coreの

- E
- H
- θ
- C_rel
- C_eff

とは同一視しない。

---

## 6. 視界依存

地形生成に使えるのは、本人が現在取得した有限観測だけ。

禁止:

    hidden World map
    resource patch coordinates
    obstacle coordinates from audit state
    correct route
    Food distribution truth
    terrain generator seed

使用可能:

    current local surface observation
    current visible Food relative positions
    current visible obstacle relative positions
    current body pose/revision
    declared finite profile

原則:

> 見えていない場所を、見えているものとして地形化しない。

初版では毎観測ごとに局所地形を作り直してよい。
永続的な地形storeは作らない。

---

## 7. 局所サンプリング

最初から連続2D rasterを作らず、
既存の有限操作語彙に合わせた小さな候補集合で試す。

例:

    forward
    forward-left
    forward-right
    left
    right
    wait

または既存身体作用との互換を優先し、

    turn -90
    turn -45
    move
    turn +45
    turn +90
    wait

程度に固定する。

各候補方向について主観的高さを計算し、
最低地形方向へ有限な一操作を出す。

一度の計算から長距離経路を生成しない。

---

## 8. Food誘引

Foodの相対位置を `(forward, right)` とする。

初版例:

    attraction ∝ -1 / max(distance, epsilon)

または有限・有界な

    attraction = -max(0, R_food - distance)

等を使う。

重要なのは式そのものより、

- 距離で単調に変化する
- 上限がある
- hidden positionを使わない
- 複数Foodでは合成できる

こと。

複数Foodの場合、

    total_food_field(direction)
      = Σ visible_food_i contribution

とする。

ただしFood数の増加だけで無限に強くならないよう
clampまたは正規化を入れる。

---

## 9. 障害物の近接反作用

障害物については、

    distance > R_repulsion
        → 0

    distance <= R_repulsion
        → 距離が近いほど正のcost増大

とする。

概念例:

    repulsion(d)
      = k * (1/d - 1/R)^2
      if d < R
      else 0

ただし初版の実装では、
より単純な有限piecewiseでもよい。

例:

    6〜12 node  : 0
    3〜6 node   : weak
    1.5〜3 node : medium
    0〜1.5 node : strong

目的は数式の再現ではなく、

**近づくほど滑らかに回避方向が強くなる**

こと。

---

## 10. 物理的通行不能との分離

反作用場と実際の身体制約を混同しない。

    subjective repulsion
    != collision truth

World側は従来どおり最終的な身体作用を判定する。

Runtimeが「通れそう」と判断してもWorldでblockedになりうる。

そのblocked結果は次観測／次decisionの材料になる。

World collisionをRuntime側で完全再現しない。

---

## 11. 合成

複数要因は、

    subjective_height(direction)
      = base_physical
      + obstacle_field
      + food_field

として一つの局所値へ合成する。

ただし各source contributionを必ず別記録する。

例:

    {
      "direction": "forward_left",
      "physical": 1.0,
      "food": -3.2,
      "obstacle": 4.1,
      "total": 1.9
    }

totalだけ保存しない。

これにより、

- Foodへ行かなかった理由
- 障害物を回った理由
- 地形が同点だった理由

を後から追跡可能にする。

---

## 12. 行動選択

地形最小値を即座に絶対選択するだけでは、
左右の細かい振動が発生する可能性がある。

初版では有限な慣性を許す。

ただし新しい長期状態は作らず、

    previous heading
    + current terrain

だけで局所tie-breakを行う。

例えば:

1. 最低値方向を求める
2. 差が小さい場合は現在向きを維持
3. 十分な勾配差がある場合だけturn
4. 現在方向が低地ならmove
5. 全候補が高い／取得不足ならwait

とする。

---

## 13. M_Bとの責務境界

初版の主観的移動地形は、

**観測から直接作るGameAI-localな行動面**

として実装する。

M_Bそのものではない。

将来:

    active M_B
    ↓
    「この方向にはFoodがありそう」
    ↓
    主観的移動地形を局所変形

という接続は可能だが、
初版には入れない。

L13S/L14Bで採用済みrelationを、
暗黙にterrain weightへ流用しない。

---

## 14. L14Bとの境界

L14Bには既に

- Food pickup
- visible landmark exploration
- 個体別M_B
- steady / curious / restless
- finite exploration request

が存在する。

初版ではこれを置換しない。

新modeを明示opt-inにする。

候補:

    SUBJECTIVE_TERRAIN_SCHEMA = "l15a-subjective-movement-terrain-v1"

または独立feature flag。

既存L14B replayは変更せず、
L15Aだけ専用contract/evidenceを持つ。

---

## 15. 実装順序

### Phase 1 — pure terrain calculator

新規pure functionで、

    observation
    → finite directional samples

だけを実装。

World作用なし。

検査:

- Food 1個
- Food左右変更
- 障害物1個
- 距離変更
- Food + 障害物
- 複数Food
- 複数障害物

---

### Phase 2 — single-object World acceptance

単一Foodだけ。

    Foodが見える
    ↓
    terrain valley
    ↓
    turn / move
    ↓
    接近

従来の直接Food servoとは別modeで比較する。

---

### Phase 3 — multiple-object composition

Foodを2〜5個にする。

確認:

- 最寄りだけをハードコードしていない
- object列順で答えが変わらない
- 同じ配置ならref名変更で同じ地形になる
- 複数対象の合成結果を保存する

---

### Phase 4 — obstacle near-field

Foodと障害物を同時配置する。

比較:

    A: Foodのみ
    B: Food + 左障害物
    C: Food + 右障害物
    D: Food + 正面障害物

期待するのは、

**Foodへ接近しながら障害物に応じて軌跡が自然に曲がること。**

特定の左右回避を正解としてハードコードしない。

---

### Phase 5 — mixed finite terrain

複数Food + 複数障害物。

同じ観測から、

    contribution
    total terrain
    chosen gradient
    actual World result

を全て保存する。

---

## 16. 受入条件

最低限以下をPASSさせる。

1. Food単体で、Food方向へ局所勾配が形成される。
2. Food位置を左右反転すると、地形と最初の方向も対応して反転する。
3. ref名やobject配列順だけでは結果が変わらない。
4. 障害物が遠距離ではほぼ作用しない。
5. 同じ障害物が近づくほど反作用が増える。
6. Foodと障害物が同方向にある場合、直進ではなく有限回避が生じ得る。
7. 左右対称配置では、固定右折ハードコードで説明できない対照を置く。
8. partial / unavailable observationを0-costへ変換しない。
9. World collision結果とRuntime地形値を別に保存する。
10. 同じ観測の再送で新しい地形履歴・身体作用を増やさない。
11. 他個体のframe / operationを流用できない。
12. terrain計算を有効化してもcanonical E/H/T1/M_Bを自動変更しない。
13. 既存L14B/L14A/L13系の保存replayが回帰PASSする。
14. 新modeを無効にした既存挙動は変更しない。

---

## 17. 保存するEvidence

各decisionについて最低限:

    observation_id
    pose_ref
    body_revision

    visible Food sources
    visible obstacle sources
    ground coverage

    directional_samples:
      direction
      physical contribution
      attraction contribution
      repulsion contribution
      total

    selected_gradient
    selected_action
    selected_reason

    operation_id
    actual World result
    next observation reference

World側監査には別途、

    actual object positions
    actual obstacle geometry
    actual path
    collision result

を保存する。

監査真値をRuntime入力へ戻さない。

---

## 18. 停止境界

L15Aで成立を主張してよいのは、

> 現在見えているFood・局所地形・障害物から、個体固有の有限な主観的移動地形を形成し、その合成勾配によって接近と回避が生じる

ところまで。

以下は主張しない。

- 世界地図を理解した
- 最短経路を学習した
- 障害物の意味を学習した
- Food分布を学習した
- 危険を理解した
- 感情が実装された
- M_Bが主観的地形そのものである
- Core H/θが移動圧である
- 一般的navigationが完成した

---

## 19. 次工程候補

L15A受入後にのみ、別契約として検討する。

### L15B
active M_Bによる地形変形

    現在見えないが
    採用済みrelationから期待される方向
    ↓
    弱い仮地形

### L15C
身体状態による地形変形

    fatigue
    hunger
    injury
    ↓
    同じWorldでも違う主観的移動地形

### L15D
個体差

    steady / curious / restless
    ↓
    未知領域や既知資源への局所地形重みの差

### L15E
複数個体

    他者
    共有資源
    距離
    learned relation
    ↓
    個体ごとに異なる主観的移動地形

---

## Codexへの実装指示（提供時の指示。今回Phase 1まで完了）

まずPhase 1だけを実装すること。

既存の探索器を直接置換しない。
新しいpure terrain calculatorと専用テストを追加し、
以下を示すこと:

1. 単一Foodによる谷
2. 複数Foodの合成
3. 障害物の距離依存反作用
4. Food + 障害物の合成
5. partial inputの非数値化
6. object ID / 配列順への非依存

Phase 1がPASSした時点で停止し、
変更ファイル、式、テスト結果、既存探索への非介入を報告すること。

World身体作用への接続は、
Phase 1レビュー後の別変更として行うこと。
