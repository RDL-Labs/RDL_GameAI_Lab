# Shared access: actual 30-day rerun

2026-09-29、実装基準`f3c5b8f`。seed20260930、3個体、30日、既存local_return比較と同設定。
resource_access=shared-all-agents-v1をmanifestへ保存。1920秒・23040取得、exit 0で完走。
A=16採取/16持帰り、B=32/32、C=0/0。合計48単位・4便。
旧local_return_30d_v2と全commandのSHA-256が一致。共用条件の明記による行動変更はない。

資源地点は実験者用の0始まりindexで集計:

| 地点 | A | B | C | 最終残量 |
|---|---:|---:|---:|---:|
| 0 | 4 | 8 | 0 | 0 |
| 3 | 12 | 0 | 0 | 0 |
| 4 | 0 | 12 | 0 | 0 |
| 6 | 0 | 12 | 0 | 0 |
| 1,2,5,7（各地点） | 0 | 0 | 0 | 12 |

地点0でA/Bの共用を実確認。Cの0は利用権拒否ではなく、この行動系列で採取しなかった結果。
全員が必ず取得する公平性や全地点の発見は保証しない。Cの探索候補枯渇による後半の停止は未変更。

監査は個体別観測参照の生成規則から実験者側で地点を照合し、成功取得総数と地点別最終残量を検査する。
同時作業の結果ログは複数完了後のstockを共有する場合があるため、1行ごとの残量差を1取得と誤認しない。
この実験者用集計は個体へ返さない。

実行は前回と同じCLI（出力名shared_access_30d.jsonl）。監査: `python -m integrations.lightweight.audit_shared_access`。
保存集計: `tests/fixtures/lightweight_shared_access_30d.json`。manifest/summary/利用者別数量/元ログとcommandのSHA-256。
全ログはlocal ignored `integrations/lightweight/output/shared_access_30d.jsonl`。
今回runtime変更なし。30日実行と監査のみで、unit全体suite・実Luantiは未実行。
