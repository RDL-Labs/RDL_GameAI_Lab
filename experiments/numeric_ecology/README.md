# 数値CPU・生態系の独立実験

RDL_GameAI_Labの実験群。既存LW本線へは未統合。2026-10-16時点の数値化と簡易生態系の比較コード・結果を保存する。

## 生態系の実行

Julia 1.13.1を使用。リポジトリルートで：

```sh
julia --project=experiments/numeric_ecology -e 'using Pkg; Pkg.instantiate()'
julia --project=experiments/numeric_ecology experiments/numeric_ecology/run.jl directional-vision-cpu
julia --project=experiments/numeric_ecology experiments/numeric_ecology/run.jl overgrazing-cpu
```

`run.jl`に渡せる名前は下の生態系5条件。再実行すると該当フォルダの結果を更新する。Pythonはシミュレーションには不要。

| 実験 | 内容・結果 |
|---|---|
| [herbivore-cpu](herbivore-cpu/README.md) | 同じ地形に大量の草、兎30体3日。捕食者なし |
| [predator-cpu](predator-cpu/README.md) | 捕食者1体、限定知覚・突進・回復・休息 |
| [motion-vision-cpu](motion-vision-cpu/README.md) | 静止警戒と動き補正ON/OFF。5seedの平均捕食2.4→3.0体 |
| [directional-vision-cpu](directional-vision-cpu/README.md) | 兎の広い視野、捕食者の前方視野、独立した視線。平均捕食3.0→4.0体 |
| [overgrazing-cpu](overgrazing-cpu/README.md) | 捕食なし10日。1,000体→108体、3,000体→100体。枯渇・大量死後に草回復 |

各版は比較証拠を保つため独立コピー。状態機械でありMB・学習・繁殖は未実装。物理・生理パラメータは試験用。草の保存・摂食保存・死亡停止・再現性等を確認しているが、生態系の妥当性や最適性を主張しない。Luanti連携は未実装。

## 数値化の履歴

| 実験 | 内容 |
|---|---|
| [numeric-cpu](numeric-cpu/README.md) | 既存LW状態の配列化、従来結果との一致 |
| [numeric-cpu-full](numeric-cpu-full/README.md) | 文字列から数値IDへの変換と実行経路監査 |
| [numeric-cpu-tracking](numeric-cpu-tracking/README.md) | 追跡ON/OFF、到達不能IDの回収。30体1日結果一致、ピーク約4.17→2.47 GB |

数値化系は既存MBモデルの実験であり、簡易生態系とは処理内容が違う。速度を直接比較しない。元の基準コードは`5b09a58c3009f59044cc08d2a551f939a3fa7790`由来の実験コピー。

大型の数値スナップショット（*.numeric.bin）と10 MiB超の結果はこのコミットには含めない。含めた小型のvalidation/metrics/reportとソースを参照。大型出力に依存する旧比較スクリプトは、その出力の再生成が必要。古い個別READMEのWindows起動例やPowerShellスクリプトは当時の記録であり、上の入口が生態系実験の現行手順。

## 検証

```sh
julia --project=experiments/numeric_ecology experiments/numeric_ecology/predator-cpu/checks.jl
julia --project=experiments/numeric_ecology experiments/numeric_ecology/predator-cpu/predator_checks.jl
```

方向視野の実験入口では29項目、前版5条件との全結果一致、基準seedの再現性を確認する。大量採食では各観測時の保存則と個体ごとの生存tick数を確認する。

参考：[RDL Living Field](https://github.com/HermannDegner/RDL_Demos/tree/main/demos/relational-ecology-lab)。限定知覚・捕食行動などの設計参照であり、その学習系やCore理論の移植ではない。
