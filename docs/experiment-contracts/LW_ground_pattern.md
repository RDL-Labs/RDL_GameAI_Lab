# 観測点から地面のまとまりへ

2026-10-07 / FINITE IMPLEMENTED / 既定off、ground_appearance必須。
Runtimeの本人観測を入力にした純粋関数runtime.ground_pattern.recognize。
World座標・wear・通行者・資源配置は参照しない。

現行5角度×3距離の観測格子で、角度または距離の隣接点を結ぶ。
sampledかつ同じappearanceの連結成分を、一つのpatternとして保持する。
異なる見た目、遮蔽、斜めのみ隣接の点は結ばない。最大15成分、各最大15点。
出典は元観測のsourceとsample_indices、結び付きはsample_links。
参照IDは観測sourceと点集合から生成し、永続的な物体同一性を主張しない。

相対極座標を平面へ写し、3点以上かつ位置分散の主/副軸比が4以上なら
sampled_band_candidate、それ以外の3点以上はsampled_patch、2点以下はinsufficient_shape。
角度/距離の広がり、隣の遮蔽点、取得範囲端への接触も保持する。
全点遮蔽はunavailable、空のgroups。見えないことを対象不在にしない。

これは疎な観測点の規則的配置候補である。点間の物理的連続性は常に未確認。
川/道の意味同定、曲率や幅の精密推定、枝分かれ同定、遮蔽先補完、経時追跡、
M_Bへの学習採用と行動利用は未実装。広い面まで無理に道と認識しない。
グループの点・リンク表現は保持するため、後段が必要なら部分へ戻れる。

EnergyAgentのdecisionにground_patternsとして保存し、実験ログにも出力する。
既存のaction/score/観測・学習contextへは入れない。原観測を変更しない。
ground_pattern_enabledで明示起動する軽量World経路であり、Luanti統合ではない。
