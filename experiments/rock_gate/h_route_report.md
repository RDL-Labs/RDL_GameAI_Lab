# Hによる経路継続・再確認・変更：3日動作試験

2026-10-26。[現行設計](../../docs/design/LW_Whole_Route_MB.md#2026-10-26更新hによる継続再確認変更)。前回の経路全体MB3日試験と入力JSONの完全一致を確認。狭い入口・初日見回し・有限備蓄12食・seed20261005を維持。

## 結果

3日正常完走、Julia呼出203.33秒、ピークRSS1.389GB。コンパイル込みで、短い検査を一部並行実行したため厳密な速度比較ではない。全員全日末reserve>0、入口通過は各1回外出・再入場0。動作確認であり、帰還性能改善を示さない。

| 個体 | 最終reserve | 経路試行 | 継続選択 | 再確認選択 | 変更選択 | 再対応 | 終端未解決 | 途中中断 | 目的達成 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 90.56 | 4 | 0 | 1 | 4 | 0 | 1 | 3 | 0 |
| B | 90.45 | 45 | 1 | 69 | 45 | 5 | 3 | 42 | 0 |
| C | 90.59 | 38 | 1 | 40 | 38 | 2 | 6 | 32 | 0 |

計87試行、継続2・再確認110・変更87。ここで継続選択は開始動作を除く。再対応7回は保持中の実行済み辺の予測終点に類似した観測が得られ、仮にカーソルを進めたもの。場所の正しさを確認した成功ではない。

直近詳細保持上限64件に対し各個体の総試行数が64未満なので、終了イベントは全件残っている。Bの3動作home経路で2手まで進んだ例があるが、最終的にH選択で中断した。

**87試行の終了時Hのうち77試行が上限32。** 低Hで継続しやすくする性質は単体検査で確認したが、実環境では経路を使う時点ですでに親目的の未解決圧が高い。今回の設計通り再確認・変更に重みが移り、長い継続や目的解決には結びついていない。Hの蓄積・飽和、目的と下位の経路評価の関係は今後の検討点。

不確実性の理由別回数は、観測なし15、対応なし62、実行候補なし20、認識不一致10、終端未解決の再評価21。これらは同じ試行・状態を複数tickで数えるため、終了試行数とは一致しない。旧版のlostは即終了だったが、新版では保持して再確認するため、lostが0になったことを認識性能の改善とは解釈しない。

## 検証と証拠

経路/チャンク71、認識27、地図/睡眠46、実配置69の計213項目PASS。追加検査は低Hの継続確率、高Hでの再確認/変更増加、変更候補を20倍にしても票数だけで群確率が増えないこと、観測途切れからの仮の再対応、同じ動作の盲目的な再実行防止、休息での保持、歩行成功では親Hが下がらないことを確認。

追加監査で入力一致、開始/終了数整合、非成功報酬ゼロ、群確率合計1、地図容量を確認。[集計](evidence/h-route-three-day/comparison-summary.json)、[経路詳細](evidence/h-route-three-day/route-audit.json)、[地図監査](evidence/h-route-three-day/map-audit.json)、[manifest](evidence/h-route-three-day/manifest.json)。実行時の未コミットソースはmanifestで識別する。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_route_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/h-route-3d-20261026 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on --home-observation on --camp-provisions 4
```
