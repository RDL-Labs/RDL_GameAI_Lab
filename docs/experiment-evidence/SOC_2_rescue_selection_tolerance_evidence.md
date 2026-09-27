# SOC-2 固定救助選別条件 Evidence

状態: **PASS / 同一3 Episodeの検査材料による固定選別条件差** / 2026-09-27。
実装開始点: `66d0eb9`。[契約](../experiment-contracts/SOC_2_rescue_selection_tolerance_contract.md)。

## 成立した差

実Godotの独立3 runから、共同delivery成功2件・共同carry不成立1件を取得した。
各runでA/Cは各能力1、実際の参加者はA+C、対象は行動不能のB。
対象荷重だけを実験者側で2 / 2 / 3に設定した。
選別へは荷重・能力・座標を渡さず、受付済み作用結果と限定envelopeを渡す。

| 同じ検査材料 | 許容0/1 | 許容1/3 |
| --- | --- | --- |
| 成功2・失敗1、全3件を検査可能 | REJECT | RETAIN |
| 判定用failure_count / validation_count | 1 / 3 | 1 / 3 |
| baseline_disposition（許容0） | REJECT | REJECT |
| 理由 | exceeds_declared_tolerance | within_declared_tolerance |

両条件のepisode_resultsはsourceを含めて完全一致する。
許容1/3でも失敗eventは残り、成功へ書き換えられない。profileごとの再評価で経験数は増えない。
これは今後の検討対象としてjoint条件を残すかという局所判定であり、次回行動の許可ではない。

## 実Worldの取得結果

| run | 荷重（実験者のみ） | joint試行 | 結果 | deliveryまでのaction | 全決定 |
| --- | --- | --- | --- | --- | --- |
| soc2-alpha | 2 | 1 | delivered | 11 | 12（完了idle含む） |
| soc2-beta | 2 | 1 | delivered | 11 | 12（完了idle含む） |
| soc2-gamma | 3 | 1 | carry_failed | 未到達 | 4 |

成功2 runは既存のstabilizing → mobilizing → recovering → recoveredを完了。
失敗runでは対象の前後位置が一致し、attachmentもdeliveryも発生していない。
失敗を受け取ったharnessがそこで試行を終了する。既存Rescueのcommitmentが自律解放されたという主張ではない。
成功runは既存RuntimeのCOMPLETEでcommitmentを解放する。

World・Rescue Runtime・通常履歴・canonical sidecar・台帳はrunごとに新規。
記録した初期位置・B身体状態・carry試行0・Experience0は全3 runで一致した。
隠れた荷重は異なるため、「完全に同じ物理条件を3回繰り返した」とは扱わない。
能力・荷重・必要人数が、全Runtime観測packet、作用Experience、選別materials/resultsへ漏れないことを検査した。
World参照ログは選別入力へ渡さない。

候補jointとA/Cの参加・同期移動はharness/SOC-0 fixtureが与える。
条件の発明、援助要請、Cの協力意思、Cの信頼性を学習した実験ではない。
作用列のtickはこのfixtureでは0で、Recovery時にWorldをstepする。
作用順は別のsource/subsequent observation参照と明示event列で残す。継続Worldの時刻競合試験ではない。

## 受付・再生・非介入

`godot/.../tests/rescue_selection_http_check.gd`は既存Heavy providerと通常Rescue HTTPを使用する。
新しい選別endpointや既定policyの変更はない。
Worldから出力した作用結果を、Python harnessが明示的に`RescueExperienceStore`へ受理する。
`runtime/rescue_selection.py`の純粋評価は、一時storeでschemaとrecord参照を再検証する。

[出典付き実記録](../../tests/fixtures/soc2_godot_replay.json)にはprotocol、3World出力、
受付materialsと両profileの評価結果を保存した。実記録を失敗へ加工した箇所はない。
3 Episodeに属する5 event（成功各2、失敗1）を3件の検査材料として数え、5票にしない。
保存記録から両判定とevaluation_idを再生できる。

同一入力の再評価は同一結果。外部の入力・返却値を変更しても固定instanceは変わらない。
Episode材料・snapshot配列順を変更しても結果は不変だが、作用列を逆転させる入力は拒否する。
record_idは既存run/event由来で、署名ではない。実行の真正性や取得完了報告はadapterの責務として残る。

Pythonの固定3 packetで評価呼出しあり／なしを比較し、Action・InteractionHistory・canonical snapshot・
SOC-1 selectorの状態と初手soloが一致した。再構成を呼ぶと失敗するguardも通った。
これは実World全行動列の反実仮想比較ではない。
新moduleの依存先はSOC-0受付のみで、NERV/T1入口を呼ばない。

## 合成条件・拒否境界

以下は実3 runと区別したPython試験。

- 失敗0/3・1/3・2/3・3/3。全成功では二条件ともRETAIN。
- 反例とpartial/context差/未試行の併存はDEFER。複数理由と反例を残し、判定用k/nはnull。
- carryだけの中断、Aだけの実参加、actor行動不能、target条件不足、全Episode未取得をDEFER。
- 部分指定・未知参照・明示欠落の不正分割、別run/actor/target/参加者、event再利用、隠れfieldを拒否。
- deliveryだけ、失敗後delivery、参加者のすり替え、終端矛盾、時刻逆行、同じ作用sourceの再利用を拒否。
- profileのbool/float/非既約分数/範囲外値、重複・有限上限超過、返却値alias、拒否後の再評価を検査。

unresolved条件は6つ目の実Worldケース等として数えていない。

## 受入の対応

| ID | 結果と検証経路 |
| --- | --- |
| S2-01 | PASS: 実Godot独立3 run、共同成功2・失敗1、非移動/Recovery |
| S2-02 | PASS: 同じ実記録を0/1・1/3で再生、sourceと件数の一致 |
| S2-03 | PASS: Python合成の失敗数0〜3の整数境界 |
| S2-04 | PASS: Pythonの不完了・未試行・条件不足と複数理由保持 |
| S2-05 | PASS: SOC-0同event再受付、純粋再評価、5eventを3Episodeとして計数 |
| S2-06 | PASS: 事前対応表、混線・部分指定・event流用・不正時系列拒否 |
| S2-07 | PASS: 作用列・終端・未知参照の拒否、明示欠落との区別 |
| S2-08 | PASS: 固定profile、入力/出力独立、順序不変ID、予算・重複拒否 |
| S2-09 | PASS: 固定packet非介入、SOC-1不変、再構成guard、依存先確認 |
| S2-10 | PASS: SOC-0/1・既存Rescue実機回帰と全体試験 |

## テスト結果と停止点

```text
SOC-2専用: 20 PASS（実Godot 3 runを含む1試験＋保存記録再生＋局所試験）
SOC-2 + SOC-1 + SOC-0 + 既存Rescue 4件: 41 PASS
全体（GODOT_BIN未設定）: 520件実行 = 471 PASS + 49 intentional skip
```

実機41件の内訳はSOC-2 20、SOC-1 13、SOC-0 4、既存Rescue 4。
SOC-1の保持ありsolo/joint/jointと保持なしsolo/solo/solo、delivery行動数の差も再確認した。
全体skipにはSOC-0/1/2の外部実機試験を含み、それらは上の実行で別途PASS。
既存外部試験すべてを再実行したものではない。Luanti・ブラウザー実機は今回再実行していない。

SOC-2は同じ有限経験に対する固定選別条件差で停止する。
NERV-4DはDESIGN ONLYのまま。SOC-1の固定selector、NERV/T1、次Episode行動へ接続していない。
