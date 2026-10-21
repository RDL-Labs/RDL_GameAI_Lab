# Julia階層化計画

対象はJuliaのみ。Python実装は参照用として残し、並行改修しない。
構造変更と行動仕様変更を分け、同一条件での結果比較を各移行の条件とする。

| 段階 | 完了条件 | 状態 |
|---|---|---|
| 1 依存関係 | 現役実装と保存版、入口と型の所有元を特定 | 完了。JULIA_LAYERS.mdと依存台帳スクリプト、実行可能な依存方向チェック |
| 2 比較基準 | LW・兎・消化の固定条件と結果を保存 | LW・消化3条件、兎30体3日の基準をローカル保存済み |
| 3 共通データ | 個体・食料・行動・観測と数値IDの所有元を整理 | 完了。src/dataにLW個体・モデル型・個体ID・食料ID。草食数値IDは共通表。観測・行動契約の所有元を文書化 |
| 4 世界・身体 | 更新責任を分離 | 完了。人の身体・消化・代謝はbody、世界はworld、結果確定はsimulation。兎は要求と資源配分と適用を分離。従来結果を維持 |
| 5 知覚・判断 | 観測から行動要求を生成、判断方式を差し替え可能 | 完了。LW・草食・捕食の判断は観測値を入力。差し替え・世界からの独立性・既存条件一致を検証 |
| 6 記憶・学習 | 記録・MB・睡眠整理を分離、記憶なし個体にも対応 | 完了。モデル型・目標更新・社会記憶・睡眠周期を分離。Stateful/Statelessの判断が同じContactWorldで動く8項目成功 |
| 7 更新順序 | 時間・観測・判断・成立判定・更新・記録を明示 | 兎の要求集計→配分→行動適用、LWの秒末生理更新を関数分離。JULIA_LAYERS.mdに従来順序と所有元を明記。結果一致 |
| 8 実験・接続 | 実装本体から実験フォルダへの依存を解消 | LW・基本兎・捕食・動態視覚・方向視覚・過放牧をsrcへ移行。実験に条件と計測を残す。srcの実験読み込み依存なし |
| 9 性能 | 1,000・10,000体、消化・記録ON/OFFを比較 | hierarchy_benchmarkに全8条件と身体直接呼び出し比較を保存。64+60項目成功。MBの割当負荷を明記 |
| 10 MB階層 | 適用条件・入力・結果・コストを持つ親子MBを実験 | MemoryBlocksで親→中間→葉の階層実験。摂食・休息を実行、追跡OFFの結果一致を含む8項目成功。既存LWの判断には未適用 |

## 移行前に確認した依存関係

`run.jl` → `integrations/lightweight_julia/run.jl` →
`experiments/julia_migration/lw_integrated/native.jl` →
`lw_integrated/run.jl` → `lw_day/run.jl` → `moving_social/run.jl`。
身体型は従来 `all_loop/loop.jl` が所有し、消化は `lw_day/digestion.jl` が所有していた。
既存スクリプトの入口を残し、実装をsrcへ移した。現在の入口・所有元はJULIA_LAYERS.mdを参照。
数値化実験の source/baseline/test-numeric は比較用スナップショットであり、
現役実装と一括置換しない。世界・身体の種間差を無理に共通化しない。

## 比較の再実行

Julia 1.13.1、既存のjulia_migration/julia環境を使用する。

```text
julia --startup-file=no --project=experiments/julia_migration/julia experiments/digestion_taste/run.jl outputs/refactor-body
julia --startup-file=no --project=experiments/julia_migration/julia test/refactor_parity.jl outputs/refactor-baseline outputs/refactor-body
```

整理前に同じ実験を `outputs/refactor-baseline` へ実行済み。
比較対象は時間計測値を含む概要ではなく、off/ordinary/meatの全結果JSON。
基準結果はローカルoutputs（Git対象外）。既存の追跡済みspec.jsonとresults.jsonも保持する。

2026-10-21: 身体型・消化の切り出し後、消化単体21項目と既存の統合・再実行検証が成功。
off/ordinary/meatの全結果JSONも、切り出し前と3条件とも一致。
これは身体型・消化の移行に対する検証であり、残る階層全体の完了を意味しない。

`julia scripts/julia_dependencies.jl` でJuliaファイルのハッシュ、include式、型定義をTSVへ出力する。
動的includeを推測せず式のまま保存する静的台帳なので、実際の到達範囲は入口から別途確認する。

## 現在の実装配置

- `src/body`: 人のBody/BodyDelta、行動による身体変化、代謝、消化。実験に依存しない。
- `src/geometry`: 円形障害物の交差判定。LWと兎の同一だった幾何実装を共通化。
- `src/ecology/herbivore`: 兎の数値状態ID、世界・個体データ、世界生成・草回復、判断、更新、実行・出力。
- 旧パスは互換入口。捕食者・動態視覚・方向視覚・過放牧版もsrc/ecologyへ移行済み。同一の草食ルールは共有し、異なる版は比較のため分けて保持する。
- 兎の状態・移動先の判断は値だけの観測を受け取る。`StateMachinePolicy` は `policy` 引数で差し替え可能。
- 草の遅延回復は知覚処理から世界の関数を呼ぶ従来順序を維持。移動の成立判定は更新側に残す。
- `src/lw/world`: ContactWorld・接触判定・世界生成を抽出。
- `src/lw/perception`: 社会的観測と移動観測。移動の候補評価は `src/lw/decision/movement.jl` へ分離し、世界参照を渡さない。
- `src/lw/learning`: 経験・目標更新・睡眠。社会モデルの型はsrc/data、選択はdecisionへ分離。
- `src/lw/simulation`: LWの統合実行。観測→計画→結果確定→生理→日末整理の順序を所有。
- `src/lw/LW.jl` / `src/RDLGameAI.jl`: 実験を読み込まずに利用できるモジュール入口。
- `integrations/lightweight_julia/native.jl`: CLI・設定・結果保存。ソースハッシュは現在のsrcと接続実装を記録する。
- ルートProject/Manifestへ共通環境を用意。旧環境は比較・旧コマンド向けに維持。

