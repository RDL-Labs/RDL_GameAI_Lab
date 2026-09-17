# RDL_GameAI — 神経パラメーター設計図

**文書種別:** Neural Dynamics / Agent Parameter Blueprint  
**版:** v0.1  
**位置づけ:** RDL_GameAI_Lab / GameAI-local design

**責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)のB/D軸。操作的ラベル、DNA基準分布、動的状態、派生感度の正本。
**依存:** [Layer計画](RDL_GameAI_NPC_レイヤー別設計計画.md)の所有・更新境界、[睡眠設計](RDL_GameAI_睡眠システム設計.md)の横断更新。
**非責務・状態:** 実在生物学の断定、canonical M_Bの定義・更新権限ではない。全サブタイプ・DNA・動的神経状態はdesign-only。既存の固定retry profileは神経値由来ではない。

## 0. 一文定義

> **神経パラメーターは、個体が同じ観測・経験・関係に対してどの程度反応し、行動し、保持し、再構成しやすいかを規定するGameAI-localな基層パラメーターである。**

人格そのものを直接記述しない。

```text
神経力学パラメーター
→ 観測・行動・注意・学習・記憶・睡眠整理への偏り
→ Experience History
→ GameAI-local relation candidates
→ canonical形成へ接続する場合のみ別契約の検査・選別・再構成
→ 個体固有の行動傾向
```

---

## 1. 操作的ラベル

以下の名称をそのまま採用する。

```text
Dopamine / DA
  D1 / D2 / D3 / D4

Serotonin / 5-HT
  5-HT1 / 5-HT2 / 5-HT3 / 5-HT4

Oxytocin / OXT

Noradrenaline / NA
  α1 / α2 / β
```

これらは生物学的実在を厳密に再現するためではなく、個体の評価傾向・反応特性・重み付けを設計するための操作的近似である。

---

## 2. DNAとの関係

DNAは行動そのものを決定しない。

DNAは各神経パラメーターの基準分布を規定する。

```text
NeuralGeneParameter
- name
- mean / μ
- sigma / σ
- optional mutation_rate
```

σは標準偏差として扱い、分散はσ²と区別する。DNAは神経基準分布を与えるが、Body・context・historyからなる瞬間状態を直接指定しない。

例:

```text
D1 μ / σ
D2 μ / σ
D3 μ / σ
D4 μ / σ
5-HT1 μ / σ
...
OXT μ / σ
α1 μ / σ
α2 μ / σ
β μ / σ
```

初期モデルでは、

```text
Parameter(t) ~ Normal(μ_DNA, σ_DNA)
```

を基本近似としてよい。

実際の瞬間値は、

```text
genetic baseline
+ body state
+ current context
+ learned relation effects
+ recent history
+ stochastic fluctuation
```

から決まる。

DNAは生涯中の基準であり、経験そのものによって直接書き換えない。

---

## 3. Dopamine

### D1 — 行動実行促進

行動候補を実際の行動へ移しやすくする。

### D2 — 行動抑制

行動候補へブレーキをかける。

```text
D1 >> D2 → 即行動寄り
D2 >> D1 → 保留・慎重寄り
```

### D3 — 反復・再現性固定

成功した行動、経路、対象選択を反復しやすくする。

```text
この場所で食料を得た
→ D3高
→ 同じ場所へ戻りやすい
```

### D4 — 低刺激時探索

低刺激・低変化状態が続いた時に自発探索を起こしやすくする。

```text
低刺激
→ D4
→ 未知の場所 / 物 / 他個体へ接近
```

---

## 4. Serotonin

### 5-HT1 — 減衰・鎮静

刺激後の反応を落ち着かせ、通常状態へ戻りやすくする。

### 5-HT2 — 感度増幅

小さな差・変化へ強く反応しやすくする。

### 5-HT3 — 強制割り込み

急激な刺激で現在行動を中断しやすくする。

### 5-HT4 — 処理速度

認識・切替・再判断の速度へ影響する。

