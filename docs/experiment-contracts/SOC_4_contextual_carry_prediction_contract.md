# SOC-4 二条件の組合せから単独carry成立を予測する

状態: **IMPLEMENTED / 有限仮説形成・独立検査・作用前予測 PASS** / 2026-09-27。
基準: `39fc2098`。[Evidence](../experiment-evidence/SOC_4_contextual_carry_prediction_evidence.md)。
[SOC-3](SOC_3_selection_guided_rescue_contract.md)の固定Selection差はそのまま保持する。

## 1. 問い・段階・停止点

同じ単独搬送でも、身体条件と足場の組合せにより成立・不成立が変わる記録から、
単一条件だけでは説明できない有限な予測規則を選び、独立した次Episodeの作用前に使えるか。
まず検討手順を固定して予測能力を検査する。考える量・反例許容度・援助要請などの個体差は後段とする。

```text
形成用4 Episodeの取得条件と実carry結果
→ 固定言語の14仮説を列挙・検査
→ 別の検査用4 Episodeで適合候補を検査
→ 根拠と規則を凍結
→ 別の予測確認用4 Episodeで、現在の取得条件から作用前予測
→ 実作用後に一致／不一致／未確認を記録
```

目的は`predict_solo_carry_establishment`。成立はAがBをattachしてcarryを開始したこと。
SOC-2のdelivery成功とは別の結果軸である。目的名を混ぜず、delivery・Recovery・移動中の持続成立は予測しない。
「今は無理そう」はこの目的での`likely_not_established`に限る。
予測でRuntime行動を変更しない。確認試行は実験者が固定したsoloで、否定予測でも実行する。
その実作用結果だけを照合し、予測や未試行を新しい失敗経験に数えない。

## 2. 観測する二条件

| 次元 | 取得値 | 初版の意味 |
| --- | --- | --- |
| movement_band | full / limited / unknown | 既存BodyStateのmovement_scale=1.0 / 0.5 / その他を区分 |
| footing_band | firm / loose / unknown | 対象のcarry接触域で得る専用fixtureの粗い足場区分 |

movement_bandは疲労・筋力の推定値ではない。既存の移動制限を使った身体条件の代理変数である。
footingはGodot専用fixtureの局所条件観測で、一般地形認識や精密な摩擦測定ではない。
センサーは接触域内でだけ足場区分を返し、域外ならunknown/partialとする。
既存Observation v1、Luanti、既定packet schemaを変更しない。用途に必要な二値cueをSOC-4の明示入口だけへ渡す。

schema `soc4-pre-carry-context-v1`の厳密field:

```text
schema, run_id, agent_id, target_id, context_ref, profile,
source_observation_id, tick, body_ref, footing_ref,
movement_band, footing_band, coverage,
actor_ready, target_ready, within_reach
```

profileは`soc4-local-contact-cues-v1`固定。coverageはcomplete/partial、ready/reachはbool。
body_refは取得時BodyState snapshot参照。footing_refはその取得に付ける局所観測参照。
荷重・搬送能力・能力合計・抵抗値・正解ラベル・World座標・予定セル番号を予測器へ渡さない。
agent/target IDは既存Rescue対象の束縛であり、遠景からの物体同定ではない。

## 3. 実験Worldの有限な作用モデル

新`contextual_carry_fixture.gd`だけで既存Heavy fixtureを拡張する。
実験者側でA基礎能力3、B荷重2を固定し、身体制限があると能力から1、looseな足場は必要抵抗へ1を加える。
参加者はAだけ。Cは加算しない。結果は実rescue resolverで計算し、予測器に結果表を埋め込まない。

| movement | footing | 能力／抵抗（実験者のみ） | 期待する実作用 |
| --- | --- | --- | --- |
| full | firm | 3 / 2 | carry成立 |
| full | loose | 3 / 3 | carry成立 |
| limited | firm | 2 / 2 | carry成立 |
| limited | loose | 2 / 3 | carry不成立 |

