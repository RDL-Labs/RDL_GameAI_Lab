# 共通MB探索による睡眠：3日試験

2026-10-25。[設計](../../docs/design/LW_MB_Shared_Sleep.md)。覚醒と睡眠で同じ有向グラフ探索・コスト・深さ/展開上限を使う。睡眠中に得た経路は未検証仮説として保存し、実際のH解消と区別する。

## 条件

狭い入口・分岐道、seed=20261005、身体要求ON・MB探索ON・まとまりON。直前の3日試験との入力差はmb_sleep=onのみ。このフラグは旧睡眠の局所的な実行可否による優先度補正も無効化するため、純粋な探索追加だけの比較ではない。監査でsleep_action_models=nullを確認。

## 結果

3日正常完走、実行251.91秒（約4分12秒、コンパイル込み）、ピークRSS 1,303,646,208 bytes（約1.30GB）。序盤に短い回帰検査も並行した単発測定であり、前回258.62秒との速度差を性能改善とは判定しない。

| 個体 | 睡眠レビュー | 睡眠探索 / 展開 | 仮説発見 / 選択 | 最終reserve | 帰還完了 |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 2 | 32 / 1242 | 0 / 0 | 82.84 | 0 |
| B | 3 | 48 / 136 | 0 / 0 | 83.10 | 0 |
| C | 2 | 32 / 746 | 0 / 0 | 83.04 | 0 |

睡眠探索は7レビュー・112探索・2124展開。全員で睡眠完了コールバックと共通探索が実行されたが、直近8起点・深さ4・鮮度1日相当の条件では目標までの経路は見つからなかった。覚醒の探索候補も0、成功まとまり形成・H報酬付与も0。容量削除なし。地図はA287/718、B260/650、C244/493（ノード/辺）。

全日末で全員reserve>0。食料消費12・地上64・携行/倉庫0で初期76を保存。前回の帰還A0/B1/C0に対し今回は全員0。daily・day_starts・eventsは前回と異なる。新探索からの候補が0なので、行動差を新しい経路利用の効果とはいえない。旧睡眠補正を外した影響と整合するが、この1seed・3日だけで一般的な優劣は判断しない。

**探索共通化の稼働は確認、実環境での仮説形成・再利用・行動改善は未確認。** 起点の選択、観測署名の接続、経路深さ、目標記憶の鮮度を分離して診断する必要がある。睡眠による報酬の遡及配分、多階層ρ、成功痕跡の再生は今回未実装。

## 検査と再現

既存MB33＋新規睡眠13＋まとまり24＋実配置69＝139項目PASS。追加監査で入力差、旧優先度モデル無効化、全個体の睡眠探索実施、探索上限、グラフ整合、食料収支を確認。単体では仮説発見と覚醒での再利用、覚醒探索との同一評価、睡眠による架空報酬なしを確認した。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_sleep_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/mb-sleep-3d-20261025 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on
node experiments/rock_gate/audit_mb_map.cjs outputs/mb-sleep-3d-20261025 outputs/mb-sleep-3d-20261025/map-audit.json
node experiments/rock_gate/summarize_food_days.cjs outputs/mb-sleep-3d-20261025 outputs/mb-sleep-3d-20261025/daily-summary.json
node experiments/rock_gate/audit_mb_sleep.cjs outputs/mb-sleep-3d-20261025 outputs/mb-chunks-3d-20261025
```

証拠：[睡眠監査](evidence/mb-sleep-three-day/sleep-audit.json)、[地図監査](evidence/mb-sleep-three-day/map-audit.json)、[日別集計](evidence/mb-sleep-three-day/summary.json)、[manifest](evidence/mb-sleep-three-day/manifest.json)、[provenance](evidence/mb-sleep-three-day/provenance.json)。provenanceのコミットは開始時の親で、実行ソースはmanifestのhashで識別する。
