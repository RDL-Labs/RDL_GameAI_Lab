# 身体維持を上位目的にする有限MB

2026-10-25。`body_purpose=on` / CLI `--body-purpose on`。既定offで旧試験を再現可能。food_body=onが必要。

## 位置づけ：テスト用の設定経路

本実装の空腹によるfoodへの切り替え、reserve>80での帰還再開、および定時休息・待機の解除は、**将来撤去するテスト用の「設定経路」**に分類する。埋め込みMBとは別であり、学習された上位選択の実装でもない。身体維持を上位に置く階層の設計方針と、それを便宜的に実現する固定処理を区別する。[共通の用語と撤去方針](RDL_Configured_Paths.md)。

## 問題と変更

従来、空腹は摂食・倉庫からの取り出し・他個体への要求に作用したが、帰還がactiveになると移動目的はhomeに固定された。夜間の定時休息も食料探索に先行した。そのため帰還が解けないまま身体エネルギーを失う経路があった。

個体ごとに `actor:energy-maintenance` を上位MBとして置き、food/homeのBasicLoopのparentを接続する。既存のhunger_selectによって補給を必要としたら、目的をfoodへ切り替える。現在拠点にいて食料在庫を確認できる場合はhome側の取り出しを使う。帰還状態は消去せず保持し、reserveが80を超えて回復したら通常の帰還要求を再び適用する。

空腹の圧・H・閾値は既存のhungerモデルを利用する。補給中は夜間・orientationの定時休息と社会応答待ちによる待機を解除する。要求への返事を待ちながら探索できるが、同じ待機中に要求を上書きして連発しない。安全行動は最優先、疲労strain>=0.8やreserve<=0による移動抑止は維持。空腹時の手持ち摂食と拠点での取り出しは社会応答より優先する。

観測できない倉庫在庫・遠方の食料位置は上位MBに渡さない。現時点では遠くから拠点の在庫を記憶して帰還と採食の期待効用を比較する機能はない。現在アクセスできる在庫のみを使う。

## 範囲と限界

今回の上位MBは身体要求に応じた有限の監督処理。下位の方法選択は既存の確率的BasicLoopであるが、上位の目的選択自体はまだ学習された確率分布ではない。身体全般（睡眠・水分等）の共通競合や上位MBへの報酬学習まで実装したものではない。既存の空腹判定を採用するため、80という境界も生理学的な主張ではない。

`body_purpose`統計は各日・最終状態・summaryに保存。選択した目的、補給中か、帰還からfoodへの上書き判断数、切り替え回数、最新32件の切り替え記録を持つ。判断数は安全・摂食等が最終行動を上書きした場合も含み、探索を実行した回数とは異なる。

## 検証

`experiments/julia_migration/lw_integrated/body_purpose_checks.jl`：帰還保留・空腹時の切り替え・在庫がある/ない拠点・回復後の帰還再開・個体の整合を検証。600tickの夜間診断で消費はoff=3/on=5。時間を短縮した診断用clockであり、通常の1日や長期生存率の改善を意味しない。

既存の統合設定（光源、地形、危険、睡眠、経験束、目印、粗ρ）とも600tickで接続を確認する。長期の12日全滅相当シナリオを修正後に再実行した結果はまだない。

再現：

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/body_purpose_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/body-parent-trial --narrow-only --days 30 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --stop-exhausted
```

## 実装の分離

固定処理の実装は [configured_paths/body_maintenance.jl](../../src/lw/configured_paths/body_maintenance.jl)。目的選択、即時補給の優先、待機・定時休息の解除を同じ場所に集約し、day.jlは返された選択と例外指定を適用する。旧decision/body_purpose.jlは移設した。CLIと保存結果の名前は維持する。
