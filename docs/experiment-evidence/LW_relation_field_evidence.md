# Angular relation movement field — evidence

2026-09-29。有限な関係場と実行継続を軽量Worldへ接続。Luanti実機ではない。

## 検証

専用10件＋既存48件 = 58 tests PASS。
複数目印からの方向差、共通yaw変化に対する角度間隔の不変性、曖昧/不完了の除外、成分和、blocked方向非復活、owner保持、旋回後の一歩、reposition引継ぎ、同色でも異なる配置の分離、操作上限、再送を検査。

自然配置seed20261001・3個体・無限資源・30日・便数終了なし。旧directional routeと同じ設定に`--relation-field-mode enabled`を追加。新runはexit 0、全23040取得、1920秒まで完走。旧30日比較は保存済みログ/fixtureを再利用し、今回の再実行とは数えない。
新コードでfield disabledの5日を別途再実行。command列ハッシュが旧方式の最初5日と一致（979e3d69ae8e0660e94c7bd88d20460ab242ea40c0fcb6750d887c5ad058a144）。

|30日|旧・経路命令|新・関係場合成|
|---|---:|---:|
|採取|981|807|
|配送|981|807|
|最終携行|0|0|
|実移動合計|3129|4755|
|旋回|3320|3402|
|終日並進0の個体日|16|1|

新方式の個体別採取/配送: A123、B457、C227。Aの14日目だけ並進0、B/Cは毎日並進。全個体の安定往復や停滞解消を証明するものではない。
終日停止の減少と採取・配送の減少が同時に起きた。複数目印、候補保持、旋回後一歩、直接目標の場への投影をまとめた有限比較なので、改善/悪化をそのうち一機構へ単独帰属しない。

## 実際に使われた処理

field担当操作3674回、そのうち複数目印の関係比較を伴う操作523回。最大3組の角度間隔を同時に使用（アルゴリズム上限10組）。現在Food/帰還目標だけの寄与と関係記憶由来の寄与を別に数える。
旋回後の一歩1029回、既存repositionへの引継ぎ748判断、拮抗判定9判断。これらは全操作の排他的分類ではなく、対応するtrace reasonの回数。

関係比較不能では従来探索へ戻る。残る課題は粗い外観の対応、距離区分近似、日予算、16経路容量など。正確な自己位置/対象同一性/最短経路は得ていない。今回も効率改善は受入条件にしていない。

## 保存・再実行

`py -3.11 -m integrations.lightweight.timed_harvest --output integrations/lightweight/output/relation_field_30d.jsonl --days 30 --seed 20261001 --inexhaustible --skyline-subrays --no-return-target --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled --return-completion-mode enabled --nested-model-mode enabled --directional-route-mode enabled --relation-field-mode enabled`

監査: `py -3.11 -m integrations.lightweight.audit_relation_field`。
現在source/pose参照、加算成分、実行方向のscored状態と高さ上限、日48操作、無限在庫、完走、mode以外のmanifest一致を確認。

保存集計: `tests/fixtures/lightweight_relation_field_30d.json`（日別、個体別、trace集計、旧raw参照と新raw SHA-256）。rawはignored output内。旧互換性確認は`relation_legacy_check_5d.jsonl`。
全体unit suite、Luanti/HTTP実機は今回未実行。
