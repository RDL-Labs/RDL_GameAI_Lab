# 数値ゼロ判定修正後の固定感度3日再試験

2026-10-26。day.jlのforecast_increment===0を、統合経路と検査で共有するforecast_method_evidence経由のiszero判定へ修正。0.0で親H増分が0なのに方法Hが失敗として増える問題を解消する。感度A=.5/B=1/C=2、その他も修正前sensitivity-spread-3d-20261026と入力JSON完全一致。

3日正常完走、217.54秒、ピークRSS約1.45GB。親/経路/感度と統合引渡し216項目、実配置69項目PASS。親・経路監査PASS。回帰検査は0/0.0/-0.0で親Hと方法Hの既存値を保持し、失敗件数・報酬を増やさないこと、正の残差・見積もりなし・目的達成の扱いを検査。実環境全期間で旧分岐の誤発火回数を測定したものではない。

| 個体 | 最終reserve | 外出 / 再入場 | 局所修正（修正前） | 暫定再接続（修正前） | H破棄（修正前） |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 88.58 | 1 / 0 | 64 (1866) | 31 (238) | 8 (144) |
| B | 91.15 | 1 / 0 | 1493 (48) | 141 (11) | 136 (7) |
| C | 90.97 | 1 / 0 | 0 (2) | 0 (1) | 0 (1) |

経路目的達成も0。挙動は大きく変化したが、帰還改善や感度の優劣は未確認。単一seed・相互作用のある環境であり、局所修正や破棄の件数だけで個性の効果を断定しない。

修正前30日試験 outputs/sensitivity-spread-30d-20261026 は6日目までの進捗確認後に停止。未完了ログを保存し、30日結果とは扱わない。修正版の30日試験は最初から別出力へ実行する。

[結果](evidence/zero-residual-three-day/report.json)、[経路監査](evidence/zero-residual-three-day/route-audit.json)、[親監査](evidence/zero-residual-three-day/parent-audit.json)、[manifest](evidence/zero-residual-three-day/manifest.json)。
