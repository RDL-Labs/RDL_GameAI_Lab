# 道の見た目は観測し、利用は未接続

2026-10-07、基準b2802bb。[契約](../experiment-contracts/LW_ground_appearance.md)。
軽量World seed20261005、A/B/C30日、地面回復あり。保存済みground_recoveryと比較。

- 各個体7680観測、合計23040観測。全観測のschema/本人/時刻/姿勢束縛を検査。
- 15点×23040=345600点。grass213524、trampled_grass77270、bare_ground46275、occluded8531。
- 全9216件のdecision commandとcompleted command/resultイベントが対照と完全一致。
- 採取94/食事94、最終reserve A85.28/B93.01/C97.28で対照と一致。
- 既存の食料保存・操作重複/時間重複なし監査もPASS。

新規3件を含む関連21テストPASS。Runtime観測保存、再送、保護された観測境界、
地面回復による新規見た目の変化、過去観測不変、遮蔽、不正参照と上限拒否を確認。
全体suite/Luanti未実行。「道を知って利用した」「道の行き先を理解した」とはしない。

[観測集計](LW_ground_appearance.json)。生ログ outputs/ground_appearance/enabled.jsonl。
実行 `python -m integrations.lightweight.ground_appearance_campaign`。
比較 `python -m integrations.lightweight.audit_ground_appearance`。
