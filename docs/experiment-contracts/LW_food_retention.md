# 譲渡への食料保持拘束

初版は `food_retention=True` のopt-in。個人所持・空腹M_B・拒否関係場を必要とする。
現在の粗い備蓄、reserve、本人の食料充足Hからgive候補のscoreへ有限なcostを加える。

```
scarcity = none:0 / low:1 / some:0.4 / many:0
need = max(0, (80-reserve)/80)
pressure = min(1, H/theta) if reserve<=80 else 0
retention_cost = scarcity * (1 + 2*need + pressure)
```

既存の身体need、相手の明示拒否経験、affiliationと合成する。
needが既存項とscarcityとの相互作用項の双方に入る設計であり、独立した証拠の2票ではない。
softmaxでgiveを残すので、最後の一個やreserve不足でも譲渡の可能性はゼロにしない。
食料なしは実行不能。share=Falseの既存固定拒否個体はその方針を維持。
要求者の不可視reserveやWorld資源量は使わない。
満腹でも少ない備蓄には保持costが残る。ただし将来予測そのものではない。

## 上位の生存性との関係

現在の実験では探索・採取・帰還・食事・休憩・譲渡が上位の食料確保/生存継続に関係する。
各行動の直接の問い、結果、身体権限を同一化しない。
逃走や休息が食料取得を遅らせても生存へ寄与し得るため、取得数だけで評価しない。

将来は「渡した後の備蓄」「本人の消費経験」「次回補給までの見通しと不確実さ」を
M_Bで評価する案。現在の満足と将来の生存性を分ける。
この予測、上位生存性モデルの採用・更新、未来のWorld真値の参照は未実装。

再実行: `python -m integrations.lightweight.food_retention_campaign`。
