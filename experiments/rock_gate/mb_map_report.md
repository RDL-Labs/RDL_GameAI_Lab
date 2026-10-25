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
