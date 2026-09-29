# Incomplete-view reposition v1

状態: FINITE LIGHTWEIGHT IMPLEMENTED。Luanti未接続。

目的: 局所色観測の一部欠測による全面待機から、現在の方向別身体観測を使って有限に観測位置を変える。
RDL_Demos warp-navigationの、停滞で既存方向への拘束を緩める発想を参考にする。
正確なgoal、BFS、全体地図、共有heat、速度増加、再出現は導入しない。

## 入力と権限

本人の受理済み前観測・command・身体結果、現在packet、元の判断を使用。
`exploration`中の`wait / acquisition_incomplete`だけが起動候補。pickup・帰還・夜・他のwait理由は保持する。
直前結果と現在姿勢・revision・時刻が対応することを必要とする。

9点のground色観測とmovement_surfaceの5方向身体観測は別である。
現在movement_surface.groundのsampledかつ絶対height_delta<=0.5の方向だけを候補にする。
output_limitedでは不実行。blocked/no_surface/unavailableは選ばない。
元のpartialをcompleteにせず、欠測を学習成功材料にしない。
軽量Worldの5方向観測自体は既存の一歩区間と障害物の交差から生成される簡略身体モデルであり、新規に実視覚センサーの精度を証明したものではない。

## 反復残存と選択

局所residualは毎秒0.5減衰。適格な取得不足待機ごとに+1、上限8。
2以上で試行、4未満は±45度内を優先、4以上は現在観測された±90度までの全候補を許す。
狭い候補がなければ観測された候補集合へ広げる。
run/agent/day/追加操作数/規則版のSHA-256で候補を再現可能に選ぶ。正解方位は使わない。
これは局所の応答残存であってcanonical E/H/θ、M_Δ、学習済みM_Bではない。個体差は本比較では加えない。

旋回後、次の観測で前方の身体観測が利用可能か再確認して一歩移動する。
実測旋回が指令と一致しなければ、その旋回計画を根拠にした一歩は実行しない。
通常の判断へ戻った場合は追加操作をせず、保留stepも解除する。
未知方向への強制移動や衝突無効化は行わず、Worldは引き続き実行結果を返す。

追加操作は旋回・移動を合わせ1個体1日16回。日境界で操作枠を更新し、residualは時間減衰する。
状態はdecisionへ保存し、既存の観測再送・操作ID管理を使う。
CLI `--reposition-mode enabled`でopt-in。既定disabled。

## 比較の限界

前回の方位あり30日runを対照として再利用し、manifestを照合する。
方向別許可と反復による選択幅変更を合わせた比較なので、成果をresidualだけの効果とは断定しない。
次に必要なら方向別許可だけの対照を追加する。今回の成果を帰還・一般探索・Luantiでの成功へ広げない。

[Evidence](../experiment-evidence/LW_incomplete_reposition_evidence.md)
