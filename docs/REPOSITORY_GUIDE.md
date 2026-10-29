# Julia中心のリポジトリ案内

2026-10-21：Julia実装の構造整理を実施。現役実装はsrcを正本とし、旧パスは互換入口。実施範囲と検証結果は[JULIA_REFACTOR_PLAN.md](JULIA_REFACTOR_PLAN.md)を参照。

## 開発先

- 生活・学習系：`src/lw`のworld/perception/decision/learning/simulation。CLIと出力は`integrations/lightweight_julia`。新規の実装を旧実験フォルダへ追加しない。
- 簡易生態系：基本の兎は`src/ecology/herbivore`、捕食・視覚・過放牧の各変種も`src/ecology`。`experiments/numeric_ecology`に条件・比較・保存結果と互換入口を残す。数値化の歴史的スナップショットは変更対象外。
- LW放牧接続：`src/ecology/lw_grazing`で既存の兎を人と同じ世界時計へ接続。条件・検査・軌跡出力は`experiments/lw_wildlife`。[接続範囲](design/LW_Wildlife_Grazing.md)。
- 共通の身体・幾何は`src/body`と`src/geometry`。ルートProject/Manifestが現役の共通環境。
- 数値化：同ディレクトリの`numeric-cpu*`。生態系の状態機械とは別系統。

## 考察と文書

[考察と研究メモ](reflections/README.md)に、対話から生まれた仮説と今後の検討課題を保存する。設計は`docs/design`、実験条件は`docs/experiment-contracts`、結果は`docs/experiment-evidence`と`experiments`で扱う。既存の考察は元の場所を保ち、索引から参照する。

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
