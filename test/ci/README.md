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

初回整理では旧workflowの検査を全て移し、繁殖・援助資源・共通試行などを追加した。
その後、下記の旧仕様検査4本を通常CIから外した。現在の通常CIは8区分・65本。
各スクリプトは独立Juliaプロセスで実行。失敗しても同suiteの後続を実行し、最後に非ゼロで終了する。
ファイル別ログと終了コード・秒数は `outputs/ci/<suite>` に保存し、Actions artifactへアップロードする。
matrixのfail-fast=falseは継続。各jobの上限は20分。CI結果のsuccess/skippedを混同しない。

日次保存・別プロセス再開は `julia-lw-checkpoint.yml` に独立して維持する。
Python/Godot互換検査は手動専用で維持する（下記）。30〜180日実験、性能比較、ローカルcheckpoint依存の
`potential_checks.jl`や監査runnerは通常CIへ混ぜない。代わりに帰巣の自己完結した短い検査を
`reproduction_checks.jl`へ追加する。長期の生存・速度改善はCI成功だけでは証明できない。

検査更新時は、食品配列の期待値・代入を現行8種類へ揃える。
旧長の入力を許容するAPI検査は別であり、入力を一括置換しない。
味の事前予測と身体状態依存の摂食結果は別に検査し、経験を記録した後の想起も検査する。
不利な交換を無理に成立させない。関係の選択効果や決済記録を試すfixtureでは、
現行仕様で利用可能な食品と在庫を用意する。未加工品の加工価値を試す場合は設備条件も渡す。

## 自動CIと旧版・実験用workflowの区別

| 区分 | workflow | 起動条件 |
|---|---|---|
| 現行Julia回帰 | `julia-ecology-smoke.yml` | mainへのpush、PR、手動 |
| 現行Julia保存・再開 | `julia-lw-checkpoint.yml` | mainへのpush、PR、手動 |
| 旧Python／Godot互換 | `python-tests.yml` | 手動のみ |
| その他の移行期・長期・比較実験 | その他の既存workflow | 手動のみ |

2026-11-06から、開発対象でない旧Python検査を毎push・PRでは起動しない。
Actionsの **Legacy Python and Godot compatibility (manual)** → **Run workflow** で実行できる。
Python実装や旧Godot連携を変更・再利用するときに、対象ブランチで互換性を確認する。
テスト本体・実行コマンド・workflowファイル名は保持し、過去の実験への参照を残す。
ここでのGodot検査はPython経由の旧縦断検査であり、Julia版の動作保証ではない。

その他の既存workflowは整理前から手動専用。名前にJuliaが含まれていても、
移行期のPython比較や旧実験入口を呼ぶものがある。現行の必須CIとは扱わず、
再利用時に入口・依存環境・試験条件を確認する。今回それらの動作を再保証したものではない。
新しい通常回帰検査はまず `suites.json` へ追加し、過去の単発実験workflowを増殖させない。

手動化は検査成功を意味しない。既に起動済みの旧CIはこの変更では中止されない。
ブランチ保護で旧 `python-tests` / `godot-verticals` を必須にしている場合は、
リポジトリ管理設定側でも必須対象を見直す（workflow変更だけでは保護設定は変更されない）。

## 整理時に見つかった残件（2026-11-06）

CIの分類整理は、全検査の成功を意味しない。次の検査は除外・skipせず残す。

- `food_exchange/policy_checks.jl`: 初回選択で `continue_activity` が出る想定と、現在の候補選択を再確認する。加工済み食品で提案・成立・拒否の検査は通るが、`skip_found` は不合格。
- `portable_items/counter_checks.jl`: 64シードで逆提案と拒否の両方が出る想定が不合格。食料在庫を増やすだけでは直らず、その試験的変更は戻した。
- `portable_items/social_checks.jl`: 自律交渉から交換が成立する想定が不合格。成立を強制したり、成立回数の検査を削ったりしない。
- `social_relationships/integration_checks.jl`: 現行の援助条件と短時間fixtureの整合を確認する。在庫・時間・拒否の期待値をまとめて緩める変更は採用しない。
- `portable_items/incidental_integration_checks.jl`: 研修OFF時も引数評価で `camp_landmark` を読む実装不具合を修正。呼出し側を `configured_camp_experience` でガードし、OFF時に存在しない研修状態を読まない。修正後、任意採取15・無効化9・保存再開2の計26項目がローカルで成功。

