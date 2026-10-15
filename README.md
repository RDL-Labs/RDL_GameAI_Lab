# RDL Game AI Lab

Juliaを主な実行・開発環境とする、RDLの生活・学習・生態系実験リポジトリ。
既存の生活ループ（LW）と、数値CPUによる簡易生態系は別の実験経路です。

## 起動

Julia **1.13.1**を用意し、リポジトリルートで依存関係を準備します。

```sh
julia --startup-file=no --project=experiments/julia_migration/julia experiments/julia_migration/julia/setup.jl
julia --startup-file=no --project=experiments/numeric_ecology -e 'using Pkg; Pkg.instantiate()'
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
| `integrations/lightweight_julia` | 既存Julia LWの安定入口 |
| `experiments/julia_migration` | Julia LW実装、固定環境、移行・回帰・性能の証拠 |
| `experiments/numeric_ecology` | 数値化と生態系の独立実験・保存結果 |
| `docs` / `notes` | 設計・契約・検証記録 |
| `runtime` / `tests` / `integrations/lightweight` | Pythonの比較基準・旧経路・回帰検証 |
| `gui-p5` / `start_workbench.bat` | Pythonで配信する既存観測用UI |
| `godot` / `integrations/luanti` | 外部エンジン連携。Julia生態系との接続は別作業 |

実装の物理移動は行わず、既存のinclude・ワークフロー・履歴からの参照を維持しています。詳しくは[リポジトリ案内](docs/REPOSITORY_GUIDE.md)。

## 検証と記録

- [Julia LWの検証・切替判定](docs/design/RDL_Julia_LW_Backend_Decision.md)
- [数値CPU・生態系の検証](experiments/numeric_ecology/README.md)
- [過去のREADME・更新履歴](docs/history/README-before-julia-primary-20261016.md)
- GitHub Actions：Juliaの短い生態系チェックを自動実行。長期LW比較は既存の手動ワークフロー。Python回帰も維持。

過去記録の「本線Python」「移行中」などは当時の状況です。現在の入口と役割はこのREADMEを優先してください。
