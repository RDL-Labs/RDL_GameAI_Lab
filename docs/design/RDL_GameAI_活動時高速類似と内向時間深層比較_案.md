# RDL_GameAI — 活動時高速類似と内向時間深層比較 案

**文書種別:** Future Design Note / DRAFT  
**版:** v0.1  
**位置づけ:** RDL_GameAI_Lab / GameAI-local future design  
**依存:** `RDL_GameAI_睡眠システム設計.md`、Experience History、RDL Functions側 `02_RDL_関係拘束類似比較.md`  
**非責務:** canonical `M_B` 更新、T1そのもの、実在神経系DMNの再現、一般的な認知理論の主張を行わない。

---

## 0. 目的

NPCが過去経験を利用する際の関係類似計算を、常時同じ深さで実行しない。

外界へ即応する活動時間では軽量な比較を使い、外界要求が弱い休止時間や睡眠では、より広い関係構造を比較する。

```text
Activity
→ Fast Similarity
→ 現在行動を支える軽量な経験候補検索

Low external demand / internally-oriented idle
→ Reflective Similarity
→ 少し広い経験再比較・関連探索

Sleep
→ Deep Similarity
→ graph比較・cluster・共通relation抽出
→ candidate relation structure
```

ここで「DMN的」は、**外界への直接行動より内部経験の再比較・再関連付けへ計算資源を多く使う時間**という設計上の比喩であり、実在のDefault Mode Networkを忠実に再現するという意味ではない。

---

## 1. 共通原則

比較の深さと真理性を同一視しない。

```text
Fast
!= 雑なTruth

Deep
!= より真実

Similarity Observation
!= Commitment
!= Active Constraint
!= Truth
```

深い比較は、単により広い関係断面・近傍構造・複数経験を比較できるだけである。

また、比較不能を低類似へ潰さない。

```text
weak relation
!= absent relation
!= NOT_OBSERVED
!= UNRESOLVED
```

したがって比較結果は、単一scoreではなく最低限、

```text
score
coverage
conflict
unresolved
boundary
provenance
evaluator identity/version
```

を保持する。

---

## 2. Activity Mode — Fast Similarity

活動中は外界観測・Safety・Food・Rescue等への応答を優先する。

目的は高度な構造形成ではなく、**現在状況に似た過去経験を安価に数件引くこと**とする。

### L0 — relation identity overlap

最軽量段階。Current ProfileとPast Profileでshared `relation_id`だけを見る。

候補生成器として、

```text
overlap(A, B) = |R_A ∩ R_B|
```

または必要なら、

```text
Jaccard(A, B) = |R_A ∩ R_B| / |R_A ∪ R_B|
```

程度を使える。L0は正式な関係拘束類似の最終評価ではなく、後続比較へ送る候補削減用とする。

### L1 — finite relation comparison

L0で残った少数候補について、

```text
same relation identity
+ status eligibility
+ polarity
+ strength distance
```

を見る。

比較可能な同一relationについては、初期形として、

```text
similarity_r(A, B) = 1 - |strength_A(r) - strength_B(r)|
```

程度でよい。ただし必ず `score / coverage / conflict / unresolved` を分離する。

### Activityで行わないこと

原則として活動中には、

```text
multi-hop graph comparison
large cluster formation
common relation extraction
candidate structure generation
large-scale reassociation
```

を行わない。必要なら既に形成済みのrelation candidateを読むが、活動中のFast Similarity自体から大きな構造再編を起動しない。

---

## 3. Internally-Oriented Idle — Reflective Similarity

将来的にNPCが、

```text
何も急いでいない
安全
移動・作業要求が弱い
ぼーっとしている
休憩している
```

ような時間を持つ場合、Activityより広い比較を許す。これはSleepほど強いconsolidation windowではない。

```text
Experience History
↓
有限sample
↓
L1 comparison
↓
必要な候補のみ1-hop relation neighborhood
↓
小規模association candidate
```

を基本とする。この時間では「あれとこれ、少し似ていたかもしれない」という弱い内部候補を形成できるが、長時間の大規模clusterや強い圧縮はSleepへ残す。

---

## 4. Sleep — Deep Similarity

睡眠では外界への通常行動要求が大きく低下するため、Experience Consolidation用により深い比較を許す。

```text
Experience History
↓
finite sleep window selection
↓
Relation Constraint Profile
↓
relation alignment
↓
polarity / status eligibility
↓
strength comparison
↓
1-hop relation neighborhood comparison
↓
profile clustering
↓
common relation
exception relation
conflict
branch condition
↓
candidate relation structure
```

この経路は、現行睡眠設計の

```text
Experience History
→ Selection
→ Compression
→ Association
→ reconstructed relation candidates
```

に対する具体的な比較機構候補である。

---

## 5. Fast / Reflective / Deep の関係