これは単純な閾値モデルであり、剛体力学・疲労生理・物理法則の学習の実証ではない。
学ぶのは二つの取得区分とcarry結果の条件付き関係で、隠れた数値や機構の同定ではない。
Bを既存のflee→行動不能の経路で準備し、Aを接触域へ置く。作用中は身体区分・足場を固定する。
作用前に取得した条件と作用時の対応が崩れれば、その記録を通常の反例へ変換せず比較不能とする。

## 4. 明示protocolとExperience受付

protocol schemaは`soc4-contextual-carry-v1`、purposeは上記固定。
experiment_id、agent_id、target_id、context_ref、およびformation/validation/forecastの各4件の
`episode_id / run_id`対応表を事前に宣言する。12件すべてでEpisodeとrunを分離する。
この対応表には条件値・予定の成否を含めない。名前・番号・配列順で予測を決めない。

形成・検査の各材料は`episodes / missing_episode_ids`で全4件を明示する。
部分指定や勝手な切捨てを許可せず、明示欠落は正常な不足として保持する。
Episode材料は次の厳密fieldを持つ。

```text
episode_id, context, event, conditions_stable, termination
```

contextは作用前観測。eventは既存SOC-0作用記録一件、または未取得のnull。
実eventは一時`RescueExperienceStore`で再検証し、A単独のrescueに限定する。
source_observation_idとtickがcontextに一致し、別の事後観測参照を持つことを要求する。
carry_established / carry_not_establishedだけをこの目的の結果へ使う。deliveryを入力すると拒否する。
実行結果がある場合termination=carry_observed、nullならnot_attempted/interrupted。
conditions_stable=false、coverage不足、準備条件不足などは理由を保持し、観測された成否と比較適格性を別々に残す。

識別子は空白だけでない128文字以内。未知field、別agent/target/run、同eventの別Episode計上、
形成と検査の参照重複、不整合な時刻・作用参照を拒否する。
これは報告の整合性検査であり、署名や外部Worldの真正性認証ではない。

## 5. 仮説言語と形成

`runtime.contextual_carry.inspect_context_hypotheses(protocol, formation, validation)`が材料を再検証する。
外部が作った仮説や評価辞書を検査済みとして受け取らない。
全仮説は「述語が真ならcarry不成立、偽なら成立」という同じ解釈を持つ。

- 定数true/false: 2件。
- 各次元の各値への一致: 4件。
- 二次元の各値の組に対するAND: 4件。
- 同じ組に対するOR: 4件。

計14件。次元・値・演算子は設計者が与え、経験から語彙や演算子を発明したとは扱わない。
どの値・演算子が残るかは実経験から計算する。ANDを常に優先したり、意味語から成否を決めたりしない。
XOR/XNORを表せない言語である。表現できる候補がなければunknownへ進み、黙って言語を拡張しない。

形成用4件に不一致があれば、その仮説の反例として記録する。
4件すべてが比較可能で、二条件の4セルを取得していることが完全な形成の要件。
不足があれば全仮説の採用判断はDEFERとし、分かった反例・適合状況は残す。
同じ条件で異なる結果があっても多数決で消さない。

## 6. 独立検査と固定モデル

形成と別の4 Episodeで同じ仮説を検査する。検査結果を使って形成候補を作り直さない。
形成で除外された仮説を、検査用記録にだけ合うことを理由に復活させない。

| 条件 | 局所disposition |
| --- | --- |
| 形成に欠落・条件不足・セル不足 | DEFER / formation_incomplete |
| 完全な形成集合に反例 | REJECT / formation_counterexample |
| 形成適合だが検査不完全 | DEFER / validation_incomplete |
| 形成適合、完全な検査集合に反例 | REJECT / validation_counterexample |
| 両集合とも全セル取得・全件適合 | RETAIN / independent_recurrence |