兎の比較手順:

```text
julia --startup-file=no --project=experiments/numeric_ecology experiments/numeric_ecology/herbivore-cpu/run.jl outputs/refactor-herbivore
julia --startup-file=no --project=experiments/numeric_ecology test/ecology_refactor_parity.jl outputs/refactor-herbivore-baseline outputs/refactor-herbivore
```

30体・3日・固定シードで全結果JSON、移動履歴CSV、草の分布CSVの3比較が一致。
身体の行動・代謝抽出もLWの全結果3条件で一致を確認。
知覚・判断分離後も兎の全結果・移動履歴・草分布が一致。
`test/herbivore_policy.jl` は世界を受け取らない別方策を100tick実行し、休息・非移動・非摂食を確認する。

LWの42ファイル移行と移動評価分離後も、全結果3条件が一致。
`test/lw_policy.jl` の5項目で、判断方式の差し替えと世界更新後にも観測値だけで判断できることを確認。
既存 `running_checks.jl` の走行OFF/ON各3日、身体・安全・統合不変条件を含む46項目が成功。
モジュール `src/RDLGameAI.jl` の読み込みも成功。性能測定値は他の実行と重なったため、この段階で速度改善・劣化の判断には使わない。

## 生態系変種・MBの追加検証

生態系の移行前コードと入力を `outputs/refactor-variants-baseline` に保存。
`test/ecology_variants_parity.jl` で捕食3シード×有無、動態視覚5シード×有無、方向視覚5シード×有無の26条件が一致。
過放牧30/1000/3000体・10日も全報告（死亡時刻・資源・状態集計）が一致。
続いて過放牧のループをsrcへ抽出し、草食状態・地形の数値IDを `src/ecology/state_ids.jl` に集約。
この追加変更後も捕食・視覚26条件と過放牧30/1000/3000体・3日の全報告が一致。
草食・捕食の既存37項目と兎の判断境界9項目も成功。

`src/learning/MemoryBlocks.jl` は階層呼び出しの実験実装。適用条件・コスト関数は副作用のない関数として渡す。
親は利用可能な葉の最小コストを比較し、同点は登録順で決める。選ばれた葉だけを実行する。
追跡OFFでは経路ID配列を組み立てない。学習による自動生成・睡眠での構造変更は、この呼び出し実験の実装範囲には含まない。

## 更新順序・性能

`JULIA_LAYERS.md`にデータ所有元・各モデルの更新順序を明記。
基本兎は要求集計、資源配分、行動適用を関数に分離。LWは秒末の代謝・消化を独立関数へ移行。
この変更後もLW3条件、兎30体3日の全結果・軌跡・草分布が一致。

`experiments/hierarchy_benchmark/README.md`に1,000/10,000体×消化ON/OFF×追跡ON/OFFの8条件を記録。
追跡ON/OFF間の身体状態は一致。MB経由の更新は短命の割当が多く、大量個体への既定適用はしていない。
身体の直接呼び出しも既存条件で再測定。両者は測定tick数と処理が異なるため、全体速度の比較には使わない。

## 最終監査

社会モデルの追加分離後もLW3条件の全結果が一致。捕食側の知覚・判断分離と草食側の共通知覚・判断適用後も26条件が一致し、過放牧3規模1日で比較成功。
以前の10日・3日比較と合わせ、構造変更の段階ごとに比較を実施した。

共通実行APIの `step_policies!` は社会・摂食の小さな共通経路で、StatefulPolicyとStatelessPolicyを混在できる。
MBの親子選択と状態機械を同じ世界で検証するための入口であり、既存の全機能LWを置き換えない。
兎と人の生理・学習モデルを統合する新しい生態ゲームや、経験からのMB自動生成は今回のコード整理では追加していない。

整理前の完全な結果について、キー順を正規化したSHA-256を `test/fixtures/refactor-goldens.json` に保存。
従来の巨大な結果ファイルをGitへ追加せず、整理前コミットa37eb00・Julia 1.13.1/Windowsの出力との一致を再検証できる。

```text
julia --startup-file=no --project=. experiments/digestion_taste/run.jl outputs/verify-lw
julia --startup-file=no --project=. experiments/numeric_ecology/herbivore-cpu/run.jl outputs/verify-rabbits
julia --startup-file=no --project=. test/refactor_goldens.jl outputs/verify-lw outputs/verify-rabbits
```

浮動小数点の厳密なゴールデン比較は記載した環境で確認したもの。CIでは境界・資源保存・状態遷移のテストを実行する。
