# Luanti L10C — 共有FoodでのM_B学習と相互干渉 Evidence

状態: PASS / 2026-09-27。実Luanti 5.17.0 / 実Runtime HTTP。
基準commit `ac6855c3`に本差分を適用。
[契約](../experiment-contracts/LUANTI_L10C_shared_food_learning_contract.md)。

## 実装と検査の位置

`SharedFoodLearning`は既存の本人別学習・T1・モデル切替を使い、装置contextを
`l10c-shared-food-apparatus-v1`へ固定する。要求payloadからcontextを選べず、L10用relationは
この装置の予測へ適用しない。通常のcount解釈と旧modeの既定条件は維持する。

`shared_food_learning_fixture.lua`が1件の実Food entityとA/Bの身体・Baseを管理し、
`shared_food_trial.lua`が開始枠、毎枠1作用、権限消費、取得・帰還・depositを処理する。
実entityを最初に取得した際に除去するため、相手の取得試行ではFoodが存在しない。
失敗boolの書換えや、壁による失敗への置換は行わない。

## 実World結果

5独立run、各12 shared Episode。合計**60 shared Episode / A・Bの120操作 / 360受理SensorFrame**。
各run72frameは、各個体の近景12・遠景12・聴覚12。拒否0、重複保存0。
形成・独立検査は各個体6＋2経験。神経parameter、他者の経験、隠れた開始順序は予測入口へ渡していない。

| 条件 | A 試行 / deposit | B 試行 / deposit |
| --- | --- | --- |
| both_active | 10 / 6 | 10 / 6 |
| neither_active | 12 / 6 | 12 / 6 |
| a_only | 10 / 5 | 12 / 7 |
| b_only | 12 / 7 | 10 / 5 |
| reversed_cues | 10 / 6 | 10 / 6 |

全60 shared EpisodeでFood entityの除去と合計depositが各1回。2人への二重取得・二重depositはない。
試行した取得者は7身体作用、非取得者は4作用。保留は0作用・初期位置維持で、取得結果null、Experienceなし。
各個体の成功を必須にしていない。相手が取得した結果を本人の失敗票へコピーせず、本人が実際に試した場合だけ
自分の非取得結果を保存する。共有EpisodeはA/Bの記録から同じ参照で追跡できる。

Episode 9〜10では、採用した本人だけがM_Bの予測で試行／保留を変え、未採用側はunknownから試行を続けた。
反転対照では同じ色への予測が形成経験に応じて逆転した。形成支持は各relation3件、独立検査は1件のまま。

## 相手の選択が予測後の結果を変える

Episode 11〜12は、観測色を変えずに実際の開始順序を反転した。

- **両者採用:** 非取得を予測した相手が保留するため、試行者は後行でもFoodを取得した。
  開始条件変更だけで必ず予測誤差が出るという検査にはしない。
- **片方採用:** 採用側が取得を予測して試す場面では、未採用側も試行し、先に取得した。
  採用側の実非取得に対し、決定時の同じM_BによるF/F'の差`-1`を記録した。
- **両者未採用:** 反転した先行者が取得。予測はunknownなのでF/F'は比較不能。
- **保留:** 試せば取得できたという反実仮想を成功経験にせず、結果を未試行のまま残した。

片方の学習結果による選択が相手の結果へ作用することを、実身体処理で確認した。
全体の取得数は各run12のままであり、試行数が減ったことを普遍的な効率・成功率改善とは呼ばない。
2回目の再構成や相手のpolicyを条件にしたrelation更新は行っていない。

## 時計・権限・記録の検査

両決定受渡しまで身体開始を待つが、World時計は進む。開始後は250000µs枠ごと最大1作用。
各Episodeで受渡しを40ms保留する側を交互に変え、各runで両方の決定到着順を記録した。
同じWorld枠内のA/B処理順もEpisodeごとに入れ替えた。各開始許可と実処理時刻を照合し、
HTTPの到着順でFood取得者を決めないことを確認した。保留はcallback内の故障注入で、実ネットワーク障害ではない。
取得からbarrier成立までは全runで102218〜173974µsであり、契約の500000µs以内だった。

