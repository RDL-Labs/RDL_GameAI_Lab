# Nested model: bounded zero-harvest seed search

2026-09-29、実装基準 d12fe0f。runtime・係数変更なし。効率ではなく0採取と停止の切り分け。

事前に配置seed20261001〜20261006を固定し、各3個体・10日実行。0採取が出た唯一の条件20261002を同設定で初日から30日再実行。Python 3.11、7runすべてexit 0。Luanti実機・全体unit suiteは今回未実行。
controller seed20260928、閾値2、left、資源8地点×12共用。skyline-subrays、goal-difference、food-goal、orientation、reposition、return-completion、nested-model有効。return回数による終了なし。配置以外のmanifest一致を監査（日数延長のみ除外）。

|seed|10日 A採取|B採取|C採取|
|---|---:|---:|---:|
|20261001|12|12|24|
|20261002|17|31|0|
|20261003|43|17|24|
|20261004|11|57|28|
|20261005|21|26|23|
|20261006|22|15|35|

18個体run中1件が0。全員0の配置は今回見つからなかった。全180個体日で実並進あり。

## 20261002を30日追跡

A17、B31、C12単位、すべて配送済み。Cは16日目まで0、17日目11単位、23日目1単位。毎日実並進あり、実移動合計1789、訪問2m区画239。10日時点は552、112区画。
Cは5/9/15/26/27/28/30日目に新規区画0。動きながら既訪問範囲を反復する日はあるが、永続停止とは判定できない。26〜28日は新規区画0が連続し、29日は7区画増えた。
0採取だけから停滞・バグとは判定しない。毎日の移動も目的進展やループ不在の証明ではない。今回の探索はこの6seedと1延長で終了し、0が出るまで無制限に探していない。

## 監査・保存

`integrations/lightweight/audit_zero_search.py` は完走、設定一致、実結果forward、日別採取/移動、待機理由を検査・集計。2m区画はWorld身体位置による実験者専用分析で、個体へ渡さない。非並進の連続完了数には夜間・帰還後待機も含み、停滞時間とは呼ばない。

集計とraw SHA-256: `tests/fixtures/lightweight_zero_seed_screen.json`。
ignored raw: `integrations/lightweight/output/zero_search_<seed>_10d.jsonl` および `zero_search_20261002_30d.jsonl`。

再実行: `py -3.11 -m integrations.lightweight.timed_harvest --output <path> --days <10 or 30> --seed <seed> --skyline-subrays --no-return-target --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled --return-completion-mode enabled --nested-model-mode enabled`

監査: `py -3.11 -m integrations.lightweight.audit_zero_search <output.json> <raw.jsonl> ...`
