# 縄張り内の採取場を1地点から3地点へ

2026-10-03。基準`544a028`。軽量Worldの配置比較。

## 条件

採取場8地点×12単位=96、共有・有限・再生なしを維持。固定危険個体は1体、縄張りの形・巣・速度・反応規則を変えない。
`original`は資源0のみ縄張り内。`three_inside`は資源1を(-18,-2)、資源3を(-20,2)へ移し、資源0/1/3の3地点が縄張り内となる。新資源の追加や総量増加ではない。
配置は実験者側だけで変更。既存の地形・目印・樹木は動かさず、特定樹木との対応を新たに教えない。資源分布の変更自体が探索難易度へ影響するため、各配置で危険対処disabled/enabledを比較する2×2試験とする。

seed20261001、A/B/C、5日、無限資源と帰還数停止を無効化。警戒H評価はenabled、他の移動/経路/目標条件は前回と同じ。危険disabledでは危険個体の実行・観測自体を無効化する。
CLIは`--territory-resource-layout three_inside --hazard-scenario territorial`。既定はoriginalで、過去の試験配置を変更しない。

## 結果

|縄張り内地点数|危険対処|採取|配送|携行|縄張り内からの採取|
|---|---|---:|---:|---:|---:|
|1|なし|60|60|0|12|
|1|あり|60|60|0|12|
|3|なし|60|60|0|36|
|3|あり|46|36|10|22|

全4runを完走。3地点・対処ありではA19/B7/C10を配送し、Bが10個を携行。資源0は12、資源1は2残り、縄張り内36単位のうち22を取得した。資源3/6/7は枯渇、World全体では50単位が残る。

Bの最終観測はcomplete、nearの`violet_warning`が方向52.5〜67.5度にある。維持根拠が更新されるため警戒H=0。今回の保留は「見えないまま根拠が更新されない」場合とは異なり、**威嚇が現在も見えているのに、有限な退避操作を使い切った**状態。時間による暫定解除は行われない。A/Cはnormalで終了。
3地点・対処ありで限定安全解除5回、Hによる暫定解除0回。近接距離<=1の離散監査は0。危険回避性能・最適化を主張しない。
次の構造的な残件は、根拠のある警戒を維持しつつ、内部の退避/待機方法を変更する経路。今回その追加はせず、配置差の結果として保存する。

## 再実行・検査

```powershell
py -3.11 -m integrations.lightweight.territory_resource_comparison --run
py -3.11 -m integrations.lightweight.territory_resource_comparison
py -3.11 -m unittest tests.test_territorial_hazard tests.test_safety_mode_review tests.test_moving_hazard_safety tests.test_timed_harvest
```

関連41 tests PASS。配置変更で在庫と地点数を保持し、指定seedで重複数が1→3になることを検査。ログ監査は有限stockの収支、同時採取batch、携行/配送、危険操作上限、既存経路支持の非誤帰属も継続。
全体suite・Luanti/Godot/HTTP・複数seedは未実施。[集計JSON](../../tests/fixtures/lightweight_territory_resources.json)に設定・原ログSHA-256・採取/枯渇・mode遷移を保存する。
