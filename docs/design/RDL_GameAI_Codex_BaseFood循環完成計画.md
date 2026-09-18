# RDL_GameAI — Codex Base–Food循環完成計画

**文書種別:** Reference Loop Completion Plan  
**版:** v0.3  
**対象リポジトリ:** `RDL-Labs/RDL_GameAI_Lab`  
**実行主体想定:** Codex  

## 0. 今回の設計変更

v0.2では、

```text
NPC観測
→ NPC短期未来予測
→ Goal形成
→ Trajectory形成
```

を初期動作の中心に置いていた。

v0.3では、NPC自身に短期未来予測能力は保持しつつ、**初期生活の足掛かりは「神の像」が与える**。

```text
World state
→ 神の像による精密計算
→ 粗い生活指標
→ NPCが観測
→ NPC自身のM_Bで解釈
→ 短期未来予測
→ Goal形成
→ Trajectoryへ落ちる
```

神の像はNPCを直接操作しない。

```text
神の像の助言
≠ action command
```

あくまで有限な外部観測・教育cueとして扱う。

---

# 1. 中心命題

> **予測で動く脳は最初から持つ。ただし、最初に何を気にすべきかは神の像が教える。**

幼体・初期個体に、

```text
在庫減少
→ 近未来不足
→ 採取
```

という生活関係を最初から完成形で埋め込まない。

代わりに、

```text
神の像:
「食料が少なくなってきた」

↓
NPC:
Baseを見る
↓
scarcityを観測
↓
少し先を予測
↓
採取Goal
↓
成功 / 失敗
↓
経験
```

を反復させる。

---

# 2. 神の像の初期役割

最初の神の像は複雑な会話AIではなく、

> **Worldの精密状態を計算し、生活上意味のある粗い指標へ圧縮して渡す補助認知装置**

とする。

毎朝、自動的に状態を評価できる。

### 神の像側で扱ってよい精密値

```text
actual base_food_stock
consumption trend
Food Site actual resource amount
distance
time / sun progression
resident FoodNeed
movement state
```

### NPCへ渡す指標

例:

```text
食料:
- 十分
- 少なめ
- かなり少ない

採取地:
- まだありそう
- 減ってきた
- かなり少ない

日:
- 余裕あり
- 遠出注意
```

最初はFood関連だけでもよい。

---

# 3. 毎朝アクセス

初期個体は生活ルーチンとして、

```text
wake
→ 神の像へアクセス
→ 指標を受け取る
→ 今日の生活開始
```

を行う。

このアクセスは初期段階では半固定ルーチンでよい。

ただし、

```text
神の像の指標
→ 強制行動
```

にはしない。

NPCは、

```text
聞く
→ 観測する
→ 解釈する
→ 従う / 無視する / 後回し
```

ことができる。

---

# 4. NPC自身にも未来予測能力を持たせる

神の像が未来を全部決めるのではない。

NPC側にも最低限、

```text
current observation
+
current M_B
↓
short predictive continuity
```

を持たせる。

例:

```text
食料が少ない
→ さらに減りそう

日が傾く
→ 暗くなりそう

採取地が少ない
→ あまり取れなさそう
```

これは高度な計画ではなく、短期的な状態推移予測。

---

# 5. 神の像は「予測結果」より「注意方向」を与える

初期設計では、神の像が

```text
「3.2日後に食料が尽きる」
```

と教える必要はない。

むしろ、

```text
「そろそろ食料減ってきたよ」
```

程度にする。

内部的には精密計算していても、NPCへは粗いcueとして渡す。

```text
precise system estimate
↓ compression
coarse life cue
```

これによってNPC自身の予測と経験が働く余地を残す。

---

# 6. 教育ループ

最初の生活教育は、

```text
Player / 神の像 cue
→ NPC observation
→ NPC interpretation
→ Goal
→ Trajectory
→ Result
→ relation update
```

とする。

成功例:

```text
「食料少ない」
→ 採取へ行く
→ 持ち帰る
→ 飢餓回避
→ low-stock と gather の関係が強まる
```

失敗例:

```text
「食料少ない」
→ 無視
→ stock枯渇
→ FoodNeed上昇
→ 飢餓 / 行動不能接近
→ low-stock 無視の結果が経験として残る
```

---

# 7. 習慣化

反復後は、

```text
神の像 cue
+
low stock
→ gather
```

から、

```text
low stock
→ gather
```

へ移れることを目標にする。

つまり、

