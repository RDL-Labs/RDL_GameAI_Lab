# Sleep夜間接続と異種関係検査

2026-10-03。基準 dc4e76c。[契約](../experiment-contracts/LW_sleep_learning.md)。

## 軽量World比較

`python -m integrations.lightweight.sleep_comparison`。
seed 20261002、3個体、3日、有限資源、縄張り＋巡回、継続選択。
3日ごとの補充設定だが、この3日run中に補充境界は到来しない。
Luanti実機ではなくPython World。付属runtime Pythonで実行した。

| 採用方式 | 採取 | A持帰り | B持帰り | C持帰り | Aの初採用時刻 | Cの初採用時刻 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 従来の日中 | 48 | 5 | 0 | 10 | 26.75秒 | 26.5秒 |
| Sleep checkpoint | 48 | 5 | 0 | 10 | 57.25秒 | 57.25秒 |

A/Cは初日の夜にADOPTED、翌日にも同一model_refを保持。Bは採取記録0件で
INSUFFICIENT_EVIDENCE。採取記録はA26、C10件。場へのM_B寄与は両条件0件なので
睡眠による経路改善・効率改善とは主張しない。
両ログの共通2208判断について、commandのkind/amount/target_ref差も0件だった。

Sleep完了はA3晩、B3晩、C2晩。Cの2日目は夜間cycleがなく、睡眠成功として数えない。
8回の関係検査、合計33組。今回の参照窓には主にmove/turn/waitが入り、
pickupと移動の混合比較は合成試験で確認した。直近64観測という制限により
日中早期の採取は異種窓から外れるが、採取用窓には保持される。

保存: `tests/fixtures/lightweight_sleep_comparison.json`。
詳細JSONLは再実行可能な`outputs/sleep_learning/`（非追跡）。

## 検証

専用試験: 日中非採用→夜の実T1採用、再送・個体分離、実wait不足、身体対応不足、
警戒中断、日跨ぎ、経験不足、反例非採用、窓凍結、異種比較とcoverage欠測。
専用8テストPASS。全体テストは1,230件実行＝1,179 PASS＋51 skip、exit code 0（589.604秒）。
全体実行開始後に追加した保存World検査も含め、最終専用8件を別途再実行してPASS。

環境注記: ローカルPython 3.11ではWorld比較のdisabled条件中に標準copy内部の
TypeErrorが発生したため、付属runtime Pythonで両条件を再実行し完走した。
これをSleep起因と断定しておらず、旧環境側の原因調査は今回の範囲外。