全操作で決定・結果を再要求し、身体完了後に同じ決定と相手の決定を再注入しても身体位置・Base stockは不変。
実行前にも相手の決定を拒否する。個体別台帳だけでなく、共有Foodの確保数、除去数、Base増分を照合する。
元HTTP応答文字列も保存し、Runtime決定と完全一致を確認する。Lua JSON往復のnull欠落・空配列表現の差は
表示記録の照合でのみ正規化し、元のframeと応答文字列は変更しない。

`shared_food_trial_checks.lua`の**77アサーション**を実Luanti内で実行した。
同じ試行についてA/B処理順を交換する比較、先行者が保留した際の後行取得、二重step・再入・再送、
別個体／内容変更／開始前の権限消費拒否、開始barrier期限、枠逸失、身体予算、不完全取得決定の拒否を含む。
ここでは身体・資源adapterを代替している。実Worldの主5runと、異常条件の局所試験は区別する。

## 保存記録と再現

[同梱replay](../../tests/fixtures/luanti_l10c_replay.json)は、各検査済みsnapshotのファイル名・SHA256、
受理frame、観測packet、要求・元応答・結果事実、World実行traceを保持する。
`capture_shared_learning_replay`で再生成する。再生ではframeの全項目一致と重複受理`new_frames=0`を検査し、
独立canonical reviewを再構築してT1と行動選択を再実行する。model/decision IDの完全再現は主張せず、
結果受付に再生側のdecision IDを使う。元IDと取得結果は同梱記録に残す。

```powershell
foreach ($scenario in @('both_active','neither_active','a_only','b_only','reversed_cues')) {
    & ./integrations/luanti/scripts/test-sensory-learning.ps1 -SharedScenario $scenario -TimeoutSeconds 90
}
python -m unittest discover -s tests -p test_shared_food_learning.py -v
python -m unittest discover -s tests
& ./integrations/luanti/scripts/test-sensory-learning.ps1
foreach ($scenario in @('opposite','a_only','b_only')) {
    & ./integrations/luanti/scripts/test-sensory-learning.ps1 -MultiScenario $scenario
}
& ./integrations/luanti/scripts/test-observation-v1.ps1 -Scenario faults
```

## テストと停止境界

L10C Python **16 PASS**。旧装置とのrelation非混同、固定context、他個体の入力・assessment拒否、
形成のcontext混在拒否、容量・再送・再構成上限、未完了・未試行の非経験化、取得不完了・鮮度、
切替前の決定モデル保持、CLIの明示opt-in、5実機runの再生を含む。

全体 **606件実行 = 555 PASS + 51 optional/opt-in skip**。
旧実Luanti回帰は以下のすべてがPASS:

- L10単一個体: 12 Episode / 36frame、10試行・5deposit。
- L10B: opposite / a_only / b_onlyの3run、計72個体Episode / 216frame。
  Aの応答を約2秒保留してもBの取得・身体作用が進むこと、個体別切替・分離を維持。
- OBS-9 faults: 108frame、拒否・応答消失からの回復、再観測、A/Bの生活Acceptanceを維持。

回帰snapshot（ignored output内）:

```text
l10-20260927-052142-867.snapshot.json
l10b-opposite-20260927-052155-432.snapshot.json
l10b-a_only-20260927-052210-386.snapshot.json
l10b-b_only-20260927-052225-400.snapshot.json
obs9-20260927-052240-796.snapshot.json
```

既存の遠景色を手掛かりとした本人の結果学習であり、他者の行動・意図を識別して推論する機能ではない。
身体同士の衝突、自由な競走、社会関係・所有・敵意、援助要請、神経・DNA、自律review、長期再学習は未接続。
開始barrierのある有限装置であり、OBS-9の周期全感覚＋Probe生活へ常設統合した証拠でもない。
今回の主World検証はLuanti。Godot・ブラウザーの新たな実行確認は含めない。
