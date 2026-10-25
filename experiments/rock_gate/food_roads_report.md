# 拠点と3つの食料地点をつなぐ分岐道

2026-10-25。World配置の追加。個体の観測・判断・学習コードは変更しない。

## 配置

狭い入口の拠点 `(0,6)` から南へ幹道を延ばし、`(0,-4)` で左・中央・右へ分岐する。各枝は次の食料地点に到達する。

| 枝 | 終点 | 初期食料 |
| --- | --- | ---: |
| 左 | `(-8,-12)` | 24 |
| 中央 | `(0,-18)` | 24 |
| 右 | `(6,-12)` | 24 |

既存の散在食料をこの3地点に置き換えた有限実験。拠点内の人工道、岩壁、入口、左右の光源、外の景観は維持する。食料総量は地点72＋初期携行4＝76。食料再生設定は既存のままで、全地点の食料が永久に枯渇しないという意味ではない。

道は1単位グリッドで幅2、寿命3650日の人工道。幹道・枝を合わせて112セル（拠点内の既存舗装と重複あり）。入口では既存の岩が通行幅を制限し、舗装しても岩は消えない。グリッド舗装が岩の下と重なる部分はあり、地面観測は既存の遮蔽処理を通す。

中心線が身体半径0.2で全区間通れること、路面セルが川に入らないこと、4近傍で拠点から全終点まで連結することを検査する。道の形・終点・食料との対応はWorld作成・実験observer用。個体には通常の地面観測だけを渡し、「この道は食料へ」「こちらが拠点」という意味は付与しない。

## 実行

```powershell
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/food-roads-on-20261025 --narrow-only --days 1 --rho coarse --rho-openings on --food-roads on
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/food-roads-off-20261025 --narrow-only --days 1 --rho coarse --rho-openings on --food-roads off
julia --startup-file=no --project=. experiments/rock_gate/compare_food_roads.jl
```

`--food-roads off`でも食料を同じ3地点へ配置し、拠点外の道だけを作らない比較条件。オプション省略は既存の岩壁実験のまま。`--prepare-only`で配置・幾何検査・入力・地図出力までを実行できる。

検証は同一配置・seed 20261005の1日比較。初回外出、各地点からの採取、道の候補選択、帰還状態を記録する。入場や地面候補の選択だけで帰還成功・道の行き先理解を判定しない。

## 1日結果

| 条件 | 外出した個体 | 左/中央/右の採取数 | 消費食料 | 帰還完了 |
| --- | ---: | --- | ---: | --- |
| 外道なし | 3/3 | 0 / 0 / 8 | 6 | Cの1回 |
| 外道あり | 3/3 | 5 / 0 / 3 | 6 | 0回 |

道ありでは左右の食料が採取され、中央は未採取。全枝の終点に食料は存在するが、全てを訪問・理解したことにはならない。1seed・1日の結果では帰還改善は見られず、道だけで帰還が解けるとはいえない。外道なしでも拠点内舗装と自然な踏み跡はある。

地面経路候補の選択回数は、なしがA244/B229/C246、ありがA247/B212/C272。これは拠点内や自然な踏み跡も含む全地面候補の回数で、追加した道に意図的に従った回数ではない。実行時間は70.92 / 78.79秒（コンパイル込み、行動差あり）。

各条件で道の構造19項目・岩壁配置33項目・生活保存則7項目、比較で道以外の入力一致など9項目、計127項目PASS。判断コードは変更していない。

証拠: [比較結果](evidence/food_roads/comparison.json)、[入力](evidence/food_roads/input.json)、[配置](evidence/food_roads/layout.json)、[実験コードhash](evidence/food_roads/source_hashes.json)。各runのmanifestとreportも同じディレクトリへ保存。

![拠点と3つの食料地点をつなぐ道](evidence/food_roads/layout.png)

## 道ありで3日継続（2026-10-25）

同じ初期状態・seed 20261005から、実行日数だけ3日にして再実行。前回の1日目のdaily・day_starts・eventsが完全一致することを既存の `compare_prefix.cjs` で確認した。途中状態からの再開ではない。判断コードと道の配置は変更していない。

```powershell
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/food-roads-on-3d-20261025 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on
node experiments/rock_gate/compare_prefix.cjs outputs/food-roads-on-3d-20261025 outputs/food-roads-on-20261025
```

| 個体 | 1日末のreserve | 2日末 | 3日末 | 3日間の帰還完了 |
| --- | ---: | ---: | ---: | --- |
| A | 88.71 | 85.17 | 81.79 | 1回。その後再外出し、次の帰還は未完了 |
| B | 88.62 | 84.78 | 81.78 | 0回 |
| C | 88.85 | 85.43 | 82.75 | 0回 |

全地点で採取が発生した。累計は左5 / 中央3 / 右3、残量は19 / 21 / 21。1日目に未採取だった中央の食料は3日目に採取された（2日末まで総残量64、3日末61）。消費食料は12、最終携行3、共有倉庫0で、初期総量76を保存。3日目終了までの追加再生量は0。

