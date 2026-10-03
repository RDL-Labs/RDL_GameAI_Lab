# 有限採取場と縄張りの重なり

2026-10-03。基準`5330252`。既存の有限stockを使い、追加の判断規則・危険係数・資源再生を導入せず比較した。

## 固定条件

A/B/C、seed20261001、5日、8地点×12単位=96単位。全員が共有できる資源。日付変更・モデル採用・配送による補充なし。帰還3回による終了も無効。
固定縄張り中心(-20,-2)、半径8。既存配置の資源0=(-22.28,-1.92)が内部、残り7地点は外部。World座標による重なりの監査で、本人へ縄張り境界や資源位置一覧を渡すものではない。
今回の設定は`inexhaustible=False` / `inexhaustible_after_model=False`。元から存在する有限資源モードを使用し、旧無限資源実験を上書きしない。

## 実行結果

|条件|日別採取（1〜5日）|合計採取|合計配送|携行残|縄張り内資源0の枯渇時刻|
|---|---|---:|---:|---:|---|
|危険なし|44 / 16 / 0 / 0 / 0|60|60|0|19.25秒|
|危険ありshadow|44 / 16 / 0 / 0 / 0|60|60|0|19.25秒|
|対処enabled|40 / 16 / 4 / 0 / 0|60|56|4|150.75秒（3日目）|

shadowの全commandは危険なしと一致。全条件で資源0/1/3/6/7が枯渇し、2/4/5は各12、計36残った。World全体の食料を取り尽くした結果ではない。

enabledでは資源0をBが8、Aが4採取。危険なしではBが12。危険との相互作用により利用時期と取得個体が変わったが、5日総採取数は同じ。Aは4個を携行したまま終了し、配送完了とはしない。
enabledは4回の限定解除後に再開した一方、終了時A/Cは`safety_unresolved`、Bはnormal。危険個体の威嚇は679step、取得された威嚇外観253件。近接距離<=1の離散監査値は0だが、生存保証・連続衝突判定ではない。

最初の枯渇後にも移動・旋回・別地点での取得が起きた。例えばCは資源7→6→3を取得。ただし枯渇だけが経路変化の原因とは断定しない。4/5日目の採取0も、全個体の思考停止や全資源枯渇と同一視しない。今回は危険由来の長期保留が残る。

## 検証

軽量World3run、各320秒・3840取得。関連32 tests PASS（採取6、縄張り9、危険対処17）。全体suite・Luanti/Godot/HTTPは未実行。
監査は全stockが非負、各成功が1単位の消費、最終在庫と成功数の一致、携行+配送=採取、補充なし、縄張り内外の両方に資源があることをassert。既存の危険操作・経路支持・shadow非介入監査も実施。
同時に複数採取が完了する場合、Worldはdue batch全体の処理後にログを出すため、同じ実行時刻のbatch単位で在庫を照合する。最初の個体のログに見える全減少をその個体へ帰属しない。資源IDの復元はWorld token生成規則を使った監査専用処理。

```powershell
py -3.11 -m integrations.lightweight.finite_territory_comparison --run
# 保存済みrawログの監査だけ
py -3.11 -m integrations.lightweight.finite_territory_comparison
py -3.11 -m unittest tests.test_timed_harvest tests.test_territorial_hazard tests.test_moving_hazard_safety
```

[集計JSON](../../tests/fixtures/lightweight_finite_territory.json)にmanifest・原ログSHA-256・個別採取/枯渇・mode遷移を保存。rawログはignored outputの`territory_finite_{disabled,shadow,enabled}.jsonl`。
固定seedの有限比較までで、危険との重なりを記憶して避ける学習や、資源再生の予測は未実装。
