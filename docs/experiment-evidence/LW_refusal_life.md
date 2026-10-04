# 拒否関係場を連続生活へ適用

2026-10-04。基準e42dacd。既存timed_harvestのsocial_camp、3個体×3日×3seed×2条件。
`refusal_field_mode=shadow/enabled` を比較。両方とも同じ確率選択器を使い、重みの適用だけを変える。
disabledは従来の選択を維持する。旧対照との混同を避けるため、今回の対照はshadow。

| seed | 要求 shadow/enabled | 譲渡 shadow/enabled | 食事 shadow/enabled | 正の重みを使った再要求判断 |
| --- | --- | --- | --- | ---: |
| 20261004 | 7 / 7 | 4 / 4 | 12 / 12 | 8 |
| 20261005 | 4 / 4 | 0 / 0 | 9 / 9 | 3 |
| 20261006 | 4 / 4 | 2 / 2 | 11 / 11 | 1 |

20261005の5秒時点は、同じ本人観測・同じdrawに対してshadowはBへ要求、enabledは要求を見送る。
このとき拒否経験重み0.6。既存活動のpickupが実行候補となり、架空の要求trialは生成しない。
最終総数は同じだが、同seedの最終携行はB/C=2/5から3/4へ変わった。
他の2seedでは同じ観測IDでの選択変更は確認されなかった。

全6runで食料保存、身体操作重複0、各9個体夜のSleep完了。
実際の逆向き要求への応答で正の拒否重みを適用する場面は0件。
逆向きの寄与はコード接続済みだが、通常生活のこの配置で影響が出たとは主張しない。

## 接続境界

本人の明示拒否記録と取得時Hから関係場を毎回再構成し、既存の相手候補選択の後に
再要求するかを評価する。相手の保持・可視範囲・要求H・親目的Hの制約はそのまま。
受信要求への応答は、未応答の当該メッセージだけを渡してgive/refuseを評価。
固定share=falseの個体は従来の拒否方針を維持。warn/withdrawを上書きしない。
affiliationは今回0。身体・在庫は現在観測を使う。

同じ不成立経験から方法Hと拒否関係場が双方寄与し得るが、独立した2件の支持とは数えない。
作用の強さや逆向き転用は依然手設計の使用仮説。長期減衰・和解による再構成は未実装。
seedは実験seed/run/個体/観測ID/問い/相手から固定。観測再送で選び直さない。
関係場が要求しないと選んだ場合は既存活動へ戻し、身体wait成功や援助成功へ変換しない。

専用3件を含む関連45テストPASS。全体suite・Luanti・30日運転は未実施。
再実行: `python -m integrations.lightweight.refusal_life_comparison`
保存: `tests/fixtures/refusal_life/comparison.json` と6本のjsonl.gz。
通常CLIへの追加は `--refusal-field-mode enabled`（social/energy/body/Sleepの依存設定が必要）。
