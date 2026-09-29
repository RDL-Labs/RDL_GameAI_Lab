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

## 30日比較（2026-09-29）

実装基準 `b6baab5`。上記3日比較と同条件のままdays=30へ延長。
seed20260930、A/B/C同設定、閾値2・left、有限資源、便数による早期終了なし。
両条件ともexit 0、1920秒の仮想時間・23040観測で完走。実時間はenabled約54.7秒、disabled約55.3秒（性能比較ではない）。

| 条件・個体 | 実移動量 | 実旋回回数 | 再見回し | 方位参照 | 左への再見回し | 採取 |
|---|---:|---:|---:|---:|---:|---:|
| disabled A | 53 | 237 | 112 | 0 | 0 | 0 |
| enabled A | 53 | 238 | 112 | 112 | 28 | 0 |
| disabled / enabled B | 3 | 1 | 0 | 0 | 0 | 0 |
| disabled / enabled C | 2 | 1 | 0 | 0 | 0 | 0 |

全員で採用モデルなし、learning records=0、最終food H=29。配送便は両条件0。
ただしhome_like_observedは多く、配送0を「全員が拠点へ戻れない」とは解釈しない。持ち帰る資源自体がない。
Aは両条件ともlandmark_no_candidate_after_scanが3248判断。B/Cはacquisition_incompleteがそれぞれ3715/3717判断。
方位consumerはその取得不完了待機には権限を持たず、B/Cでは一度も起動しない。

結論: 方位を参照した左右選択差は長期にも残ったが、総移動量・採取・配送の改善はなかった。
単一seed・同一個体設定の結果であり、方位能力一般の無効性ではない。現consumerは再見回しの符号選択だけで、帰還・目印記憶・地面再取得の仕組みではない。
次の切り分け候補は、本人の取得不完了から有限に再観測する権限、および見回し後に観測済み候補を選べない理由。今回これらの挙動は変更していない。

全ログはlocal ignored `integrations/lightweight/output/orientation_30d_{enabled,disabled}.jsonl`。
保存集計は `tests/fixtures/lightweight_orientation_30d_comparison.json`。manifest、個体別・日別集計、待機理由、summary、元ログSHA-256を含む。
`python -m integrations.lightweight.audit_orientation_long`で再集計し、完走・同一初期条件・閾値・見回し上限を検査済み。
今回は実行・集計・文書のみ。runtime変更なし。全体unit test・Luanti実機は再実行していない。