### 全ジョブ完了後の追加調査

`bc8e6ac` のActions run `42210590724` は69本中59本成功、10本不合格。
保存・再開の独立workflowは成功。上記の1本修正はこの実行の後であり、クラウド再検証前。
移動グループは13/18本成功で、次の5本も残る。

- `rock_gate/post_return_idle_checks.jl`: 待機への移行が0回。観測数＋待機数を全tick数とする期待値も、睡眠遮断分を含んでいない。行動条件と集計を分けて調査する。
- `rock_gate/local_success_checks.jl`: 活動計画が存在する前提で `active` を参照して例外。備蓄60の条件で出発・局所帰還が起きていない。観測1200回の期待も実測1001回と不一致。
- `rock_gate/parent_plan_switch_checks.jl`: 同様に備蓄60の条件で採取・枯渇・親計画切替が発生していない。枯渇処理自体の不具合とはまだ断定できない。
- `rock_gate/food_site_observation_checks.jl`: 学習結果の `models["known_food"]` 参照が `KeyError`。現在のモデルキー・記録契約を確認する。
- `julia_migration/lw_integrated/body_purpose_checks.jl`: `returning!` が未定義で停止。旧APIの検査を現在の設定経路APIと照合する。後続には生ドングリ非可食・夜間活動を前提とする検査もあるため、名前だけの置換で対応完了にしない。

旧仕様検査として下記へ移した4本を除き、残件は通常CIで引き続き検出する。検査条件が古いのか実装の不具合かを個別に確認し、
本体の認知・交換ルール変更はCI整理から分ける。全体がgreenになるまで成功扱いにしない。

## 通常CIから外した旧仕様検査（2026-11-06）

ユーザーの旧検査整理方針に基づき、以下は `suites.json` から外す。
コードは元の場所へ保存し、必要時は `julia --startup-file=no --project=. <path>` で手動実行できる。
過去の実験再現では当時のコミットと環境も合わせる。現行HEADで通ることは保証しない。

| path | 外す理由 | 現行検査として作り直す場合の条件 |
|---|---|---|
| `experiments/julia_migration/lw_integrated/body_purpose_checks.jl` | 未定義の旧API `returning!`、生ドングリ非可食、夜間活動の旧前提 | 現在の設定経路API・食品・睡眠仕様に基づいて身体目的切替を検査する |
| `experiments/rock_gate/post_return_idle_checks.jl` | 旧食料入力から毎日外出・帰還・待機を期待し、睡眠遮断分を観測集計へ含めていない | 待機の適格性と自律的な帰還頻度を分離し、睡眠・待機・観測の区間を別集計する |
| `experiments/rock_gate/local_success_checks.jl` | 備蓄60でも活動計画と局所帰還が必ず存在する前提、睡眠を含む全tickで観測する期待 | 実際に開始した親計画に対して局所成果が親成功にならないことを検査する |
| `experiments/rock_gate/parent_plan_switch_checks.jl` | 備蓄60のシーンでも短時間で採取・枯渇することを必須にする旧実験条件 | 採取が成立した条件から、残量観測と目的切替・帰路保持を確認する |

ファイル単位で外すため、同居する単体検査も自動実行対象から外れる。代替で全てを
網羅したとは扱わない。特に親計画の統合挙動・待機適格性の検査範囲には不足が残る。
`food_site_observation_checks.jl`、`depleted_home_route_checks.jl`、
`search_resistance_checks.jl`、共通日次計画・保存再開・睡眠検査は引き続き実行する。
交換・援助の成立条件や `known_food` の記録契約はまだ原因を確定していないため、
「古い検査」として一括除外しない。今回の整理だけでCI全件成功になるとは扱わない。
