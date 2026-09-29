# Nested local models: 30-day acceptance

2026-09-29。基準`4cac756`、同一seed20260930・3個体・30日。既存全opt-inを維持しnested-model-modeのみenabled。
旧対照はshared_access_30dログを再利用。manifestの追加mode以外を照合した。
最終runはexit 0、1920秒・23040取得で完走、実時間約240秒。

| 個体 | 旧採取/配送 | 新採取/配送 | 旧移動量 | 新移動量 | 新配送便 |
|---|---:|---:|---:|---:|---:|
| A | 16 / 16 | 37 / 37 | 772 | 1728 | 6 |
| B | 32 / 32 | 22 / 22 | 119 | 1537 | 1 |
| C | 0 / 0 | 1 / 1 | 403 | 1605 | 1 |

全体48→60採取・配送、4→8便。全員の携行量は終了時0。
共有資源の結果なのでBは減少。全個体の改善や移動効率向上を主張しない。
既存採用M_BはBで保持。新しい局所モデル運用は学習によるモデル採用とは別。

共通selectorでfood/repositionが選ばれた操作数はA219/B264/C206。
Cは従来12日目以降の並進0に対し、新runは12〜30日すべてで並進（1日7〜108単位）。
同じ地点で見回すだけの長期停止はこのrunでは解消した。ただし、歩き続けることを学習や効率向上と同一視しない。
帰還側にも同じ評価を実装したが、本runの新selectorによる実介入は食料側だけ。帰還操作は既存の有限return-repositionが担当した。

## 保存と検証

専用9件＋関連49件、計58テストPASS。局所Hの分離、defer、観測変化時の解消、候補枯渇からの提案、身体／日予算gate、優先権、ログ上限、到着と荷下ろしの分離、代替失敗コスト、Runtime再送非加算を確認。
全体suiteと実Luantiは未実行。
最初の関連テスト実行は結果未出力のexit 1。成功と数えず、最終58件を再実行した。

最初の実装run `nested_models_30d.jsonl`は60採取で完走したが、代替nodeのHコストと有荷／空荷の問いの分離前なので最終比較には使わない。
修正後の`nested_models_30d_v2.jsonl`は約111.25秒でsummaryなし、exit 1（原因未確定）。部分ログを保持し、成果として数えない。
最終`nested_models_30d_final.jsonl`を比較対象とした。各試行でseed・係数を成功するまで変更したものではない。
全ログはlocal ignored `integrations/lightweight/output/`。途中試行も上書きしていない。

実行: `python -m integrations.lightweight.timed_harvest --output integrations/lightweight/output/nested_models_30d_final.jsonl --days 30 --seed 20260930 --skyline-subrays --no-return-target --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled --return-completion-mode enabled --nested-model-mode enabled`
監査: `python -m integrations.lightweight.audit_nested_models`
保存: `tests/fixtures/lightweight_nested_models_30d.json`。対照・最終runのmanifest、summary、日別移動・切替、最終局所モデル、元ログSHA-256。
監査で完走、状態上限、実介入のphase、現在候補内操作、日16回追加操作枠を確認。
