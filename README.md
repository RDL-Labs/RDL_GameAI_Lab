# RDL Game AI Lab

Juliaを主な実行・開発環境とする、RDLの生活・学習・生態系実験リポジトリ。
既存の生活ループ（LW）と、数値CPUによる簡易生態系は別の実験経路です。

開発時の共通注意事項：[関係拘束の強さを頼りに世界を渡る](docs/design/RDL_Common_Relational_Policy.md)。認識・選択を個別の正解判定で継ぎ足さず、経験・予測・H・ρによる共通の仕組みを優先します。

## 起動

Julia **1.13.1**を用意し、リポジトリルートで依存関係を準備します。

```sh
julia --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
```

共通入口：

```sh
julia --startup-file=no run.jl --help
julia --startup-file=no run.jl lw outputs/lw-native --days 3 --seed 20261005
julia --startup-file=no run.jl ecology directional-vision-cpu
julia --startup-file=no run.jl ecology overgrazing-cpu
```

Windowsでは同じ引数を`start_julia.bat`へ渡せます。JuliaがPATHにない場合は環境変数`JULIA_EXE`へ実行ファイルを指定します。

## 二つの実験経路

| 経路 | 用途 | 詳細 |
|---|---|---|
| Julia LW | 生活・身体・資源・局所モデル・社会・Sleep | [起動と設定](integrations/lightweight_julia/README.md) / [移行範囲と判定](docs/design/RDL_Julia_LW_Backend_Decision.md) |
| 数値CPU・生態系 | 数値ID管理、兎と捕食者、視覚、過採食 | [実験一覧・結果](experiments/numeric_ecology/README.md) |

LWの主要機能移植は宣言した差分の範囲で完了。Python全機能・全外部連携との同値を意味しません。新規LWの既定設定は小規模構成で、過去の全機能30日条件とは別です。保存済みspecを使う場合は、その設定が優先されます。

```sh
julia --startup-file=no run.jl lw outputs/lw-replay --spec path/to/spec.json
```

生態系は状態機械による独立実験で、既存のMB学習系への統合・繁殖・Luanti接続は未実装。角度や生理値は試験用です。

## 構成

| 場所 | 役割 |
|---|---|
| `run.jl` / `start_julia.bat` | Juliaの共通起動入口 |
| `Project.toml` / `Manifest.toml` | 現役Julia共通環境 |
| `src` | 身体・幾何・LW各層・兎の共通実装 |
| `test` | Julia階層化の回帰・境界テスト |
| `integrations/lightweight_julia` | 既存Julia LWの安定入口 |
| `experiments/julia_migration` | 互換入口、旧固定環境、移行・回帰・性能の証拠 |
| `experiments/numeric_ecology` | 数値化と生態系の独立実験・保存結果 |
| `docs` / `notes` | 設計・契約・検証記録 |
| [`docs/reflections`](docs/reflections/README.md) | 考察・研究メモ・実装前の仮説 |
| `runtime` / `tests` / `integrations/lightweight` | Pythonの比較基準・旧経路・回帰検証 |
| `gui-p5` / `start_workbench.bat` | Pythonで配信する既存観測用UI |
| `godot` / `integrations/luanti` | 外部エンジン連携。Julia生態系との接続は別作業 |

Juliaの構造整理を実施しました。現役実装は`src`を正本とし、旧パスには互換入口を残しています。[計画と検証結果](docs/JULIA_REFACTOR_PLAN.md)、[責任境界と更新順序](docs/JULIA_LAYERS.md)、[リポジトリ案内](docs/REPOSITORY_GUIDE.md)を参照してください。

## 検証と記録

- [味・満腹・遅延消化のLW接続実験](experiments/digestion_taste/README.md)：味と栄養を分離。狩猟・味による探索選択は未接続。

- [Julia LWの検証・切替判定](docs/design/RDL_Julia_LW_Backend_Decision.md)
- [数値CPU・生態系の検証](experiments/numeric_ecology/README.md)
- [過去のREADME・更新履歴](docs/history/README-before-julia-primary-20261016.md)
- GitHub Actions：Juliaの短い生態系チェックを自動実行。長期LW比較は既存の手動ワークフロー。Python回帰も維持。

過去記録の「本線Python」「移行中」などは当時の状況です。現在の入口と役割はこのREADMEを優先してください。
