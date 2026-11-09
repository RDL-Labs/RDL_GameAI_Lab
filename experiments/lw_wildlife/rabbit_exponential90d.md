# 指数型候補数制御90日試験

2026-11-09。出力C:/Users/ken_m/Documents/Codex/rabbit-exponential90d-20261109。
同じ入力/シードの初日から90日。兎100、捕食者1、人なし、草倍率1.5、泳ぎあり、CPU/GPU auto、diverse/patchy/distributed/layered。
指数型ON: minimum1/maximum8/full_H20/curvature3。開始・解除ゲートを迂回。摂取時の親H更新を維持。
暫定固定の候補幅と粗順位であり学習済みMB強度そのものではない。近傍観測は全候補を維持し、遮蔽加点と確率選択を上位候補へ限定。
比較元rabbit-food-acquired-release90d-20261109: 426.3297秒、選択714719、再検討48307、最終129、出生83、幼体餓死15/離乳後0、捕食39。
今回の選択回数はcandidate_work.calls、残した候補総数evaluated、有効観測候補available、1候補選択singleで見る。旧ゲートのfood_pressure.calls/activeは比較に使わない。
処理時間/GC/割当/日次時間と個体数/生存/選択回数を合わせて比較。軌跡が違う単発試験のため処理単体の高速化とは断定しない。
局所試験と通常接続検査は既にPASS。起動時点では90日結果未確定。完了はexit_code=0とcompleted.json verified=true/90日を併せて確認する。
