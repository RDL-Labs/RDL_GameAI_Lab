# 身体系から局所方法選択への寄与 v1

`body_method_field=True` はpersonal_food/hunger/continuous selectionを必要とする。
空腹は本人reserveから常時評価し、既存hunger M_Bの5秒比較Hを参照する。
候補評価では同じ取得時刻で再計算するが、新たなH受付は行わない。
状態の正式保存は従来どおりSocialAgentのprospective learningで行う。

今回はexploration/returnのmethod_reselectionだけを対象にする。
危険・夜間・方位確認、身体対応不成立、現在の保護された提案、旋回後の測定済み一歩を
上書きしない。新しい方法・座標・食料知識を生成しない。

寄与は既存energy可否・costとSleep寄与の後に合成する。

```
urgency = hunger_intensity * (1 + min(1, hunger_H / theta))
fatigue = strain
recoverable = min(1, reserve / 20)

wait:      +fatigue * recoverable - urgency * 0.5
move/turn: +urgency * 0.5 - fatigue * 0.5
```

固定されたGameAI-local使用仮説であり、canonical M_B/E/Hの新権限ではない。
returnへの寄与は既存帰還方法の選びやすさで、拠点に食料があるという予測ではない。
休憩で食料が得られたと見なさず、身体実行不能を空腹で解除しない。
energy/no_feasible_move等のtrialなしfallbackは寄与対象外。
方法のHは既存の実行結果比較を維持し、疲労自体をCore Hへ変換しない。

各成分のbefore/delta/afterと選択差を記録する。
SleepのchangedはSleep適用直後、身体寄与のchangedはその後の選択差として分離する。
食事/要求、個人備蓄による休止など後段が最終身体行動を置換する場合があるため、
中間候補のchangedだけを実行差と呼ばない。

大目標や日内phase自体の切替、疲労・損傷それぞれの新規Hモデル、
遠隔救助の統合は含まない。常時身体評価を全ての権限より優先する設計でもない。

再実行: `python -m integrations.lightweight.personal_food_campaign --hunger --body-field`
