# 連続H・残差別感度：3日確認

2026-10-26。[実装設計](../../docs/design/LW_Continuous_H_Sensitivity.md)。既定感度は全員・全要素1.0。入力JSONは直前local-repair-3d-20261026と完全一致。最終版は3日正常完走、206.09秒（コンパイル込み）、ピークRSS約1.43GB。

| 個体 | 最終エネルギー | 外出 / 再入場 | 局所修正 | 暫定再接続 |
| --- | ---: | ---: | ---: | ---: |
| A | 91.28 | 1 / 0 | 1675 | 237 |
| B | 90.98 | 1 / 0 | 11 | 3 |
| C | 90.10 | 1 / 0 | 17 | 6 |

全員の最終エネルギーは正。経路目的達成0、外からの再入場0で、帰還改善は示していない。感度による個体差の長期比較も未実施。前回の30日悪化を解決したという結果ではない。

検査は親/経路/感度203、確率選択116、報酬43、目印候補35、実配置69の計466項目PASS。親・経路監査と入力一致も確認。初回統合試験でH由来の段階番号がFloat64となり配列添字に使えない問題を検出し、dayとobserved_cuesで段階番号のみ整数化した。目印候補には分数Hの回帰検査を追加。最終試験はその修正を含む。

[経路監査](evidence/continuous-h-three-day/route-audit.json)、[親MB監査](evidence/continuous-h-three-day/parent-audit.json)、[結果](evidence/continuous-h-three-day/report.json)、[manifest](evidence/continuous-h-three-day/manifest.json)。実行時未コミットソースはmanifestで識別する。
