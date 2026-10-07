# 個人所持と粗い備蓄認識 v1

軽量生活のopt-in `personal_food=True` / CLI `--personal-food`。
旧共有在庫の回帰は既定Falseで保持する。今回の生活実験はTrue。

採取物は本人のinventoryに保持する。自動deposit/takeは選択しない。
World実行側でもこのモードのdeposit/takeをunavailableにして、共有在庫へ移さない。
既存の明示giveと本人eatは維持し、重量は既存energy/bodyへ反映する。
ここでの備蓄は携行在庫であり、拠点に置く個人倉庫は未実装。

Worldは正確な個数を保存し、`social.food_band`として
none=0 / low=1..2 / some=3..5 / many=6以上を生成する。
出典は既存social sourceで個体・観測・姿勢・取得時刻へ束縛する。
初版の充足評価 `personal_food.assess` はbandと身体reserveだけを受け取る。
既存の正確なinventoryとenergy.loadは身体・旧経路との互換のため残っており、
エージェント全体から正確な個数を隠す実装ではない。

現在の固定使用規則:

- reserve<80かつ食料あり: 食べる。
- 空腹でなくsome/many: 探索期にwaitを選べる。
- none/low: 既存活動へ戻す。探索成功・移動を強制しない。

観測区分と「十分」の評価は別関数。区分・reserve閾値は初期設定で、
学習済み消費予測、日数予測、個体別の安心量ではない。
危険対応、身体対応、期限、帰還、夜間Sleepの優先を維持する。
到着した要求/警告への応答は備蓄休止より先に処理する。
休止は毎観測で再評価し、在庫消費・譲渡で減ったら既存活動を再び選べる。
置換された移動trialへwait成功を帰属させない。
粗い区分はsocial observationの一部として既存Sleep記録にも残る。

再実行: `python -m integrations.lightweight.personal_food_campaign`
既存30日統合設定・共有拠点初期配置を使用し、個人所持だけを有効化する。
