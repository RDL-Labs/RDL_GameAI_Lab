# RDL_GameAI 全体設計地図 v0.1

*MASTER DESIGN MAP — canonical成熟度・NPC内部レイヤー・ゲーム機能・横断システムを分離して接続する*

## 0. 目的

RDL_GameAI_Lab では、設計対象が増えるにつれて異なる種類の計画が同じ一本道へ混ざりやすくなった。

本稿では、全体を次の4つのViewへ分離する。

```text
A. Canonical / RDL Maturity
B. NPC Internal Layer Profile
C. Game Feature Roadmap
D. Cross-cutting Systems
```

重要なのは、

```text
canonicalの成熟順
!= NPC内部構造
!= ゲーム機能の実装順
!= 横断システムの更新契機
```

である。

この文書はそれらを一つの巨大ロードマップへ統合せず、接続関係だけを示す。

---

## 1. A — Canonical / RDL Maturity

canonical側では、現行Core v2.3の意味境界を維持する。

```text
bounded observation
→ Purpose / finite B
→ RIB_B
→ frozen pre-update M_B
→ F / F'
→ E
→ finite review
→ unresolved H
→ M_Δ
→ Probe
→ Expansion
→ Inspection
→ Selection
→ Reconstruction
→ M_B'
→ finite-context authority
```

GameAI-localな生活状態・神経状態・履歴・会話状態を追加しただけでは、canonical authorityは増えない。

```text
GameAI-local state
!= Core primitive by identity
!= canonical M_B by identity
!= graph mutation authority
```

canonical成熟度の詳細は `notes/experiment-roadmap.md` を正本とする。

---

## 2. B — NPC Internal Layer Profile

NPC内部は、更新速度・保持期間・拘束伝播の違いを観察するため、次のLayer Profileを使う。

```text
Generation / DNA
        ↓
Neural Dynamics
        ↓
Physical / Body
        ↓
Experience / Relation History
        ↓
Realtime / Current Context
```

これはNPCの存在論ではなく、実装・比較・試験のための整理Viewである。

### 2.1 Generation / DNA

DNAは性格や行動を直接指定しない。

```text
DNA
→ neural parameter baseline distribution
→ body / sensory possibility range
```

神経系については、各パラメーターの基準値と揺らぎ幅を与える。

```text
parameter μ
parameter σ
```

初期実装では生涯中immutableでよい。

### 2.2 Neural Dynamics

GameAIでは、神経物質名を操作的近似ラベルとして保持する。

```text
Dopamine
├ D1
├ D2
├ D3
└ D4

Serotonin
├ 5-HT1
├ 5-HT2
├ 5-HT3
└ 5-HT4

Oxytocin
└ OXT

Noradrenaline
├ α1
├ α2
└ β
```

これらは、注意・反応・行動開始・抑制・反復・関係保持・警戒・回復等への偏りを与える。

### 2.3 Physical / Body

```text
FoodNeed
RestNeed
EnergyReserve
ActiveEnergy
injury
movement capability
sensory capability
```

などを所有する。

Body状態は急変しうる。

### 2.4 Experience / Relation History

有限interactionの履歴を保持する。

```text
誰に助けられた
どこで襲われた
どの食料が役立った
誰から何を聞いた
どの行動が成功した
```

正負・矛盾した履歴は共存できる。

### 2.5 Realtime / Current Context

tickまたは短期windowで高速に変化する現在条件。

```text
currently visible agents / objects / places
current target
current action
current place
recent event
current hunger / fatigue snapshot
```

---

## 3. C — Game Feature Roadmap

生活世界の縦方向の実装順は、canonical roadmapとは別に管理する。

第一開発ライン:

```text
Food
↓
Rest
↓
EnergyReserve / ActiveEnergy
↓
Safety / Danger
↓
Incapacitation / Injury
↓
Rescue / Recovery
↓
Hunting
```

第二開発ライン:

```text
Materials
↓
Tools
↓
Crafting
↓
Barter
↓
Emergent Value
```

この縦方向の詳細は `RDL_GameAI_実装手順予定.md` を正本とする。

---

## 4. D — Cross-cutting Systems

次のシステムは単純なPhase番号へ置かない。

```text
World Time
Sleep / Consolidation
Communication
Lexicon
Player Intervention
Neural Dynamics
Relation Formation
```

これらは複数のGame FeatureとNPC Layerを横断する。

---

## 5. World Time

時間は生活周期を成立させる横断条件である。

```text
朝
→ 活動
→ 昼
→ 探索 / 食料 / 会話 / 危険
→ 夕方
→ 帰還
→ 夜
→ 睡眠
→ 翌朝
```

時間は、

- 食事周期
- 疲労
- 就寝
- 危険生物の活動時間
- ルーチン
- 不在検出
- 行方不明捜索

へ接続する。

---

## 6. Sleep / Consolidation

睡眠は独立した第6Layerではない。

```text
Sleep
├ Body Recovery
└ Experience Consolidation
```

睡眠を契機として、日中に蓄積した有限履歴を選別・圧縮・再構成する。

```text
Experience History
↓
Neural weighting
↓
Selection
↓
Compression
↓
Association
↓
翌日の関係構造 / M_B形成候補
```

