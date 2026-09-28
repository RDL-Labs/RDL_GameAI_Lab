# L15A Phase 1 — 有限な主観的移動地形の計算

状態: Phase 1 ACCEPTANCE COMPLETE。基準 `52b09d5c`。2026-09-28。
[提案と構想図](../design/RDL_GameAI_Luanti_Subjective_Movement_Terrain_Plan.md)。
Core意味基準は `86a0d4f3` / BASE v2.3.1 / SPEC v2.5。

## 今回の入口と停止境界

`runtime.subjective_movement_terrain.calculate_terrain(observation)` は、1つの現在観測から5方向の高さを返す純粋関数。
最低値の方向を全件診断として返すが、turn/move/wait/pickup、操作ID、行動権限を生成しない。
慣性、閾値による行動選択、World身体作用、センサーadapter、配送store、長期履歴は作らない。
既存L13/L14A/L14Bの入力や選択器へは登録せず、明示的な関数呼出しだけで利用する。

この局所面はGameAIの設計上の表現。RIB_B/M_B/Core E/H/θ/C_rel/C_effではない。
採用済みrelation、L14B profile、空腹・危険・仲間・未知領域の価値を暗黙に利用しない。
図の連続面や回避曲線は構想であり、Phase 1は離散方向の計算まで。

## 固定profileと有限入力

schemaは `l15a-subjective-movement-terrain-v1`、profileは `l15a-finite-directional-v1`、ruleは `l15a-phase1-v1`。
係数はfixture用の設計値で、学習結果・生物の能力値・L14Bの偏りを解消する保証ではない。

| 項目 | Phase 1の値 |
| --- | --- |
| 方向 | −90 / −45 / 0 / +45 / +90度。正は身体の右 |
| 評価点 | 各方向へ水平1 nodeの点q。現在位置は(0,0) |
| Food | 現在観測された可食材料の点、最大5個 |
| 障害物 | 現在観測された障害物の点、最大8個 |
| 座標範囲 | 身体相対 `(forward,right)`、前方半円、水平距離12 node以内 |
| 地表 | 各評価方向に1件、計5件。statusと相対高さ差 |
| 入力上限超過 | 明示拒否。先頭だけを使わない |

トップレベルは `schema/profile/context/food/obstacles/ground` のみ。
contextには `run_id/world_epoch/agent_id/observation_id/clock_id/capture_us/pose_ref/body_revision` を持つ。
各channelは `source/coverage/output_limited` と、点の`items`または地表の`samples`を持つ。
sourceはcontext全フィールドとframe IDを含み、全channelで同じ取得時刻・姿勢・個体・run等が必要。
相違は `TerrainInputError` で拒否し、partialであっても検査を省略しない。

点は `ref/forward/right` のみ。World座標・資源残量・地形seed・任意重みなど余分なフィールドは拒否する。
refは同channel内で一意。数値にNaN/Infinity/boolを認めない。地表方向の重複・欠落も不正入力。
coverageは `complete/partial/unavailable`。completeはこの有限な取得計画内の完了で、World全体の網羅を意味しない。出力上限を使ったchannelはpartialでなければならない。
unavailableな点channelは空、地表は5方向ともunavailableにする。

**これは本人の現在観測を呼出し側が用意する契約であり、frameの実在・受付を認証する入口ではない。**
frame ID文字列を解析して所属や姿勢を推測しない。整合した偽のsourceを検出できるとは主張しない。
既存L13Tの地表色rayやL13Uの面特徴を、障害物形状・高さ差へ自動変換するadapterは未実装。
入力座標はすでに同じ取得時の身体基準へ揃っているというprofile契約。pose refの文字列一致から座標変換を作らない。
今回は合成した明示入力だけを使い、既存のWorld監査座標から欠けた観測を補完しない。
可食性の判定や障害物の認識もこの関数の責務外。

## 計算式

`q=(cos(angle), sin(angle))` を身体相対の `(forward,right)` とする。対称方向は対称な固定座標を用いる。

### Food誘引

観測点fに対する評価点からの距離を `d=||q-f||` として、

```text
raw_food_i(q) = -4 × max(0, 1 - d/12)
food(q) = Σ raw_food_i(q) / max(1, Food数)
```

