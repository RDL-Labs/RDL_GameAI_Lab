# 警戒モードの維持根拠と局所Hによる暫定解除

2026-10-03。基準`71f3bd3`。`warning-mode-justification-v1`、軽量Worldのopt-in実装。

## 評価契約

局所モデル` safety/maintain-warning `の問いは「現在観測から警戒維持の根拠を更新できるか」。期待F=1、観測された根拠更新の有無F'=1/0、その差E=0/1を持つ。
これは危険の実在予測ではなく、モード選択用の固定された評価。Core H/T1への新規受付でも、経験から獲得された危険モデルでもない。

- 可視危険特徴がある: coverageがpartialでも根拠更新。H=0。時間だけで威嚇を無視しない。
- 危険特徴なし・complete: 1秒以上の間隔でHへ2加算。
- 危険特徴なし・partial: 同じ間隔でHへ1加算。理由は`basis_unrenewed_under_partial_observation`。不存在の証明ではない。
- 身体結果の対応不成立: 加算しない。待機時間の後追い加算もしない。
- H>=θ=8: 警戒維持の優先権を暫定解除。`provisional_mode_release`として現在時刻・帰還未達・通常候補を再評価する。

加算は固定gainを使う局所E→H。連続条件ならcompleteで最短4評価、partialで最短8評価だが、脅威再観測でHが0へ戻る。単なる開始時刻からのタイムアウトではない。係数は有限実験用で個体差の推定値ではない。
32操作/16秒の対処予算を使い切っても、このモード評価は続く。予算をそのまま延長する変更ではない。再びnear/watchが見えれば新しい警戒episodeを開始し、H=0から評価する。

通常の限定解除`limited_clearance`は維持する。暫定解除は完全安全を意味せず、その後も危険観測が続く。解除時に特定方向へ移動させず、既存の物理条件・帰還・採取等の選択を呼ぶ。新しい一歩Probeや内部の待機/退避ごとのHは今回追加していない。
上位モードのHだけを独立管理し、食料/帰還/経路Hへ転記しない。経路支持保護と割込みtrialのdeferは従来どおり。

入力は本人のhazard観測・取得時刻・身体結果だけ。個体/run束縛、同時刻再送の冪等性、内容競合、時刻逆行を検査。最大32評価記録と直近入力を保持する。H上限8、処理周期変更・Worldの安全真値利用はない。

## 同一条件比較

[有限採取場と縄張り](LW_finite_territory.md)と同じseed20261001・A/B/C・5日・8地点各12単位・再生なし。危険対処自体は全条件enabled。変更するのは`warning_review_mode`のみ。

|モード評価|採取|配送|携行|終了時の警戒状態|暫定解除|
|---|---:|---:|---:|---|---:|
|disabled|60|56|4|A/C unresolved、B normal|0|
|shadow|60|56|4|同上|0（行動非介入）|
|enabled|60|60|0|全員normal|1|

shadowの全command列はdisabledと一致。enabledではAが160.5秒に安全操作予算へ達した後も評価を継続。168秒、partial観測・H=8で暫定解除し、その判断で帰還phaseの`relation_field`旋回を選択。175.250001秒に4個を配送した。
Cは別途271.5秒に既存の`limited_clearance`で解除。Cに直接新H解除が発生したわけではない。Aの行動変更に反応して危険個体の状態・対象・軌道も変わるため、個体単独の改善とは帰属しない。
危険個体の威嚇stepは679→73、取得された威嚇特徴は253→19。近接距離<=1の離散監査値は両側0。負傷がない実験なので、暫定解除の生存上の優位性を示すものではない。
全条件で採取60・残36。総採取や効率を最大化した結果ではなく、警戒の長期保留からの再選択が成立した例。

## 検証

専用8 + 既存関連91 = **99 tests PASS**。complete/partialの異なる評価、可視威嚇による更新、再送/競合、個体混線、身体対応欠落、長い欠測の非水増し、再警戒、shadow非介入を検査。
軽量World3run、各320秒・3840取得を完走。旧stock/経路/危険監査に加え、H上限・記録上限・可視危険下の非解除・暫定解除の出典をassertした。
全体suite・Luanti/Godot/HTTP・複数seedは未実施。視野外の脅威が存在するまま再開するリスクを含む固定判断規則であり、万能な安全機構ではない。

```powershell
py -3.11 -m integrations.lightweight.warning_review_comparison --run
# rawログから監査だけ
py -3.11 -m integrations.lightweight.warning_review_comparison
py -3.11 -m unittest tests.test_safety_mode_review tests.test_moving_hazard_safety tests.test_territorial_hazard tests.test_timed_harvest tests.test_nested_local_models tests.test_route_weight tests.test_relational_movement tests.test_directional_routes tests.test_food_revisit tests.test_local_return tests.test_incomplete_reposition
```

単独runのCLIは`--warning-review-mode enabled`で有効化（既定disabled）。[集計JSON](../../tests/fixtures/lightweight_warning_review.json)に元ログSHA-256、設定、遷移、暫定解除時の最終actionを保存。rawはignored outputの`warning_review_{disabled,shadow,enabled}.jsonl`。
