# 固定休息報酬・旧慣性撤去版 10日

2026-11-26 12:52 JST開始、13:29 JST正常終了。実装e1b9df0。
exit_code=0、completed.days=10、日次checkpoint10件、栄養収支検査22項目PASS。

前回のtrade_use30入力から、days=10、home_rest_reward=off、movement_inertia=offのみ変更。
初期状態から実行し、中止した23日末からは継承しない。

- A/B/C/D、seed20261007、感度A/B=0.5・C/D=1。
- 動物なし、3栄養素身体、再生食料、通常採取・釣り・加工。
- 香り・用途差取引・関係投資ON、個人倉庫非公開。
- 食品専用の旧取引は撤去済み。食品も物品混合取引を通す。
- 維持する暫定固定: configured_negotiation、configured_fishing_training、
  configured_routine_actions、configured_trade_work_wait、configured_salted_fish_sample。
- embedded_rest、gradient_roll、睡眠遮断は維持。post_return_idleはOFF。
- Julia1.13.1、1スレッド、単発タスク、安全上限24時間、毎日checkpoint。

[入力](retired_rest_inertia10_input.json)。ランナーはexperiments/body_macronutrients/lw_run.jl。
出力: C:/Users/ken_m/Documents/Codex/human-retired-rest-inertia10-20261126
ジョブ接頭辞: 同パスに-job。
タスク: RDL-Julia-7904b4da0fc946f38ee9525ae945222c。
凍結IDSと開始ログで4体・10日を確認。起動確認は完了の証明ではない。

終了後はexit.json、completed.json、10日分のdailyを照合する。
身体、帰還・荷下ろし、採取/釣り、取引、処理時間を確認。
今回は旧食品専用経路も撤去済みのため、以前の長期試験との差を休息報酬だけの効果としない。

## 結果

呼出し全体2239.64秒（37分19.6秒）、累積割当439.77GB、GC67.90秒（約3.0%）。
内側native_mainは2196.24秒。計測範囲が違うため混同しない。
累積割当は同時使用メモリではない。コンパイル・保存を含む実行で速度比較用の対照はない。

|個体|最終糖|組織|個人在庫|荷下ろし回数|持ち帰り量|
|---|---:|---:|---:|---:|---:|
|A|27.56|100|0|28|53|
|B|18.53|100|0|26|48|
|C|27.76|100|2|24|35|
|D|27.24|100|4|30|51|

全員alive=true、最終状態は拠点内。荷下ろし回数は日次目的達成回数とは別。
物品・食品混合取引のoffered/exchangedはともに0。
retired_action_pathsで両機能effective=falseを確認。

日末ファイルの保存時刻差（保存込み概算、2〜10日目）は
193.7 / 327.2 / 149.1 / 287.0 / 185.3 / 268.5 / 151.5 / 249.9 / 167.4秒。
3日目がこの範囲で最長。開始UTCとファイル時刻の時間帯解釈に差があったため、
初日の値はこの推計へ含めず、全体時間は実験のtiming値を採用。
