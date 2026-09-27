# SOC-2 同じ救助経験に対する固定選別条件の比較

状態: **IMPLEMENTED / 固定許容条件の有限比較PASS** / 2026-09-27。
実装開始点: `66d0eb9`。[SOC-2 Evidence](../experiment-evidence/SOC_2_rescue_selection_tolerance_evidence.md)。
SOC-1基準: `e78e680c`。[SOC-1契約](SOC_1_repeated_heavy_rescue_contract.md)と
[実装済みのEvidence](../experiment-evidence/SOC_1_repeated_heavy_rescue_evidence.md)。

## 1. 問いと停止点

同じ3 Episodeの成功・失敗記録をすべて保持したまま、固定した失敗許容条件だけで、
**共同搬送という条件を今後の検討対象として残すか**が変わるか。
SOC-1は履歴へのアクセス有無を比較した。SOC-2では両条件とも同一の全履歴を参照する。
変えるのは許容分数0/1・1/3だけであり、不都合な経験を削除する実験にはしない。

問いは `joint_rescue_delivery_eligibility`、規則版は `soc2-joint-rescue-tolerance-v1` とする。
設計者が試行前に与える候補は「AとCが参加する、行動不能のBの搬送」で固定する。
Candidateの自動形成や、その形成に使った経験とは別の経験での追試は今回行わない。
3 Episodeは、あらかじめ指定した候補に対する検査集合である。

到達点は出典付きの局所 `RETAIN / REJECT / DEFER` と二条件の再生比較。
RETAINは次回行動の許可、REJECTは永久的な禁止、DEFERは救助放棄を意味しない。
次Episodeの実行条件へ渡す接続は、この比較を確認した後の別契約にする。

## 2. SOC / NERV / T1の境界

[NERV-4D案](NERV_4D_selection_tolerance_contract.md)と、検査事実と許容判断を分ける考え方を共有する。
ただし4DはFood acquisitionのNERV/T1材料を扱う未実装案であり、SOC記録を直接入力しない。
SOC-2はNERV-4Dの実装・受入を兼ねず、既存SOC-1の選択規則も変更しない。

RDL参照は[固定したCore参照](../semantic-reference/RDL_Core_T0_T1_reference.md)の
`327098256a29e3f82f2a8649a6ec0202fd68a6c4`、T1「検査と選別」「SILN展開」。
問い・境界・選別基準を先に定め、情報不足をDEFERにする各系設計として扱う。
SOC-2の局所判定はcanonical T1-B記録ではない。M_deltaの発生、T1-A展開、T1-C、M_B更新を追加しない。
搬送失敗率をcanonical E/H、神経感度、身体損害、感情へ読み替えない。

## 3. 固定する有限境界

同じactor A、target B、helper C、既存Rescueの搬送先・到達条件を使う。
EpisodeごとにWorld、身体、Rescue Runtime、通常履歴、canonical sidecar、操作台帳を初期化する。
独立性は別のworld run / Episode / eventを持つ実試行という意味で、統計的独立同分布は主張しない。

初版は対象・協力者の一般化、soloとの優劣比較、共同動作の通信コストを扱わない。
観測可能な条件は、対象の行動不能、実際の参加者、carry成立、delivery結果とその取得参照まで。
能力値・荷重・必要人数・正解条件・World座標を選別入力や出力へ追加しない。

`context_ref = soc2-bounded-joint-rescue-v1` は上の条件と既存搬送手順を指す。
文字列一致だけで比較可能とせず、元の作用記録と明示した取得条件を照合する。
この境界には隠れた能力・荷重の同一性を含めない。
従って「同じ可視条件で異なる結果」が得られても、完全に同じ物理条件の偶然変動とは呼ばない。

## 4. 入力・受付・欠落

入口は `runtime.rescue_selection.RescueSelectionEvaluator(protocol, profile).evaluate(materials, request)`。
構築時にexperiment ID、A/B/C、問い・規則版・context_ref・3件対応表を含むprotocolと、
固定profileの全内容をコピーして保持する。評価時にprotocolを変更する口は設けない。
評価は純粋再生とし、Experience store・SOC-1 selector・既存Runtime stateへ書き込まない。
判定済みの件数やdispositionを外部から受け取って信用する入口にはしない。

