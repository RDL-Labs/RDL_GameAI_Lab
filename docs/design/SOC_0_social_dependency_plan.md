> ユーザー提供の着手計画を保存。以下のDRAFT表記は提出時の状態。実装結果は[SOC-0契約](../experiment-contracts/SOC_0_heavy_rescue_contract.md)と[Evidence](../experiment-evidence/SOC_0_heavy_rescue_evidence.md)を参照。

# SOC-0 社会依存の最小縦断実験
## 単独失敗から協働成立へ

状態: IMPLEMENTATION PLAN / DRAFT v0.1
対象: `RDL-Labs/RDL_GameAI_Lab`
基準: Observation v1 COMPLETE、NERV-1/2・3・4A・4B・4Cまでの現行実装を維持する。

---

## 0. この文書の目的

本稿は、RDL_GameAIにおいて社会性を直接実装するのではなく、

> **個体単独では成立しなかった行動が、他個体を含む条件では成立する**

という最小条件をWorld上に作り、その差を有限なExperienceとして取得するための実装方針を定める。

今回の中心仮説は以下である。

```text
身体的限界
↓
単独行動の失敗
↓
条件変更
↓
他個体を含む条件で成功
↓
成功可能域の拡張
↓
他個体とのrelation形成余地
```

ここで社会的relationそのものをハードコードしない。

最初に作るのは、

```text
他者がいるから助けを求める
```

という知識ではなく、

```text
自分だけで実行
→ 失敗

条件を変えて再試行
→ 他個体が関与
→ 成功
```

というWorld上の差である。

---

# 1. 基本原則

## 1.1 破断検査は特殊機構ではない

GameAIにおける初歩的な破断検査は、通常行動の失敗そのものでよい。

```text
候補Trajectory / Action
↓
実際に実行
↓
期待したWorld遷移が成立しない
↓
その条件で破断
```

新しい`RuptureTest`クラスや特殊な破断イベントを導入しない。

通常の、

- approach
- carry
- pickup
- travel
- use

等の実行結果が、そのまま有限な検査になり得る。

---

## 1.2 失敗は普遍的不可能を意味しない

単独搬送に失敗しても、

```text
「一人では絶対に運べない」
```

という一般知識を即座に形成してはならない。

得られた事実は、

```text
この個体
この身体状態
この対象
この時点
この方法
この条件
→ 搬送が成立しなかった
```

までである。

別条件では成立する可能性を残す。

---

## 1.3 成功も普遍的relationを意味しない

AとCが一度協働して成功しても、

```text
Cは信頼できる
Cは友達
他者は有益
```

などへ直接昇格させない。

取得するのはまず、

```text
solo condition
→ failure

joint condition
→ success
```

という有限な結果差である。

社会的意味は後段のExperience / Candidate / T1を通して形成する。

---

# 2. 既存資産との関係

現行GameAIにはすでに、

- Body / Energy系
- Injury
- Incapacitation
- Safety
- Rescue
- Safe-place delivery
- Staged Recovery
- Multi-Agent Rescue
- Luanti Multi-Agent World
- 個体別Observation
- Experience
- Outcome Gradient
- NERV-1〜4C

が存在する。

Rescueではすでに、

```text
負傷
→ incapacitated
→ 他個体が発見
→ approach
→ carry
→ safe-place delivery
→ recovery
```

まで成立している。

したがって、新しい社会システム全体を作る必要はない。

今回追加するのは、

> **既存Rescueの搬送成立条件に、個体単独では不足する有限な身体制約を持つ専用fixture**

を一本加えることである。

既存Rescueの通常経路を変更しない。

---

# 3. 最小World実験

仮称:

```text
SOC-0 Heavy Rescue
```

これは正式名称候補であり、既存命名体系により必要なら変更してよい。

---

## 3.1 登場個体

最低3個体。

```text
A = 救助を試みる個体
B = incapacitated target
C = 追加の搬送能力を持つ別個体
```

初版ではA/Cの能力差を作る必要はない。

```text
A carry_capacity = 1
C carry_capacity = 1
B carry_load     = 2
```

のような有限fixture値でよい。

これらの数値はWorld物理の試験条件であり、NPCへ完全情報として直接渡さない。

---

## 3.2 単独試行

