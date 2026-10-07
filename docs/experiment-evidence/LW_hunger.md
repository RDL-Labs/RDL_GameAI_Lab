# 80％空腹起動と局所M_B/Hの30日試験

2026-10-07、基準 `38110ee`、seed 20261004、個人所持の共有拠点初期配置。
`personal_food=True,hunger_enabled=True`。再実行:
`python -m integrations.lightweight.personal_food_campaign --hunger`。
[設定と集計](LW_hunger.json)。

reserve>80では空腹寄与0、80で0.05、0まで線形に1へ増加。
局所goal_differenceを利用し「5秒後にreserve>80」をFとする。
期日後の本人観測で比較し、未達E=1をHへ蓄積、達成でH=0。
θ=2。観測の頻度を増やしても同じ窓では加算しない。
時間飛びでは未観測窓の失敗を補完しない。canonical E/H/T1の登録ではない。

既に成立しているeat/request候補について
food_score=0.2+空腹強度+min(1,H/θ) と既存活動score=0.5を比較する。
80％で即命令する方式ではなく、軽い空腹でも解消されなければ寄与が残る。
危険・身体・期限・受信応答・帰還・Sleepの優先は維持。
未実行requestのpendingは作らない。食料候補が無いときは既存探索へ任せる。
探索全候補への空腹場の合成や救助候補生成は今回未実装。
各M_Bが身体実行不能を解除する権限を得るわけではない。

| 結果 | 以前の個人所持 | 空腹寄与あり |
|---|---:|---:|
| 採取 | 67 | 100 |
| 食事 | 69 | 99 |
| 最終reserve A | 0 | 96.72 |
| 最終reserve B | 80.47 | 85.22 |
| 最終reserve C | 82.93 | 65.81 |

以前の値は保存済みLW_personal_food.json。30日完走、全4608操作で食料保存、
重複・身体操作重なりなし。最終携行A2/B3/C0、共有在庫0。
単一seedの複合軌跡差であり、最適化や普遍的改善の証拠ではない。

初回運転で、食事見送りが旧return_unload_attemptへ戻り、
個人在庫から旧共有帰還処理が引き落とす不具合を検出。
個人モードでは見送り後もsocial_base_waitへ変換して旧unloadを実行しないよう修正。
修正後の30日再実行を上表に記録。関連24テストPASS（新規3件）。
全体suite・Luantiは未実行。生ログ outputs/hunger/enabled.jsonl。
