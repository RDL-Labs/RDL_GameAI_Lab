# 固定縄張り反応物 — 契約と有限比較

2026-10-03。`fixed-territorial-response-v1`、軽量Worldのみ。基準`9a1ebd2`。
動く危険物体の[既存対処契約](../experiment-contracts/LW_moving_hazard_safety_contract.md)へ接続する。

## 固定規則

World所有の縄張り中心(-20,-2)、半径8、待機地点(-20,-14)。侵入検知はWorldの距離判定で、動物自身の視覚や学習ではない。
一対象を選び、退去するまで保持。同時侵入は距離順、同点はID順。複数個体同時追跡はしない。

`idle → approaching → warning → returning → idle`。
侵入者へ毎秒2単位で接近し、距離3以内では停止して威嚇外観を出す。相手が離れれば接近を再開するが、縄張りを出たら帰巣する。巣から12を超える移動も中止して帰巣。帰巣中は新侵入者を追わず、帰着後の次判断で検査する。
対象は時間窓で消去せず存在し続ける。250msごと、全探索個体の当該stepの判断より前に一度進める。開始済み採取の完了処理が先。同時刻の再呼出しは再移動しない。

`decide()`は固定反応、`execute()`は身体移動・威嚇出力に分けた。将来の学習型判断への交換点であり、今回学習した動物ではない。
身体は既存solid障害物への線分接触で停止する。経路探索はしないため帰巣不能もあり得る。探索個体との物理衝突・攻撃・負傷はない。

## 個体へ渡るもの

既存の前方視野・距離12・遮蔽規則による粗い相対方向/距離帯のみ。通常外観`violet_hazard`と威嚇外観`violet_warning`を既知危険として扱う。後者も同じ安全対処規則を使い、威嚇だけで別の恐怖量を加算しない。
威嚇は現在の観測外観に出る信号。音声・アニメーション・Luantiの表示ではない。背後/遮蔽下の威嚇は届かず、威嚇信号だけを視野外へ送らない。
縄張り中心・境界・追跡対象ID・検知結果はWorld監査ログ限定。見えない危険個体へ接近が起きても、その内部状態を探索個体に教えない。

食料目的の保留、限定確認後の再開、支持/Hの割込み非誤帰属、500ms採取完了後の切替、有限安全予算は前契約を維持。縄張りの場所を学ぶ機能は未実装。

## 5日比較

seed20261001、A/B/C、無限資源、同じ初期状態、帰還数による早期停止なし。既存の関係場・経路・方位・局所目標機構を有効化。各320秒、3840取得。

|条件|採取・配送|A/B/C配送|危険個体の威嚇step|取得された威嚇特徴|安全解除|
|---|---:|---|---:|---:|---:|
|disabled|194|46/87/61|—|—|—|
|shadow|194|46/87/61|235|214|診断のみ|
|enabled|147|46/56/33|18|6|5|

shadowの全command列はdisabledと一致。enabledでは退避step20判断、見回し30判断、退避旋回25判断が発生し、5回の限定確認後に再開。終了時はA/B/Cすべてnormal、携行0。危険個体は5回帰巣phaseへ入り、最後はidle。近接距離<=1の離散サンプルはshadow/enabledとも0。
威嚇phaseへの遷移はenabled12回で、18stepとは別単位。威嚇していても視野外なら観測されないため、特徴取得数も一致しない。全runで危険個体の障害物停止は0、衝突停止は単体試験のみ。
shadowとenabledで侵入行動が変わるので危険個体の軌道も変わる。固定軌道同士の比較ではなく、同じ固定反応規則との相互作用比較である。採取減少を安全改善と同一視しない。

## 検証・再実行

専用9 + 既存関連82 = **91 tests PASS**。侵入/接近/威嚇/退去/帰巣、leash、対象保持、再送/時計、障害物停止、視野外/遮蔽/真値非漏洩を検査。
3runのログ監査もPASS。移動速度・leash・個体入力の限定、安全操作予算・経路支持保護、時刻完走、shadow非介入をassert。
全体suite・Luanti/Godot/HTTPは未実施。複数seed・長期の一般的な性能は未確認。

```powershell
py -3.11 -m integrations.lightweight.timed_harvest --output integrations/lightweight/output/territory_enabled.jsonl --days 5 --seed 20261001 --skyline-subrays --inexhaustible --no-return-target --mb-field-mode enabled --goal-difference-mode enabled --food-goal-mode enabled --lateral-side left --orientation-mode enabled --reposition-mode enabled --return-completion-mode enabled --nested-model-mode enabled --directional-route-mode enabled --relation-field-mode enabled --hazard-mode enabled --hazard-scenario territorial
py -3.11 -m integrations.lightweight.audit_territorial_hazard
py -3.11 -m unittest tests.test_territorial_hazard tests.test_moving_hazard_safety tests.test_route_weight tests.test_relational_movement tests.test_directional_routes tests.test_food_revisit tests.test_nested_local_models tests.test_local_return tests.test_timed_harvest tests.test_incomplete_reposition
```

disabled/shadowもmodeと出力名を変えて実行してから監査する。[集計JSON](../../tests/fixtures/lightweight_territorial_hazard.json)は元ログSHA-256、設定、集計、遷移を保持。rawログはignored outputに保存。
