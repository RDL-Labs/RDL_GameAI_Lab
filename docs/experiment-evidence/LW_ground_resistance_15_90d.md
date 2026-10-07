# LW統合版：基本抵抗1.5だけ変更した90日比較

2026-10-07、基準25b0fa2。前回90日と同じ形成30日checkpoint、seed20261005、
未学習3個体・各90日（World通算120日）。係数変更は普通地面1.0→1.5のみ。
高抵抗5.0、道軽減式、回復速度、道候補score、H/θ、優先処理は変更しない。
十分に踏まれた普通地面の歩行抵抗は1.25。両条件のmanifestは道M_B接続フラグ以外一致。

| 基本抵抗 | 道M_B | 採取 | 食事 | 移動距離m | 道候補選択 | 道候補の実行 |
|---|---|---:|---:|---:|---:|---|
| 1.0（前回） | disabled | 274 | 269 | 845 | 0 | 0 |
| 1.0（前回） | enabled | 272 | 269 | 912.5 | 13 | 歩行1 |
| 1.5 | disabled | 273 | 270 | 978.5 | 0 | 0 |
| 1.5 | enabled | 274 | 270 | 917 | 3 | 旋回1 |

| 期間 | 採取 disabled/enabled | 移動距離m disabled/enabled | 道候補選択→実行 |
|---|---:|---:|---:|
| 1〜30日 | 88 / 92 | 338 / 359.5 | 2 → 1 |
| 31〜60日 | 92 / 91 | 346.5 / 313 | 1 → 0 |
| 61〜90日 | 93 / 91 | 294 / 244.5 | 0 → 0 |

道候補が存在した判断7、選択3。うち2件はbody_phase_boundaryのwaitが優先。
唯一の実行は30日目A、1858.75秒開始のfood/ground_120、左90度旋回。
実resultはturned/yaw=-90、並進0。その次の判断では同モデルが
not_currently_supportedとなり、rotation_then_stepの継続条件不成立でHが0→1。
続けて出されたcommandはreachable_food_work/pickup。
道が間違っていた/消えた、またはHだけが採取を選ばせたと結論しない。
現在の帯を継続確認できず、別の有効な採取が実行候補になった記録である。

暫定モデル累計936（distinctな道ではない）、最大同時active4、link保持参照6,266、
観測条件変化740。kind/amountは両条件13,824判断中3,350件異なる。
この差には後続の相互作用を含み、直接の道利用数ではない。

両条件ともreserve枯渇なし。最終reserveはdisabled A89.20/B82.99/C79.46、
enabled A91.20/B87.78/C84.76。最小値はdisabled A28.45/B40.72/C54.51、
enabled A28.45/B47.10/C32.94。

各90日完走、食料保存、身体作用の重複/重なりなしPASS。
接続あり全13,824判断の暫定M_B再構築が保存状態と一致。
期間別採取・食事合計もWorld集計と一致。係数変更時の関連48テストはPASS済み。
今回の変更は実行先指定と記録のみで、単体テスト・全体suite・Luantiは再実行していない。

結論: 抵抗差を普通地面にも作ったが、この1seedでは道M_Bの継続利用は増えなかった。
採取数はほぼ同程度。現在の配置は拠点近くに資源があり、遠方への道追従や
一般的な効率改善を主張する試験ではない。結果を見て係数を追加調整していない。

[最終地図](LW_ground_resistance_15_90d.html) / [詳細・実行出典・ログhash](LW_ground_resistance_15_90d.json)。
実行 `python -m integrations.lightweight.ground_model_campaign --days 90 --output outputs/ground_resistance_15_90d`。
生ログ `outputs/ground_resistance_15_90d/{disabled,enabled}.jsonl`。
