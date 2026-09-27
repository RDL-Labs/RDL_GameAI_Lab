# SOC-4 二条件によるcarry予測 Evidence

状態: **PASS / 有限な組合せ規則の形成・検査・作用前予測** / 2026-09-27。
実装開始点: `39fc2098`。[契約](../experiment-contracts/SOC_4_contextual_carry_prediction_contract.md)。

## 成立した予測

実Godot 4.7.2の独立12 runを、形成4・独立検査4・予測確認4へ分けて実行した。
各段階で同じ4条件を別Episodeとして取得し、各runでA単独のcarryを一度だけ試した。

| 観測した身体区分 | 局所足場区分 | 形成時の実結果 | 独立検査時の実結果 | 次Episodeの作用前予測 | 次Episodeの実結果 |
| --- | --- | --- | --- | --- | --- |
| full | firm | 成立 | 成立 | likely_established | 成立 |
| full | loose | 成立 | 成立 | likely_established | 成立 |
| limited | firm | 成立 | 成立 | likely_established | 成立 |
| limited | loose | 不成立 | 不成立 | likely_not_established | 不成立 |

成立は既存resolverによるA→B attachment。不成立ではattachせず、Bの位置も変わらない。
12件中9件成立・3件不成立だが、形成・検査・予測確認は別の役割であり、12票の形成支持ではない。
予測確認4件は実行前に保存され、全件で結果と一致した。実Worldの結果を後から予測入力へ足していない。

ここで確認したのは**既知の二条件4セルから新しいEpisodeへのcarry開始予測**である。
未経験組合せへの外挿、別対象・別身体への一般化、deliveryやRecoveryまでの予測は検証していない。

## 取得条件とWorldの責務

各runでWorld・Rescue Runtime・InteractionHistory・canonical sidecarを新規にした。
Bは既存fixtureのfleeを3回実行して行動不能へ進む。AをBから10の接触域へ置き、参加者をAだけに固定する。
身体区分は既存movement_scaleの1.0 / 0.5から取得し、足場は接触域内だけで返す専用二値cueを使う。
これらは出典付き作用前contextとなり、実rescue actionと同じ観測ID・tickへ束縛される。

実験者専用の作用モデルは、A基礎能力3から制限時に1を引き、B荷重2へloose時の抵抗1を加える。
能力が抵抗以上なら既存attach resolverへ進む。予測器はこの計算式をimportせず、能力・荷重・抵抗値も受け取らない。
全12runの入力material、通常Runtime packet、予測要求・予測結果について、それら隠れfieldの非流入を検査した。
World位置や数値を含む実験者検証ログは、学習・予測の入力に含めていない。

movement_scaleは疲労や筋力そのものではなく、身体条件の代理である。
足場も専用fixtureの局所区分であり、一般地形センサー・剛体摩擦計算ではない。
この閾値モデルの二条件が同時に成立した場合の破断を予測できたのであって、複雑な物理機構や原因を同定した証拠ではない。
Observation v1の完了条件と既存Luanti観測経路は変更していない。

## 何を経験から得たか

候補言語は設計者が固定した14件（定数2・単一次元4・AND4・OR4）。
述語が真ならcarry不成立、偽なら成立という同一の規則で、全候補を検査する。
語彙・演算子自体を発見したとは主張しない。

形成記録から残ったのは、次の一件だった。

```text
movement_band == limited AND footing_band == loose
→ carry not established
```

「いつも不成立」「制限だけで不成立」「足場だけで不成立」等には、実形成記録から反例が付いた。
候補の優先順位や特定のANDへの加点はない。
別runの4件がすべて適合したため、この候補だけが局所RETAINになった。
形成数4・検査数4とそれぞれの出典を残し、model_idを固定した。

この形成は候補言語の有限な適合検査であり、統計的な因果同定ではない。
完全な4セル表を使うため、未知セルへの推論能力を示したことにもならない。
経験から選んだ規則を、独立した検査と次Episodeの事前予測へ使ったところが到達点となる。

## 予測を実行結果より先に固定した

Godotは作用前contextを取得し、テスト専用`/soc4/predict`へ送る。
Python側の固定予測器は、既に取得した形成・検査の8件だけを保持している。
同じ予測要求の再送でも同一結果で、Godot側の実event数・carry試行数はまだ0。
その後、同じ観測packetを通常`/v1/observe`へ送り、既存Rescue Runtimeが返したrescueを実Worldへ適用する。
HTTP受渡し順序も、各予測確認runでpredict → predict再送 → actionになった。

