# SOC-3 選別結果を次の救助Episodeの条件選択へ接続する

状態: **DESIGN ONLY / 未実装・受入未実施** / 2026-09-27。
基準: `13554374`。[SOC-1](SOC_1_repeated_heavy_rescue_contract.md)、
[SOC-2契約](SOC_2_rescue_selection_tolerance_contract.md)と
[検証済みEvidence](../experiment-evidence/SOC_2_rescue_selection_tolerance_evidence.md)。

## 1. 問いと到達点

同じ過去3 Episode、同じ現在の可視条件、同じ順位付け規則でも、固定選別条件0/1・1/3の違いが、
**次Episodeで試す搬送条件と実Worldの結果を変えるか**。
SOC-2のRETAINを直接rescue指令へ変換せず、jointを候補に含められるかを制限する。

```text
固定した過去3 Episode
→ SOC-2を再評価して根拠付き判定を凍結
→ 今回のjoint候補の使用可否
＋ 現在の実行可能条件
＋ 今回すでに失敗した条件
→ SOC-1と同じ順位付け
→ solo / joint / defer
→ 既存Rescueの実行と作用結果
```

これは同じAを二つのprofileで比較する独立runであり、他個体のExperienceをAへコピーする実験ではない。
実験上の変更変数は固定profileの許容分数とそれに由来する候補制限だけ。
二つの新runには別のEpisode / run / event IDを付けるが、これら識別子は選択基準に使わない。
候補語彙・共同参加・順位付け規則を発明したこと、神経・身体から選別条件が形成されたことは主張しない。
到達点は有限な次Episodeの行動差。NERV-4D、社会relation、canonical T1、M_B更新は接続しない。

## 2. 過去3件と現在1件を別の予算にする

SOC-1の`RepeatedRescueSelector`は自身の選択履歴を持つ最大3 Episode用である。
その内部archiveへSOC-2材料を注入したり、容量を4へ拡張したりしない。
SOC-3専用adapterが、読み取り専用の過去3 Episodeと、現在の新しい1 Episodeを分けて所有する。

入口案: `SelectionGuidedRescueEpisode(source_protocol, source_materials, source_request, profile, binding)`。
構築時に既存`RescueSelectionEvaluator`を呼び、全入力と評価結果をコピーして固定する。
外部から持ち込まれたevaluation辞書やdispositionだけを信用する入口は作らない。
SOC-2の不正入力拒否・DEFER・反例保持をそのまま維持する。

bindingはschema `soc3-rescue-binding-v1`、rule `soc3-selection-guided-rescue-v1`、
experiment_id、episode_id、world_run_id、agent_id、target_id、helper_id、context_refを持つ。
agent/target/helper/contextは元SOC-2 protocolへ束縛し、Episode / world runは過去3件と重複不可。
新しいeventにも過去event IDを再利用しない。ID文字列の番号やprofile名で行動を分岐しない。
全IDは空白だけでない128文字以内、未知fieldは拒否。規則・schemaは初版固定。

1 instanceは新しい1 Episodeだけを扱う。過去材料・profile・bindingの差替え、終端後の再開は不可。
今回得たExperienceは別のcurrent領域へ保存する。
過去の判定用failure_count / validation_countやevaluation_idを今回の結果で書き換えない。
次の学習cycleへ何を渡すかは、この初版の範囲外とする。

## 3. 選別による制限と現在の実行可能性

| SOC-2の判定 | joint候補の条件 | 記録する制限理由 |
| --- | --- | --- |
| RETAIN | 現在も実行可能で、今回未失敗なら候補に入る | 制限なし |
| REJECT | この新Episodeでは候補から除外 | selection_rejected |
| DEFER | この新Episodeでは使用を保留 | selection_unresolved（元の理由も保持） |

RETAINだけで実行を強制しない。helper不在・現在文脈不足・今回の失敗を過去の成功で上書きしない。
REJECTとDEFERはともに今回jointを選べないが、診断上は区別する。
この制限は固定した新Episode内で有効。永久禁止、別対象・別runへの権限として持ち出せない。
solo失敗後もjointのREJECT/DEFERを解除しない。

soloには今回のjoint選別を流用せず、両profileで共通の「未試行なら一度試せる」条件を与える。
これはsoloの有効性を学習済みという意味ではなく、設計者が与える有限な探索許可である。
候補語彙はsolo、joint、deferの3つ。deferは常に残す。

