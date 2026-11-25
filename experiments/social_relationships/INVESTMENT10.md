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

## 完了結果

日本時間15:48完了、exit_code=0、completed.json=10日、栄養収支検査22項目PASS。
実行2172.37秒（36分12秒、runner計測）、GC65.46秒。外側worker時間36分27秒。
4体ともalive=true、incapacitated=false。最終糖 A25.09/B17.05/C21.67/D25.83。
物品取引台帳：提示45（逆提案を含む）、拒否43、成立2、期限切れ0、実行不能0。
行動イベント：自発提示40、逆提案5、受諾成立2、食料援助give/transferred1。
拒否イベント38と台帳43は集計経路が違うため、同一回数として扱わない。
成立は2日目A-C、6日目D-B。

関係予測の後日評価は4件：A→C/C→A/B→D/D→Bに各1。
いずれも観測された不成立。予測0.5、残差−0.75、分散0.5625。
中立帯sqrt(分散)=0.75なので符号付きH=0、睡眠強度変更0件。
残差は睡眠後も保存され、未観測のまま消えたわけではない。最終pending0。
全12方向のstrength=0。A→Bの初期予測1/3、D→A0.4は既存履歴による初期化。

接続・保存・後日評価は実際のLWで動作したが、定着による行動変化は未確認。
前回同系統2099.30秒比+3.48%だが、異なる行動・コード・単発計測のため追加機構の費用とは断定しない。
集計根拠：出力先investment_summary.json、run/result.json、completed.json、worker exit.json。
終了した一回限りのタスク登録は解除済み。実験データは保持。