```text
外部補助
→ 成功/失敗経験
→ relation強化
→ repeated trajectory
→ 習慣化
→ cue省略可能
```

という沈降を許す。

---

# 8. 成人認定と補助解除

将来の発達構造として、

```text
幼体:
毎朝 神の像アクセス = 基本

成長中:
神の像 + 自己経験

成人:
毎朝の強制アクセス解除
```

とする。

成人後は、

```text
相談する
相談しない
困った時だけ行く
相変わらず毎朝行く
```

を個体自身が選べる。

成人条件の詳細は今回固定しない。

候補:

```text
Baseへ自力帰還
Food shortageへ反応
最低限の危険回避
Food loop自律完遂
```

---

# 9. 最初に完成させる行動力学

優先順位は以下。

```text
1. 神の像から粗いcueを受け取る
2. NPC自身で短期未来を予測する
3. Goalを形成する
4. Trajectoryを形成する
5. 外乱がなければその軌道へ落ち続ける
6. Base–Food循環を完遂する
```

新奇・脅威による割り込みはその後。

---

# 10. Goal と Trajectory

```text
Goal
= 目標状態

Trajectory
= 現在Goalへ向かう行動系列

Commitment
= Trajectoryを維持する強さ
```

例:

```text
Goal:
Base foodを補充

Trajectory:
Base
→ Food Site
→ gather
→ return
→ deposit
```

---

# 11. 毎tick全候補再選択を避ける

避ける:

```text
tick
→ 全候補評価
→ action select

next tick
→ また全候補評価
```

採用:

```text
Goal形成
→ Trajectory成立
→ local continuation
→ local continuation
→ local continuation
```

外乱がなければ継続する。

---

# 12. Base

最低限:

```text
base_id
position
food_stock
storage_capacity
```

---

# 13. Food Site

最低限:

```text
site_id
position
resource_type = food
resource_amount
max_resource_amount
```

採取:

```text
resource_amount ↓
```

---

# 14. World truth と NPC observation

World:

```text
actual stock
actual site amount
actual time
actual position
```

NPC:

```text
observed stock band
visible site amount
sun / light cue
distance / direction
held food
god-statue cue
```

NPCはWorld truthを直接読まない。

神の像だけは初期補助装置として、より精密なWorld情報へアクセス可能。

---

# 15. Base在庫知覚

NPC側:

```text
full
enough
low
critical
empty
```

などの粗い知覚でよい。

神の像は精密値を利用してこの指標を生成できる。

---

# 16. Goal formation の初期形

例:

```text
god cue = food low
+
NPC observed stock = low
+
known Food Site
↓
short prediction:
stock may worsen
↓
Goal = replenish_base_food
```

将来的には god cue なしでも成立可能にする。

---

# 17. Trajectory phases

```text
GO_TO_SITE
GATHER
RETURN_BASE
DEPOSIT
COMPLETE
```

通常tickでは現在Phaseの局所継続のみ。

---

# 18. Trajectory解除条件

初期:

```text
target vanished
path impossible
resource empty
movement impossible
goal already satisfied
```

これは構造破綻による解除。

新奇・脅威割り込みは後段。

---

# 19. Carry / Return / Deposit

```text
gather
→ held food increases

GATHER complete
→ RETURN_BASE

at Base
→ deposit
→ base_food_stock increases
```

---

# 20. Base consumption

```text
base_food_stock
→ periodic consumption
→ stock decreases
```

この減少が次の教育 / 自律Goal形成を起こす。

---

# 21. Food Site depletion

```text
gather
→ site amount decreases
```

同じSiteへの往復で、

```text
observed yield ↓
```

が発生する。

複数Site探索は後回し。

---

# 22. Phase構成

## Phase 1 — 神の像 morning cue

実装:

```text
morning access
precise Food state evaluation
coarse cue generation
NPC observation of cue
```

まず cue が action command ではないことを保証する。

---

## Phase 2 — Goal-to-Trajectory 安定化

```text
cue / observation
→ short prediction
→ Goal
→ Trajectory
→ no disturbance
→ completion
```

---

## Phase 3 — Base–Food完全往復

```text
stock low
→ go
→ gather
→ carry
→ return
→ deposit
```

---

## Phase 4 — 成功 / 無視 / 飢餓経験

少なくとも、

```text
cueに従う
cueを無視する
```

の両方を通す。

無視してstockが枯渇した場合、

```text
FoodNeed worsening
→ severe hunger / incapacity direction
```

