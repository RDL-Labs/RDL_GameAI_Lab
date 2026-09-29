# Directional routes: 30-day continuation

2026-09-29、実装1b9d762。自然seed20261001、3個体、無限資源、便数終了なし。
前回の5日比較から期間だけ30日へ延長。係数・runtime変更なし。
機能disabled/enabledを各1run、Python3.11で完走、exit 0。

## 結果

|期間|なし採取|なし配送|あり採取|あり配送|
|---|---:|---:|---:|---:|
|1–5日|260|260|234|180|
|6–10日|155|155|107|145|
|11–20日|536|536|360|376|
|21–30日|445|445|280|280|
|全30日|1396|1396|981|981|

両群とも最終携行0。区間の配送が採取より多い箇所は前区間からの携行分。序盤の未配送分は後日届けたが、後半もなし側を上回ってはいない。この1配置における長期化で改善したとは言えない。

## 支持と候補

あり側の最大支持は5日終了時A2/B1/C1、30日終了時A4/B3/C6。成功支持の蓄積自体は起きた。全個体の経路台帳が16件に到達（A9日目、B6日目、C14日目）。現仕様は満杯時に新規系列を追加せず、既存支持を更新する。この容量境界も含む結果で、単に十分な学習期間だけの比較ではない。
21–30日は経路操作が食料543/帰還156。経路なしと比べて並進774対1214、旋回1168対708。時間を延ばしただけで単純な安定往復へ収束したとは確認できない。

## 並進しない日の発生

なし側: 全90個体日に実並進あり。
あり側:
- A: 7、25〜30日目が並進0。
- B: 9〜10、24〜28日目が並進0。
- C: 9〜10日目が並進0。

Aの25〜30日目は日ごとにdirectional_route旋回21〜24回、incomplete_reposition旋回16回、acquisition_incomplete待機84〜87回。帰還枠はhome_like_observed待機95回、夜待機32回。したがって「遠くで帰れず迷子」というだけではなく、探索枠でも旋回と取得不完了待機が続いて並進しない状態。
支持強化・経路選択・位置変更の合成を次に調べる根拠となる。ここでは単一機構に原因を確定せず、runtimeを修正して結果を取り直していない。

## 監査・再実行

`py -3.11 -m integrations.lightweight.timed_harvest --output <path> --days 30 --seed 20261001 --inexhaustible --skyline-subrays --no-return-target --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled --return-completion-mode enabled --nested-model-mode enabled --directional-route-mode <disabled|enabled>`

監査: `py -3.11 -m integrations.lightweight.audit_directional_routes_30d`。
完走、両manifestのmode以外一致、無限在庫維持、経路/支持/操作上限、receipt出典を検査。両群とも最初の5日のcommand列SHA-256が前回5日runと一致。期間延長前の行動を再現した。

保存: `tests/fixtures/lightweight_directional_routes_30d.json`。日別/区間別集計、並進0日の行動理由、最終経路、rawハッシュ。
rawはignored `integrations/lightweight/output/directional_disabled_30d.jsonl` / `directional_enabled_30d.jsonl`。
今回unit全体suite、Luanti実機は未実行。軽量Worldの期間延長試験であり、複数seedの一般傾向ではない。
