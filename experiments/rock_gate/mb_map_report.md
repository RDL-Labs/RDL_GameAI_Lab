# MB観測地図のシミュレーション：1日試験

2026-10-25。身体要求の設定経路ON、狭い入口・分岐道・同一seed=20261005。新規に `mb_simulation=on` を追加。実装範囲は[設計文書](../../docs/design/LW_MB_Map_Simulation.md)。

1日を正常完走。実行92.21秒（コンパイル込み、同時に短い回帰検査も実行しており速度比較には使わない）。全員外出1回、帰還0、日末reserve A89.20/B89.03/C89.17。食料消費6、地上64、携行6、倉庫0。初期76を保存。

| 個体 | ノード | 辺 | 内部探索回数 | 展開数 | 行動提案 | 選択 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 128 | 178 | 86 | 1398 | 0 | 0 |
| B | 128 | 282 | 69 | 1409 | 0 | 0 |
| C | 128 | 217 | 79 | 1702 | 0 | 0 |

観測と実行から関係は形成されたが、探索範囲内で現在の目的までつながる経路は見つからなかった。初日の帰還経験もないため、逆経路を仮定しない本実装では帰還へ向かう材料が限られる。ただしこれだけを原因と断定しない。全員ノード上限128へ達し、削除回数A61/B41/C37。署名の分裂・古い関係の削除・最大4段の探索限界も診断対象。

終端でhomeラベルを保持したノードはA1/B1/C3、foodは全員0。ラベルは同じ署名の現在観測で更新されるため、過去に食料があった記憶を無条件に維持するものではない。類似場面を同じ署名と扱う粗さも残る。

したがって今回の1日結果は**関係の蓄積と有限内部探索の接続確認**であり、行動改善の証拠ではない。観測モデルの単体検査では2段先の目標へ向けた最初の行動提案、予測一致/不一致/unknownを確認した。

MB地図検査28、既存の身体目的21・目印34、試験内の道構造19・岩壁33・生活保存則7、計142項目PASS。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_map_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/mb-map-1d-20261025 --narrow-only --days 1 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on
```

証拠：[日別集計](evidence/mb-map-one-day/summary.json)、[個体別結果](evidence/mb-map-one-day/report.json)、[観測グラフ・探索記録](evidence/mb-map-one-day/maps.json)、[manifest](evidence/mb-map-one-day/manifest.json)。provenanceは開始時の親コミット、実行した変更済みソースはmanifestのhashで対応づける。day.jlには読み取り専用の通過記録フックがある。

## 容量10倍で3日動作試験（2026-10-25）

コミットec0c812の実装を使用。ノード1,280・辺5,120、その他は同じ狭い入口・分岐道・seed。粗ρでの地形評価は既存のまま。MB地図のρ階層化は未実装で、今回も導入していない。目的は容量拡張後の蓄積・探索・保存・資源収支の動作確認。

3日を正常完走。実行257.28秒（約4分17秒、コンパイル込み）、日末までの全体約262秒。プロセスのピークRSS 1,281,249,280 bytes（約1.28GB）。単発測定であり旧上限との厳密な速度・メモリ比較ではない。

| 個体 | ノード | 辺 | 探索回数 | 展開数 | 平均展開/探索 | 容量削除 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 288 | 781 | 402 | 12176 | 30.29 | 0 |
| B | 324 | 1054 | 386 | 12191 | 31.58 | 0 |
| C | 292 | 933 | 411 | 13807 | 33.59 | 0 |

旧上限128/512を越えて保持でき、今回は容量削除なし。内部探索は合計1199回・38174展開。ただし**行動提案・選択はいずれも0**で、選択後の予測一致/不一致/unknownの照合も発火していない。照合の動作保証は前の単体検査によるもので、この実配置試験での実績とは分ける。

終端のhomeラベルはA1/B1/C3、foodはA0/B0/C1。材料が増えた一方、現在の条件で目的までつながる経路は得られなかった。最大4段、1日相当の鮮度、現在観測の署名、方向付きの接続、最初の動作の実行可能性など、提案を出すまでの条件のどこで止まっているかは未分離。容量だけが原因とはいえず、これを長期学習の失敗とも判定しない。

身体要求の設定経路ON・MB内部探索OFFだった30日試験の最初の3日と、daily・day_starts・eventsが完全一致。入力差は日数上限とmb_simulationのみ。今回は行動提案0なので、内部探索が行動を変えていないことも確認した。

3日末reserve A83.39/B83.97/C83.66、帰還完了A0/B1/C0。食料消費12、地上64、携行・倉庫0で初期76を保存。道構造19・岩壁33・生活保存則17、計69項目PASS。追加監査で全グラフの参照整合・容量上限・累積展開上限・保持した探索記録の深さ上限・観測数・有限なコストを確認。

```powershell
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/mb-map-3d-cap10-20261025 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on
node experiments/rock_gate/audit_mb_map.cjs outputs/mb-map-3d-cap10-20261025 outputs/mb-map-3d-cap10-20261025/map-audit.json
node experiments/rock_gate/summarize_food_days.cjs outputs/mb-map-3d-cap10-20261025 outputs/mb-map-3d-cap10-20261025/daily-summary.json
```

証拠：[地図監査](evidence/mb-map-three-day-cap10/map-audit.json)、[日別結果](evidence/mb-map-three-day-cap10/summary.json)、[行動一致](evidence/mb-map-three-day-cap10/behavior-audit.json)、[manifest](evidence/mb-map-three-day-cap10/manifest.json)。完全なグラフは元出力のnarrow/run/result.jsonとsummary.jsonに保存。
