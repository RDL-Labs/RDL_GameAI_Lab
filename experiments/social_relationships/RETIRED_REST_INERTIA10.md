# 固定休息報酬・旧慣性撤去版 10日

2026-11-26 12:52 JST開始。実装e1b9df0。状態: 起動確認、完了未確認。

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
