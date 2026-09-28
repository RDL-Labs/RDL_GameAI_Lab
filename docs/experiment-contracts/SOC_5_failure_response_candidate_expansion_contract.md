# SOC-5 実失敗後の有限候補展開

状態: **IMPLEMENTED / shadow-only finite candidate expansion** / 2026-09-28。  
[SOC-0](SOC_0_heavy_rescue_contract.md)〜[SOC-4](SOC_4_contextual_carry_prediction_contract.md)の既存結果を変更しない。  
[Evidence](../experiment-evidence/SOC_5_failure_response_candidate_expansion_evidence.md)。

## 1. 問いと停止点

SOC-0〜4では、単独搬送の実失敗、共同条件での成功、反復Experience、Selection差、次Episodeの条件選択、文脈付き単独carry予測まで確認した。一方で、**実際に失敗した直後に「次に何を試せるか」を有限に開く工程**はまだ独立していなかった。

SOC-5の問いは次だけに限定する。

```text
実際の solo carry failure
↓
失敗後の有限観測
↓
現在の条件で検討可能な応答候補を展開
↓
retry / reposition / known_tool / seek_agent / wait / abandon
```

ここでは候補を**選ばない**。`seek_agent`を選んでHELP/CALLを送ることも、既知道具を実際に使うことも、周囲の物を代用品として発明することも行わない。

したがって到達点は、

> **失敗が一つの負例で終わらず、次の有限探索空間を開く材料になりうることを、正解漏洩なしで表現する**

までである。

## 2. 候補語彙は設計者が与える

初版の候補語彙は固定する。

```text
retry
reposition
known_tool
seek_agent
wait
abandon
```

これはNPCが六種類の対処法を自律発明したことを意味しない。SOC-1の`solo / joint / defer`と同様、**操作可能な候補語彙を設計者が有限に与え、その時点で候補として成立するかを切り分ける試験**である。

候補の順序は優先順位ではない。score・winner・selectedを返さない。

## 3. 起点は実作用の失敗だけ

入口はSOC-0形式の受理可能な`RescueExperience`であり、以下を要求する。

```text
action = rescue
attempt_condition = solo
participants = [agent]
result = carry_not_established
target_moved = false
```

さらに、actorが行動不能化しておらず、targetの救助Goalがまだ残る有限条件に限定する。

事前予測`likely_not_established`、未試行、候補除外、defer、期間終了を失敗Eventとして代用しない。

```text
prediction != actual failure
not attempted != failure
selection rejection != failure
```

## 4. 失敗後Context

schemaは`soc5-post-failure-context-v1`。fieldを次に固定する。

```text
schema
run_id
agent_id
target_id
context_ref
source_observation_id
coverage
actor_ready
movement_ready
retry_budget_remaining
known_tool_refs
observed_agent_refs
```

`source_observation_id`は失敗Eventの**後続観測**へ一致させる。

許可しないもの:

```text
required_carriers
carry_load
combined_capacity
correct_helper_id
requires_helper
```

つまりWorld側が知っている「二人なら足りる」「Cが正解」といった答えを候補展開器へ渡さない。

`known_tool_refs`はすでに既知道具として参照可能な有限集合であり、新しい用途の発明を意味しない。`observed_agent_refs`は現在観測できる他個体の参照であり、その個体が助ける・有能・信頼できることを意味しない。

## 5. available / unavailable / unresolved

候補は二値だけにしない。

- **available**: 現在の有限Contextで、その候補を次段の検討対象として残せる。
- **unavailable**: 現在取得済み条件から、その候補をこの断面では使えない。
- **unresolved**: 取得不足のため不在・不可を確定しない。

特に`coverage=partial`で道具や他個体が見つからない場合、

```text
no reference observed
!=
no tool / no other agent exists
```

なので`unresolved`にする。

## 6. 各候補の初版条件

