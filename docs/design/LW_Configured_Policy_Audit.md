# LW固定設定の棚卸し（2026-11-04）

対象は現行Julia LW (`src/lw`) の実行入口・判断・学習・観測・世界処理。116ファイルの構成と、行動代入・帰還切替・定時処理・固定候補・互換経路を横断検索し、day.jlの選択順と関連実装を確認した。全数値定数が固定行動という意味ではない。Python、凍結済み実験ソース、別実装の生態系は今回の改修対象外。

## 今回隔離した処理

| 処理 | 隔離先 | 条件・介入 | 有効化／既定 | 記録／置換方針 |
|---|---|---|---|---|
| 定時・積載帰還 | configured_paths/return_purpose.jl | return/night期または荷物6以上で帰還要求、帰着・荷下ろしまで保持 | 現行LW常時。後続の身体・日次MBが上書きし得る。独立OFF未提供 | return_purposeのentries/completed。将来、日次MB等の要求だけへ置換 |
| 空腹時摂食・倉庫取り出し | routine_actions.jl | 可食物・胃容量・在庫を確認して即時行動 | scene.configured_routine_actions、既定true | events.configured_rule=immediate_meal/hungry_store_retrieve。通常候補へ置換対象 |
| 夜間静止・応答待ち | 同上 | quiet_night以降、または未完の援助要求でrest。身体優先の解除を維持 | 同上 | quiet_night/pending_social_reply。時間・待機の候補評価へ置換対象 |
| 拠点作業・定時orientation休息 | 同上 | 帰還目的で拠点内ならdeposit/rest、orientation期ならrest | 同上 | home_service/scheduled_orientation |
| 近距離食料即時作業 | 同上 | 探索目的、観測目標1.25以内ならpickup/recover | 同上（basic_loop経路）。旧非MB経路は互換挙動を保持 | near_food_work。到着後の作業候補へ置換対象 |
| 拠点見学後の学習用休息 | 同上 | configured_camp_experience、見学完了、場所MB未完了、拠点内 | 既存camp experience設定、既定off | camp_learning_rest。初期経験の固定補助 |
| 作業候補の初期priority=5 | 同上 | 即時作業を通常の結果学習へ接続する単一候補 | 既存basic_loop接続 | method=work。候補が一つなので比較選択ではない |
| 旧非MB移動 | 同上 | home不可視でscan、可視食料採取、局所cost/距離最小方向 | basic_loop=false時のみ | legacy_unseen_home/legacy_no_step/legacy_local_steering。旧比較用 |
| 旧他者応答の個体B例外 | 同上 configured_legacy_generosity | social_response/food_body/relations無効時、Bだけ非協力 | 旧互換入力のみ | 応答イベント。学習系有効時は使用しない |

今回の隔離は前回削除した「元気で食料3個なら探索中休息」を復活させない。
新しい強制帰還も加えない。呼び出し順と乱数消費を維持する。
`configured_routine_actions=false`は今回まとめた通常行動介入を停止する実験用スイッチで、すべての固定設定を止めるスイッチではない。
他のbody-maintenance/food_preparation等が同じ行動を選ぶ場合はある。OFF時の長期生活成立は未検証。

発動ログはeventsのconfigured_rule。理由変更もイベント境界として保存する。
既存のconfigured_observation/configured_place_restを維持し、新しい理由ラベルを学習成功や報酬へ変換しない。
`decision/return_purpose.jl`は旧実験向け互換入口のみ。判定実体はconfigured_paths。

## 既に隔離されている設定

身体維持の目的切替・加工レシピ・初日見学・拠点休息報酬・達成後の認知停止・取引の1日開始上限・テスト用物品操作・旧取引評価・表情の初期写像・日次計画の初期スコアはconfigured_pathsにある。各フラグと制限はREADMEおよび個別仕様を参照。これらも学習で自然発生した挙動とは扱わない。

## 区別して残したもの／今後の設計課題

- 身体実行不能・疲労0.8以上・reserve枯渇時の停止は身体保護の実行制約。世界の衝突、資源保存、所有権も行動選好とは区別する。
- embedded_restは睡眠圧と学習する場所価値から確率的に帰還要求する初期モデル。night_fearは見積もり残差から圧を作るモデル。係数は仮定だが今回の「3個なら無条件休息」とは異なる。
- 食料不安、援助、交渉、目標到着・安全候補は経験・観測から選択する。先に安全、次に食事・応答等を評価する接続順そのものは設計上の優先階層であり、自律形成した階層ではない。
- 日次親計画の一日期限、64秒再検討、見積もり初期値、inventory/reserveの初期重みは局所実験設定。スコアは隔離済みだが、learning/mb_daily_plan.jl内の時間定数・初期見積もりまで全面抽出したわけではない。今後の設定データ化対象として明記する。
- 観測範囲、距離区分、候補数上限、学習率は観測モデル・計算予算・更新則。固定行動として一括撤去しない。
- simulation/legacy_loop.jlは旧移行比較用の別実行系。現行nativeの行動選択はday.jl。旧履歴の凍結ソースを書き換えない。

## 検証

configured_routine_checks.jl：優先順、解除条件、OFF、採取距離境界、旧3個休息がないこと、帰還状態の終了を19項目で確認。
比較はoutputs/configured-audit-b22-20261104。固定休息削除済み版と同じ21日目の状態・乱数から22日目を再開し、行動回数・在庫・位置・日次達成記録を照合する。ログ理由の追加によるイベント形式変更は許容する。

検証結果：19項目PASS。22日目の再実行も終了し、全個体の行動回数・在庫・最終位置・日次達成記録が隔離前と完全一致した（verification.jsonの4項目true）。30日全体の再試験は完了（configured-isolated-nondepleting-four-30d-20261104）。routine OFF長期試験は未実施。[統合記録](LW_Performance_Investigation_Lessons_20261104.md)を参照。