Aが通常のRescue経路でBへ接近する。

```text
A
↓
Bを発見
↓
approach
↓
carry attempt
```

World側の搬送条件を満たさないため、搬送は成立しない。

最低限、

```text
B displacement = 0
carry not established
```

を確認する。

必要ならAへ有限なEnergy消費を与えてよいが、

```text
失敗するまで無限にEnergyを消費する
```

挙動にはしない。

---

## 3.3 失敗の扱い

失敗時にNPCへ、

```text
requires_two_agents = true
need_helper = true
Cを呼べ
```

などの答えを渡してはならない。

NPC側へ与えてよいのは、有限な作用結果だけ。

例えば、

```text
carry attempt occurred
target did not move
carry did not establish
bounded effort was spent
```

程度。

World内部では原因としてcapacity不足を保持してよい。

ただし、

```text
World truth
≠
NPC observation
```

を維持する。

---

# 4. 「じゃあどうする？」は次の探索問題として分離する

SOC-0では、

```text
単独失敗
→ 自律的にCへ助けを求める
```

までを一度に実装しない。

まず二条件を独立に成立させる。

### Condition SOLO

```text
Aのみ搬送へ参加
→ failure
```

### Condition JOINT

```text
A + C が搬送へ参加
→ success
```

初版では試験harnessが条件を明示的に作ってよい。

これにより、

> 他者を呼ぶ能力

と、

> 他者が関与すると可解域が変わるというWorld構造

を分離できる。

後者を先に固定する。

---

# 5. 協働搬送の最小規則

専用fixtureでは、搬送成立条件を例えば、

```text
Σ active_carrier_capacity >= target_carry_load
```

とする。

重要なのは、

```text
requires_two_agents = true
```

のような社会専用flagではなく、

**身体能力の合成によって結果として複数個体が必要になる**

構造にすることである。

例えば、

```text
A capacity = 1
B load = 2

A alone:
1 < 2
→ failure

A + C:
1 + 1 >= 2
→ success
```

となる。

将来的に、

```text
strong agent capacity = 2
```

が存在すれば、一個体でも搬送可能でよい。

したがって、

```text
二人必要
```

をWorld法則として固定しない。

---

# 6. JOINT成功

AとCの両方がBの搬送へ有効に参加した場合、

```text
combined capacity >= load
```

なら既存Rescueの搬送経路へ接続する。

```text
joint carry established
↓
safe-place movement
↓
delivery
↓
staged recovery
```

既存Recoveryまで完走させる。

ここで新しいRecovery系を作らない。

---

# 7. Experienceとして必要な差

SOC-0の重要な成果は社会relationそのものではなく、

```text
SOLO
action attempted
→ transport failure

JOINT
same class of goal
→ transport success
```

という別Experienceを取得できることである。

最低限、後段で次を区別可能にする。

```text
attempt condition
participants
target
result
body consequence
World consequence
```

ただしNPCのExperienceへ、

```text
hidden carry_load
hidden capacity total
requires_helper
```

などのWorld完全情報をそのまま入れない。

---

# 8. 初版ではrelation学習を自動接続しない

SOC-0だけで、

```text
A likes C
A trusts C
C is useful
social value
friendship
```

を形成しない。

まず、

```text
solo failure
joint success
```

の因果的に追跡可能なExperienceが残ることだけを確認する。

その後、別契約で、

```text
共同成功Experience
↓
Outcome Gradient
↓
NERV perceived gradient
↓
Bias
↓
反復Experience
↓
Candidate
↓
T1 inspection / selection
```

へ流す。

---

# 9. 「他者がいる」を直接報酬にしない

次のような処理は禁止する。

```text
other_agent_present
→ reward +1
```

または、

```text
cooperation
→ automatic positive Bias
```

としない。

価値が発生するなら、

```text
他個体が関与した条件
↓
以前失敗したGoalが成立
↓
Outcome差
```

から形成されるべきである。

---

# 10. coexistence と social relation を維持する

既存の原則、

```text
coexistence != social relation
```

を維持する。

SOC-0を通しても、

```text
visible_agent
```

が即、

```text
known helper
trusted person
social resource
```

になるわけではない。

今回確認するのは、

```text
他個体の身体的参加
→ World上の到達可能性が変化した
```

