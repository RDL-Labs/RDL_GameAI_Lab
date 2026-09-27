# Luanti L10B — 複数個体の学習による行動差 Evidence

状態: PASS / 2026-09-27。基準commit `520f82fb`に本差分を適用。
[契約](../experiment-contracts/LUANTI_L10B_multi_agent_learning_contract.md)。
実Luanti 5.17.0・実Runtime HTTPで、3独立run × A/B × 12 Episode = **72 Episode、216 SensorFrame**を検証した。

## 実World結果

各個体で観測色条件ごとに形成3件＋別Episode検査1件を使用し、2 relationをT1経由で再構成した。
以下はEpisode 9〜12の実際の決定と身体結果。通常対応は赤で通路遮断、灰で通路開放。
逆対応は反対。11〜12ではこのWorld条件を反転する。

| run / 個体 | active切替 | 評価4 Episodeの選択 | 全12中の試行 / deposit |
| --- | --- | --- | --- |
| opposite / A | あり | 保留・試行・保留・試行 | 10 / 5 |
| opposite / B | あり | 試行・保留・試行・保留 | 10 / 5 |
| a_only / A | あり | 保留・試行・保留・試行 | 10 / 5 |
| a_only / B | なし | 試行・試行・試行・試行 | 12 / 6 |
| b_only / A | なし | 試行・試行・試行・試行 | 12 / 6 |
| b_only / B | あり | 保留・試行・保留・試行 | 10 / 5 |

採用前は全個体がunknownから有限試行する。採用後だけ本人のM_Bの予測値と出典Candidateが現れる。
片方だけ採用する対照では他方の予測はunknownを保ち、行動も未学習時の試行を続けた。
oppositeでは同じ色名への行動がA/Bで逆転し、固定規則へ色名の正解を埋め込んでいないことを確認した。

試行は実壁nodeによる接近停止、実Food entityの取得・除去、帰還、本人のBase stock増加まで検査する。
保留では身体作用0回・開始位置維持・取得結果null・Experienceなし。
canaryでは学習済み成功予測に実失敗が来た場合だけ、同じM_BによるF/F'差-1を確認した。
保留が新しい成功機会を見逃すため、今回の結果は成功率や効率の改善を一律に主張するものではない。

## 分離・並走

- 各runでA/Bそれぞれ36frame（近景12・遠景12・聴覚12）。合計72、感覚拒否0、全frame IDが一意。
- A/Bのprofile、取得時刻、姿勢参照、Experience、Candidate根拠、T1 artifact、modelが本人へ結び付く。
- Runtimeは同じローカルoperation/event/learning IDをA/Bが使用する単体試験も通る。
  他方のdecision ID付き結果や他方のassessment、frame、Experienceは拒否する。
- 実機の全72操作で自分の決定を再要求し、身体権限消費は各1回。各個体で相手の応答注入を拒否した。
- Aのlearn成功応答の受渡しを実測 **2.056253 / 2.033310 / 2.030773秒**保留した。
  それぞれの保留区間内に、Bの新規取得時刻と実身体作用時刻が存在することを検査した。
- A/BのM_B切替回数はoppositeが各1回、a_only/b_onlyは指定した片方だけ1回。
  親モデルarchiveの所有者と未切替側のM_delta継続も照合した。

同じWorld時計・HTTP serverのもとで並走するが、別採食区画を使う。相手の身体が通路を塞ぐ、
同じFoodを奪い合う、他者の結果を学習するなどの相互作用を発生させた試験ではない。

## 再現と保存記録

```powershell
& .\integrations\luanti\scripts\test-sensory-learning.ps1 -MultiScenario opposite
& .\integrations\luanti\scripts\test-sensory-learning.ps1 -MultiScenario a_only
& .\integrations\luanti\scripts\test-sensory-learning.ps1 -MultiScenario b_only
python -m unittest discover -s tests -p test_multi_sensory_food_learning.py -v
python -m unittest discover -s tests
& .\integrations\luanti\scripts\test-sensory-learning.ps1
& .\integrations\luanti\scripts\test-observation-v1.ps1 -Scenario faults
```

ignored output内の実機snapshot:

- `l10b-opposite-20260927-033957-808.snapshot.json`
- `l10b-a_only-20260927-034157-702.snapshot.json`
- `l10b-b_only-20260927-034234-184.snapshot.json`

[同梱replay](../../tests/fixtures/luanti_l10b_replay.json)は上記snapshotから、検査済みの受理frame全項目、
決定要求、結果事実、World実行記録を抽出する。元ファイル名とSHA256を保存。
`capture_multi_learning_replay`で再生成できる。
Python試験はA/Bを交互に再生し、frameを再受理して元記録と全項目一致を確認し、個体別T1と行動選択を再実行する。
独立canonical reviewの比較窓は再作成するため、元bundle/model IDの完全再現を主張しない。
再生結果の受付には再生で得たdecision IDを使い、元IDと結果事実は同梱JSONに変更せず残す。

## 検証結果と限界

- L10B専用 **12 PASS**（3実機runの再生を含む）。既存L10専用 **19 PASS**。
- 全体 **590件実行 = 539 PASS + 51 optional/opt-in skip**。
- 既存単一個体L10実機 **PASS**、12 Episode / 36frame。
- OBS-9 faults実機 **PASS**、108frame、再観測・A/B生活Acceptance成立。

単体試験では個体別16操作予算、完全再送と改変拒否、同名IDの分離、片方だけの切替、
他個体入力拒否時のstate不変、返却値の分離、両方のcutover後にも決定時M_Bで結果を評価することを確認した。
新機能の主比較は実Luanti。Godot・ブラウザー・L7実機の再実行は今回行っていない。

周期全感覚＋Probeとの常設統合、自律review/Sleep、一般Goal/Trajectory、NERV/SOC、社会学習、
共有資源競合、長期継続学習は保留。今回の到達点は**同じWorldで複数個体が自分の経験から学習し、
自分のM_Bによって異なる実行を選べる**こと。
