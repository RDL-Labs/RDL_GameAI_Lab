# Local return: 30-day comparison

2026-09-29、基準`3825808`。seed20260930、3個体、30日、有限資源、閾値2、left、方位・探索reposition有効、便数終了なし。
新しい局所荷下ろし観測、到達・作業確認、帰還候補拡張を同時に追加した比較。単一因果の分離ではない。

| 個体 | 旧採取 | 新採取 | 旧持帰り | 新持帰り | 新便数 | 旧移動量 | 新移動量 |
|---|---:|---:|---:|---:|---:|---:|---:|
| A | 12 | 16 | 0 | 16 | 2 | 51 | 772 |
| B | 22 | 32 | 0 | 32 | 2 | 39 | 119 |
| C | 14 | 0 | 0 | 0 | 0 | 120 | 403 |

新runはexit 0、1920秒・23040取得で30日完走。実時間約179秒（性能比較ではない）。
A/Bは1日目と2日目に各1便、合計48単位を実荷下ろしし、全員の携行量は最終0。
Bは既存学習経路で12記録と採用M_B、A/Cは採用なし。

帰還repositionはA148操作、B23操作、C44操作。
Cでも22旋回、旋回後21歩、直接1歩が発生し、「同じ場所で見回すだけ」から位置変更へ進んだ。
最終home Hは全員0。ただしCの採取は0であり、全個体の成果改善ではない。
共有Worldで行動が分岐し、採取の割当も変わった。Cの採取減少の原因を資源競合だけとは確定していない。
残り4地点の資源は未取得。長期の探索最適化や全資源回収の達成ではない。

## 初回実装の不成立も保存

`local_return_30d.jsonl`では配送0、採取34。
A/Bは迂回旋回直後に塔方向へ戻され、位置変更がほぼ出なかった。
Cは空荷の到達後も荷下ろし待機を続けた。
修正で、保留stepの現在観測による再確認を通常接近より先に置き、空荷の局所到着と有荷の配送完了を分離した。
修正後ログは`local_return_30d_v2.jsonl`。初回結果を成功Evidenceに置き換えず両方保存する。

## 検証

専用8件＋関連40件、計48テストPASS。
局所可視性・出典、near非完了、到達時作業要求、受理後完了、空荷到着、旋回後の権限、身体対応、上限、荷下ろし再送、夜間自動配送なしを確認。
監査スクリプトは3runの完走・manifest条件、帰還phase、追加操作の日16回上限、現在の候補内の操作を検査。
全体suite・実Luantiは未実行。

実行: `python -m integrations.lightweight.timed_harvest --output integrations/lightweight/output/local_return_30d_v2.jsonl --days 30 --seed 20260930 --skyline-subrays --no-return-target --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled --return-completion-mode enabled`
監査: `python -m integrations.lightweight.audit_local_return`
保存: `tests/fixtures/lightweight_local_return_comparison.json`。旧対照・初回・修正後の集計、元ログSHA-256、最終World身体位置（実験者側のみ）を含む。
全ログはlocal ignored `integrations/lightweight/output/`。
