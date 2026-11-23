# 2026-11-23 変更整理・公開時の確認

開始HEADは `a173f20`。origin/mainをfetchし、同じHEADであることを確認。
蓄積した147ファイルの変更を、身体基盤、LW接続と検査・実験、設計記録に整理した。
身体・取引・Hの接続はday.jlなどで相互依存するため、接続部分はまとめて保存する。

## 主な範囲

- 三栄養素の身体・消化・身体要求、糖基準の見込みと摂食済み栄養の評価。
- 非公開在庫、交換履歴からの供給者想起・呼びかけ、援助と提供判断のH分離。
- 人側の各MB固有の見込み残差H、移動と獲得の評価、観測省略前の結果対応付け。
- API試験の一時レート制限再試行・研修と再開用の実験コード。
- 局所実験、長期実験の手順・記録、H/ρ/境界と今後の設計考察。

## 今回再実行した検査

Julia 1.13.1、Windows。

- `test/ci/run.jl core`: 9/9スクリプトPASS。
- `experiments/body_macronutrients/checks.jl`: 29項目PASS。
- `experiments/body_macronutrients/human_checks.jl`: 31項目PASS。
- `experiments/local_relational_observer/human_forecast_h_checks.jl`: 40項目PASS。
- `experiments/simple_language/api_transport_checks.jl`: 8項目PASS、模擬通信のみ。
- `experiments/simple_language/supplier_call_checks.jl`: 供給者・呼びかけ・語句147項目PASS
  （読み込み先の既存物品検査もPASS）。
- `git diff --check`: エラーなし。

直前の対応付け修正ではtask_focus 171項目とchunk 26項目PASS。
全オプション回帰スイート、GitHub CI、長期運転完了の保証ではない。
旧バイナリ保存には構造体レイアウトの互換性問題があるため、旧実験の凍結ソースを保持し、
新方式の10日実験は初期状態から開始している。

10日実験は公開時点で継続中。詳細は
[共通H・移動10日](LW_Common_Forecast_Navigation10_20261123.md)を参照。