ことだけ。

---

# 11. 受入条件

## SOC0-01 単独搬送の実失敗

A単独でBの搬送を実行し、

```text
carry does not establish
B does not move
```

を実Worldで確認する。

事前に「不可能」と判定して行動を省略するだけでは不可。

---

## SOC0-02 失敗が有限

単独失敗で、

- 無限retryしない
- 無限Energy消費しない
- Bが不正に移動しない
- A/Bの状態が壊れない

こと。

---

## SOC0-03 答えを漏らさない

NPC観測・Experienceへ、

- required_carriers
- hidden carry_load
- hidden combined_capacity
- correct helper ID

を直接渡さない。

---

## SOC0-04 JOINT条件で成立

同じBについてA+Cが有効に参加すると搬送可能になる。

---

## SOC0-05 人数ではなく能力合成

搬送条件は「二人だから成功」ではなく、

```text
combined capability >= requirement
```

によって成立する。

---

## SOC0-06 既存Rescueへ接続

JOINT成立後は既存の、

```text
carry
→ delivery
→ recovery
```

を使い、新しい平行Rescue実装を作らない。

---

## SOC0-07 SOLO / JOINT結果の出典

単独失敗と共同成功を別Experienceとして追跡できる。

同一eventとして偽装しない。

---

## SOC0-08 社会relationを自動生成しない

SOC-0終了時点で、

- friendship
- trust
- usefulness
- social value
- role

などを自動生成しない。

---

## SOC0-09 既存回帰

既存の、

- single-carrier Rescue
- Multi-Agent Rescue
- Luanti multi-agent life
- Observation v1
- NERV-1〜4C

の既定挙動を変更しない。

専用opt-in fixtureで実装する。

---

## SOC0-10 停止境界

SOC-0の完了条件は、

```text
solo attempt
→ actual failure

joint condition
→ actual success

両方の有限Experience
→ provenance付きで取得
```

まで。

以下は次工程。

- 失敗後に自律的に他者を探す
- help request
- Communication
- 誰を呼ぶかの選択
- 他者relation Candidate
- trust
- attachment
- role
- barter
- distributed knowledge
- social Goal / Trajectory

---

# 12. 次段階の仮説

SOC-0成立後、次に問える。

```text
「一人で失敗した」
↓
次に何を試すか
```

ここではじめて、

- retry
- reposition
- tool use
- seek another agent
- wait
- abandon

などの候補展開が問題になる。

その取捨選択には将来的に、

```text
神経parameter
身体状態
履歴
relation importance
loss tolerance
probe tendency
persistence
```

が作用し得る。

これは人間語でいう、

- 恐怖
- 好奇心
- 執着
- 安心
- 社会依存傾向

等へ見える挙動を形成する可能性がある。

ただし、これらの感情ラベルをSOC-0で実装しない。

---

# 13. RDL上の読み方

本実験では、

> **通常行動の失敗そのものを、有限条件下での破断観測として扱う。**

```text
候補Trajectory
↓
World相互作用
↓
成立
  → その条件では残存

不成立
  → その条件では破断
```

ただし、

```text
failure != universal rejection
success != universal retention
```

である。

失敗・成功の反復と条件差を後段のInspection / Selectionへ渡す。

T1のretain / reject / defer、M_B再構成へSOC-0から直接接続しない。

---

# 14. Codexへの着手指示

1. 現行Rescue / Multi-Agent Rescue / Luanti multi-agent実装を確認する。
2. 既存single-carrier Rescueを変更せず、専用opt-in fixtureを作る。
3. 身体能力の合成による有限な搬送成立条件を最小追加する。
4. SOLOで実際にcarryを試みて失敗する経路を作る。
5. JOINTでは同じ対象をA+Cで搬送し、既存safe-place delivery / recoveryまで完走させる。
6. World内部能力値をNPCの観測・Experienceへ漏らさない。
7. SOLO failure / JOINT successを別Experienceとして記録する。
8. social relation、help seeking、Communication、NERV/T1接続は追加しない。
9. 既存Rescueと主要回帰を再実行する。
10. 実装後はEvidenceに「何を実Worldで確認したか」と「何をまだ主張しないか」を明記する。

**この一周がPASSした時点で停止すること。**
