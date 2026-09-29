# Initial orientation comparison

2026-09-29。軽量Worldの同条件disabled/enabled比較。各3個体・3日、2304取得、192秒の仮想時間で完走。

| 条件 | 方位consumer参照 | 左への再見回し | 採取 | 帰還 |
|---|---:|---:|---:|---:|
| disabled | 0 | 0 | 0 | 0 |
| enabled | 4 | 1 | 0 | 0 |

130.75秒のAで、同じ従来観測内容から右90度が左90度へ変化。累計の最終command差は2件で、後続160秒の差は経路分岐後の結果であり同一入力比較ではない。
方位入力の利用と身体旋回差は成立。探索・採取・帰還改善は未確認。B/Cの取得不足を解消する機構ではない。

実行方法: `python -m integrations.lightweight.timed_harvest --output <path> --days 3 --seed 20260930 --skyline-subrays --no-return-target --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled`。対照は最後をdisabledにする。
全ログはlocal ignored `integrations/lightweight/output/orientation_{enabled,disabled}.jsonl`。同じ比較は `tests/test_initial_orientation.py` の実World試験で再実行できる。

検証: 方位専用5件と関連31件、計36件PASS。量子化・折返し・昼夜・個体束縛・取得不可・同日履歴・再送command・実World初回同入力差と見回し枠を確認。
リポジトリ全体テスト、Luanti実機、HTTPは今回未実行。
