# Julia中心のリポジトリ案内

2026-10-16：起動と案内をJulia中心に整理。コードの移動・削除やシミュレーション挙動の変更は行わない。

## 開発先

- 既存の生活・学習系：`integrations/lightweight_julia/run.jl`が`experiments/julia_migration/lw_integrated/native.jl`へ委譲し、既存の生活ループを使う。`julia_migration`という名前は来歴であり、現在も実行コードを含む。
- 簡易生態系：`experiments/numeric_ecology`。各版を証拠として独立保存。新しい比較は対象版と対照条件を明記する。
- 数値化：同ディレクトリの`numeric-cpu*`。生態系の状態機械とは別系統。

## Python・外部連携の扱い

Python runtimeとtestsは比較基準・回帰検証として保持。Luanti、Godot、p5.jsの既存連携にはPython側の経路もある。Juliaを主入口にしたことは、これら全てをJuliaへ置き換えたことを意味しない。

`start_workbench.bat`は従来の観測用UI、`start_julia.bat`はシミュレーションの入口。旧UIから新しい生態系が自動操作できるわけではない。

## 出力と再現

LWは`outputs/`等の指定先へspec・manifest・result・summaryを保存。長期比較は保存specと実装リビジョンをセットで残す。生態系の既存ランナーは各実験内の結果を再生成するので、実行後のGit差分を確認する。

数値スナップショット等の大型出力は全てGitへ含まれているわけではない。個別READMEの欠落データ説明に従う。

## CI

`julia-ecology-smoke.yml`はpush/PRで短いJuliaチェックを実行。既存のJulia LW・長期比較workflow_dispatchと、Python/Godot回帰ワークフローは維持。今回それらを統合・無効化していない。

## 更新履歴

[整理前のREADME](history/README-before-julia-primary-20261016.md)に過去の記録を保存。歴史的な完成宣言や本線指定は、当時の実装範囲で読む。

## 整理時の確認

2026-10-16、Julia 1.13.1 / Windowsで確認：ルートCLIとWindows起動のhelp成功、ルートCLIからLWの1日実行完了（seed 20261005）、生態系の視野比較29項目・旧条件一致・再現一致、CIと同じ草食／捕食チェック37項目成功。計66項目。GitHub Actions上の実行結果は別途確認が必要。