距離が遠いほど弱い線形の谷。合成後は常に[-4,0]。Food数による無制限な強化を防ぐため平均する。
最寄りの1個に絞らない。点ごとのraw値と正規化後の寄与、分母を保存する。
距離は評価点からの距離であり、足元のFoodを通り越して進む命令を正当化するものではない。
到着・pickup・停止の制御はPhase 2以降で別に定める。

### 障害物の近接反作用

観測障害物oと、現在位置からqまでの閉線分との最短距離をdとする。

```text
t = clamp(dot(o,q), 0, 1)
d = ||o - t×q||
raw_obstacle_i(q) = 6 × max(0, 1 - d/6)^2
obstacle(q) = min(12, Σ raw_obstacle_i(q))
```

線分から6 node以上は0、近いほど増し、接触する点では1件あたり6で有限に飽和する。
評価点だけで測ると、一歩の途中にある障害物を通り越した評価で反作用が弱まり得るため、線分距離を採用する。
観測点が正面の1 node以内へ入ると、その方向への反作用は6を保つ。
各点の距離と寄与、合計、上限12を保存する。
点形状の近接コストであり、未知の幅・高さ・身体半径を復元するものではない。衝突判定の再実装でもない。
この項は候補線分のコスト。有限方向の高さを比較するだけで、連続2D面やそのベクトル勾配を計算していない。

### 基礎面

地表statusが`sampled`で、取得した相対高さ差の絶対値が1 node以内なら、

```text
physical(q) = 2 × abs(height_delta)
total(q) = physical(q) + food(q) + obstacle(q)
```

上り/下りを同じコストとする初版の固定近似。平地0、1 node差2。
sampledの高さ入力範囲は[-4,4]、1 node超は `step_height_exceeded` としてその方向を評価対象外にする。
`blocked/no_surface`も評価対象外。physical/totalはnullとし、Infinityや「0だから安全」に置換しない。
これらは与えられた取得結果に基づく局所制限であり、現Worldの通行可能性を保証しない。

## 欠測・同点・出典

1channelでもpartial/unavailable/output_limitedなら全方向を `not_evaluated` とし、
physical/food/obstacle/total/source_contributionsをすべてnullにする。
利用できた原観測はevidenceへ残し、全ての不足理由を保持する。正常な取得不完了と不正入力拒否は別。

全channel完全取得の空の場では0の平地を返す。既知のblocked/no_surfaceが全方向なら
`no_supported_direction`、minimum_height=null、minimum_directions=[]。
取得不完了ではminimum_directions=null。全方向を調べた上で評価対象がない状態と区別する。

数値を持つ方向の最低高さと、そこから絶対誤差1e-9以内の**全方向**を返す。
左右同点なら左右を両方保持し、固定右折やrefによる勝者選択はしない。
各channelの原観測とsource、方向ごとの地表・全Food・全障害物の寄与を保存する。
配列順は正規化し、数値の加算はrefによらない順序で行う。ref名変更で変わるのは出典の文字列だけ。

再呼出しは同じ結果を新しい辞書として返すだけで、履歴を追加しない。入力・他の呼出し結果と可変参照を共有しない。
身体操作の重複実行を防ぐ台帳は、操作自体が存在しないPhase 1では実装も実証もしていない。

## Phase 1の受入

単一Foodの谷、左右反転、複数Food合成、距離依存反作用、複数障害物と飽和、Food+障害物、
対称な同点、ref/配列順非依存、取得不完了、既知の評価対象外、上限・不正数値・混線拒否、純粋性を検査する。
固定入力の既存L14A/L14Bを呼出しあり/なしで比較し、行動・保存state・canonical/M_Bが同じであることを確認する。
既存L14B/L14A/L13を含む全体の保存replayも回帰する。

Phase 1で停止する。新センサー取得、実Worldでの接近・回避、慣性・待機閾値・旋回/移動の配分、
受付済みframeへのbinding、身体操作の再送・他個体権限はレビュー後の別変更。
局所極小・袋小路・対称停滞・経路到達・L14Bの南西偏りの改善を保証しない。
