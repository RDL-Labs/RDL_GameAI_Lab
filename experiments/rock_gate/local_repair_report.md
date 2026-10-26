# 局所修正を保持する経路MB：3日確認

2026-10-26。[設計](../../docs/design/LW_Local_Route_Repair.md)。

同じ目的での回避・見回しなどは選択中の経路、カーソル、固定見積もりを保持する。修正の操作・消費は実績に加え、見積もり残差によるHを通じて全体変更・破棄の候補を選ぶ。目的変更は別途中断可能。現在の辺の両端だけを照合し、曖昧なら進捗を作らない。再接続は暫定認識であり、元の経路の検証成功や報酬には数えない。

## 同じ狭い入口・3日

直前の censored-mb-3d-20261026 と入力JSON完全一致。3日完走、189.90秒（コンパイル込み）、ピークRSS1.28GB。全員全日末reserve>0。

| 個体 | 最終reserve | 外出 / 再入場 | 局所修正 | 暫定再接続 | 経路開始 | H破棄 | その他中断 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 89.29 | 1 / 0 | 205 | 79 | 30 | 30 | 0 |
| B | 91.27 | 1 / 0 | 1397 | 222 | 237 | 134 | 102 |
| C | 90.60 | 1 / 0 | 0 | 0 | 0 | 0 | 0 |

Bは1経路保持したまま終了。局所修正1602回、暫定再接続301回を記録。経路目的達成は0であり、帰還性能改善はまだ示していない。Cは経路選択自体が0なので、この個体で局所修正の有効性は評価できない。

## 検査

局所修正を含む親/経路/見積もり188、認識27、地図/睡眠46、実配置69の計330項目PASS。経路と見積もり不変、両端再接続、曖昧な観測で進めないこと、余分な修正の残差、明示的破棄、親目的変更、開始前からあるHと経路自身の残差の区別を確認。追加監査で確率・終了件数・保持上限・親学習・地図整合を確認。

検査スクリプト: experiments/julia_migration/lw_integrated/mb_local_repair_checks.jl

3日実行は experiments/rock_gate/run.jl に --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on --home-observation on --camp-provisions 4 を指定。

[経路監査](evidence/local-repair-three-day/route-audit.json)、[生存と出入口](evidence/local-repair-three-day/report.json)、[manifest](evidence/local-repair-three-day/manifest.json)。実行時の未コミット実装はmanifestのソースハッシュで識別する。