GameAIでは、

- 忘却
- 一般化
- 誤一般化
- 誤接続
- 妙な連想

を意味上の正常動作として許容する。

ただしprovenanceや参照整合性の破損は許容しない。

---

## 7. Communication / Lexicon

会話は有限interactionとして扱う。

```text
A current state
→ CommunicativeIntent
→ Expression
→ B observes
→ B interprets under own finite relation structure
→ response
```

```text
Aが伝えた意味
!= Bへ直接コピーされた内部状態
!= World Truth
```

初期intent候補:

```text
GREET
CALL
POINT
REQUEST
OFFER
WARN
HELP
ACK
```

会話履歴はExperience / Relation Historyへ接続できる。

---

## 8. Player Intervention

暫定Player Interfaceは拠点内の「しゃべる神の像」とする。

初期の主な役割は、

```text
未知対象
→ NPCが質問
→ Playerが語彙を供給
→ NPCが語との関係候補を形成
→ NPC間で伝播
```

である。

PlayerはTruth Sourceではない。

```text
Player says X
!= World Truth = X
```

プレイヤー発言は、NPCが観測した一つの情報・履歴として扱う。

---

## 9. Relation Formation

関係は単一好感度へ潰さない。

```text
Aに助けられた
Aに物を取られた
```

から、

```text
A ↔ help
A ↔ safety
A ↔ possession-risk
```

のような複数・矛盾した関係が共存できる。

対象は他個体だけに限定しない。

```text
Person
Object
Place / Space
Concept
Community
```

OXT等のNeural Dynamicsは、これらの関係をどれだけ拾い・保持し・再利用しやすいかへ影響できる。

---

## 10. 神経力学と個性

個性を固定Personalityタグとして直接実装しない。

```text
DNA neural baseline
×
current neural fluctuation
×
Body
×
Experience
×
Current Context
×
Sleep Reconstruction
→ individual behavior tendency
```

個性は「何を知っているか」だけでなく、

- 何を拾いやすいか
- 何へ反応しやすいか
- 何を反復しやすいか
- 何を忘れにくいか
- 未知へどう反応するか
- 危険からどの程度戻りやすいか

の偏りとして現れる。

---

## 11. 誤りを許すGameAI

GameAIでは意味上の誤りを世界現象として許容する。

```text
semantic fallibility allowed
structural integrity required
```

許容例:

```text
誤認
誤一般化
誤命名
噂
妙な連想
誤った危険判断
偏った人物評価
```

非許容例:

```text
履歴破損
item_id破損
referent消失
provenance消失
意図しないcanonical mutation
```

誤りは、後続interactionによって補強・弱化・破断・再構成され得る。

---

## 12. 全体接続図

```text
                    ┌──────────────────────┐
                    │ Canonical RDL Path   │
                    │ B/RIB_B/F/E/H/T1...  │
                    └──────────┬───────────┘
                               │
                    finite reviewed connection
                               │
┌─────────────────────────────────────────────────────┐
│                 GameAI Agent Layers                 │
│                                                     │
│ Generation / DNA                                    │
│       ↓                                             │
│ Neural Dynamics                                     │
│       ↓                                             │
│ Physical / Body                                     │
│       ↕                                             │
│ Experience / Relation History                       │
│       ↕                                             │
│ Realtime / Current Context                          │
└─────────────────────────────────────────────────────┘
             ↕                  ↕
      Sleep Consolidation   Communication
             ↕                  ↕
          World Time         Vocabulary
                                ↕
                          Player / 神の像

             ↓ 全部を使って生活する ↓

Food / Rest / Safety / Rescue / Hunting
Materials / Tools / Crafting / Barter / Value
```

---

## 13. 文書責務

```text
RDL_GameAI_全体設計地図.md
→ 全体接続・責務分離

notes/experiment-roadmap.md
→ canonical成熟度

RDL_GameAI_NPC_レイヤー別設計計画.md
→ NPC Layerの所有・更新・保持・接続契約

RDL_GameAI_実装手順予定.md
→ 生活世界の縦実装順

RDL_GameAI_神経パラメーター設計図.md
→ Neural Dynamics / DNA baseline

RDL_GameAI_睡眠システム設計.md
→ Sleep / Consolidation

RDL_GameAI_簡易会話からプレイヤー介入まで.md
→ Communication / Lexicon

RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md
→ Player Interface

RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md
→ ゲーム体験・世界観・設計核
```

---

## 14. 現在の優先順

現在は、canonical側の安全性を維持しながら、生活世界のvertical sliceを増やす。

短期的には、

```text
既存 Experience / Body / Sensitivity slice
+
Food / Rest / Energy
+
World Time
+
Sleepの最小Consolidation
+
Communication MVP
```

を相互接続していく。

Generation / DNAは設計を確定しておくが、繁殖・進化runtimeは後段とする。

---

## 15. 一文圧縮

> **RDL_GameAI_Labでは、canonical RDLの成熟度、NPC内部の時間スケールLayer、生活世界の実装順、睡眠・会話・時間等の横断システムを別々のViewとして管理し、それぞれを有限な接続契約で組み合わせる。**
