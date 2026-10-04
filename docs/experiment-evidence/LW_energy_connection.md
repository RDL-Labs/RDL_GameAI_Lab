# エネルギー場の探索接続 — 同じ物性での比較

2026-10-04。基準90c1ecb。[契約](../experiment-contracts/LW_energy_connection.md)。
3個体×3日×4run、seed20261002。軽量Python World。

| 条件 | cost選択寄与 | 採取 | 持帰り個数 | energy単独の候補変更 | 観測最大荷重 |
| --- | --- | ---: | ---: | ---: | ---: |
| 自然地形＋縄張り＋巡回 | shadow（なし） | 0 | 0 | 0 | 0 |
| 同条件 | enabled | 0 | 0 | 53 | 0 |
| 低障害＋危険観測shadow | shadow（なし） | 36 | 31 | 0 | 10 |
| 同条件 | enabled | 36 | 36 | 33 | 13 |

enabledの各runで459判断の既存候補へ場を評価。変更数はSleep寄与より前の候補順位差。
両条件とも同じ重量消耗・抵抗場であり、enabledだけ消耗を軽くした比較ではない。
単一seedの有限結果。自然地形の採取改善はなく、全般的な効率改善は主張しない。

Sleepは自然地形shadowで8完了、enabledで7完了＋1中断。
残り各1個体夜は未開始。低障害では両方9完了。欠けた処理を成功扱いしていない。
Sleepに保存したbody_observationと元観測の一致、身体状態の連続、重複作用0を確認。

専用5＋エネルギー場/荷重/身体/探索/Sleep/継続選択等、計71テストPASS。
実移動の消耗、再送、候補追加なし、未知の非昇格、Sleep条件分離を検査。
全体suite・Luanti実機は未実施。

保存: `tests/fixtures/energy_connection/comparison.json`と4runのjsonl.gz。
dropは依然専用実験側。今回通常探索へつないだ荷重は、食料inventoryの固定単位重量。

## d1dc0df1後のfallback修正

全候補不成立時に元のmovement identityをコピーしていた処理を、
`energy/no_feasible_move` の非trial待機へ変更した。
未知・blockedの両条件で、待機後の観測まで進めても元methodのH=1と
last_selectedが保持され、偽の成功eventが作られないことを検査。
その後、可否が成立すれば通常の移動trialへ戻る。

エネルギー接続/場・継続選択・身体・身体探索・Sleep関連の51テストPASS。
上記4runは以前の保存記録の再検査であり、今回World比較の再生成、
全体suite、Luanti実機の再実行はしていない。