試行開始前にexperiment ID、問い、規則版、context_refと、**3件のEpisode / world run対応表**を固定する。
requestはこの3 Episode全件を指定する。成功だけを指定する部分リスト、暗黙の最新履歴選択、ID番号による条件分岐は不可。
対応表の出典を保存し、どのEpisodeに何が欠けたかを追跡する。
materialsはEpisode材料と明示的なmissing_episode_idsで、対応表の3件を過不足なく分割する。
黙った省略や同一Episodeの両側への指定は拒否する。
未知の参照・重複ID・対応表の変更は入力拒否。登録済みEpisodeの未取得は明示欠落としてDEFERにする。

各Episode材料は `soc2-rescue-episode-v1` の限定envelopeと、そのrunのSOC-0受付snapshotからなる。
envelopeはepisode_id、world_run_id、context_ref、coverage（complete / partial）、
termination（delivered / carry_failed / not_attempted / interrupted）、順序付きevent_refsを持つ。
これは試験adapterが取得範囲と終了事由を報告するもの。terminationだけから成功・失敗を決めない。

各SOC-0 eventを既存 `RescueExperienceStore` と同じ検証へ通し、record_idとpayloadを再照合する。
同じrun内の時刻は非減少、作用のsource/subsequent observation参照を保持する。
別run間でtick値を比較して順序や独立性を捏造しない。
actor/target混線、A/C以外の参加者、参照の欠落・改変、未知field、同一eventの多重参照は拒否する。
同event再送は受付側で同一recordに収束し、複数Episodeや複数試行として数えない。

正規のpartial報告と、event_refsにあるのにpayloadがない破損入力を分ける。
helperが参加できず実参加者がAだけだった等、A/Cの範囲内で予定条件が成立しなかった報告は
`condition_not_realized` とし、joint失敗に数えない。
記録の真正性、未報告試行の有無、coverage報告の正しさはadapterと実験harnessの責務。
有限snapshotの整合性検査だけで外部のWorld実行を認証できるとは主張しない。

## 5. Episode検査と判定用の計数

各Episodeはjointを最大1回試す。1 Episode最大2 event、3 Episodeで最大6 event。
失敗後の条件変更・再試行・同じEpisode内の成功による相殺は初版に含めない。
Episode材料・参照・snapshot recordの予算は入力時、重複排除前に検査する。
上限超過を切り詰めず拒否する。IDは空白だけでない128文字以内、未知fieldは拒否する。

| 取得された記録 | 検査結果 | 判定用の扱い |
| --- | --- | --- |
| 同じA+Cのcarry成立 → 対応するdelivery、取得範囲complete | `success` | 成功1 Episode |
| A+Cが実参加してrescueを試み、carry_not_established・非移動、completeで終了 | `failure` | 失敗1 Episode |
| carry成立だけで配送が未完了・中断 | `unresolved` / `delivery_unconfirmed` | DEFER |
| 試行なし、参加条件不足、context不一致、partial | `unresolved` / 各理由 | DEFER |
| deliveryのみ、失敗後delivery、異なる参加者へのすり替え、終端報告と記録の矛盾 | 入力拒否 | 判定しない |

successには同一run/actor/target/参加者によるordered carry→deliveryの対応を要求する。
rescue時点では対象が行動不能で、actorが行動可能であることも照合する。
failureは実行済みrescueの有限な結果であり、「delivery記録がない」だけでは作らない。
途中の運搬不成立や期限切れを、attach失敗と同じ種類の反例へ広げない。
Recovery完了は成功fixtureの回帰確認として別記し、選別の成功票を増やさない。

全3 Episodeを検査できる場合だけ `comparison_complete=true` とし、n=3、k=失敗Episode数とする。
一つでもunresolvedなら全体DEFER、判定用k/nはnull。
その場合も、検査できた成功・反例・欠落理由をEpisode別にすべて残す。
部分集合を分母にした成功率や、未試行を失敗とした率は返さない。