形成数と検査数は別に残す。4+4を形成支持8票にしない。
各仮説・各Episodeについて予測、観測結果、match=true/false/null、比較不能理由を残す。
規則・protocol・全出典・診断から決定的なmodel_idを作る。
このmodelはGameAI局所の予測資料であり、canonical M_Bではない。

## 7. 作用前予測と後の照合

`ContextualCarryPredictor(protocol, formation, validation)`は再検証結果をコピーして固定する。
`predict(request_id, episode_id, context)`は別のforecast rosterに束縛した現在観測だけを受け取る。
利用可能なRETAIN仮説の予測が一致した場合だけlikely_established / likely_not_establishedを返す。
現在条件不明・部分取得・文脈差・行動準備不足・検証済み仮説なしならunknown。
仮説間不一致もunknownとするが、現行14言語と全セル検査では異なる仮説が同時にRETAINにはならない。

likelyという名称はこの有限な検査済み規則の予測であり、確率推定や保証値ではない。
初版は既知4セルの新しいEpisodeへの予測に限定し、未取得組合せ・連続量・別対象への外挿は検証しない。
返却値には取得context、model_id、使用仮説、理由、prediction_idを保持する。

同request_id・同完全入力の再送は同じ記録、変更は競合拒否。
同Episodeへの別requestや5件目を拒否する。再送で経験や支持数が増えない。
`record_outcome(request_id, material)`は事前に予測を記録したEpisodeだけ受け付ける。
元contextへの完全一致を要求し、実event・現在の参加条件・取得時刻を再検査する。
未実行や途中条件変化ではmatch=null。異なる結果はmatch=falseのまま残す。
元モデル・元予測・形成/検査件数を新結果で更新しない。同結果の再送は読取り、変更再送は拒否。

予測受付が実行前だったことはGodotのHTTP順序と実作用前のevent数0で検査する。
純粋なPython APIだけで外部Worldの実時間順序を証明したとは扱わない。
台帳はprocess内、単一試験要求順序の保証であり、任意ネットワーク障害・並行運転・永続再開は範囲外。

## 8. 予算・非介入・受入

1実験=形成4＋検査4＋予測確認4の12独立run、各最大1 carry試行・1作用event。
14仮説×8形成/検査記録=最大112組の照合。予測と結果台帳は各4件。
Godotは既存操作台帳で同decisionの再送による二重作用を防ぐ。
既定bridgeにはendpointを追加せず、`/soc4/predict`はテストhandlerだけに置く。

| ID | 必須検査 | 結果 |
| --- | --- | --- |
| S4-01 | 二条件4セルの実作用を、形成・検査・予測確認の12独立runで取得 | PASS |
| S4-02 | 二条件AND候補が経験から残り、定数・単一条件候補に反例 | PASS |
| S4-03 | 独立検査の反例で除外、検査だけに合う候補を復活させない | PASS |
| S4-04 | 全16結果表の合成対照。AND以外も形成、言語外2表ではunknown | PASS |
| S4-05 | 欠落・未試行・未知条件・条件変化・同条件矛盾を失敗票にしない | PASS |
| S4-06 | 別Episode作用前の予測を固定し、実作用と照合 | PASS |
| S4-07 | 参照・個体・時刻・因果混線、過去event再用、上限・競合を拒否 | PASS |
| S4-08 | 再送非重複、出力独立、結果による予測/モデルの事後書換えなし | PASS |
| S4-09 | 隠れ数値非流入、既定Action/履歴/canonical非介入、NERV/T1未接続 | PASS |
| S4-10 | 保存再生、SOC-0〜3/Rescue実Godot回帰・全体試験、検証境界を記録 | PASS |

[RDL参照](../semantic-reference/RDL_Core_T0_T1_reference.md)に沿い、局所予測の照合結果をcanonical E/Hへ昇格させない。
NERV-4D、Selection tendencyの動的形成、原因同定、行動接続、援助要請、モデルの次cycle更新は保留。
次工程は別契約で扱い、本版の有限な予測能力を基準にする。