選択要求にはchoice_id、固定binding全内容、現在のsource_observation_id、context_ref、
現在のevents、available_conditionsを明示する。bindingは構築時の全内容と一致しなければ拒否する。
available_conditionsは重複なしの有限リストで、defer必須。
fixture adapterが現在のA/Bの条件とCの参加可能性を確認し、solo/jointの実行可能性だけを渡す。
荷重・能力・必要人数・正解条件・World座標は渡さない。
この参加可能性報告はharnessの責務であり、NPCによる援助意思の推論や一般的な観測機能ではない。

現在の文脈が元の対象・搬送手順に対応しない、または確認できない場合は両身体条件を使用せずdeferにする。
別agent/target/runの入力は正常な文脈不足へ丸めず拒否する。
Aが対象へ近づくapproachは既存Rescueへ任せ、実carry直前に参加条件をadapterで再確認する。
その前提が成立しなくなればincompleteで終了する。
jointを選んだのにAだけで代行して実行する処理は作らない。

## 4. 共通の順位付けと診断

使用可能かつ今回未失敗のsolo/jointを、次の順で選ぶ。

1. 過去のdelivery成功Episode数が多い。
2. 過去のcarry失敗Episode数が少ない。
3. 同点ならsolo優先。

候補がなければdefer。順位付けはprofileやRETAINという文字列から直接選択を返さない。
SOC-1の純粋な順位付け部分を切り出して共用してよいが、旧schema・choice ID・結果・上限は維持する。
SOC-2の結果から過去件数を再計算し、外部から渡されたscoreを信用しない。

標準材料ではjointの過去成功2・失敗1、soloは過去試行0である。
REJECTでjointを除外しても、jointの成功・失敗数と全出典を消さない。
過去比較がDEFERならjointの判定用集計はnullのままにし、判定できた部分だけで順位を付けない。
その場合の個別成功・反例・未確定理由は元評価に残す。soloの過去件数0は、この検査境界でsoloを評価した経験がないことを意味し、反証ではない。
過去材料はjoint候補の検査集合として参照する。参加条件不成立でAだけが試みた記録を、
別途検証せずsolo用の過去学習材料へ再分類しない。元の作用記録は残す。

各候補にcondition、available_now、selection_disposition、eligibility、exclusion_reasons、
failed_this_episode、過去の成功/失敗件数と参照を残す。
soloのselection_dispositionは対象外のnullとし、jointのREJECTをsoloへのRETAINに転用しない。
選択結果にはbinding、元evaluation_idと全根拠、現在の入力断面、選択条件・理由を保存する。
現在不可はcurrently_unavailable、今回失敗済みはfailed_this_episode、
現在文脈の不足はcurrent_context_unavailableとする。複数の除外理由は同時に保持し、
実行側の利用不可と選別側のREJECTを混同しない。

## 5. 現在Episodeの受付・再送・副作用

`choose(...)`はEpisode開始時と、実carry失敗の受付後だけ呼ぶ。
carry成立後は条件を再選択せず、既存Rescueがdeliveryまで進む。
現runのSOC-0作用記録を再検証し、選んだ条件・参加者・source observationとの対応を確認する。
選択時observationと実作用時observationはapproachを挟むため同一とは限らない。
adapterの監査ログでchoice → 実行したactionのsource → 結果eventを結ぶ。
同一run/actor/source_observationの作用は一つだけとし、event IDだけを変えた再計上も拒否する。

未選択条件の試行、過去run/event流用、prefix変更・省略、時刻逆行、同じ試行の別名計上、
carryなしdelivery、終端後のevent追加は拒否する。入力拒否で現在の受付・選択台帳を部分更新しない。
未実行、現在条件の喪失、attach後の未完了をcarry失敗へ変換しない。

同choice ID・同完全要求の再送は同じ記録を返す。内容変更は競合拒否。
再送応答は新しい身体作用の許可ではなく、既存選択の参照である。
adapterは現在run・最新choice・未終端を確認し、古いchoiceを再適用しない。
同じ実行済みrescue decisionの再送は既存SOC-0操作台帳で副作用を繰り返さない。
選択再送とWorld action再送を別の試験として確認する。

初版は一度に一つの選択/行動要求だけを扱う試験専用handlerで実行する。
通常bridgeへのendpoint追加や、進み続けるWorldでの任意の遅延・並行割込み保証は行わない。

## 6. 有限終了と未完了の意味

新Episodeは最大3 choice（再送を除く）、最大2 carry試行（各条件1回）、最大3 event、最大30行動決定。
過去3 Episode最大6 eventと現在最大3 eventを別々に検査し、上限超過は切り詰めず拒否する。
各choiceは副作用を実行せず条件を返し、harnessが参加設定と既存Rescue実行を担当する。

