# Juliaの責任境界と更新順序

## 所有元

| データ・処理 | 正本 | 外部へ渡すもの |
|---|---|---|
| 人の身体・変化量・代謝・消化 | src/body | Body、BodyDelta、消化結果 |
| LW個体・局所モデル型・個体ID・食料ID | src/data | 共通型、既存の文字列ラベルと数値コード |
| 障害物交差 | src/geometry | Circle、交差結果 |
| 草食状態・地形の数値ID | src/ecology/state_ids.jl | UInt8コード |
| 基本兎の世界・個体配列 | src/ecology/herbivore/types.jl | 知覚が取得した値 |
| LWの世界 | src/lw/world/contact.jl | 社会的観測、行動結果 |
| 観測 | src/lw/perception、src/ecology/herbivore/perception.jl | 世界の可変参照を持たない移動観測 |
| 行動選択 | src/lw/decision、src/ecology/herbivore/decision.jl | 候補評価・行動要求 |
| 経験・局所モデル・睡眠 | src/lw/learning | 予測、候補、更新された記憶 |
| 階層MB実験 | src/learning/MemoryBlocks.jl | 数値IDの選択経路、処理結果、コスト |
| 時間と実行順序 | src/lw/simulation、各ecologyのsimulation/trial | 結果報告 |
| CLI・保存 | integrations/lightweight_julia | spec、manifest、result、summary |

基本兎と視覚・捕食の各版は異なる規則を持つため別モデルを維持する。
共通IDは同じ意味にだけ使い、種の異なる生理モデルを同じBodyに押し込まない。
LWの過去の出力契約は文字列キーを保つ。数値化の歴史的スナップショットは
experiments/numeric_ecology/numeric-cpu*に保持し、現役共通実装とは混同しない。
全面的なデータ表現の変更は、今回の結果を維持する構造整理と同時には行わない。

## 基本兎の1秒

1. `prepare_requests!`: 消化・眠気更新→知覚→状態選択→草の要求量集計。
2. `allocate_grass!`: 全個体の要求を集計してから、セルごとに比例配分。
3. `apply_actions!`: 摂食・移動要求を実行し、衝突判定・消耗を確定。
4. simulation側で軌跡・日次統計を記録。

これらを`step!`だけが順に呼ぶ。移動先の知覚には草の遅延回復があるため、
従来の個体順と知覚順を維持する。捕食・視覚版はそれぞれのtrialが、知覚→捕食者計画→
兎更新→捕食確定→死亡判定→記録の順を所有する。視線更新は知覚の前。

## LWの1秒

1. 時計・地面・日境界・資源・危険源を更新。
2. 全個体の社会・移動・帰還先などの観測を取得。
3. 前回行動の経験を統合し、各個体の行動要求を選ぶ。
4. 既存の個体順に行動を確定し、結果の時刻を秒末に記録。
5. `advance_physiology!`で代謝→消化を更新。
6. 資源保存を確認し、日末なら睡眠・経験整理と日次記録を実行。

この順序は`lw_day`が所有する。兎とLWの身体更新タイミングの違いは従来仕様であり、
単一の順序へ変更すると挙動が変わるため、無理に同じループへ統合しない。

## 記憶を持たない判断

`StatelessPolicy`は観測だけ、`StatefulPolicy`は所有する記憶と観測を受け取る。
`step_policies!`では同じContactWorldに異なる方策を割り当て、全個体の観測と計画を取得した後に行動を確定する。
現在の共通経路は既存の社会・摂食行動を対象とする。操作結果の領収記録は世界の重複実行防止であり、個体の深い記憶とは別。
