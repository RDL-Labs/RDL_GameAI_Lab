# 人間と現行生態系の接続試験

## 2026-11-12 現行人間＋動物の60日再接続

`human_ecology_dual60.jl OUTPUT HUMAN_SEED WILDLIFE_SEED [DAYS=60]`。
直近の人間4体比較入力candidate_longrun_input.jsonを使い、初期状態から現行生態系を再接続。
人間感度A/B=0.5、C/D=1、MB持越しなし。四角近似境界をON。
加工・技能・食品期限・食料不安・共通物品/食品取引・交渉・人間関係・勾配記録を維持。
別系統food_exchangeは従来通りOFF（共通item_exchangeはON）。
兎150（初期幼体込み）・地上捕食者1・猛禽、二層草倍率1.5、泳ぎ・繁殖あり。
研修・拠点休息/認知停止・取引待機・人臭/固定拠点臭・捕食者補充・猛禽150/100出入は既存設定。
人間の狩猟、捕食者の対人攻撃は追加しない。

両環境1thread・batch_cpu、日別記録は毎日、checkpointは2日ごとと最終日。
橋渡しランナーの第9/10引数にbackend/save intervalを追加。省略時auto/1で旧実験互換。
PC人間seed20261007・動物seed20261112、クラウド人間20261008・動物20261113。
地形とサブシステム独立seedのすべてを変更するわけではない。別seedなので機械速度比較ではない。
ソースは出力先sourceへ凍結。PC出力 C:/Users/ken_m/Documents/Codex/human-ecology60-20261112/。
クラウドは手動workflow `julia-human-ecology-longrun.yml`、上限6時間、記録と最終checkpointを14日保持。

2026-11-11。`humans_learned_predators.jl` の第8引数trueで選択する。
第8引数を省略した旧条件は維持。現行条件はdonor index=0、rabbit H=trueを必要とする。

人間4体の既存生活入力に、兎150匹（初期幼体5匹込み）、分散配置、二層草、
草倍率1.5、地上捕食者1匹、栄養倍率1.0、猛禽を接続する。MBは新規。
兎の近傍照会はCPU/GPU自動。川は高コスト地形。人臭と拠点臭は第6引数でON。
動物・草の細部のseed=20261111。地形と各独立サブシステムのseedは維持する。

既存の暫定固定設定を再使用する：初期分散配置、巣穴の安全・母体境界回避、
日次の捕食者死亡補充、猛禽の総兎数150で出現／100で退場、拠点の固定臭。
これらは学習成果ではない。身体・MBの設定をこの接続のために変更しない。
将来は各configured_pathsファイルに記した観測・判断・外部個体群の方式へ置換する。

人間は兎と地上捕食者を動体として観測する。猛禽は兎・地上捕食者の生態系に接続するが、
人間の猛禽専用の視覚・反応、人間の狩猟、捕食者の対人攻撃は今回追加しない。
人の既存の研修、食事、加工、取引、休息等の入力設定は維持する。

出力：conditions.json、日別daily.jsonlとprogress.json、日次checkpoint、completed.json。
生態系cohort（猛禽・補充履歴を含む）を人間側checkpointに保存する。
捕食死は地上捕食と猛禽の合算。人間4体のreserveと動物・拠点への接近も記録する。
実行中の凍結sourceは変更しない。

試験保存先：`C:/Users/ken_m/Documents/Codex/humans-current-ecology-30d-20261111`。
1日動作検査を先行し、30日をWindows一回限りタスクで実行する。

1日動作検査 smoke-v2 は verified=true。人間4体reserve84.80〜86.80、兎148、餓死0、地上捕食1・猛禽捕食1。初期MB検査7項目PASS、日次収支・保存復元検査通過。30日本番はrunへ起動。取引OFF・人間の夜間恐怖OFFは入力から維持。

## フル接続の条件確認と訂正

`food_exchange=false`だけを見て「取引OFF」と報告したのは誤り。
元入力でも`item_exchange=true`の共通取引は食品数量も扱い、`social_relationships=true`。
別系統のfood_exchangeはpost_return_idleとの併用検査で禁止されているため、単純に全flagをONにしない。
最初の30日走行はユーザーのフル接続指定により21日保存後に停止。
`humans-full-ecology-30d-20261111`へ初日から再実行する。
共通取引・関係・交渉・加工・技能・食品期限・食料不安はONを確認。
実際の変更はitem_attention=true（目的別の物品観測）とgradient_logging=true。
旧走行は取引なし対照として扱わない。人間側の未接続の狩猟・対人攻撃等は引き続き追加しない。
conditions.jsonへ人間側の主要機能スイッチを保存するよう接続ランナーを更新。

## 手動停止式の連続実行

第4引数DAYS=0で、実験用凍結コピーのtick反復を無期限にする。
通常LWの1..180日制限は変更しない。入力config.days=1は初期化用であり、
このモードの終了日ではない（conditions.days=0が運用条件）。
STOPファイルを出力ディレクトリに置くと、その日の日次checkpoint保存後に終了し、
実際の経過日数で最終報告を作る。日付・身体・MB・RNGを区間ごとにリセットしない。
WindowsタスクのMaxHours=0も併用。自動復帰やディスク保存量の上限管理は追加していない。
日次履歴とcheckpointは継続して蓄積する。

無期限モードの停止検査: stop-smokeは初期化用1日を越えて2日目へ進み、STOP要求後3日目のcheckpoint保存・最終収支検査・verified=true/manual_stopで正常終了。無期限本番はhumans-full-ecology-unlimited-20261111/run。