終端は`completed / deferred / incomplete`。
completedには対応するcarry→deliveryを要求し、deferredには最後の選択がdeferであることを要求する。
attachだけでdeferred/completedへ進めない。取得不完了・予算到達・現在条件喪失はincompleteとして保存する。
`finish_episode`で終端記録を凍結する。終了後の新choice/event/finishは拒否する。
既存choiceの完全再送は読取りとして返せるが、終端を解除せずadapterも再実行しない。

特に厳格側のsolo失敗後は、soloが今回失敗済み・jointが選別で除外済みとなりdeferを選ぶ。
そこでharnessは追加のRuntime行動要求を停止する。
監査上は`rescue_goal_status=pending`と未達targetを残し、救助完了や目標取消として扱わない。
これは永続的なGoal待機/再開機構ではなく、終了した有限試行の未達記録である。
既存Rescue commitmentを成功扱いで解放せず、実行終了時点の状態を記録してrunを閉じる。

選別のDEFERと、実行Episodeのdeferredを区別する。
例えばjointの選別がREJECTでも、他条件が残らずEpisodeがdeferredになる。
未実行jointにfailure eventを生成せず、defer自体を追加失敗票へ数えない。

## 7. 実Godotの最小受入構成

過去材料は出典付きの実SOC-2記録からprotocol/materialsを変更せず読み、保存済みevaluationsは信用せず再計算する。
新Episodeの結果は、開始前の評価・候補件数へ混ぜない。
既存SOC-0 Heavy providerとRescue Runtimeを使い、各runで全World/Runtime/履歴/台帳を新規にする。
主比較の2 runはA/C能力各1、B荷重2、同じ初期位置・身体・参加可能条件とする。
数値条件は実験者側へ隔離する。

| run | 選別条件 | 想定する選択・実行 | 終端と検査 |
| --- | --- | --- | --- |
| 主比較・厳格 | 0/1、joint REJECT | solo → 実carry失敗 → defer | deferred、B非移動、joint試行0、目標未達 |
| 主比較・許容 | 1/3、joint RETAIN | joint → carry → delivery | completed、solo試行0、既存Recovery完了 |
| 現在条件の対照 | 1/3、joint RETAIN、Cは参加不能 | solo → 実carry失敗 → defer | RETAINでもjoint試行0 |

三つ目はCを参加距離外に置く専用対照であり、主比較2 runの同条件性とは分ける。
profileやrun名に応じてsolo/jointをharnessが直接決定してはならない。
過去材料→再評価→候補制限→共通順位付け→実参加→作用結果の鎖を記録する。

choice一覧、元判定、初手、solo/joint試行数、今回の未試行条件、実action列、
actions_to_delivery（未達ならnull）、終端理由、B変位、Recoveryを保存する。
deferred側の行動数が少ないことを、救助効率向上とは扱わない。
全成功・全反例・過去DEFER・現在文脈不足・別ID・再送などはPython局所試験として実機3 runと区別する。

## 8. 受入条件（全件未実施）

| ID | 必須検査 |
| --- | --- |
| S3-01 | 同一の過去3 EpisodeをSOC-2で再評価。profile以外の根拠一致、反例と元集計を維持 |
| S3-02 | 同じ新World条件の主比較2 runでsolo失敗→deferred / joint→completedの実行差 |
| S3-03 | 実C不在対照でRETAINを強制実行にしない。現在不可・今回失敗・選別理由を分離 |
| S3-04 | 全成功なら両profile同じ候補、全反例なら両方除外。過去DEFERはREJECTに変換しない |
| S3-05 | 共通順位付け、soloの共通探索許可、RETAINからの直結やprofile名/番号分岐なし |
| S3-06 | 厳格側でjoint非復活。未実行joint/未完了/deferを失敗票にしない。目標未達を保持 |
| S3-07 | 過去3/現在1の独立予算、source因果参照、改変・混線・未選択試行・容量拒否、部分更新なし |
| S3-08 | choice完全再送と内容競合、古いchoiceの非適用、終端固定、実action再送の非重複 |
| S3-09 | 今回結果の過去評価への非混入、入力/出力独立、SOC-1旧choiceとSOC-2旧評価の互換 |
| S3-10 | SOC-0/1/2・既存Rescue回帰、全体テスト、NERV/T1非接続、実機/合成別のEvidence |

今回は契約のみ。実装・受入結果や新しいPASS件数は主張しない。
[RDL参照](../semantic-reference/RDL_Core_T0_T1_reference.md)に沿い、局所選別結果と身体実行権限を分ける。
固定選別基準による有限行動差で停止し、一般的な性格形成・自律援助要請・神経由来の条件更新は別工程とする。
