# Julia CIの区分と実行方法

2026-11-06。通常回帰検査は `test/ci/suites.json` を唯一の一覧とし、
GitHub Actionsとローカルで `julia --startup-file=no --project=. test/ci/run.jl <suite>` を実行する。
`--list` は一覧・パス存在・重複を検査する。

| suite | 対象 |
|---|---|
| boundaries | 層境界・共通世界・起動入口 |
| food | 加工品質、釣り、期限、味、食料交換、共通試行 |
| social | 関係学習、援助見積もり、表情、資源観測、自力優先 |
| portable | 物品の所有・受渡し・交渉・交換の経験 |
| navigation | 親計画、帰還、探索、局所成果 |
| observation | 視覚、継続移動、固定行動隔離、睡眠遮断 |
| animals | 既存動物・捕食者、開口境界 |
| wildlife | LW草食接続、繁殖・初期親子・帰巣回避、動体観測 |

旧workflowの検査を落とさず分類し直し、繁殖・援助資源・共通試行などを追加した。
各スクリプトは独立Juliaプロセスで実行。失敗しても同suiteの後続を実行し、最後に非ゼロで終了する。
ファイル別ログと終了コード・秒数は `outputs/ci/<suite>` に保存し、Actions artifactへアップロードする。
matrixのfail-fast=falseは継続。各jobの上限は20分。CI結果のsuccess/skippedを混同しない。

日次保存・別プロセス再開は `julia-lw-checkpoint.yml` に独立して維持する。
Python/Godot互換検査も削除しない。30〜180日実験、性能比較、ローカルcheckpoint依存の
`potential_checks.jl`や監査runnerは通常CIへ混ぜない。代わりに帰巣の自己完結した短い検査を
`reproduction_checks.jl`へ追加する。長期の生存・速度改善はCI成功だけでは証明できない。

検査更新時は、食品配列の期待値・代入を現行8種類へ揃える。
旧長の入力を許容するAPI検査は別であり、入力を一括置換しない。
味の事前予測と身体状態依存の摂食結果は別に検査し、経験を記録した後の想起も検査する。
不利な交換を無理に成立させない。関係の選択効果や決済記録を試すfixtureでは、
現行仕様で利用可能な食品と在庫を用意する。未加工品の加工価値を試す場合は設備条件も渡す。

## 整理時に見つかった残件（2026-11-06）

CIの分類整理は、全検査の成功を意味しない。次の検査は除外・skipせず残す。

- `food_exchange/policy_checks.jl`: 初回選択で `continue_activity` が出る想定と、現在の候補選択を再確認する。加工済み食品で提案・成立・拒否の検査は通るが、`skip_found` は不合格。
- `portable_items/counter_checks.jl`: 64シードで逆提案と拒否の両方が出る想定が不合格。食料在庫を増やすだけでは直らず、その試験的変更は戻した。
- `portable_items/social_checks.jl`: 自律交渉から交換が成立する想定が不合格。成立を強制したり、成立回数の検査を削ったりしない。
- `social_relationships/integration_checks.jl`: 現行の援助条件と短時間fixtureの整合を確認する。在庫・時間・拒否の期待値をまとめて緩める変更は採用しない。
- `portable_items/incidental_integration_checks.jl`: 物品種類数を修正すると後続の無効化条件まで進み、`day.jl` の `camp_landmark` 参照で `KeyError` を検出する。単なる期待値の古さとは別の残件。

これらは通常CIで引き続き検出する。検査条件が古いのか実装の不具合かを個別に確認し、
本体の認知・交換ルール変更はCI整理から分ける。全体がgreenになるまで成功扱いにしない。
