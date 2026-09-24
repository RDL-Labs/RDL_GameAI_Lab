# RDL_GameAI — Sleep / Fast-Deep Experience Loop 実装計画

**文書種別:** Implementation Plan / DRAFT  
**版:** v0.1  
**基準HEAD:** `655ca6d`  
**位置づけ:** Rescue / Recovery完了後、Hunting着手前の時間循環実装  
**依存:** [睡眠システム設計](RDL_GameAI_睡眠システム設計.md)、[活動時高速類似と内向時間深層比較案](RDL_GameAI_活動時高速類似と内向時間深層比較_案.md)、[コード抽象度・道具的関数階層案](RDL_GameAI_コード抽象度・道具的関数階層_案.md)、Experience History

## 0. 目的

既存の生活縦断は次まで成立している。

```text
bounded observation
-> Goal
-> committed Trajectory
-> World change
-> causal Experience
```

本計画では、そのExperienceを時間越しのGameAI-local構造へ変換する。

```text
daytime Experience
-> finite Sleep window
-> Deep Similarity
-> one finite cluster
-> sourced relation candidate
-> next-morning Fast retrieval
```

成功・失敗・危険・救助を後日の個体差へ運べる基盤を、Huntingより先に作る。

## 1. 実装順

```text
Phase 5  Rescue / Recovery                          COMPLETE
Phase 6A finite Sleep window                       COMPLETE
Phase 6B Relation Constraint Profile               COMPLETE
Phase 6C Deep Similarity Shadow                    COMPLETE
Phase 6D real Sleep consolidation vertical        COMPLETE
Phase 7A Activity Fast Retrieval                   COMPLETE
Phase 7B Fast <-> Deep one-cycle Evidence          NEXT
Phase 8  Core sync / Dynamic M_B                   DEFERRED UNTIL PHASE 7
Hunting                                            DEFERRED UNTIL CROSS-SURFACE ROADMAP REVIEW
```

Sleepは内部Layerではなく横断更新イベントだが、本計画では実装優先順位を示すためPhase番号を使う。

実装責務はコード階層案に従い、relationの有限検査をI1、ExperienceからProfileへのpureな変換をI2、Fast / Deep SimilarityとSleep window保持をI3、実Sleep行動との接続をI4として分離する。HTTP / Godot / InspectorはI6に留める。

## 2. 共通境界

```text
Sleep action != Sleep Consolidation
Similarity Observation != Commitment != Active Constraint != Truth
relation candidate != canonical M_B admission
Sleep != T1
```

初期実装ではcandidateへ行動権限を与えず、raw Experienceを更新・削除・圧縮置換しない。

比較結果は最低限、次を保持する。

```text
source experience IDs
window ID / boundary
comparison purpose
evaluator identity / version
score / coverage / conflict / unresolved
formation tick / sleep cycle
```

## 3. Phase 6A — Finite Sleep Window

一個体のraw Experience Historyから、固定された有限windowを作る。

```text
accepted raw Experience
-> same agent filter
-> finite eligible set
-> fixed window of 3..6 records
-> immutable source references
```

### 境界

- 明示opt-in、最大6件。
- agentを跨いで混ぜない。
- pending resultは含めない。
- window形成後のraw History追加で既存windowを変えない。
- 不足時は `INSUFFICIENT_EVIDENCE` とし、空clusterを成功扱いしない。

### Acceptance

1. windowは有限で順序が固定される。
2. source IDsをすべて回収できる。
3. raw History snapshotは形成前後で不変。
4. replayは同じwindowを返す。
5. agent混線とsource消失を拒否する。

## 4. Phase 6B — Relation Constraint Profile

window内Experienceを比較可能な有限Profileへ投影する。

```text
actor relation
target relation
place/context relation
action relation
outcome relation
```

Rescue系では、rescuer、rescued agent、safe place、danger context、delivery / recovery outcomeの役割差を保持できるようにする。

### Acceptance

1. Profileはraw recordとは別の派生物。
2. relation identity、status、polarity、strengthは有限語彙。
3. exact World truthを後付けしない。
4. 各relationからsource Experienceへ戻れる。
5. Profile化だけではcandidateを確定しない。

## 5. Phase 6C — Deep Similarity Shadow

Sleep window内の少数Profileから、一つのclusterと一つのcommon relation candidateをshadow形成する。