| 候補 | 初版の成立条件 | この段階で意味しないこと |
| --- | --- | --- |
| retry | actor ready かつ有限retry budgetが残る | retryが正解、成功する |
| reposition | actor ready かつ現在movement可能 | 別位置なら成功する |
| known_tool | 既知道具参照が現在取得済み | 道具の用途発明、代用品発見 |
| seek_agent | 他個体参照が現在取得済み | helper能力、信頼、友情、HELP送信 |
| wait | 非介入候補を常に保持 | 待てば改善する |
| abandon | Goalから離れる候補を保持 | Goalが無価値、永久破棄 |

`actor_ready=false`ではretry / reposition / known_tool / seek_agentをunavailableとする。wait / abandonは候補語彙として残す。

## 7. 「仲間に聞く」とCommunicationの境界

今回の`seek_agent`は、

> **他個体を次の問題解決経路として検討可能な候補へ載せる**

ところまでである。

まだ次は行わない。

```text
helper choice
CALL
HELP
POINT(target)
DialogueTurn
相手の解釈
相手の参加判断
共同再試行
```

これらはCommunication設計と接続する次契約に分離する。HELP/CALLを失敗Eventから直接自動発火させない。

## 8. Experience / Relation Historyとの境界

SOC-0〜4の経験から、他個体を含む条件で成功可能域が変わる記録は存在する。しかしSOC-5は、

```text
C is useful
C is trusted
ask C first
```

を形成しない。

後段では、`seek_agent`候補が選ばれ、実際に特定個体へ働きかけ、再試行結果が得られたとき、

```text
failure context
→ seek_agent / communication
→ participation
→ retry result
```

の因果鎖を別Experienceとして保持できるようにする。その反復から「この相手との関係では解決可能域が変わった」という局所Relation Candidateを検査できる余地を残す。

## 9. 道具利用の段階分離

今回の議論に合わせ、順序を分ける。

```text
SOC-5: 失敗 → 有限候補展開
↓
次段: 他個体への働きかけ（seek_agent → CALL / HELP / POINT）
↓
その次: 既知の道具を既知用途で使う
↓
さらに後: 周囲の物を代用品として使う / 新しい組合せを発見する
```

`known_tool`は候補語彙だけ先に置くが、SOC-5で実行・用途推論はしない。**代用品・新規組合せは別の高負荷探索問題**として残す。

## 10. 実装

`runtime/failure_response_candidates.py`の`expand_failure_response(...)`をshadow-only純粋関数として追加する。

出力は、

```text
source failure provenance
post-failure finite context
6 candidates
status / reasons / evidence_refs
candidate_set_id
```

だけ。永続store、通常bridge endpoint、既存action selector、Rescue Runtime、Communication Runtime、NERV/T1、canonical sidecarへhookを追加しない。

同じ内容から同じ`candidate_set_id`を生成し、入力と返却値をaliasしない。参照配列順は意味差にしない。

## 11. 受入条件

1. 実`carry_not_established`形式以外から候補集合を作らない。
2. solo失敗に限定し、joint失敗や予測結果を暗黙変換しない。
3. 6候補を固定語彙として返すが、score / rank / selectedを返さない。
4. 完全観測では既知道具・観測他個体の有無をavailable/unavailableへ反映する。
5. partial観測で参照なしを不在断定せずunresolvedにする。
6. retry budget・movement ready・actor readyを有限条件として反映する。
7. hidden capacity / load / correct helper / requires helperを入力できない。
8. trust / friendship / usefulness / CALL / HELP / POINT / DialogueTurnを生成しない。
9. 入力非変更、返却値非alias、参照順非依存を確認する。
10. 既存SOC-0〜4・Rescue・通常action pathへ介入しない。

## 一文圧縮

> **SOC-5は、実際の単独搬送失敗を「答え」や恒久的負例へ変えず、その後の有限観測からretry・reposition・既知道具・他個体・wait・abandonという次の検討候補を開くshadow工程である。候補の選択、HELP/CALL、社会relation、既知道具の実使用、代用品発見はまだ行わない。**
