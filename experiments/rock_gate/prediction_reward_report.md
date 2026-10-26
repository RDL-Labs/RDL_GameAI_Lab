# 予測差報酬・3日試験（2026-10-26）

[設計](../../docs/design/LW_Completion_Prediction_Reward.md)。基準は `similarity-learning-rich-3d-20261026`。新試験は `prediction-reward-rich-3d-20261026`。入力JSON一致を確認。狭い入口、人工道・食料分岐、豊かな世界特徴、類似学習ON、固定感度A0.5/B1/C2、初日観察・備蓄4、親/経路/睡眠MB ON、seed20261005。

3日正常完走。呼出し240.09秒（コンパイル込み）、ピークRSS1.30GB、累積割当126.76GB。同時使用量ではない。基準237.33秒との単発差から性能変化は判断しない。

| 個体 | 最終reserve | 再入場（基準→今回） | 経路試行 | 成功経験束 |
| --- | ---: | ---: | ---: | ---: |
| A | 90.26 | 0→0 | 33 | 1 |
| B | 90.38 | 1→0 | 0 | 0 |
| C | 90.40 | 0→0 | 0 | 0 |

Aのfood目的で実行済み2辺の成功経験を保存。H_before=H_after=0、報酬1.269740。以前はこの条件で保存しなかった。Aの経路試行33回は放棄12・中断21、経路目的達成0。基準では全員経路試行0だった。基準Bには成功経験束1件があったため、全体の束数が増えたわけではない。

**成功記録の入口と報酬接続は動作したが、帰還改善は示していない。** 初成功を高くする専用ボーナスはなく、初期予測に対する実績で評価する。親目的達成数A12/B7/C7は実際の再入場回数とは異なる。親評価の末尾64件に完了記録は残っておらず、全達成の報酬分布はこの保存結果から復元できない。Aの上記報酬は束記録から確認した。

専用33項目、既存の親/経路/感度216項目、旧報酬互換43項目、構造診断11項目PASS（includeによる重複実行は加算しない）。実配置・生活整合69項目PASS。親・経路監査PASS。変更したruntime5ファイルは、runnerが挿入する読み取り専用observer呼出し1行を除き実行時コピーと一致。専用検査をJulia CIへ追加したが、リモートCI結果は別途確認が必要。

[集計](prediction_reward_3d_summary.json)、[結果](evidence/prediction-reward-three-day/report.json)、[manifest](evidence/prediction-reward-three-day/manifest.json)、[provenance](evidence/prediction-reward-three-day/provenance.json)。provenanceのcommitは変更前6eec63eを指す。実行は今回の未コミット変更を含むコピーで、manifestのハッシュを参照する。
