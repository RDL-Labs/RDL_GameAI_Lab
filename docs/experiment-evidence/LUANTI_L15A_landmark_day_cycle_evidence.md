# L15A — 塔の目印・帰還試行・夜間休止・3日連続World

状態: FINITE WORLD ACCEPTANCE COMPLETE / 改善の因果比較ではない。
実行日: 2026-09-28。基準 `edca0b6`。[契約](../experiment-contracts/LUANTI_L15A_landmark_day_cycle_contract.md)。

## 実行と保存

`python -m integrations.luanti.tests.run_landmark_day_cycle --output tests/fixtures/luanti_l15a_landmark_day_cycle.json.gz`

同一World、A/B/C、同一steady、3日×64秒=192秒、1.5倍。
最終runは`l14b-d2b63b634ff54b0e`。実時間128.158152秒（World終了時点、export/replay時間を除く）。
最大World step 183018µs、最大pending A=1/B=2/C=2。expired/stale/stoppedなし。
1個体768観測、合計2304観測・身体結果をHTTP往復し、保存記録をRuntimeで再生して一致を検査。
毎日Worldを作り直す試験ではない。身体・在庫の連続性と共有資源保存則を全操作で検査した。

保存: `tests/fixtures/luanti_l15a_landmark_day_cycle.json.gz`。
SHA-256: `1c82b1b7764fd53b16b387c6ec1b3872c57b7efa9d1011ca258d10b30e9b26c6`。source SHA-256と事前条件は同梱reportに保持。

## 日ごとの結果

| 個体 | 日 | 本人側の帰還結果 | 帰還中の実前進 / 実旋回 | 塔中心との水平距離（監査のみ） | 採取 |
|---|---|---|---|---|---|
| A | 1 | acquisition_incomplete | 0 / 4 | 18.001 | 0 |
| A | 2 | home_like_observed | 0 / 0 | 2.783 | 0 |
| A | 3 | home_like_observed | 0 / 0 | 9.068 | 0 |
| B | 1 | acquisition_incomplete | 0 / 4 | 20.822 | 0 |
| B | 2 | home_like_observed | 22 / 5 | 8.426 | 0 |
| B | 3 | home_like_observed | 5 / 2 | 8.523 | 0 |
| C | 1 | home_like_observed | 0 / 1 | 8.001 | 0 |
| C | 2 | home_like_observed | 0 / 0 | 3.836 | 0 |
| C | 3 | home_like_observed | 0 / 1 | 7.464 | 0 |

拠点域内（水平10以内）の本人再認は7/9個体日、取得不完了による帰還未達は2/9。
ただしA/Cの域内結果は、探索終了時点ですでに近傍にいたものを含む。
**帰還のために実際に歩いた正例はBの2日目22歩、3日目5歩**。
本人は塔のWorld座標や域内監査結果を取得していない。
7件を全て「遠方から経路を学習して帰った」と数えない。

最終版の採取は全て0、資源残量96。harvest学習の新規記録・採用も0。
拠点へ戻れることと採取成果、睡眠による改善を分ける。
1日目のA/Bは上向きfanの一部がWorld生成境界外へ達し、4回見回しても全取得が成立せず停止した。
不在・永久障害とせず取得不完了を残し、その位置で夜を迎えた。

## 夜間休止と記録整理

9個体夜×32実wait=288。各夜の位置不変をWorld readbackで検査。
夜はphase名であり、照度低下・睡眠生理は今回導入していない。
各夜16件、合計144件の本人の当日移動/旋回/採取の実結果を整理した。
A: moved29/turned19、B: moved30/turned13/blocked5、C: moved24/turned23/blocked1。
同じ経験の再計数・支持票には使わず、夜間整理からT1/M_Bを更新しない。
最初に取得した目印外観は全個体ochreで、出典を固定したまま翌日へ保持した。

今回、夜入り時点ですでに負荷proxyは全件0だった（帰還後の待機等でも回復する）。
したがって、この実機結果だけで「夜の睡眠によって疲労が回復した」とは言えない。
夜間整理なしの同条件対照も未実施で、睡眠学習の効果は主張しない。

## 試作を最終結果と区別する

1. 起動試作`l14b-9d834020f0db47a6`は新Lua moduleのinstall一覧漏れで起動失敗。修正した。
2. 1日試作`l14b-392b4f7bc3324e27`は空域未生成で初期skylineがPARTIAL、全個体目印未確定。
   専用Worldの空域を31まで生成し、欠測を完全取得へ読み替える修正はしなかった。
3. 3日試作`l14b-09d3c77bd8b346e4`はPARTIAL時waitのみで、帰還の実前進0。
   Bは3日目に12個採取・harvestモデル採用後にinvalidatedとなった。
   これは最終版の成果ではない。有限見回しと有作用記録整理を追加後、同じ条件を再実行した。
   位置や以後の行動が変わるため、12→0を単独の睡眠効果や探索能力低下へ帰属しない。

試作の原記録はローカルoutputの`day-cycle-pilot.json.gz`と`day-cycle-three-day-pilot.json.gz`に保存。
同梱fixtureは最終実装のrunだけ。改善例を選んで最終結果に差し替えていない。

## 検証と限界

専用6件＋関連58件、合計64件PASS（55.395秒）。
`PYTHONPATH=tests python -m unittest test_landmark_day_cycle test_reversal_review test_task_deadline test_terrain_steering test_movement_rest test_replay_portability test_goal_reassessment -v`
PowerShell構文検査・`git diff --check`もPASS。全体suiteは今回未実施。
初回の回帰起動は既存test間importに必要なPYTHONPATH指定不足で2件import errorとなり、
環境を揃えて上記64件を再実行した。Runtime失敗や意図的skipとして計数していない。
旧経路の実機回帰`l14b-3b5c4e060e2a4538`もPASS。
32秒の既存rest/reactivation/reassessment/reversal review経路で、
A/B/Cの距離17.414/28.071/9.828、採取0、Bの静止再観測→同じ反転要求の保留を再確認した。
既存defaultの空域・センサー・phase制御は維持する。

現在の帰還は、開始時の粗い外観記憶と現在観測に基づく初期制御。
学習した複数目印経路、見えない拠点の位置推定、睡眠による採用モデル更新は未成立。
曖昧な類似外観、欠測、blocked、身体対応不足は合成Pythonでも検査し、
実Worldで全ての失敗状態を発生させたという意味にはしない。