```text
外界要求 高
ACTIVE
→ L0 / L1
→ 安価
→ 少数候補
→ 即応支援

外界要求 低
INTERNALLY-ORIENTED IDLE
→ L1 / L2
→ 小規模1-hop比較
→ association探索

SLEEP
→ L2 / L3 / L4
→ graph comparison
→ clustering
→ common / exception extraction
→ candidate structure generation
```

ここで段階名は実装上の仮称であり、RDL CoreのTierやT1段階を意味しない。

---

## 6. Experience Historyとの接続

raw Experience Historyを比較のたびに破壊・書換しない。

```text
raw Experience History
↓
comparison profile
↓
Similarity Observation
↓
cluster / extracted pattern
↓
relation candidate
```

を別オブジェクトとして追跡する。

最低限、relation candidateには、

```text
source experience IDs
comparison boundary
comparison purpose
evaluator identity/version
score
coverage
conflict
unresolved
formation time/window
```

を辿れるようにする。

意味上の誤一般化や妙な連想は許容しても、`source reference loss / silent history rewrite / provenance loss / implicit canonical mutation` は許容しない。

---

## 7. 睡眠時の誤接続

Deep Similarityは「正しい一般化機構」に限定しない。

例えば、

```text
森で危険生物に襲われた
雨が降っていた
光る石を持っていた
Aに助けられた
```

という複数経験から、

```text
森 ↔ danger
A ↔ safety
雨 ↔ danger
光る石 ↔ A
```

のようなcandidateが形成されてもよい。ただし、形成理由は比較・近接・cluster等のprovenanceから追跡可能でなければならない。

---

## 8. 計算資源と深度

将来的には処理深度をモード名だけで固定せず、有限な計算予算で制御できる。

候補入力:

```text
external urgency
current committed trajectory
available compute budget
unprocessed experience count
candidate density
sleep / rest state
```

例:

```text
high urgency
→ Fast only

safe idle + spare budget
→ small Reflective pass

sleep window
→ Deep pass
```

ただし、計算予算はsalience、Truth、知性、ρそのものではない。

---

## 9. ρとの境界

比較深度と観測解像度 `ρ` を同一視しない。

```text
high ρ
!= Deep Similarity

low ρ
!= Fast Similarity
```

`ρ` は有限Boundary内の関係識別解像度であり、Fast / DeepはGameAI側の**比較処理深度・計算予算・探索範囲**の区別である。

将来、入力Profileの生成時にρ差を使うことはあり得るが、別契約とする。

---

## 10. M_B / T1との境界

本設計が直接行うのは、

```text
Similarity Observation
cluster
candidate relation structure
```

まで。

```text
cluster
!= new rule

candidate relation structure
!= canonical M_B update
```

とする。

睡眠もぼーっとする時間もT1そのものではない。GameAI-sideで形成したcandidateをcanonical `M_B`へ接続する場合は、別途有限な検査・選別・再構成契約が必要になる。

---

## 11. 最小実装案

### Stage A — Fast candidate retrieval

```text
Experienceをrelation_id集合でindex
↓
Activity時
current profileからoverlap検索
↓
top-k候補
↓
L1 finite comparison
```

まずは行動権限を持たせず、Inspectorへ候補と比較理由を出す。

### Stage B — Reflective idle experiment

```text
safe / no urgent trajectory
↓
少量Experienceをsample
↓
1-hop comparison
↓
小規模association candidate
```

外界行動への影響はまだ与えない。

### Stage C — Sleep Deep experiment

```text
sleep window
↓
finite Experience set
↓
profile comparison
↓
cluster
↓
common / exception extraction
↓
candidate relation structure
```

翌日のGameAI-local relation candidateとしてshadow表示する。

### Stage D — reviewed influence

形成candidateが翌日の局所解釈や選択へ影響する経路を別途検証する。canonical admissionはさらに後段とする。

---

## 12. 最小受入条件

### Fast

1. Activity時の比較対象数に有限上限がある。
2. L0候補生成とL1評価を区別する。
3. UNRESOLVEDを0へ潰さない。
4. scoreとcoverageを分離する。
5. Fast結果だけでrelationを新規確定しない。

### Reflective

1. 外界要求が低い明示条件でのみ起動する。
2. Experience sample/windowが有限。
3. 1-hop範囲を越えて暗黙拡張しない。
4. candidate形成provenanceを保持する。

### Deep / Sleep

1. raw Historyを黙って書き換えない。
2. clusterをTruth / Commitmentへ昇格しない。
3. common / exception / conflict / unresolvedを分離する。
4. comparison boundaryとevaluator versionを回収可能にする。
5. relation candidateとcanonical `M_B`を同一視しない。

---

## 13. 一文圧縮

> **活動中は現在状況に似た経験を高速・浅く検索し、外界要求の弱い内向時間では少し深く再比較し、睡眠では関係近傍・cluster・共通/例外構造まで掘る。ただし深い比較はTruthを意味せず、出力は追跡可能なrelation candidateとして保持する。**