## 6. 二つの固定SelectionProfile

profile schemaは `soc2-selection-profile-v1`。
fieldはschema、agent_id、profile_id、revision、tolerance_numerator、tolerance_denominator。
IDは空白だけでない128文字以内、revisionは整数1。
許可分数は既約の **0/1 と 1/3のみ**。bool、float、負数、分母0、2/6、未知fieldは拒否。
同じexperiment/agentの二つの独立評価instanceで同じ材料を再生する。
profile差替えや返却値の変更が既存instanceへ影響する入口は作らない。

比較が完了した場合に限り、許容分数p/qについて `k*q <= n*p` ならRETAIN、超過ならREJECT。
整数演算を使い、経験は等重み。身体・神経・履歴からp/qを動的に作らない。

| 同じ3 Episodeの検査結果 | 0/1 | 1/3 |
| --- | --- | --- |
| 成功3・失敗0 | RETAIN / `no_observed_failure` | RETAIN / `no_observed_failure` |
| 成功2・失敗1 | REJECT / `exceeds_declared_tolerance` | RETAIN / `within_declared_tolerance` |
| 成功1・失敗2、または失敗3 | REJECT | REJECT |
| 反例あり＋一件でもunresolved | DEFER | DEFER |

許容対象はこの検査集合の搬送試行失敗比率だけ。生命の価値や負傷の許容、母集団の成功確率ではない。
一度の反例が許容されたことと、反例が消えたことを明確に分ける。

## 7. 出力と非介入

出力は `soc2-rescue-selection-evaluation-v1`。
問い・規則版・experiment・固定A/B/C・context_ref・profile全内容・全3件の出典とEpisode検査結果、
comparison_complete、判定用k/n、p/q、disposition、理由を保持する。
source recordsは両条件で同一。許容0の `baseline_disposition` も再計算し、許容1/3で上書きしない。
反例event、判定不能理由、成功のcarry/deliveryの両参照を残す。

結果IDは凍結した条件と全入力から決定する。Episode材料の配列順に依存しないが、
Episode内の作用順を並べ替えて壊れた列を修復してはならない。
同じ完全入力の再評価は同じ結果。profile差による結果IDの違いを経験差として数えない。
新しい支持数store、選択履歴ledger、永続化、自動呼出しhookは追加しない。
入力・返却値は独立し、評価失敗でも元storeや既存stateを部分変更しない。

## 8. 実Godot記録の取得条件

既存SOC-0のGodot providerとRescue Runtimeを再利用し、joint試行を明示する専用harnessを作る。
SOC-1 selectorを無理に通して初手jointへ誘導せず、今回の候補が試験側指定であることを明記する。
SOC-0/1の保存済み成功を失敗に書き換えて、実World反例とすることは禁止する。

独立した3 runを取得する。A/Cの能力は各1、対象荷重は二つのrunで2、一つで3。
いずれもAとCが実際に参加できる位置・身体状態を用意し、既存resolverにrescueを実行させる。
荷重3のrunではattach不成立と対象非移動を実Worldで検査する。
負の結果を受け取った時点で有限試行を終了し、成功するまでリトライさせない。
成功2 runは既存deliveryとRecoveryまで進める。各run最大30行動決定、World側既存の有限台帳を維持する。

荷重の設定・位置・World検査ログは実験者側へ隔離する。
選別には、それらを含まない受付済み作用記録と限定envelopeだけを渡す。
この操作で変わるのは隠れた物理条件であり、jointの失敗が「Cは信用できない」を示すわけではない。
同一の3 run記録を二つのprofileで評価するので、選別差の比較時にはWorldや入力履歴を変えない。
三つの結果を得てから行うoffline比較で、次Episodeの自律的な行動選択の証拠にはしない。

実記録は改変せず出典付きfixtureに保存し、Pythonから受付と選別を再生する。
その他の失敗数境界・欠落・改変条件は合成試験として区別する。
SOC-1の全成功記録だけから、この許容度によるdisposition差を実証したとは記載しない。

## 9. 受入条件（S2-01〜10 PASS）