まで接続できる。

---

## Phase 5 — 習慣化の最小実験

同じ条件と結果を反復し、

```text
god cue dependency ↓
low-stock cue alone ↑
```

が可能な設計にする。

この段階では高度な学習アルゴリズムを要求しない。

---

## Phase 6 — generic interrupt基盤

```text
current trajectory
vs
interrupt candidate
```

を作る。

---

## Phase 7 — Threat interruption

同じThreat観測でも個体差を出す。

---

## Phase 8 — Novelty interruption

同じ新奇刺激でも、

```text
ignore
inspect
divert
```

の差を出す。

---

# 23. 個体差

後段で極端例から調整。

```text
trajectory persistence
interrupt threshold
novelty salience
threat salience
D3-like repetition fixation
D4-like exploration
```

診断ラベルは直接実装しない。

---

# 24. M_Bとの関係

NPC側で現在の解釈・行動を拘束する有限関係、

```text
Base stock relation
known Food Site
god-statue advice relation
past hunger relation
current Goal
current Trajectory
```

などはM_B構成要素になり得る。

神の像の精密World計算そのものはNPCのM_Bではない。

NPCが受け取った有限cueと、その解釈関係がNPC側へ入る。

---

# 25. Hを欲求圧力に使わない

以下はHではない。

```text
scarcity pressure
food-seeking salience
god cue
trajectory commitment
novelty salience
threat salience
```

Hは現行定義:

```text
有限review後にも残る未解消残差
```

を維持する。

---

# 26. FoodNeed shadowを壊さない

変更しない:

```text
FoodNeed shadow frozen comparison
same-window frozen M_B
global canonical sidecar isolation
assessment / H
T1
θ
M_Δ
canonical action authority
```

---

# 27. 今回やらないこと

```text
full natural-language dialogue
sharing
spoilage
food lifetime
nutrition
weight
hunting
generation inheritance
parent-child teaching
horizontal cultural transmission
weather
season
complex long-horizon planning
MCTS
canonical T1 reconstruction
```

---

# 28. 最低テスト

### A. Morning access

```text
morning
→ NPC accesses statue
→ receives coarse Food cue
```

### B. Cue is not command

同じcueでもNPC側条件次第で、

```text
act
ignore
delay
```

が可能。

### C. Goal persistence

```text
Goal成立
→ trajectory
→ no disturbance
→ completes
```

### D. Full loop

```text
Base
→ Food Site
→ gather
→ Base
→ deposit
```

### E. Ignore consequence

```text
food low cue
→ ignore
→ stock depletion
→ FoodNeed worsening
```

### F. Repeat learning hook

反復結果を履歴へ残し、将来の習慣化に使用可能。

### G. Later autonomous trigger

神の像cueなしでも、

```text
observed low stock
→ Goal formation
```

可能な経路を持つ。

### H. Later threat / novelty

同じ観測に対して個体差が出る。

---

# 29. Codex実装順

```text
1. Add God Statue morning Food assessment
2. Expose coarse Food life cue to NPC
3. Ensure cue has no direct action authority
4. Add Goal / Trajectory / Phase state
5. Add short predictive continuity on NPC side
6. Complete Base → Food Site → Base loop
7. Add ignore / shortage / hunger consequence evidence
8. Add experience hook for repeated cue-result relation
9. Permit future cue-independent Goal formation
10. Add generic interrupt interface
11. Add threat interruption
12. Add novelty interruption
13. Add extreme profiles for tuning
```

---

# 30. Stage completion

## Stage 1

```text
God Statue cue
→ NPC observes
→ NPC predicts
→ Goal
→ Trajectory
→ no disturbance
→ Base–Food loop completion
```

## Stage 2

```text
cue
→ obey / ignore
→ result
→ experience
→ behavior changes on later recurrence
```

## Stage 3

```text
god cue absent
→ NPC can still respond to learned low-stock relation
```

## Stage 4

```text
trajectory
+
novelty / threat
→ individual response difference
```

---

# 31. 一文圧縮

> **NPCは最初から短期未来を予測して目標へ落ちていく能力を持つが、生活開始時点では何を注意すべきかの足掛かりを神の像が毎朝の粗い生活指標として与える。NPCは助言を観測して自分で解釈・予測・行動し、成功や無視による飢餓経験を通じて関係を学び、最終的には神の像の補助なしでもBase–Food循環を自律的に開始できることを目標とする。**
