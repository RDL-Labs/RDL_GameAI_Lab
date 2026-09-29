# LW-3: 30-day paired campaign

基準 `e40bfe8`。World/Runtime/係数は変更せず、計画済みseed 20260928、3個体、8資源地点×12単位、最大30日／3持帰りで実行。変更条件はmodel field disabled/enabledのみ。同じrun_idは、独立プロセスの対応比較で参照文字列を揃えるために使用し、stateは共有していない。

## 結果

| 条件 | 完了日数 | wall実行秒 | 各個体観測 | 採取 | 持帰り | 採用モデル | field適用 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| disabled | 30 | 30.006 | 7,680 | 0 | 0 | 0 | 0 |
| enabled | 30 | 29.573 | 7,680 | 0 | 0 | 0 | 0 |

各runは23,040件の観測・行動・結果を保存。終了理由はtime_limit。初期World一致を確認し、対応する全packet/command/result/bodyに差なし。wall時間差を性能改善とは扱わない。M_B形成も適用機会もなく、M_Bの有効性を評価できた実験ではない。

| 個体 | 移動距離 | move | turn | wait | acquisition_incomplete |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 37 | 37 | 128 | 7,515 | 3,661 |
| B | 34 | 34 | 124 | 7,522 | 3,678 |
| C | 0 | 0 | 1 | 7,679 | 3,719 |

acquisition_incompleteの全該当観測でdistantがPARTIAL。ground/food/landmarksはその時点でcompleteだった。有限ray観測から得た特徴が4件上限を超えると遠景がpartialとなり、既存判断側の取得完全性条件が探索を止める。食料visibleが非空の観測は全個体0件。これは観測範囲内の記録であり、Worldの資源不在ではない。

日数延長でこの停止は自然解消しなかった。LWの水平fanを既存遠景の4特徴payloadへ投影する際の取得範囲・集約・上限と、判断側がどのchannelの完全性を要求するかを次に整理する。見えていないものを不在としたり、partialをcompleteへ偽装したり、Hで無条件に進ませる変更はしない。今回の比較終了後に別条件として契約化する。

## 保存と確認

- `tests/fixtures/lightweight_world_30day_disabled.jsonl.gz` (2,259,771 bytes)
- `tests/fixtures/lightweight_world_30day_enabled.jsonl.gz` (2,259,139 bytes)
- `tests/fixtures/lightweight_world_30day_comparison.json`: 初期条件、全体/個体/日次集計、入力hash、source hash、差分集計。
- 新しい`integrations/lightweight/compare.py`は保存ログを順次読み、個体・操作結合、重複、時刻順、在庫差と採取数、終了summaryを検査する。Runtimeへ書込みしない。
- lightweight関連Python: 9テストPASS（比較器3件、既存World6件）。全リポジトリテスト・Luantiは未実行。
- p5配下の再生画面で各gzipファイルを選択して読める。30日ログのブラウザー再生負荷は今回は未測定。

LW-3の事前固定条件比較は完了。学習由来の行動差は未成立。LW-4のHは未接続。