```text
finite profiles
-> relation alignment
-> status eligibility
-> polarity / strength comparison
-> score + coverage + conflict + unresolved
-> one cluster
-> one common relation candidate
```

初期実装ではmulti-hop探索、大規模cluster、ランダム誤接続、忘却を行わない。

### Acceptance

1. 比較対象数と比較回数に上限がある。
2. coverage不足を低scoreへ潰さない。
3. conflictとunresolvedを分離する。
4. clusterはTruthやruleへ昇格しない。
5. candidateはshadow storeだけに保存される。
6. canonical snapshot、H、T1は不変。

### 最初のfixture

```text
experience 1: BによるRescue delivery
experience 2: Bとsafe placeを共有した回復結果
experience 3: B付近でdanger exposureが解消
-> Sleep Deep comparison
-> B <-> safety/help candidate
```

fixtureは役割付き有限relationの反復を検証するものであり、人格やTruthを固定しない。

## 6. Phase 6D — Sleep縦断Evidence

```text
day interactions
-> accepted Experience records
-> explicit safe sleep action
-> fixed consolidation window
-> Deep comparison
-> sourced candidate
-> next morning snapshot
```

### Acceptance

1. sleep action成功だけでcandidateを捏造しない。
2. Experience不足ならcandidateなしで終了する。
3. candidate sourceはacceptedされた昼Experienceだけ。
4. raw HistoryとWorld stateをconsolidationが変更しない。
5. 翌朝actionはまだcandidateによって変化しない。

## 7. Phase 7A — Activity Fast Retrieval

```text
current bounded profile
-> L0 relation identity overlap
-> top-k
-> L1 finite comparison
-> Inspector retrieval result
```

### Acceptance

1. top-kと比較回数が有限。
2. L0候補生成とL1評価を分離する。
3. raw Experienceとsleep candidateをsource typeで区別する。
4. Fast結果から新規relationを形成しない。
5. action policyへまだ接続しない。

## 8. Phase 7B — Fast / Deep One-Cycle Evidence

```text
day 1 interaction
-> night Deep candidate formation
-> day 2 bounded situation
-> Fast retrieval finds that candidate
-> Inspector shows complete source chain
```

この時点の完了条件は検索可能性であり、行動変化ではない。

## 9. Phase 7C — Reviewed Local Influence

行動影響は別契約でのみ解禁する。

```text
reviewed candidate
-> bounded current context
-> GameAI-local interpretation bias
-> finite action difference
```

禁止事項:

```text
candidateから直接action
clusterから直接canonical mutation
Sleepだけで人格確定
Deep scoreをTruth confidenceとして利用
sourceを失った圧縮relationの採用
```

## 10. Phase 8 — Core同期への移行条件

1. 有限Sleep windowが固定されている。
2. Deep comparisonが一つのsourced candidateを形成できる。
3. 翌朝Fast retrievalがcandidateを検索できる。
4. raw History / candidate / canonical stateが分離されている。
5. 実Godot/HTTP EvidenceとCIがある。

条件成立後は横断ロードマップのC1へ進み、Core `3270982`のSILN、`theta_eff`、`H`、`M_delta`をGameAI契約へ翻訳する。HuntingはDynamic M_BとGodot再統合の進捗を確認するまで保留する。

## 11. 実装単位

| PR | 内容 | 停止条件 |
|---|---|---|
| S1 | finite Sleep window store | COMPLETE: immutable source windowと不足状態 |
| S2 | Experience -> relation profile compiler | COMPLETE: provenance付き有限Profile |
| S3 | Deep comparator + one cluster/candidate | COMPLETE: shadow only、canonical非介入 |
| S4 | real Sleep consolidation vertical | COMPLETE: fixed daytime windowから実Sleep経由candidate |
| F1 | Activity Fast L0/L1 retrieval | COMPLETE: top-3、source type分離、p5 read-only表示 |
| F2 | Fast / Deep one-cycle Evidence | NEXT: day 2でsource chain回収 |
| F3 | reviewed local influence | 別途review後のみ |

各PRで全テストを通し、段階を跨いだ先行実装を行わない。

## 12. 完了状態

```text
NPCが日中に経験する
-> 夜に有限な深層比較を行う
-> provenance付きrelation candidateを形成する
-> 翌朝の高速検索で候補を再発見する
```

この一周が実World・実Runtime・同一個体で証明され、行動権限とcanonical authorityが未接続のままなら基礎段階を完了とする。
