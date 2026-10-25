# 目的Hの解消で経験をまとめる：3日試験

2026-10-25。実装範囲は[設計](../../docs/design/LW_MB_Reward_Chunks.md)。予測一致は関係の信頼度、目的達成によるH減少は成功経路の報酬として別に扱う。実際に観測した連続する2辺以上を仮のまとまりにし、同じ経路の成功で支持と報酬を増やす。内部の辺は残し、再認識できた地点から候補として再利用する。固定した行動継続ではない。

## 条件と結果

狭い入口・分岐道・seed=20261005、身体要求ON、MB内部探索ON、粗ρ。直前の容量10倍の3日試験と入力を比較し、差はmb_chunks=onだけ。3日正常完走、実行258.62秒（コンパイル込み）、ピークRSS 1,379,581,952 bytes（約1.38GB）。前回257.28秒との差は約0.52%だが単発測定であり、速度差の確証とはしない。

| 個体 | ノード / 辺 | 内部探索 | まとまり形成 | 再利用候補 / 選択 | 日末reserve | 帰還完了 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 288 / 781 | 402 | 0 | 0 / 0 | 83.39 | 0 |
| B | 324 / 1054 | 386 | 0 | 0 / 0 | 83.97 | 1 |
| C | 292 / 933 | 411 | 0 | 0 / 0 | 83.66 | 0 |

全員のまとまりへの報酬付与0、内部探索からの候補も0。前回とdaily・day_starts・eventsが完全一致し、今回の仕組みは行動を変えていない。食料消費12、地上64、携行・倉庫0で初期76を保存。

**形成と再利用の実環境での効果は未確認。** Bには帰還成功があるが、目的H解消と連続した有効な観測経路が同時に揃った記録は得られていない。どの成立条件が経路を切ったかは今回の集計では分離していない。観測署名の断続、目的変更、非移動行動などを診断する必要があり、実行期間だけを原因とは断定しない。

## 検証範囲

単体検査では実観測を模した2辺経路で、H解消による形成、繰り返し成功による強化、二重加算防止、H=0時の無報酬、経路途中からの再利用、予測一致と目的報酬の分離、不一致・不完全観測・辺削除への対応を確認。新規24、既存MB地図33、H報酬43、実配置の道・岩壁・生活保存則69、合計169項目PASS。追加監査でグラフとまとまりの参照・容量整合も確認した。

現在は食料取得・拠点到達という既存目的のHを使う。身体要求全体を一つの学習報酬に統一したものではなく、多階層ρによるまとまりの抽象化も未実装。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_chunk_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/mb-chunks-3d-20261025 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on
```

証拠：[日別集計](evidence/mb-chunks-three-day/summary.json)、[地図監査](evidence/mb-chunks-three-day/map-audit.json)、[入力・行動比較](evidence/mb-chunks-three-day/behavior-audit.json)、[manifest](evidence/mb-chunks-three-day/manifest.json)、[provenance](evidence/mb-chunks-three-day/provenance.json)。provenanceのコミットは開始時の親で、実行ソースはmanifestのhashで対応づける。
