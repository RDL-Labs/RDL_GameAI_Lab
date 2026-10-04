# 簡易エネルギー場 — 有限実行

2026-10-04。[契約](../experiment-contracts/LW_energy_field.md)。

| 条件 | 結果 |
| --- | --- |
| 6個、前方抵抗1、reserve100 | walk |
| 6個、前方抵抗5、reserve100 | 側方detour |
| 6個、前方抵抗5、reserve.2 | 前方body_limited、側方detour |

採用候補の予測deltaと実行後body deltaの一致を確認。
未知・blockedを低costとして選ばず、操作再送で二重消耗しない。

2個体例: Aが実資源6個取得、1個置く、Bが取得、Aの取り戻しはunavailable。
その後の荷重はA=5/B=1。各自の移動を実行し、総重量6、地面残量0を維持。
この受渡し順序は試験側が設定し、所有権や譲渡意図を学習した結果ではない。

専用6＋荷重・身体・探索接続・Sleep統合回帰の計34テストPASS。
全体suite・Luanti実機・長期energy_field統合は未実施。
再実行: `python -m integrations.lightweight.energy_field_comparison`
保存: `tests/fixtures/energy_field.json`。
