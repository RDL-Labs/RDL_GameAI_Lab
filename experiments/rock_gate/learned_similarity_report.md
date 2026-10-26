# 類似基準を経験から学ぶ：新仕様世界で3日

2026-10-26。[設計](../../docs/design/LW_Learned_Similarity.md)。前回rich-connected-3d-20261026と学習フラグ以外の入力が完全一致。固定個性感度A=.5/B=1/C=2は維持。初期の認識重みは距離帯2、相対配置1。

| 個体 | 終了時の距離重み | 終了時の配置重み | 正/負の更新 | 最終reserve | 再入場 |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 2.0693 | 0.8961 | 793 / 1196 | 90.35 | 0 |
| B | 2.1198 | 1.4872 | 127 / 645 | 90.51 | 1 |
| C | 2.0703 | 1.3096 | 56 / 339 | 90.48 | 0 |

計3156回の経験ペア更新。上下限への張り付きなし。独立した成功3156件ではない。不明比較はA59490/B54269/C57708。通常の実行済み遷移から学習でき、経路MBが選ばれない初期段階でも係数は更新された。

**経路MB開始は全員0のまま。** 報告JSONと60秒ごとの位置/エネルギー記録は前回と完全一致。候補の比較基準は変わったが、実際の行動改善は示していない。Bの1再入場も新しい学習の効果ではない。認識基準の学習だけでは、観測されたグラフの経路不足・目的条件・候補化の問題は解決しない。

237.33秒（コンパイル込み）、ピークRSS1.27GB。前回229.18秒だが単発計測であり性能差の確定ではない。専用12・認識27・既存の親/経路/感度216・実配置69項目PASS。親/経路監査、係数の有限性・範囲・バッファ64件、入力差分も確認。

検査:

    julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_similarity_learning_checks.jl

実行は既存の新仕様3日条件に --similarity-learning on を追加。offで固定基準へ戻せる。[学習記録](evidence/learned-similarity-three-day/learning.json)、[結果](evidence/learned-similarity-three-day/report.json)、[manifest](evidence/learned-similarity-three-day/manifest.json)。
