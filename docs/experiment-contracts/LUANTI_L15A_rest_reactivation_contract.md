# L15A — 休憩中の有限関係再活性化とモード切替

2026-09-28、基準 `60f2464`。FINITE IMPLEMENTATION / WORLD MODE ACCEPTANCE COMPLETE。
[Evidence](../experiment-evidence/LUANTI_L15A_rest_reactivation_evidence.md)。実Worldの地形寄与・行動差は未成立。
schema `l15a-rest-reactivation-v1`。研究上の位置づけは[モード接続ノート](../design/RDL_GameAI_Cognitive_Mode_Research_Map.md)。

## 比較と権限

同じ疲労休憩・自然草地・3個体steady・seed20260928・2期間で、再活性化disabled/enabledを比較する。
enabled＋2地点control＋配送故障を別runにする。各1run、実時間揺れあり。全条件を実行前に固定。
本機構は情報の参照先を切り替える局所規則であり、生物学的DMN実装でも新しいM_Bでもない。
新規採用・支持数増加・T1再構成は呼ばない。既存の採取学習は従来どおり独立して動く。

## 身体と認知の状態を分離する

| phase | 処理 | 身体 |
| --- | --- | --- |
| external_observation | 現在観測から既存選択 | 既存の権限に従う |
| internal_reactivation | 本人の記録を有限参照し、現在との適用条件を検査 | 今回は有限休憩中。通常観測は継続 |
| resume_review | 新規観測で再検証し、一判断だけ寄与を計算 | 休憩終了後、既存priorityに従う |

`phase`、`previous_phase`、`trigger`、`body_resting`、取得元、model_refを別に記録する。
enabledは休憩開始時に取得、休憩中に再評価、終了時に一回利用。次判断でcacheを捨てるが履歴は消さない。
pickup/上位priorityによる休憩中断、period切替、新しい休憩では古いcacheを流用しない。
取得時計・休憩予算は旧契約のまま。モードによって追加の身体操作や観測を発行しない。
disabledは身体が休憩していてもexternal_observationであり、元の休憩経路とcommand/学習が一致することを検査する。

## 本人の記録と採用済みM_B

休憩開始時に直近16観測と受信済み結果だけを見る。5秒以内でmoveのmoved/blocked、pickupのpicked_up/not_foundを新しい順に最大3件保持。
run/agent/epoch/clock・操作/観測対応を検査。未来の結果・他個体・World座標・全軌跡を使わない。
選択は新しさと結果種別による固定の実験規則であり、記憶の重要性を学習したものではない。
採取成功・移動成功も保存するが、位置や方向を一般化して別の場所を誘引しない。

採用済みM_Bがあれば、既存の採取purposeをそのまま呼ぶ。近距離affordanceがないとunknownになる。
modelなし、失効済み、休憩開始時からmodel_ref変更、既存purposeでunknownを区別する。
現在のM_Bには経路予測がないため、採取関係を方向・道・山の誘引へ変換しない。

## 一時的な関係拘束の近似

blocked move記録について、同じ取得姿勢ref/revision（移動・回転なし）、同じ完全な粗視覚条件、取得から5秒以内なら、前方の現在scored地形へ+0.5の一時costを付ける。
複数記録でも加算は一度で、票を増やさない。永久障害や学習済み法則として保存しない。
欠測・姿勢対応なし・外観条件変化・model変更なら寄与0。観測で除外された方向を復活させない。
適用はresume_reviewの一判断だけ、現在のmove/turnかつ完全な地形に限定する。元のpickup・variation・body gate・既存waitを上書きしない。
新しい方向を強制せず、寄与しても同じ選択でよい。元のterrainと寄与後の選択・根拠operationを分けて保存する。

## 受入・停止点

純粋評価の合成正例で一時costによる選択差、非適用・未知・期限・姿勢・モデル失効を検査する。
実M_B採用経路から作ったmodelで、scope内known/scope外unknown、model不変を確認する。
再送・内容競合・受付途中失敗でmode/cacheの部分更新や再利用を起こさない。
実Luantiは全観測・身体・休憩・モード遷移を再生。適用0件や選択差0件もそのまま報告し、合成正例をWorldでの効果と混ぜない。
この有限比較で止め、一般記憶、自由連想、睡眠、動く身体の姿勢変換、神経ネットワーク間の生理的切替は未実装とする。
