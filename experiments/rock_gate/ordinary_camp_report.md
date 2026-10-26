# 普通の拠点・3日比較（2026-10-26）

狭い入口の難度を下げるため、拠点の囲い岩23個だけを除去した。塔・松明4本・内側舗装・食料への分岐道・初期備蓄・背景の木や岩・AI設定は直前の`return-outlook-rich-3d-20261026`と同一。特徴付与後に囲い岩を除去するので、乱数系列がずれて他の特徴や食料量が変わることを避けた。入力JSONは岩23個と場面名以外の完全一致を確認。

`run.jl`に`--ordinary-only`を追加。既定のwide/narrowは保持し、従来のnarrow生成も配置検査・入力一致を確認した。AI本体の変更はない。出力 `outputs/ordinary-camp-rich-3d-20261026/ordinary/`。

## 結果

| 個体 | 帰還経路MB成功：狭い→普通 | 帰還接続候補の選択 | 最終reserve：狭い→普通 | 経路試行 |
| --- | ---: | ---: | ---: | ---: |
| A | 0→4 | 15 | 90.35→85.20 | 525 |
| B | 0→9 | 18 | 90.35→64.30 | 469 |
| C | 0→3 | 1 | 90.40→84.39 | 593 |

普通の拠点では全員で帰還経路MBの成功が記録された。探索中の帰還接続候補も計34回選ばれ、直前の0回から変化した。帰還見通しが付く候補は計9205回、未確認候補90949回（再評価を含む）。成功経験束はA13/B38/C31。

**囲いの難度が挙動に影響したことは確認できるが、安定した帰還は未達。** 帰還目的の完了累計は2日目末でA43/B62/C58、3日目も同じで増加なし。これは長距離から独立に帰還した回数ではなく、拠点内外で目的が再度成立した回数も含む。全員最後は帰還目的が未達のまま拠点外。

観測用の半径5境界への再入場はA111/B98/C122。ただし初日の強制観察中だけでA67/B71/C81あり、境界付近の往復を多く数える。3日目はA9/B0/C0で、Aも帰還目的の完了は増えていない。この数字を帰還成功回数として扱わない。帰還経路MB成功16件も元の計画全体が正しかった証明ではなく、局所修正後の達成を含む。

食料収支は初期86、消費11、地面61、共有14。採取A14/B3/C4、預入A2/B1/C1。Bは3日目にreserve87.52→64.30へ低下。拠点を簡単にしても、継続して食料確保と休息へ接続する課題が残る。

## 計測と検証

3日正常完走。呼出し381.06秒（6分21秒、コンパイル込み）、ピークRSS1.38GB、累積割当180.97GB。狭い版242.09秒より実行が長くなった。行動と経路試行が大幅に変わっており、世界の描画や衝突処理だけの速度比較ではない。

普通の配置13、食料道19、生活整合16項目PASS。親・経路・帰還見通し監査PASS。従来narrowの準備検査52項目PASS。runtimeは直前の3442734のまま。監査スクリプトは任意のCASE引数を受けられるようにし、既定はnarrowを維持。

実行コマンド（Juliaのプロジェクトとdepotは既存環境を使用）:

```text
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/ordinary-camp-rich-3d-20261026 --ordinary-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on --home-observation on --camp-provisions 4 --mb-sensitivities experiments/rock_gate/sensitivity_spread.json --world-features on --similarity-learning on
```

[集計](ordinary_camp_3d_summary.json)、[結果](evidence/ordinary-camp-three-day/report.json)、[配置図](evidence/ordinary-camp-three-day/layout.svg)、[manifest](evidence/ordinary-camp-three-day/manifest.json)、[provenance](evidence/ordinary-camp-three-day/provenance.json)。
