# Sleep関係自動採用と次行動

2026-10-03。基準84e873c。[契約](../experiment-contracts/LW_sleep_auto_adoption.md)。

`python -m integrations.lightweight.sleep_comparison --auto-adoption`。
seed20261002、3個体、3日、縄張り＋巡回・有限資源・継続選択。
両方ともSleep学習あり、自動採用だけdisabled/enabled。
3日補充設定だが期間中に補充は起きない。軽量Python WorldでありLuanti実機ではない。

| 自動採用 | 採取 | 持帰り | A持帰り/残荷 | B持帰り/残荷 | C持帰り/残荷 |
| --- | ---: | ---: | --- | --- | --- |
| disabled | 48 | 15 | 5/21 | 0/12 | 10/0 |
| enabled | 45 | 27 | 5/18 | 0/0 | 22/0 |

有効条件で形成したセルはA6/B6/C4。採取relationを作れない個体も、他の実経験から
局所M_Bを形成できた。寄与適用434判断、context不足624判断、該当セルなし496判断、
モデル未形成660判断。現在候補集合の寄与前後で選択が変わったのは88回（A9/B21/C58）。
二つのWorldログの共通2168観測IDではcommand kind/amount/target_ref差706件。
この706件は行動によってWorldが分岐した後の差も含み、直接の88回とは別の指標。

採取減少と持帰り増加が併存した。この1seed・3日から一般的な効率改善を主張しない。
特に実行成立率は大目標の成果とは違うため、待機等を過大評価する可能性を残している。
現行記録と局所投影の再利用であり、任意の意味・因果関係を発見した結果ではない。

保存: `tests/fixtures/lightweight_sleep_auto_comparison.json`。
詳細ログ: `outputs/sleep_auto/`（非追跡、上記コマンドで再生成）。

専用・Sleep・継続選択・採取・既存学習の関連52テストPASS。
追加の保存World検査を含めた専用5件を再実行。全体テストは今回は再実行していない。
直前コミットの全体結果と今回の関連結果を混同しない。
