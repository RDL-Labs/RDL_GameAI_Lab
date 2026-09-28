# L15A — 早回しの負荷境界

2026-09-28、基準 `e95a454`。[契約](../experiment-contracts/LUANTI_L15A_speed_probe_contract.md)。
実Luanti・同じローカルHTTP Runtime・3個体を使用。
草地、seed20260928、steady、疲労休憩・内部参照・目標再評価enabled、障害除去を固定。
既存の行動係数、観測周期、操作予算、学習規則は変更していない。

## 初回の16秒比較

| 要求倍率 | World壁時間（秒） | 最大pending/個体 | 結果 |
| --- | ---: | ---: | --- |
| 1 | 16.118 | 1 | 基準、192指令・結果 |
| 2 | 8.100 | 1 | 全指令種別・量・理由・結果が基準と一致 |
| 4 | 4.109 | 2 | 通信破綻なし。ただしB5件/C1件の系列差 |
| 8 | 2.129 | 5 | expired15、stale6、stopped4 |
| 16 | 0.468（中断） | 9 | pending上限8を超過し明示停止 |

8倍は元のreplay監査自体はPASSする。期限切れ等を正しく拒否した記録を再現できるためである。
しかし、早回しによって予定の身体作用を実行できなくなっており、運用には不適格とする。
16倍の失敗snapshotも保存し、成功runだけを選別しない。
最大sim刻みは初回1〜16倍で35.6/104.6/124.7/70.0/78.1ms。
今回の主な限界は取得枠の飛び越しよりも、通信と身体指令の対応が追いつかないことだった。

## 64秒確認

初回結果を見た後、1/1.5/2倍・16秒×4期間を固定して追加実行した。
期間ごとの予算更新は従来どおり。一期間の探索期限を64秒へ延ばしたものではない。

| 倍率 | World壁時間（秒） | 最大pending | 通信・取得監査 | 1倍との系列差 A/B/C |
| --- | ---: | ---: | --- | --- |
| 1 | 64.134 | 1 | PASS | 0/0/0 |
| 1.5 | 42.798 | 1 | PASS | 0/95/49 |
| 2 | 32.113 | 2 | stale3件 | 94/129/105 |

各runは768観測。1.5倍は実効約1.496倍、World実行時間は約3分の2。
起動・snapshot保存・完全replayを含む全処理は別で、78.25/56.77/47.21秒だった。
倍率に比例して検査処理まで速くなるわけではない。

## 同値性の限界

1/1.5倍の64秒確認をもう一度行った。両方とも768観測、pending最大1、
expired/stale/stoppedなし。1.5倍のWorld壁時間は42.795秒、実効1.497倍。
1.5倍同士は全指令・結果系列が一致した。一方1倍同士はCの49件が異なった。
このfixtureの実時間HTTP運転には通常速度にも揺れがあり、倍率だけの因果効果を主張しない。

**当面の探索用候補は1.5倍**とする。64秒で拒否が出た2倍から25%下げた値で、
2回の確認を通った範囲の経験的な余裕。最大安全倍率の証明ではない。
この機械と条件で64秒を約42.8秒へ短縮できた。既定値の一括変更は行わない。
高負荷・別World・別個体数で再確認し、stale/expired/pending増加が出たら速度を下げる。

1.5倍でも長い行動系列は1倍と一致しない。短い2倍の一致を長時間へ外挿できなかった。
同じsim単位を使っていても、HTTP応答から身体操作までの待ち時間が相対的に増える。
既存疲労回復はwait実行後から次観測までの時間に依存し、局所stateに差が残る。
それが後の閾値や選択へ影響し得る。今回の集計だけで全差分の原因を一つに特定しない。
探索性能の倍率間比較や学習効果の帰属には、速度を揃えた対照を使う必要がある。

この機構は離散身体操作のfixture時計を速めるものであり、Luanti一般の連続物理を加速するものではない。
通常設定は1倍のまま。厳密な時間・挙動同値が必要なら、別途決定的な実行時刻/通信調停が必要になる。

## 成果物と再現

`tests/fixtures/luanti_l15a_speed_probe.json.gz` に初回、64秒確認、再確認を分けて保存。
`check_speed_probe.summarize` はreplayの可否とtransport_healthy、系列一致を別に返す。
実機は計10run（9run完走・replay PASS、16倍1runは意図した負荷測定中の容量停止）。
完走のうち8倍と長期2倍はtransport_healthyではない。
専用5件と関連回帰42件、計47テストPASS（27.036秒）。PowerShell構文検査PASS。
リポジトリ全体テストは今回再実行していない。

```powershell
python -m integrations.luanti.tests.run_speed_probe --output integrations/luanti/output/speed-sweep.json.gz
python -m integrations.luanti.tests.run_speed_probe --speeds 1 1.5 2 --periods 4 --output integrations/luanti/output/speed-confirm.json.gz
python -m integrations.luanti.tests.run_speed_probe --speeds 1 1.5 --periods 4 --output integrations/luanti/output/speed-repeat.json.gz
```
