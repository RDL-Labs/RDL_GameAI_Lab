# 257日目の捕食者復活・通算3000日への継続

2026-11-10。ユーザー指示により、餓死した地上捕食者1匹だけを一度復活。
入力 `rabbit-fresh3000-20261110/run-v2/checkpoints/day-257.jls`。
出力親 `C:/Users/ken_m/Documents/Codex/rabbit-revive257-to3000-20261110`。

食料0→900（既存初期値）、alive=true、mode=idle。位置、記憶、乱数、疲労、損傷、捕獲数、兎、草は保持。
身体reserveの鏡も900に揃える。旧収支式との互換のため外部補給900をeatenへ計上し、mind.estimatesの
`experiment_external_food` と `intervention/revival.json` に明記。捕食による摂食量として解釈しない。
復活そのものは試験準備だけで実施し、通常の生態ループに自動復活は加えていない。
保存再読込・収支・捕獲数不変など6項目を確認。

残り2743日、通算3000日を指定。日次保存、run/STOPによる停止、捕食者死亡停止を継続。
タスク `RDL-Julia-11bcd8686b17475297adb9d067c479ef`。完了時はexit.json/completed.jsonを確認し登録削除。
利用者向け停止スクリプトは出力親のstop.ps1。
