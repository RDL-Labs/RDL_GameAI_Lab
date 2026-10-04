# エネルギー場と探索・Sleep接続

2026-10-04。基準90c1ecb。軽量Worldのopt-in。

`timed_harvest --body-mode enabled --selection-mode continuous --energy-mode enabled`。
energy-mode disabledは従来挙動。shadowはenabledと同じ荷重・抵抗・身体処理だが、
候補へのエネルギーcost減点を行わない比較用モード（場のshadow計算保存ではない）。

## 実消耗と観測

食料1個を重量1としてinventoryから荷重を計算し、実移動の消耗と越え能力へ使用。
World地面はx方向幅2の固定帯で抵抗倍率1/5を交互配置する専用物性。
各step中点の抵抗をその操作の有効抵抗とする。空間積分・ニュートン力学ではない。
個体ID、目的地、成功履歴によって地面を変えない。

本人の局所観測として、5方向(-90,-45,0,45,90)の歩行掃引可否と抵抗、
正面climbの抵抗、本人の荷重をlocomotorへ追加。既存source bindingを維持し、
全座標・帯配置の地図は個体へ渡さない。現在の専用センサーは局所値を直接取得する近似。
Worldは作用完了時の位置・身体・荷重・抵抗で改めて実消耗を計算する。
荷下ろしでinventoryが減れば、次回の負荷も下がる。drop/可変重量の品目台帳は未統合。

## 選択権限

既存continuous_selectionが生成した候補だけを対象とし、新しい経路は追加しない。
moveとrotation_then_step候補に予想歩行消耗を減点する。
旋回後は新観測で再評価し、その場で予定した歩行まで同時実行しない。
未知/blocked/身体能力不足の方向は候補から外す。全て不成立ならwaitへ戻す。
このfallbackは専用identity `energy/no_feasible_move` を持つ非trial待機とする。
元の移動methodのidentity、H、last_selectedを引き継がず、待機成功を移動成功として記録しない。
次の観測で候補を再評価する。通常の休憩methodの試行・評価は従来どおり。
pickup、夜間wait、荷下ろし、見回しには移動costを付けない。
危険回避が除外した候補を復活させず、残った候補内で消耗を比較する。
この寄与は既存のH/目的評価を置換しない。

## Sleep

取得時の荷重・方向別抵抗をbody_observationに保持する。
局所Sleepモデルの比較条件にも追加し、荷重/抵抗の異なるセルや、
情報を持たない旧body記録を同じ条件として使わない。
これは固定の消耗モデルを使った選択接続で、エネルギー法則の学習ではない。
未開始・中断の夜間処理を完了へ補完しない。

今後の別契約候補は、ρに応じた身体・抵抗条件の有限band化と、
pickup/inventory/drop/World上の荷物/再取得/unloadを結ぶ台帳。
現行の完全一致セルを一般化済みとは扱わない。

再実行: `python -m integrations.lightweight.energy_connection_comparison`
自然地形/低障害対照×shadow/enabled、3個体3日。両条件Sleepと局所自動採用あり。
