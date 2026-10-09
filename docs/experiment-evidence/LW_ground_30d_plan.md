# LW 現行踏み道の30日実行

状態: 実行準備・起動記録。30日完了のEvidenceではない。

seed 20261005 / social_base / A,B,C / human_scale_v1。30日を同じWorld・同じ個体履歴で連続実行し、持帰り3回で停止しない。形成速度、回復速度、資源再生、身体・認知条件は既存設定を保持。

形成は1mセルの実通過距離を累積、wear=10で抵抗低減が最大。未使用1日後からwearを1日2ずつ回復。現在の道観測・連続帯候補・energy寄与を有効にする。

実験者用の日別ground snapshotと地図を追加。記録追加によって個体入力や選択へ新情報を渡さない。日別JSONの行動数・地面候補選択数は開始からの累計。最終auditで資源収支・身体操作の重複/重なりも検査する。

出力先: `outputs/ground_30d_20261009/`
- `status.json`: running / completed / failed と終了コード
- `progress.json`: 人間換算1時間ごとの到達日数、累計行動
- `ground-day-NN.html/json`: 初期状態と各日終了境界の地図・地面履歴
- `day-NN.json`: wear>0セル、wear>=10セル、最大wear、累計候補選択など
- `run.jsonl`: 元記録、`stderr.log`: アクセス違反を含む障害記録
- `report.json`: 完了時のaudit。作られるまで成功扱いしない

実行:
```powershell
python -m integrations.lightweight.long_ground_campaign --days 30 --output outputs/ground_30d_20261009
```

親プロセスがhuman_scale_v1 / PYTHONHASHSEED=0を固定してworkerを監督する。既存出力先を上書きしない。異常終了時は失敗のまま保存し、自動で別runに置き換えない。途中の地図は再開用の個体checkpointではない。

22件の道・時刻・記録非介入試験PASS、10秒の接続smoke完了。30日分の実行時間は以前の1日約24分からの単純換算で約12時間だが、長期化による増加は未検証。
