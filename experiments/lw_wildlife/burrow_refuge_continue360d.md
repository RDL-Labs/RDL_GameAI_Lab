# 巣穴退避版90日から追加360日

2026-11-09。入力checkpoint: C:/Users/ken_m/Documents/Codex/rabbit-burrow-refuge90d-20261109/checkpoints/day-090.jls。
出力: C:/Users/ken_m/Documents/Codex/rabbit-burrow-refuge-continue360d-20261109。
追加360日、通算90→450日。兎135、捕食者1生存の状態から、世界時間・草・身体・親子・妊娠・記憶・乱数・授乳pendingを引継ぐ。
草倍率1.5/二層草/泳ぎ/CPU-GPU auto、指数型候補・授乳成立・警戒比較・巣穴退避の設定を維持。
継続引数のbaseline/fullは再初期化を行わない指定。配置と草はcheckpointを使用し、元のdiverse/patchy/distributedを上書きしない。捕食者とMBもそのまま。
日次時間・累積時間・候補処理・生存/出生/死亡を記録。世界の出生/死亡累計は90日までの分を含むため差分で読む。プロセス内候補作業/警戒比較統計は新規起動で0開始。
前回90日399.3033秒の単純4倍なら約26分37秒だが、繁殖数・処理量次第で変動する。
完了はexit_code=0、completed.json verified=true/days360/start_day90/end_day450を確認。起動時点では結果未確定。
