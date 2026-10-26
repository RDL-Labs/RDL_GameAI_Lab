# 未達・中断からも見積もりを学ぶ：実装確認

2026-10-26。[設計](../../docs/design/LW_Parent_MB_Estimation.md)。未達は右打切り観測として、到着時間と区別して学習する。進行中の同じ試行は1件を更新し、達成時にその記録を置換する。初期値は時間について1件の擬似観測として、直近最大128試行の経験と組み合わせる。現在の試行の見積もりは固定。

## 3日回帰確認

直前の親MB3日試験と入力JSON完全一致。3日正常完走、213.22秒、ピークRSS約1.42GB。コンパイル込みで検査を一部並行。全員全日末reserve>0。最終reserveはA88.91/B90.48/C90.56。外出は各1、外からの再入場は全員0、経路目的達成も0。帰還性能改善は示していない。

| 個体 | 達成記録 | 未達更新回数 | 最後に残った未達試行数 | 未達の実行操作数 | 現試行の固定上限 | 次回用の暫定上限 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 12 | 65 | 1 | 5632 | 256 | 7040 |
| B | 7 | 23 | 1 | 5690 | 128 | 7113 |
| C | 7 | 66 | 1 | 5419 | 256 | 6774 |

未達更新154回を154件の独立経験にはしていない。終了時に残る観測は達成26件と未達3件。未達から予測を更新しても成功数・報酬は増えない。

上表の「次回」は、終了状態を読み込み、現行の `mb_parent_estimate!` を呼んで計算した値。次回試行を実際に完走した結果ではない。未観測の末尾が残るため平均予測は下限、暫定上限は既知の下限より25%先などの仮定を含む。到着時間7040を観測したわけではない。

A/Cの帰還探索は実経験1件なので初期値の重みは1/2。Bは短い達成1件と未達1件から1/3。繰り返し長い未達を記録しても、初期値の重みを不当に薄めない。時間初期値の影響は独立した経験数とともに薄れる。消費予測には未達中の実消費も反映した。

## 検査

打切り/親/経路/見積もり169、認識27、地図/睡眠46、実配置69の計311項目PASS。5000操作未達を到着と偽らないこと、同一試行の水増し防止、後の達成への置換、20回の64操作達成後に初期重み1/21となること、短い経験を追加すると予測を短くし直せること、保持上限128、未達の高消費、休止の証拠、現試行の見積もり不変を検査した。追加監査で入力一致・証拠IDの一意性・モデル件数・確率/地図/経路整合を確認。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_censored_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/censored-mb-3d-20261026 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on --home-observation on --camp-provisions 4
```

[集計](evidence/censored-mb-three-day/comparison-summary.json)、[経験モデル](evidence/censored-mb-three-day/parent-audit.json)、[固定見積もりと次回予測](evidence/censored-mb-three-day/next-estimates.json)、[manifest](evidence/censored-mb-three-day/manifest.json)。実行時の未コミットソースはmanifestで識別する。
