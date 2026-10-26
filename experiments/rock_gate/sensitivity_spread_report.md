# 固定感度を個体別に変えた3日試験

2026-10-26。感度は学習対象ではなく固定個性値として扱う。A=0.5、B=1.0、C=2.0。delay/stagnation/energy/contradictionの全4項目を各個体内で同じ倍率にした。実行中の自動更新なし。

同じ狭い入口、初日観察・備蓄4、3日。感度以外の入力JSONはcontinuous-h-3d-20261026-v3と完全一致。202.53秒、ピークRSS約1.35GB、3日正常完走。配置・生活整合69項目PASS、親・経路監査PASS。終了状態の全個体・全感度が指定値のままであることを確認。

| 個体 | 感度 | 最終エネルギー | 外出 / 再入場 | 局所修正（前回） | 暫定再接続（前回） | H破棄（前回） |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A | 0.5 | 91.27 | 1 / 0 | 1866 (1675) | 238 (237) | 144 (164) |
| B | 1.0 | 90.83 | 1 / 0 | 48 (11) | 11 (3) | 7 (3) |
| C | 2.0 | 90.65 | 1 / 0 | 2 (17) | 1 (6) | 1 (5) |

前回は全員1.0。Aの低感度化で局所修正増加・H破棄減少が見られたが、単一seed・短期・共有環境なので一般的な因果や最適感度は確定できない。感度を変えていないBも変化し、他個体との相互作用を含む。Cは経路利用自体が少ないため、破棄件数だけで粘り強さを比較できない。全員再入場0、経路目的達成0。帰還改善は未確認。

再現はrun.jlの既存3日条件に --mb-sensitivities experiments/rock_gate/sensitivity_spread.json を追加する。追加した引数は個体名と感度を検証し、実行input/manifestへ保存する。

[設定](sensitivity_spread.json)、[経路監査](evidence/sensitivity-spread-three-day/route-audit.json)、[結果](evidence/sensitivity-spread-three-day/report.json)、[manifest](evidence/sensitivity-spread-three-day/manifest.json)。

訂正注記（2026-10-26）: 本試験には0.0の見積もり内判定漏れが含まれる。感度効果の評価には[修正後の同条件再試験](zero_residual_report.md)も参照する。
