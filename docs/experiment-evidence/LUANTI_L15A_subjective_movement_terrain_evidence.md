# L15A Phase 1 — 主観的移動地形の純粋計算

状態: Phase 1 ACCEPTANCE COMPLETE。専用20テスト・全体回帰PASS。2026-09-28。基準 `52b09d5c`。
[実装契約](../experiment-contracts/LUANTI_L15A_subjective_movement_terrain_contract.md)・
[ユーザーの計画と構想図](../design/RDL_GameAI_Luanti_Subjective_Movement_Terrain_Plan.md)。

## 実装した範囲

新規 `runtime/subjective_movement_terrain.py` の `calculate_terrain(observation)` を明示的に呼ぶ。
現在の身体相対観測を受け取り、−90/−45/0/+45/+90度の5方向の高さと全同点最小方向を返す。
各方向についてphysical/food/obstacle/totalと全source寄与を保存する。
ref・入力配列順は数値や最低方向を決めない。原観測の出典は失わない。

式は次の固定profile。詳細な入力条件と係数の意味は契約を正とする。

```text
Food:       mean(-4 × max(0, 1 - 評価点とFoodの距離/12))
Obstacle:   min(12, sum(6 × max(0, 1 - 候補線分と障害物点の距離/6)^2))
Physical:   2 × abs(取得した高さ差)   [高さ差1 node以内]
Total:      Physical + Food + Obstacle
```

対象は前方半円・12 node以内、Food最大5、障害物最大8、地表5方向。
障害物は点の近接コストであり、大きさや身体との衝突真値を再現したものではない。
近い点を仮の一歩でまたぐと反作用が小さくなる問題を避けるため、障害物だけは評価点でなく閉線分との距離を使う。
連続面の微分・行動選択・慣性・身体移動・到着判定はまだ扱わない。

## 合成入力による計算例

[全入力と全出力のJSON](LUANTI_L15A_phase1_examples.json)を保存した。以下の数値は表示だけ小数4桁に丸める。
座標は `(forward,right)`、角度の正は身体の右。地表は完全取得した高さ差0。
**ここに示すものは合成入力であり、実Luantiの取得・作用記録ではない。**

| 入力 | −90° | −45° | 0° | +45° | +90° | 最低方向 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| single_food | -2.3003 | -2.5498 | -2.6667 | -2.5498 | -2.3003 | [0] |
| left_food | -2.0563 | -2.1965 | -2.1144 | -1.8764 | -1.6430 | [-45] |
| right_food | -1.6430 | -1.8764 | -2.1144 | -2.1965 | -2.0563 | [45] |
| two_food | -2.0995 | -2.2664 | -2.3333 | -2.2664 | -2.0995 | [0] |
| far_obstacle | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | [-90, -45, 0, 45, 90] |
| near_obstacle | 2.6667 | 3.4147 | 4.1667 | 3.4147 | 2.6667 | [-90, 90] |
| food_front_obstacle | 0.3663 | 0.8649 | 1.5000 | 0.8649 | 0.3663 | [-90, 90] |
| food_left_obstacle | 0.3663 | 1.0918 | 0.8382 | -0.0424 | 0.0609 | [45] |
| food_right_obstacle | 0.0609 | -0.0424 | 0.8382 | 1.0918 | 0.3663 | [-45] |
| partial_food | null | null | null | null | null | None |

1. 単一Food(5,0)は正面0度を最低にする。
2. Food(5,−4)/(5,+4)で数値面と最低方向が左右反転する。
3. Food(4,−4)と(4,+4)は単独なら各−45/+45度、合成すると0度が最低となる。最寄り1個を選んだ結果ではない。
4. Food(5,0)と正面障害物(2,0)の合成では−90/+90度が同点。右側だけを勝者にしない。
5. 同じFoodに左障害物(2,−1)なら最低は+45度、右障害物(2,+1)なら−45度。固定右折では説明できない。
6. partial Foodでは全physical/food/obstacle/totalがnull、最低方向もnull。残ったFoodを使って完全な地形とはしない。

前方障害物を身体から12/7/6/3/1.5/1/0.5/0 nodeへ近づけたとき、0度方向の反作用は
`0 / 0 / 0.1667 / 2.6667 / 5.0417 / 6 / 6 / 6`。
遠方で0、近づくほど増大し、候補線分上では有限の最大値を保つ。
8個の障害物が足元にあればraw合計48を保存しつつ、合成項は12へ制限する。

## 欠落と操作不能の区別

不完全取得は全体 `acquisition_incomplete`、数値寄与を作らない。
完全取得の空の場は5方向とも0で、全方向を同点として残す。
完全取得で特定方向がblocked/no_surface/高さ差超過なら、その方向だけphysical/total=null。
全方向が対象外なら `no_supported_direction`、最低方向[]。取得不足によるnullとは区別する。
それをwaitへ変換する行動権限はPhase 1に存在しない。

個体・run・epoch・時計・観測ID・取得時刻・pose ref・body revisionの混線、
上限超過、重複ref、NaN/Infinity/bool、不明profile、World座標等の余分な入力は明示拒否した。
これは宣言されたsourceの整合性検査で、実SensorFrameの受付や座標変換の検証ではない。

## 検査と非介入

専用20テストで、上の例、反作用の単調性、地表コスト、上限、全同点、入力順不変、ref改名、
partial/unavailable/output_limited、複数不足理由、文脈混線、不正入力を検査した。
繰り返し計算で同じ結果、入力不変、出力を変更しても入力や他の出力が変わらないこと、有限JSON化も確認した。

既存L14AとL14Bの固定12 packetを、計算呼出しあり/なしで比較した。
既存行動、観測・結果・所持品を含む保存state、L14Bの採用M_Bとcanonical記録が一致した。
新schemaを既存FiniteExplorationへ設定すると拒否されることも検査した。
calculatorは既存exploration/HTTP/World/canonicalへimportやhookを追加せず、標準ライブラリだけを使用する。

全体回帰は **846件実行 = 795 PASS + 51 intentional skip**、476.584秒。
その後、巨大な整数の境界拒否と非介入対照の検査を補強し、専用20テストを再実行してPASSした。
既存探索を含む回帰本体への変更はない。合成入出力10例も最終calculatorで再計算して完全一致した。

```powershell
python -m unittest discover -s tests -p test_subjective_movement_terrain.py -v
python -m unittest discover -s tests -v
```

ローカルログ: `integrations/luanti/output/l15a-phase1-tests.log`、`l15a-phase1-full-tests.log`。
今回Luanti本体やHTTP/身体の実機試験は起動していない。全体回帰中のOBS/L13/L14等の確認は保存記録の再生。
ユーザー提供画像3枚は元ファイルとSHA-256が一致し、改変していない。

## 変更ファイルと停止点

- `runtime/subjective_movement_terrain.py`: 純粋計算、固定profile、厳密な入力検査、成分別出典。
- `tests/test_subjective_movement_terrain.py`: 専用20テスト。
- Phase 1契約・本Evidence・合成入出力JSON: 式、上限、欠測、実装と構想の区別。
- 計画書・`L15A_concept_*.png`: ユーザー提供の計画と図を保存。画像は変更せずコピー。
- README、文書一覧、roadmap: Phase 1到達点への参照。

**Phase 1で停止する。** 実Worldの接近・回避、新しい観測adapter、配送・操作ID台帳、個体間の作用権限、
L14Bへの接続、M_B由来の重み付けは未実装。これらの受入PASSは今回主張しない。
特に、対称な最低方向を残せたことから、袋小路を脱出できる・南西への集中を解消できるとは言えない。
