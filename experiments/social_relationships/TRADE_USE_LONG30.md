# 香り・用途差取引 30日試験（2026-11-26）

状態: ユーザー指示で中止。23日目末まで保存、24日目途中で停止。開始10:32 JST、停止12:04 JST（2026-11-26）。
終了コード-1は意図したプロセス停止によるもの。30日完了ではない。
停止記録は実行先のstopped_by_user.json。凍結ソース・入力・保存状態は保持。
取引全体の接続監査は [監査記録](../../docs/design/LW_Trade_Connection_Audit_20261126.md) を参照。
実装基準: 3d5248d。未コミット変更なしから起動。

- 初期状態から30日、seed=20261007、A/B/C/Dの4体。A/B感度0.5、C/D=1。
- 動物OFF、3栄養素身体、通常の採取・釣り・加工・再生食料。
- food_aroma=true、trade_use_outlook=true、trade_relationship_investment=true。
- 個人倉庫非公開、取引・人間関係ON。
- 暫定固定: configured_fishing_training、configured_salted_fish_sample、
  configured_routine_actions、configured_trade_work_wait、configured_negotiationは従来どおりON。
  home_observation=off、configured_trade_idle=false。その他入力も前回のまま。
- 1日試験の入力から日数だけ30へ変更。ソース/入力は実行先へ凍結。
- 1スレッド、Julia 1.13.1。既存ランナーの安全上限は実時間24時間。
- チェックポイントは現ランナーでは毎日。コードの実動作を確認済み。

[入力](trade_use30_input.json)。実行先:
C:/Users/ken_m/Documents/Codex/human-trade-use30-20261126

実行: experiments/body_macronutrients/lw_run.jl INPUT OUTPUT 30
（Windowsではscripts/run_julia_scheduled.ps1による単発タスクを使用）
タスク: RDL-Julia-88f244d41f314f3d862521d55692e6d1。
ジョブログ接頭辞: C:/Users/ken_m/Documents/Codex/human-trade-use30-20261126-job。

開始ログの4体・30日、凍結IDSの4体、Juliaプロセス稼働、stderr空を確認。
起動確認は完了の証明ではない。exit.jsonとcompleted.json、結果の30日分を確認すること。

終了後は提示/拒否/成立/品目、塩の入手・加工、食事・身体状態、香りの想起を確認。
処理時間は総時間と日別チェックポイント時刻の差からの推移を区別する。
後者は保存も含む概算であり、日別の計算時間だけを直接計測したものではない。
前回初日は提示0だったため、取引機会のない状況と候補評価による棄却を混同しない。
