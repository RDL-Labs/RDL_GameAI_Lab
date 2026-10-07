# LW 候補評価と身体試行の分離

基準 `f8c0ccd`。同じ取得packetで既存の目的・方法H・身体/energy・Sleep・経験bundle・履歴寄与を評価する。確定したrotation_then_stepは、実測旋回後の一歩を新候補の得点競争から分離する。通常観測と現在前方・身体・危険・上位phaseの再検査は継続。

baselineの見え方変化だけでは移動Hを解消しない。対応した非zero並進を局所進展として評価。食料・帰還達成の主張ではない。固定thinking delay、候補比較のための身体旋回、経路全体の固定は追加しない。

## 検証

専用7件を含む関連100テストPASS。候補更新による一歩の横取り防止、旋回だけではH非解消、前方取得不能・危険・phase変更・採取による中断、身体制限waitへの誤った成功付与防止、並進/blockedの区別を検査。既存再送・個体binding・energy・Sleep・bundle・選択履歴・地面連続性回帰も含む。全体suite/Luantiは再実行していない。

World: seed 20261005、social_base、human_scale_v1、A/B/C、600 World秒（人間換算50分）。旧版は保存済み1日runの同時間幅。新版は終了コード0、資源収支と操作重複/重なりなしaudit PASS。実処理38.65秒。

| 個体 | 旋回 旧→新 | 実移動回数 旧→新 | 最大拠点距離 World m 旧→新 |
|---|---:|---:|---:|
| A | 220→203 | 213→229 | 11.44→10.67 |
| B | 134→175 | 300→259 | 18.90→25.23 |
| C | 331→139 | 101→296 | 13.03→27.01 |

Cの旋回は減り、並進と到達範囲が増えた。一方Bの旋回は増えており、全個体の旋回抑制・効率向上を保証する結果ではない。両条件とも、この600秒内の採取は0。

長い2,400秒/1,800秒比較は未完了。途中ログをoutputsに保存。最終の1,800秒直接実行ではPythonが `Windows fatal exception: access violation` で終了し、stackは `integrations/lightweight/world.py:15 segment_hit` / `:105 <genexpr>`。原因未特定。完了結果へ含めない。したがって長時間のCの反復解消、帰還期、夜間の実World回帰は未確認。

600秒の実行:
```powershell
$env:RDL_LW_TIME_PROFILE='human_scale_v1'
python -X faulthandler -m integrations.lightweight.scaled_base_campaign --window-seconds 600 --worker
```

[比較集計](LW_movement_commitment.json)。元ログ: `outputs/scaled_base_600000000us/run.jsonl`。旧ログ: `outputs/scaled_base_17280000000us/run.jsonl`。公開集計にWorldの隠れた位置を個体入力へ追加する変更はない。
