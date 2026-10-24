# LW固定ρ近似地図・ポテンシャル初版

2026-10-23。Juliaのみ。動的ρ選択や思考の統合に先立ち、同一観測からの近似地図と移動評価を導入。

後続変更: [初回外出改善](../../rock_gate/exit_opening_report.md)で隙間候補と観測priorを追加。以下はその追加前の比較。現行コードで初版条件を再現する場合は `--rho-openings off` を指定する。

## 実装範囲

- `config.rho_profile`: `off`（従来）/ `coarse` / `fine`。native CLIでは `--rho-profile`。有効時は `ground_perception`、`ground_continuity`、`continuous_descent` が必要。
- 粗・細は連結可能距離2.5 / 1.0の有限profile。同一の15地面点・7障害rayを再解釈する。観測数・視野を増やす機能ではない。
- 観測された異種境界・clear ray・未知区間を跨いで結合しない。隙間の通行可能性は未検証として残す。
- 選択された方向への引力、障害・水への反発、細長い観測済み地面群の軸に沿う寄与をスカラーコスト化。身体状態・荷物・走行でclearanceと移動距離が変わる。
- 選択方向の±45度内を11.25度刻みの9候補で比較。確率的な方法選択は既存BasicLoop、局所補正は最小コストの決定的選択。既存の物理実行可否検査は維持。
- 地図は既存の構造記憶と経路候補の絞り込みにも使う。そのためρ比較には地図からの候補変化も含まれ、ポテンシャル単独の因果比較ではない。
- planにprofile・観測source・ポテンシャル内訳を付与。ground_effectsに適用回数と最終内訳を保存（既存のground_effects出力がある地形モード）。

正解世界の地図は近似地図の入力にしない。点間の面を保証せず、通行判定は既存の実行側に残す。停滞によるρの切り替え、追加観測、ρ選択学習、思考空間への適用は未実装。

## 検証

`julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/rho_map_checks.jl`：既存構造29項目＋新規27項目PASS。source対応、stale地図の不採用、実際のsteering接続、CLIも確認。

`julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/structure_movement_checks.jl`：従来の共有移動場34項目PASS。

狭い入口の再現コマンド（各出力先は新規ディレクトリ）：

```powershell
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/rock-gate-rho-off-20261023 --narrow-only --days 1 --rho off --rho-openings off
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/rock-gate-rho-coarse-20261023 --narrow-only --days 1 --rho coarse --rho-openings off
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/rock-gate-rho-fine-20261023 --narrow-only --days 1 --rho fine --rho-openings off
```

左右対称の4光源、同一初期状態・seed 20261005・個体順序。各条件はソースsnapshotとspec・manifestを保存。1seed・1日であり、長期帰還や一般的な優位性は判定しない。計測はコンパイル込みで、経路・操作構成の違いも含むため純粋な評価器の速度比ではない。

## 1日比較の結果

| 条件 | 実行秒（コンパイル込み） | A 外出/入場 | B 外出/入場 | C 外出/入場 | 消費食料 |
| --- | ---: | ---: | ---: | ---: | ---: |
| off | 75.41 | 1/0 | 0/0 | 2/1 | 5 |
| coarse | 74.04 | 1/0 | 2/1 | 2/1 | 6 |
| fine | 81.88 | 1/0 | 0/0 | 1/0 | 6 |

粗ρでは3体とも外出した。細ρではBは外出しなかった。いずれも帰還目的が有効な間の内向き通過は0回で、入場回数は帰還成功を意味しない。粗ρの全個体で1日末の帰還目的が未完了。粗い表現が常に優れるとも、細かくすれば入口を通れるとも結論しない。

粗ρは今回の総実行時間で従来と同程度、細ρは約8.6%長かった。単発・コンパイル込みの結果であり、CPU評価器単独の負荷差ではない。既定値はoffのまま比較可能にし、粗ρ・細ρは明示指定する。

各runで地形33項目・生活保存則7項目、合計120項目PASS。`experiments/rock_gate/compare_rho.jl`で、ρ以外の入力一致、各個体へのρ適用、有限なポテンシャル値など28項目PASS。上記の構造・移動検査を含め238項目PASS。

保存証拠: [比較結果](../../rock_gate/evidence/rho_map/comparison.json)。元出力は上記コマンドの3ディレクトリ。比較結果には体力・操作数・目的状態・メモリ計測も含む。メモリのallocated_bytesは累積割当量で、同時使用RAMではない。

次段階は、この固定ρ条件を基準に、元の目的に進展がない場合だけ別ρや追加観測を候補にすること。今回の実装で自動切り替えや帰還問題の解決を主張しない。
