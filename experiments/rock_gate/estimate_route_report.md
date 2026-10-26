# 見積もり残差でHを更新：3日動作試験

2026-10-26。[設計追記](../../docs/design/LW_Whole_Route_MB.md)。前回H経路試験と入力JSONの完全一致を確認。地形・seed・初日見回し・有限備蓄・3日間を維持し、経路の固定見積もりに対する逸脱が増えた分だけHへ反映する。

## 結果

3日正常完走。Julia呼出197.81秒（コンパイル込み）、ピークRSS約1.42GB。全員全日末reserve>0。

| 個体 | 最終reserve | 外出 / 再入場 | 経路試行 | 継続 / 再確認 / 変更 | 見積評価 | 見積内・未達成 | H加算要求量 | 経路の目的達成 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 90.34 | 1 / 0 | 10 | 1 / 11 / 10 | 22 | 20 | 2 | 0 |
| B | 90.95 | 2 / 1 | 65 | 3 / 94 / 65 | 162 | 118 | 38 | 0 |
| C | 90.51 | 1 / 0 | 17 | 1 / 24 / 17 | 42 | 31 | 11 | 0 |

226評価中169回は見積もりの逸脱0で、未到着でもHを増やさなかった。H加算要求量は合計51で、経路外の評価・H上限・フェーズ境界の評価保留を含む実際のH増分とは区別する。単体検査では、見積内の実行で実際の親Hが保持され、報酬や失敗罰を付けないことを確認した。

経路92試行、未解決終了10・中断82・目的達成0。再確認129回、継続5回（初回動作を除く）、仮の位置再対応3回。前版の継続2回より多いが、短期単一seedの分岐差であり改善の根拠には不十分。Bの再入場1回も経路MBの成功とは結び付いていない。

**経路開始前からの高Hは残る。** 終了イベントはA10/B64/C17の91件保存され（Bの最初の1件は保持上限で落ちる）、そのうち81件がH32。経路外の通常探索は従来評価のままで、既に蓄積したHを経路選択だけでリセットしないため、見積内を進んでも高い変更圧を持つことがある。

Bの食料2動作経路の例では、見積もりが移動2＋取得1の計3操作。実績10操作に達し、1操作の余裕を超える差6をH加算要求として記録した。対してCの2動作経路を2操作で進んだ例では逸脱0・加算0である。どちらも場所の確認や食料取得の成功を示すものではない。

## 検証

経路/見積もり92、H報酬43、確率選択116、認識27、地図/睡眠46、実配置69、計393項目PASS。既存選択の既定動作を維持し、見積もり内のH維持、遅延・消費超過・矛盾、重複評価、固定見積もり、休息除外、ゼロHでの実際の目的達成を確認した。追加監査で入力一致、開始/終了整合、非成功報酬ゼロ、確率・容量・逸脱量の整合を確認。

最初の試験はゼロH達成時の終了条件修正のため中断。集計には修正後に最初から実行した `estimate-route-3d-20261026-final` のみを使用。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_estimate_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/estimate-route-3d-20261026-final --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on --home-observation on --camp-provisions 4
```

[集計](evidence/estimate-route-three-day/comparison-summary.json)、[見積もり・実行結果](evidence/estimate-route-three-day/route-audit.json)、[地図監査](evidence/estimate-route-three-day/map-audit.json)、[実行ソースmanifest](evidence/estimate-route-three-day/manifest.json)。実行時の未コミットソースはmanifestで識別する。
