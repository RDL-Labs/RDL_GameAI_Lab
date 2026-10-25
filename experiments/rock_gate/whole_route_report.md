# 経路全体MB：3日動作確認

2026-10-26。[設計](../../docs/design/LW_Whole_Route_MB.md)。前回の確率的認識3日試験と同じ配置・seed・初日見回し・有限備蓄。今回の変更は経路全体の実行状態と結果評価。

3日正常完走、Julia呼出177.26秒（コンパイル込み、短い検査の並行実行あり）、ピークRSS約1.40GB。全個体の最終reserveはA90.36 / B90.53 / C90.05。入口通過は各1回外出・再入場0回。帰還性能改善の証拠ではない。

| 個体 | 経路試行開始 | 終端未解決 | 観測・記憶喪失 | 実行不能 | 認識矛盾 | 別行動へ中断 | 目的達成 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 6 | 2 | 1 | 1 | 0 | 2 | 0 |
| B | 34 | 4 | 15 | 3 | 4 | 8 | 0 |
| C | 5 | 2 | 2 | 1 | 0 | 0 | 0 |

計45試行、未決の実行状態0。全員の記録件数が詳細保持上限64未満なので、この試験の経路イベントは全件保存されている。Bは睡眠由来の食料2動作経路を2手実行し、その後も目的未解決だったため経路全体を未解決として記録。Aは覚醒探索由来の3動作経路を2手進めた後、観測/対応の喪失で終了。いずれも次状態の一致確認0であり、仮の進行である。

この段階で確認できたのは、経路の途中を毎回拾い直さずカーソルで進み、動作実行と目的達成を分けて評価すること。実環境での成功・帰還安定化は未確認。既存候補との確率的競合で途中中断も起こる。

検査は経路/チャンク55、認識27、地図/睡眠46、実配置69の計197項目PASS。加えて経路開始数と終了数の整合、イベントの実行手数、非成功時の報酬ゼロ、地図容量を監査。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_route_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/whole-route-3d-20261026 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on --home-observation on --camp-provisions 4
```

[経路結果](evidence/whole-route-three-day/route-audit.json)、[地図監査](evidence/whole-route-three-day/map-audit.json)、[個体結果](evidence/whole-route-three-day/report.json)、[実行ソースmanifest](evidence/whole-route-three-day/manifest.json)。開始時の親コミットと実行ソースはprovenance/manifestで区別する。

参考として直前30日試験は3991.25秒、ピークRSS2.98GB。A/Cは最終reserve85.49/79.40、Bは26日目に0。再入場A11/B2/C10。Cの旧2動作チャンクは部分動作を974回使用したが、形成時の成功1回のみだった。この旧回数は新しい「経路試行開始」と定義が異なるため増減を直接比較しない。[旧30日個体結果](evidence/whole-route-three-day/previous-thirty-day-report.json)。
