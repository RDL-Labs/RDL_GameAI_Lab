# Incomplete-view reposition: 30-day comparison

2026-09-29。基準 `449c793` に有限repositionを追加。
seed20260930、3個体、30日、左右left、goal閾値2、方位enabled、有限資源、目標便数なし。
既存orientation-enabled 30日ログを対照として再利用し、追加mode以外のmanifest一致を確認。
新runは1920秒・23040取得、exit 0。実時間約74秒。

| 個体 | 対照移動量 | 有効時移動量 | 対照採取 | 有効時採取 | 追加操作 |
|---|---:|---:|---:|---:|---:|
| A | 53 | 51 | 0 | 12 | 11 |
| B | 3 | 39 | 0 | 22 | 9 |
| C | 2 | 120 | 0 | 14 | 10 |

合計48採取、4地点が枯渇。全員の配送便は0で、採取分は携行したまま。
Bは10学習記録と採用M_B、Cは2学習記録、Aは0。観測不足をcompleteへ書き換えて学習させたものではない。
最終home HはA/B=29、C=28。食料取得後の帰還未達が残る。
追加操作は合計30回（旋回18、一歩12）。観測された候補方向だけを使い、全操作でexploration・元acquisition_incomplete・日16回以内を監査。

解釈: このseedでは観測位置変更への有限権限で採取へ進めた。反復残存だけの効果は未分離で、方向別許可の効果も含む。
帰還成功、全seedの改善、未知の正解経路の学習は主張しない。

専用4＋関連36=40テストPASS。優先権、身体対応、候補除外、旋回後再確認、予算、残存上限・減衰、純粋再評価を確認。
全体suite・実Luantiは未実行。

実行: `python -m integrations.lightweight.timed_harvest --output integrations/lightweight/output/reposition_30d_enabled.jsonl --days 30 --seed 20260930 --skyline-subrays --no-return-target --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled`
監査: `python -m integrations.lightweight.audit_reposition`
保存集計: `tests/fixtures/lightweight_reposition_30d_comparison.json`（manifest・個体別結果・介入／判断理由・元ログSHA-256）。全ログはlocal ignored output内。