予測と独立にharnessがsoloを試す実験者権限であり、「無理そうだから回避した」行動ではない。
成立3件・不成立1件を実行してから`record_outcome`で照合した。
全件のmatch=trueを得ても、元model・形成数・検査数・予測内容は変えない。
既存SOC-0の作用receiptに同じdecisionを再送しても、12runすべてで身体・位置・Experience・試行数は増えなかった。
別sourceの追加rescueを直接注入する予算guardも同じ12runで確認し、二度目のcarry試行やeventを生成しなかった。
任意の遅延・プロセス再起動・並行要求に対する保証ではない。

作用列のtickは既存fixture同様0で、今回の試験ではcarry一回で終了する。
HTTPの順序と実event生成の前後を確認したものであり、進み続けるWorldの鮮度・割込み競合は検証していない。

## Python試験と限界の確認

以下は実World12runと区別した合成・局所試験。

- 二条件の全16結果表を与える。表現可能な14表は対応する規則で予測し、XOR/XNORの2表はunknown。
  定数、単一条件、他のAND、ORも残せるため、特定の失敗組合せを予測器へ埋め込んだ実装ではない。
- 独立検査だけ結果を変えると、形成候補をREJECTする。検査だけに合う別候補を復活させない。
- 形成/検査の明示欠落・partial、未知条件、現在文脈差、準備不足はunknown。
- 同じ取得条件に異なる結果があると、反例を残す。未取得セルを勝手に補わず、セル不足も記録する。
- 未試行・条件変化・実行時の身体条件不足は比較不能。観測された不成立を残しても、そのまま反例票へしない。
- 同じ形成/検査材料の並び替えでmodel_idが不変。Episode名の変更で残る述語は変わらない。
- 別個体・別run・別target、source/tick不一致、共同試行、delivery、未知field、過去event再利用を拒否。
- 全roster必須、形成/検査/予測確認のEpisode/run重複、5件目予測を拒否。
- 予測完全再送は読取り。内容変更・別requestによる同Episode再計上は拒否し、台帳不変。
- 予測前の結果受付を拒否。予測と違う新結果を与えればmatch=falseで、元modelは不変。
- 未試行報告はmatch=null。予測した失敗を実失敗経験へ変換しない。
- 結果再送と変更競合、入力/出力alias、拒否時の部分更新なしを確認。

現在の14言語と全セル条件ではRETAINは最大一件。多候補間の予測分岐を実Worldで検証したという主張はしない。
likely_*はこの局所規則の予測ラベルで、母集団の成功確率・信頼度推定ではない。

## 非介入・再生・テスト結果

[SOC-4実記録JSON](../../tests/fixtures/soc4_godot_replay.json)へ、12runの変更していないmaterial、
予測要求・結果、実作用ログ、形成/検査材料と最終snapshotを出典付きで保存した。
保存記録から元model、作用前予測、作用後照合を完全再生した。

固定3 packetの呼出しあり／なしで、既定Action・InteractionHistory・canonical snapshotは一致する。
再構成禁止guardも通った。実12runのcanonical T1材料数は0。
新moduleは既存RescueExperienceの検証だけを共有し、NERV/T1入口や既定policyを呼び替えない。
新HTTP入口はテストhandlerだけで、通常bridgeは変更していない。

```text
SOC-4専用: 18 PASS（局所16＋保存再生1＋実Godot12runを含む1試験）
SOC-4 + SOC-3 + SOC-2 + SOC-1 + SOC-0 + 既存Rescue: 80 PASS
全体（GODOT_BIN未設定）: 559件実行 = 508 PASS + 51 intentional skip
```

80件の内訳は18 + 21 + 20 + 13 + 4 + 既存Rescue4。
SOC-3の厳格/許容/参加不能、SOC-2の同じ経験による選別差、SOC-1の保持対照も実Godotで再確認した。
全体skipには別途実行したSOC外部試験も含む。全外部試験がPASSしたという意味ではない。
Luanti・ブラウザー実機は再実行していない。

契約S4-01〜10は以上の範囲でPASS。実Worldと合成条件の検証範囲は分けて読む。
生ログは無視対象の`integrations/luanti/output/soc4-tests.log`、`soc4-godot-regressions.log`、`soc4-full-tests.log`。
再実行（PowerShell、リポジトリroot）:

```powershell
$env:GODOT_BIN = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
$env:PYTHONPATH = 'tests'
python -m unittest test_contextual_carry -v
```

全体はGODOT_BIN未設定の別shellで`python -m unittest discover -s tests -v`。
NERV-4Dは引き続きDESIGN ONLY。考える量・援助要請・選別の癖、予測による行動変更、原因同定、
canonical E/H/M_B更新、新結果による次学習cycleは、本試験の到達点に含めない。