---

## 5. Oxytocin

### OXT — 関係重み・関係持続性

OXTは「好感度」ではない。

対象は人だけに限定しない。

```text
Person
Object
Place / Space
Concept
Community
```

主な作用候補:

```text
対象へのsalience上昇
対象への接近傾向
対象関連経験の保持
睡眠整理時の残存確率
関係の反復・持続
対象状態が行動へ与える影響の増幅
```

例:

```text
Aに助けられた
→ A ↔ safety

毛布で安心して眠れた
→ blanket ↔ safety

木の下で何度も休んだ
→ place ↔ rest
```

```text
OXT高
!= Aが好き
!= friendship score
!= B
```

具体的な関係内容はExperienceと再構成から形成される。

---

## 6. Noradrenaline

### α1 — 危険フォーカス

危険候補へ注意を固定しやすくする。

### α2 — 復帰調整

高覚醒状態を抑え、通常状態へ戻しやすくする。

### β — 非常時行動出力

逃走・救助・戦闘・運搬などの高出力行動を維持しやすくする。

Body / Energy systemとの接続が強い。

---

## 7. 派生Sensitivity

```text
DNA → neural μ/σ → dynamic state → derived sensitivity
→ attention / action / memory / consolidation bias
```

必要に応じ、下位神経値・Body・Historyから、

```text
Explore
Stabilize
Attach
Alert
```

や、

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
recoverability_sensitivity
```

等をGameAI-localな派生軸として得る。

これらはCore primitiveではない。

---

## 8. M_Bとの関係

以下の形成は将来の接続案。現行のcanonical M_Bは凍結count evaluatorであり、神経状態・圧縮履歴そのものではない。

```text
Neural Dynamics
→ 何を拾うか
→ 何に強く反応するか
→ 何を残すか
→ どの関係が形成されやすいか

M_B
→ 現在その個体に形成されている具体的関係構造
```

両者を同一視しない。

---

## 9. 睡眠との接続

SleepはLayerではなく横断回復・consolidationイベント。sleep != T1。local候補の形成とcanonical採用を分離する。

```text
Experience History
→ Neural weighting
→ Selection
→ Compression
→ Association
→ GameAI-local relation candidate
→ canonical形成へ接続する場合のみ別契約で検査・選別・再構成
```

候補:

```text
D3高   → 反復経験が残りやすい
OXT高  → 人・物・場所との関係経験が残りやすい
5-HT2高 → 小さな差異を候補として拾いやすい
NA高   → 危険経験が優先保持されやすい
```

意味上の誤接続は許容する。

---

## 10. 個性

個性は固定タグではなく、

```text
DNA neural baseline
× individual fluctuation
× Body
× Experience
× M_B
× Sleep reconstruction
× Current Context
```

から形成される。

同じDNA基準でも、経験が違えば個体差は拡大しうる。

---

## 11. 初期実装

将来の実装案として全サブタイプのスロットを検討する。現在のデータ構造に存在するという意味ではなく、本整理では追加しない。

初期接続候補:

```text
D1 / D2 / D4
5-HT1 / 5-HT2
OXT
α1 / α2 / β
```

後段:

```text
D3
5-HT3
5-HT4
```

を習慣・割り込み・処理速度へ接続する。

---

## 12. 設計上の不変条件

> **神経パラメーターは行動命令ではなく、反応・注意・行動・記憶・再構成の重み付け条件である。**

> **DNAは神経パラメーターの基準分布を規定するが、実際の行動・状態・M_Bを直接決定しない。**

> **Person / Object / Place / Concept への関係は共通の関係形成機構で扱える。**

> **意味上の誤学習は許容するが、履歴・参照・provenanceなどの構造的整合性は保持する。**

---

## 一文圧縮

> **GameAIの個性は、DNAが与える神経力学パラメーターの基準分布を土台に、瞬間的な揺らぎ、身体状態、経験、関係、睡眠再構成が相互作用することで生成される。**
