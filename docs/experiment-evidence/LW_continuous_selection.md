# 継続選択と旧回数上限の比較

2026-10-03。基準 `657185f`、[契約](../experiment-contracts/LW_continuous_selection.md)。実行面はPython lightweight Worldであり、新しいLuanti実機比較ではない。

## 条件と結果

seed20261001、A/B/C、各5日、8資源地点各12単位、共有有限在庫、縄張り重複3地点。脅威disabled/enabled × selection legacy/continuous。予算リセットを追加せず比較した。

| 脅威 | 選択 | 採取 | 持帰り合計 | 終了時所持 A/B/C |
|---|---|---:|---:|---|
| なし | legacy | 60 | 60 | 0/0/0 |
| なし | continuous | 36 | 18 | 6/12/0 |
| あり | legacy | 46 | 36 | 0/10/0 |
| あり | continuous | 41 | 33 | 8/0/0 |

脅威ありlegacyはBが `safety_unresolved`、32操作で打切り。continuousではA/Bが `safety_uncertain` のままでも方法選択を継続した。最大警戒操作数924。旧32操作を越えた警戒中にも実commandはmove798件、turn800件。これは成功や安全の保証ではなく、回数終了により選択不能にならなかった記録である。

全continuous判断で候補集合と選択元を検査。候補最大9・方法状態最大64・履歴最大32を保持。警戒中pickupなし、共有在庫保存を検査。終了時はAが安全方法のmove、Bが安全方法のturn、Cが夜間waitを選択していた。

採取・帰還は改善しておらず、脅威なしでは持帰りが大きく減った。新たな候補選択は既存の経路実行を変える。循環・迷子・帰還未達を解決したとはしない。局所の見え方変化は大目的への進展とは別である。

## 再現と検証

```
py -3.11 -m unittest tests.test_continuous_selection -v
py -3.11 -m integrations.lightweight.continuous_selection_comparison --run
```

専用13テストPASS。連続140判断、旧上限後の選択継続、未知地面、身体未対応、再送のH非加算、警戒の不完全観測、符号付き見回し、現在地面による旋回後前進、採取/荷下ろし/夜間権限、未実行経路への誤強化防止を検査。

関連91テストPASS（専用13を含む）。全体discoverは1212件実行、1152 PASS・51 skip・7 failures・2 errors。全体実行後に専用試験を2件追加しているため、全体件数を1214 PASS等とは表記しない。

旧探索再生のreceipt不一致7件は、runtimeモジュールを基準HEAD `657185f` のソースへ差し替えて同じ7試験を実行しても全件再現した。別のerrorは既存campaign failure試験が一時fixtureへ `runtime/resource_exploration.py` を用意していない問題で、基準でも再現。残るerrorは旧multi-resource seed再生中のPython deepcopy TypeError。全体PASSとはしない。旧fixture更新や無関係な失敗の抑制はこの変更に含めない。

旧seed試験を単独再実行しても6件中1件が同じdeepcopy TypeError、5件PASS。原因は未確定。見回し中に別種の旋回が入った場合の積算リセット修正後、選択/警戒関連38件もPASS。

集約記録: `tests/fixtures/lightweight_continuous_selection.json`。生ログ: `integrations/lightweight/output/continuous_selection_*.jsonl`（git対象外）。再実行中に1回Python deepcopy内TypeErrorで中断した試行があり、4条件を最初から再実行して完了した。原因未確定の中断を受入成功には含めない。
