# Successful landmark food revisit — evidence

2026-09-29。基準754f95dからの修正。日替わりに成功した方法を候補から落としていた点へ、有限な成功目印記憶を接続。

## 実行

`py -3.11 -m integrations.lightweight.compare_food_revisit --run`

最終コードで自然配置seed20261001をdisabled/enabled各5日、単純目印fixtureをenabled4日実行。すべて軽量World実行・exit 0。今回Luanti実機ではない。
3個体、資源は全runで明示的に無限、早期終了なし。他の統合モードは両群同一。自然配置の比較manifestはfood_revisit_mode以外一致。単純配置は塔1本と茶色の目印1本、資源1地点。配置座標はWorld/harnessだけが保持し、比較器に渡さない。

|条件|採取|配送|最終携行|再訪操作|再訪試行から実取得|
|---|---:|---:|---:|---:|---:|
|自然・disabled・5日|260|260|0|0|—|
|自然・enabled・5日|268|229|39|51|0|
|単純目印・enabled・4日|294|294|0|56|4|

自然配置のenabledでは10個体日に再訪を最初の方法として選択。7試行は目印が曖昧で比較不能、3試行は再取得できず不成立となり探索へ戻った。採取の8増加を効率改善とは呼ばない。配送は31減り携行39が残った。日ごとの帰還未達も許容しており、改善のみを選んだ評価ではない。

単純配置ではBの2日目、Aの3/4日目、Cの4日目が、それぞれ再訪操作10回の後に実pickupを取得し、同日配送も成立した。同じ資源1地点しかないWorld条件での再訪・採取・帰還であり、個体がWorld資源IDを認識したという意味ではない。失敗4試行も保存。

## 範囲と限界

成功した方法を日替わりで消さず、現在観測で再試行する接続は成立。任意の自然配置で同じ場所へ安定往復する能力の完成ではない。自然配置では粗い色と方位の対応が不足している。記憶自体が無い場合・帰還できない場合は再訪が起動しない。
過去の採取relationのcanonical M_B採用とは別のepisodic route hypothesis。大目的の食料確保のもとでの有限な下位方法。

## 検証と保存

専用11テスト＋nested/local-return/timed-harvest/reposition回帰27 = 38 PASS。日越し保持、成功条件、再送、入力不変、別個体拒否、上限、比較不能、失敗一回計数、閾値、現在Food/夜/足元の優先を検査。
全体unit suiteとLuantiは今回再実行していない。

`compare_food_revisit.audit`で完走、無限在庫維持、記憶の本人実pickup出典、目印の本人観測出典、48操作上限、8記録上限、再訪phase、比較manifest一致、翌日の実再訪取得を検査。
保存集計 `tests/fixtures/lightweight_food_revisit.json` はmanifest、summary、個体日ごとの方法、比較結果、配送、raw SHA-256を含む。
最終rawはignored `integrations/lightweight/output/revisit_final_*.jsonl`。
開発途中の`food_revisit_*_5d.jsonl`/`food_revisit_simple_4d.jsonl`も保存しているが、上表は最終3runだけ。
