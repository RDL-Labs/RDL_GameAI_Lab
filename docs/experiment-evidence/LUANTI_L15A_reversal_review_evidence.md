# L15A — 逆旋回停止後に一度だけ見直す

2026-09-28、基準 `b72d0ab`。[契約](../experiment-contracts/LUANTI_L15A_reversal_review_contract.md)。
単一32秒作業・3個体・1.5倍・草地・障害除去を固定し、disabled/enabledを実Luantiで比較した。
受入2run・768通常観測。全wire・最終state・身体結果・stock・休憩・目標再評価を既存監査で再生PASS。

## 実機で成立した経路

| B | slot64 | slot65 | その後 |
| --- | --- | --- | --- |
| disabled | 逆旋回停止、対象を除外、wait | goal_budgetでwait | 待機 |
| enabled | 対象と旋回履歴を保留、wait | 新しい通常観測で同じ反転要求、保留確定、wait | 待機 |

enabledのslot64は16,016,570µs、slot65は16,251,037µsで取得。
両方とも実身体結果waited、移動量0・旋回量0。取得時の粗い見え方は一致した。
slot64では対象refをblocked_targetsへ入れず、approachと停止時の姿勢・旋回方向を保持した。
slot65では`same_reversal_deferred`となり、対象を期間内の除外集合へ移した。
待機を挟んだだけで前回の旋回方向や連続旋回数を忘れる経路にはしていない。

A/Cはこの追加検討を起動しなかった。Bも開始1件・再検討1件であり、繰り返し起動はない。
disabled/enabledとも移動距離A17.414・B28.071・C9.828、採取0。
**静止したままの再観測は成立したが、今回のWorldでは移動再開や採取改善につながらなかった。**

これは新しい観測を取得しなかったのではなく、取得した材料から同じ反転要求が出た結果。
通行不能や資源価値の負例、新M_Bにはしない。
現在の条件が変わって非反転のmove/turnが選択された場合の解放、採取優先、
姿勢・鮮度・結果欠測・取得不完全時の保留は合成Python試験で検査し、実機成功例とは分ける。

## 次の境界

今回で、停止と対象除外の間に「理由を持って一度見直す」段階を挟めた。
静止再観測だけでは材料が変わらなかったため、次に比較するなら有限な見回しなど、
何を変えて何を追加取得するかを別契約で定める段階になる。
反転防止を解除することや、無制限な目標・接近予算の更新とは分ける。

## 除外記録と検証

連続旋回数の保持を追加する前のpilotは作業出力へ保存し、受入には数えない。
修正後の最初の再実行はHTTP接続失敗で中断した。LuantiログはCould not connect to server、
原因はこの記録だけでは未特定。実装条件を変えずに取り直した2runを受入とした。
中断snapshotは同梱archiveの`excluded_attempts`へ保存し、成功記録で置換していない。

成果物: `tests/fixtures/luanti_l15a_reversal_review.json.gz`。
再送は同じcommand・追加観測0・追加frame0で、判断stateや検討枠を変更しない。
設定変更の拒否、個体別最大1件、待機後も旋回履歴を保持することを検査する。
専用6テストPASS（2.022秒）、関連65テストPASS。関連は旧steering・目標再評価・作業期限・
休憩・内部参照・replay可搬性。PowerShell構文検査PASS。全体テストは今回再実行していない。

```powershell
python -m integrations.luanti.tests.run_reversal_review --output tests/fixtures/luanti_l15a_reversal_review.json.gz
python -m unittest discover -s tests -p test_reversal_review.py
```
