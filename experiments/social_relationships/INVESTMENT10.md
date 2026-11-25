# 関係期待ON・LW10日（2026-11-25）

実行コード基準bc0e6bc。日本時間15:11開始。新規開始、人間A/B/C/D、動物OFF。
入力は human-food-supply10-20261124/input.json と同じ、変更は
scene.trade_relationship_investment=true のみ（10日を再指定）。
個人備蓄各3、非公開倉庫、3栄養素身体、採取・釣り・加工・取引・援助、日次食料再生。
既存固定研修・交渉制限・待機などは維持。詳細はinvestment10_input.jsonを参照。

runner: experiments/body_macronutrients/lw_run.jl
出力: C:/Users/ken_m/Documents/Codex/human-investment10-20261125
job prefix: C:/Users/ken_m/Documents/Codex/human-investment10-20261125-job
scheduler: RDL-Julia-8b91ed34c95540b9b9b677e02bb748e8
Julia1.13.1、1thread、MaxHours24。実行用ソース・入力は出力先へ凍結。

既存同系統10日は2099.30秒。ただし今回との性能対照実験ではなく参考時間のみ。
結果確認時はexit.jsonとcompleted.json両方、10日完了を確認。
交換・援助・身体・生存、取引関係予測pending/records/reviews、睡眠反映、時間を調べる。
relationsはチェックポイントで保持。観測がなければpendingが残ることは許容。
開始記録であり、完了結果ではない。
