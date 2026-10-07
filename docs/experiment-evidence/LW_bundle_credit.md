# 親Hによる拘束強化の実装と30日確認

2026-10-07、基準3fc0399。[契約](../experiment-contracts/LW_bundle_credit.md)。
seed20261005、A/B/C、軽量World30日。Sleep整理ありの保存済みrunを対照とする。

選択変更5判断から、同一親trialの重複を除き3件の試用を登録した。

| 個体/操作obs末尾 | 保存した親H | 親評価 | 強化 |
|---|---:|---|---:|
| C/1550 | 12 | 未充足 | 0 |
| C/1890 | 29 | 未充足 | 0 |
| B/5785 | 0 | 未充足 | 0 |

Aは適格試用なし。未評価pendingは全員0。Hが大きくても成功未確認なら強化しない。
全体は採取98・食事96、最終reserve A74.95/B82.01/C81.07。
形成束47/73/65、再活性化106、候補変更5で対照集計と同じ。
自然運転で成功強化から行動変更へ至る例は今回0件。

合成試験では選択時H=6でcredit6、H=30で有限上限8、複数束への等分、
成功時の次選択差、未充足/比較不能/最終操作差替えの非強化、再処理非増加、
本人binding、shadow非介入を確認。新規6件を含む関連45テストPASS。
既存5秒評価のreserve>80を使用し、操作成功だけを親の成功へ昇格しない。

4608操作、食料保存・重複/時間重複操作なし、束と出典重複なし。
全体suite/Luanti未実行。生ログ outputs/bundle_credit/enabled.jsonl。
[全試用・比較・集計](LW_bundle_credit.json)。
実行: `python -m integrations.lightweight.bundle_credit_campaign`。
