# Nested local models: multi-seed movement continuity

2026-09-29、実装基準`0062f6a`。今回の優先は効率より、有限な行動切替で位置移動を継続すること。
World配置seed20260928/20260929を追加実行し、完了済み20260930と比較。
各3個体・30日・23040取得・1920秒。追加2runともexit 0。runtime・係数変更なし。

controller seed=20260928、goal閾値2、left、steadyを全個体で固定。資源8地点×12単位は全員共用。
方位、探索reposition、局所帰還、nested modelをすべて有効、便数による早期終了なし。
World seedは地形と資源配置を変更する。候補選択seedの独立sweepや性格混在の比較ではない。

| World seed | A採取/配送 | B採取/配送 | C採取/配送 | 合計 | 便数 |
|---|---:|---:|---:|---:|---:|
| 20260928 | 47 / 47 | 6 / 6 | 19 / 19 | 72 | 8 |
| 20260929 | 28 / 28 | 45 / 45 | 23 / 23 | 96 | 9 |
| 20260930（既存run再利用） | 37 / 37 | 22 / 22 | 1 / 1 | 60 | 8 |

## 今回の主要観測

全9個体runで30日すべてに身体結果forward>0があった。
270個体日中、丸一日並進0の日は0。後半12〜30日も各個体19/19日に並進した。
この指標は「一日のどこかで実移動した」であり、常時移動、全域探索、同じ経路の非反復、目的への進展を保証しない。
効率や経路長は合否に使わない。

seed20260929は全96単位を取得し、枯渇後も移動を継続した。個体がWorld全体の資源枯渇を知る設定ではない。
全runの最終携行0、home H=0。全員に少なくとも1配送あり。
成果の個体順位はseedで変わる。Cは1/19/23単位となり、個体Cというラベルだけで低成果が決まるわけではない。
単一機構の因果対照ではなく、現在の統合設定の有限な配置比較。

## 保存・再実行

`python -m integrations.lightweight.timed_harvest --output integrations/lightweight/output/nested_seed_<seed>.jsonl --days 30 --seed <seed> --skyline-subrays --no-return-target --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled --return-completion-mode enabled --nested-model-mode enabled`

集計: `python -m integrations.lightweight.audit_nested_seeds`。
完走、配置以外のmanifest一致、局所状態上限、介入方向・phase・日予算を検査。
保存集計: `tests/fixtures/lightweight_nested_seed_comparison.json`。元ログSHA-256、日別実移動・選択回数、個体別結果と最終モデル状態。
全ログはlocal ignored output内。20260930は`nested_models_30d_final.jsonl`を再利用し、再実行と数えない。
今回は2run実行＋3runログ監査。runtime変更なし、unit全体suite・Luantiは未実行。
