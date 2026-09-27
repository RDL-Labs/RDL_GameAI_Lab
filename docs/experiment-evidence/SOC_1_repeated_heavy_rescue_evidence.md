# SOC-1 Repeated Heavy Rescue Evidence

状態: **PASS / 経験保持あり・なし各3 Episode完了** / 2026-09-27。
実装開始点: `fb874fd`。[契約](../experiment-contracts/SOC_1_repeated_heavy_rescue_contract.md)。

## 成立した差

同じGodot Worldの初期条件を、別プロセス・別world run IDで6回生成した。
各回の位置、Bの身体状態、carry試行0、Experience0を実行前に比較し、一致を確認。
Rescue Runtime・canonical側・通常履歴も毎回新規。条件間で変えたのはSOC-1 selectorの過去Episode参照可否だけ。

| 条件 | Episode | 初手 | solo試行 | solo retry | joint試行 | 条件切替 | deliveryまでのaction | 全決定（完了idle込み） |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 保持あり | alpha | solo | 1 | 0 | 1 | 1 | 12 | 13 |
| 保持あり | beta | joint | 0 | 0 | 1 | 0 | 11 | 12 |
| 保持あり | gamma | joint | 0 | 0 | 1 | 0 | 11 | 12 |
| 保持なし | alpha | solo | 1 | 0 | 1 | 1 | 12 | 13 |
| 保持なし | beta | solo | 1 | 0 | 1 | 1 | 12 | 13 |
| 保持なし | gamma | solo | 1 | 0 | 1 | 1 | 12 | 13 |

全6回で既存Rescueのdeliveryと4段階Recoveryが完了した。
A/Cは同じ、対象は毎回B。別対象への一般化は試験していない。
保持ありbeta/gammaではsoloを実行していないため、そのEpisodeにsolo失敗記録はない。
「3回とも単独失敗を確認した」とは扱わない。保持なし側では3回とも単独失敗→共同成功を再現した。
削減されたのはsoloの初回試行1 actionであり、retry回数はどちらも0。

## 過去経験が実行前の選択へ届く経路

```text
Episode alphaの実Godot carry失敗・共同attach・delivery
→ boundedなSOC-0作用結果を検査・受理
→ Episodeを終了
→ 新World betaの初期選択時に過去delivery記録を参照
→ joint条件を選択
→ harnessがA+Cの有効参加を設定
→ 既存Rescue Runtimeが実行するapproach/rescue/deliver
```

選択時に送るeventはその時点までのものだけ。
新Episodeの未来結果は先に投入せず、初手のsource_eventsには過去Episodeの記録だけがある。
保持ありgamma初手のjoint成功支持は2 Episodeで、最後のgamma成功を先取りしない。
attachとdeliveryを2成功として数えず、成功支持はdeliveryを持つdistinct Episodeで数える。

Godotからの条件選択リクエストは試験専用`/soc1/choose` handlerが処理する。
本番bridgeへの新endpointはない。通常の行動HTTPは既存RescueTrajectoryPolicyを使う。
選択・候補・根拠event参照を凍結し、実行した参加者と受理したExperienceの一致を検査した。
全Runtime packet、条件選択結果、Experienceに能力・荷重・必要人数は含まれない。

## 学習としての限定

固定規則は、現在Episodeで失敗済みの条件を除き、記録されたdelivery成功Episode数、多失敗でない条件、solo先の同点規則で選ぶ。
Episode名の数値や「2回目」を参照する分岐はない。Episode3/99等の名前でも未経験ならsoloを選ぶ局所試験がPASS。
保持なしでも現在Episodeの失敗は使うが、終了済みEpisodeはaudit archiveに残すだけで選択へ使わない。

この実験は**経験を引き継ぐと固定の選択規則への入力が変わり、次回の実試行が変わる**ことを示した。
選択規則そのもの、jointという候補語彙、Cの協力意思を獲得した実験ではない。
Cは初めから近くにあり、参加設定と同期運動はSOC-0と同じharness/World fixtureが与える。
共同動作の通信・探索・調整コストはaction指標に含まれない。
従って「一般に協働は効率的」「他者を呼ぶことを覚えた」「性格が形成された」とは結論しない。

## 保存記録と局所検査

[実記録JSON](../../tests/fixtures/soc1_godot_replay.json)に6World出力と両selectorの監査snapshotを出典付きで保存。
Worldの`initial`/`world_checks`は実験者用。selector入力はbounded Experienceだけであり、位置・能力から成功を予測しない。
全選択を各時点のrequestから再生してchoice ID・根拠・最終snapshotが一致した。
保持あり7 event、保持なし9 eventが、それぞれ異なるepisode/world/event参照で保存される。

専用13テストの範囲:

- 保持有無の差、初回一致、Episodeラベル独立、成功支持の単位。
- 利用不能なjointを履歴で強制しない、両条件失敗でDEFER。
- attachだけのincompleteは成功支持0。
- 同request再送の非増殖、変更再送・prefix省略・重複event・別run/個体/参加者・未選択条件を拒否。
- deliveryだけの偽成功、有限Episode/choice上限、返却値aliasなし、拒否時部分更新なし。
- 保存済み実記録の全選択再生、6実World Episode。

DEFER、incomplete、両条件失敗は合成/保存SOC-0記録を使ったPython局所試験。
6つの実World runで未完了を発生させたとは主張しない。

## 回帰

```text
SOC-1専用（GODOT_BIN設定）: 13 PASS
SOC-1 + SOC-0 + 既存single/Multi-Agent Rescue等: 21 PASS
全体（GODOT_BIN未設定）: 500件実行 = 452 PASS + 48 intentional skip
```

外部Godot試験を有効にした21件には、SOC-0専用4件と既存Rescue4件を含む。
全体のskipにはSOC-0/1の外部World試験を含み、それらは上の実行で別途PASS。既存外部試験すべての再実行ではない。

実Luanti主要回帰:

- 複数個体Food生活: MULTI LIFE PASS、2 pickups / 2 deposits / 2 results。
- OBS9 normal / faults: 各108 frame、A/B生活完了、reobserved。

今回はOBS9全8runの再実行ではない。全8runはSOC-0 Evidenceの記録で、今回とは分ける。
SOC-1コードは独立追加で、既存SOC-0 provider、Rescue、Luanti、Observation、NERV-1〜4Cの既定経路は変更していない。
全6WorldでRescue commitmentはCOMPLETE後に解放され、canonical T1-Aは0件。
NERV-4Dは設計のみを維持。SOC-1から社会relation、NERV、T1、M_B更新への接続は作らない。

**独立Episodeの経験保持による、有限な条件選択と試行数の差までで停止する。**