Aはtick 42020に帰還目的を持って入口から内側へ入り、帰還完了を1回記録。その後tick 42257に再外出した。共有倉庫へのdepositは0であり、帰還1回を食料搬入の成功とはみなさない。B/Cは初日の外出後に入口を戻っていない。終了時は3体とも帰還目的が有効。

3日試験は正常終了。実行225.02秒（コンパイル込み、全処理は約230秒）。道構造19項目・岩壁33項目・生活保存則17項目の計69項目PASSと、1日prefix一致を確認。1seedの結果であり、道の効果や安定した往復行動の成立はまだ確認できない。

証拠: [集計](evidence/food_roads/three-day/summary.json)、[個体別結果](evidence/food_roads/three-day/report.json)、[1日prefix照合](evidence/food_roads/three-day/prefix-audit.json)、[通過イベント](evidence/food_roads/three-day/crossings.jsonl)。元出力は `outputs/food-roads-on-3d-20261025/`。

## 道ありで30日（2026-10-25）

同じ初期状態・seed・配置で30日を完走。個体の判断・移動コードは変更していない。前回3日分のdaily・day_starts・eventsは完全一致。実行1605.18秒（コンパイル込み、約26分45秒）、全体約1610秒。道構造19項目・岩壁33項目・30日の生活保存則152項目、計204項目PASS。

```powershell
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/food-roads-on-30d-20261025 --narrow-only --days 30 --rho coarse --rho-openings on --food-roads on
node experiments/rock_gate/compare_prefix.cjs outputs/food-roads-on-30d-20261025 outputs/food-roads-on-3d-20261025
node experiments/rock_gate/summarize_food_days.cjs outputs/food-roads-on-30d-20261025 outputs/food-roads-on-30d-20261025/daily-summary.json
```

**計算は正常終了したが、自立的な採食・往復の維持はできなかった。** 全員がreserve 0となり、その翌日以降は終日休息になった。これはシミュレーション内の行動停止で、プロセスのクラッシュではない。reserveは身体のエネルギー指標であり、今回の結果を死亡判定とは呼ばない。

| 個体 | 外出/入場 | 帰還完了カウンタ | 初めてreserve 0で日を終えた日 | 終日休息 |
| --- | --- | ---: | ---: | --- |
| A | 6 / 5 | 6 | 18日目 | 19〜30日目 |
| B | 3 / 2 | 0 | 10日目 | 11〜30日目 |
| C | 2 / 1 | 0 | 8日目 | 9〜30日目 |

帰還完了カウンタは `active && at_home && load==0` で増える目的単位の値であり、壁の通過回数と一対一ではない。Aの6回を「外から拠点への6往復」とは解釈しない。B/Cは壁の内側に入ることがあっても帰還目的を解決していない。

| 日末 | A reserve | B reserve | C reserve | 地上食料 |
| --- | ---: | ---: | ---: | ---: |
| 1 | 88.71 | 88.62 | 88.85 | 64 |
| 3 | 81.79 | 81.78 | 82.75 | 61 |
| 5 | 76.32 | 76.11 | 56.83 | 58 |
| 8 | 88.79 | 27.50 | 0 | 54 |
| 10 | 81.80 | 0 | 0 | 51 |
| 15 | 66.46 | 0 | 0 | 48 |
| 18 | 0 | 0 | 0 | 48 |
| 30 | 0 | 0 | 0 | 48 |

Aによる倉庫への搬入は計4、取り出しは計2、最終倉庫在庫は2。地上食料は左12 / 中央21 / 右15、合計48残った。初期総量76＋再生3＝消費29＋地上48＋倉庫2を保存し、最終携行・個人倉庫は0。drop/recoverは0であり、地上からの採取総量は初期地上72＋再生3−最終地上48＝27。

再生は3日間隔で判定し、今回の追加量は10日目開始時の3のみ。他の判定では各地点の残量が補充上限を満たしていたため追加0。食料が世界全体から枯渇した結果ではない。

道と食料があっても、帰還未解決の間に補給へ切り替えることや、拠点まで到達することが十分に機能していない可能性がある。ただしこの試験だけで、経路認識・目的優先順位・局所的な停滞のどれが主因かは分離できない。次の診断対象はB/Cの帰還未解決区間と、Aが最後の補給後にreserveを失った区間。今回は観測と集計のみで修正していない。

証拠: [日別集計](evidence/food_roads/thirty-day/summary.json)、[個体別結果](evidence/food_roads/thirty-day/report.json)、[3日prefix照合](evidence/food_roads/thirty-day/prefix-audit.json)、[通過イベント](evidence/food_roads/thirty-day/crossings.jsonl)、[manifest](evidence/food_roads/thirty-day/manifest.json)。元出力は `outputs/food-roads-on-30d-20261025/`。