| ID | 必須検査 |
| --- | --- |
| S2-01 | 実Godotで独立3 run、joint delivery成功2・実attach失敗1。失敗時の非移動、成功時の既存Recovery |
| S2-02 | 同じ受付済み3 Episodeで0/1はREJECT、1/3はRETAIN。source・Episode検査・k/nは一致 |
| S2-03 | 失敗0/3、1/3、2/3、3/3の整数境界。全成功なら判定差がない |
| S2-04 | 未試行・参加不足・partial・context差・attachのみはDEFER。反例との併存でも全理由を保持 |
| S2-05 | carry/deliveryで成功2票にしない。event再送、再評価、profile違いでもEpisode数は増えない |
| S2-06 | 事前3件対応表、部分指定・別個体・別target・別run・event流用・隠れfield・不正時系列を拒否 |
| S2-07 | 未知参照・deliveryのみ・矛盾した終端を拒否。明示欠落と破損入力を区別 |
| S2-08 | 固定profile検査、返却値非alias、順序不変ID、作用列の順序維持、全件/予算超過拒否 |
| S2-09 | 入力snapshot・SOC-1・既存Action/history/canonicalの非介入。NERV/T1非呼出し |
| S2-10 | SOC-0/1・既存Rescue回帰、全体テスト。実機/再生/合成を分けてEvidenceへ記録 |

専用20テスト、実Godot独立3 runと保存記録の再生をPASS。
受入の内訳、実機/合成の区別、回帰結果はEvidenceを正本とする。
停止点は「同じ有限経験への固定選別条件差」まで。
神経・身体・履歴が条件を変える機構、援助要請、他者評価、社会relation、次回行動、T1接続は別工程とする。

## 10. 実装された形式と信頼境界

- protocol: `soc2-rescue-protocol-v1`。schema、experiment_id、agent_id、target_id、helper_id、
  purpose、rule、context_ref、episodes（episode_id / world_run_idの3件対応表）。
- request: experiment_id、purpose、episode_ids（全3件）。
- materials: episodes（envelope / snapshot）、missing_episode_ids。二集合は対応表を過不足なく分割する。
- event_refsは受付snapshotのrecord_idを参照し、その順序がEpisode内の作用順となる。
  snapshotのrecord配列順は意味を持たない。出力sourceではevent_refs順へ整列するがeventの値は変えない。
- 判定用k/nのfieldはfailure_count / validation_count。profile分数とbaseline_dispositionも別に保存する。

Episode検査はstatusとobserved_outcomeを分ける。参加条件不足・partial等でstatusがunresolvedでも、
記録自体のcarry失敗はobserved_outcomeとsourceに残す。これをjointの失敗票にはしない。
actorが行動不能ならactor_unavailable、rescue結果で対象の行動不能を確認できなければ
`target_not_incapacitated`としてDEFERにする。関係のすり替えや不正な作用列は先に入力拒否する。

受付再検証は一時的なSOC-0 storeで行う。record_idは従来のrun/event identity由来であり、
署名やpayloadの真正性保証ではない。入力を外部の原本と認証照合する機構は追加していない。
protocol/profileは公開APIで差替え不可だが、Python内部属性への直接改変を防ぐセキュリティ境界ではない。

実機の作用結果はGodotから出力後、Python harnessが明示的にSOC-0 storeへ受理する。
既存HTTPは通常の観測・行動・InteractionHistoryに使用し、SOC-2受付endpointは追加しない。
失敗runではharnessが処理を終了する。既存Rescue policyが自律的に失敗を選別・中断した証拠にはしない。

## 次工程（SOC-3実装・受入済み）

[SOC-3契約](SOC_3_selection_guided_rescue_contract.md)で、固定選別結果を新しい1 Episodeの
joint候補の使用可否へ渡す境界を定義した。SOC-2の純粋評価・反例保持・集計は変更しない。
RETAINを身体実行命令にせず、現在条件と共通順位付けを通す。
[SOC-3 Evidence](../experiment-evidence/SOC_3_selection_guided_rescue_evidence.md)で次Episodeの実行差を確認した。
SOC-2自体は純粋な局所評価として維持し、NERV/T1へ接続しない。
