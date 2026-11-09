# 捕食者流入100・退場幅50：360日実験

2026-11-09、実装基準99649d9。新規世界から360日、継続実験ではない。

- 人なし、兎100匹（既存95＋幼体5）。初期状態diverse・草patchy・distributed配置。
- 草量1.5、二層草、巣穴・授乳・巣穴退避・泳ぎを維持。
- 近傍幾何処理CPU/GPU自動切替、Julia 1 thread。
- 初期固定捕食者0。ratioにより開始時1体を境界へ導入。新規MB、継承なし。
- 日次確認：流入100k、退場N<=100k-50。中間帯は在場数を維持。
- 暫定固定の世界条件。流出時の境界歩行と場外生態は省略、死亡とは別記録。
- 捕食者不在でも続行。要求360日または既存の安全停止まで。

出力：`C:/Users/ken_m/Documents/Codex/predator-population-hysteresis360d-20261109`

ジョブ接頭辞：同パス末尾に `-job`。
タスク：`RDL-Julia-fa8f6bcfca62455287f3cea2ae6ce10f`。
開始登録：2026-11-09 19:20 JST。バックグラウンド実行、安全上限24時間。

進捗はprogress.json、日別はdaily.jsonl、出入りはresult.jsonのmigration_events。
兎の出生・捕食・餓死、捕食者の在場・流入・流出・死亡、処理時間を確認する。
開始記録であり完了報告ではない。終了時はexit_code=0、completed.jsonの
verified=trueとdays=360を併せて確認し、上記の一回実行タスクを削除する。
