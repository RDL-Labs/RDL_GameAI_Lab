# RDL_GameAI — 暫定プレイヤー役割「しゃべる神の像」

**文書種別:** Player Role / DRAFT  
**版:** v0.1  
**位置づけ:** RDL_GameAI_Lab / GameAI-local design

**責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)におけるPlayerの存在形式・許可する介入・禁止権限。
**依存:** [Communication](RDL_GameAI_簡易会話からプレイヤー介入まで.md)の発話・履歴、[Concept](RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md)の体験。
**非責務・状態:** 会話schema・語彙伝播の詳細はCommunicationへ委ねる。暫定design-onlyであり、Workbenchの実験者UIをゲーム内Player能力とは扱わない。

## 0. 一文定義

> **プレイヤーは拠点内に置かれた「しゃべる神の像」のような存在として、生き物たちから話しかけられ、質問に答え、未知の物や場所へ名前を与える。**

ただし、プレイヤーの発言は世界の絶対的真理として自動確定しない。

---

## 1. 存在形式

初期段階では、プレイヤーは拠点内部の固定物として扱う。

```text
拠点
└─ しゃべる像
   └─ Player Interface
```

プレイヤー自身がフィールドを歩き回ることは初期前提にしない。

---

## 2. 初期機能

```text
質問に答える
名前を教える
新しい名前を付ける
知っていることを伝える
意見を言う
曖昧に答える
知らないと答える
```

初期PlayerにNPC直接操作・状態書換・強制移動・全知的世界アクセスを与えない。外部語彙・情報源に限定する。

```text
Player → Communication → lexical / informational input
Player statement != World Truth
```

---

## 3. 命名

```text
NPC「これは何ですか？」
Player「石像だよ」
```

するとNPC側に、

```text
object_x
↔ called_by_player
↔ 「石像」
```

のような関係候補が形成され得る。

---

## 4. 命名は絶対定義ではない

```text
Playerが「石像」と言った
!= world ontologyがstone_statueへ書き換わる
```

NPC側では、

```text
「Playerがこれを石像と呼んだ」
```

という有限な履歴として保持する。

よって、

```text
間違った名前
冗談の名前
個体ごとの違う名前
後からの訂正
類似物への誤一般化
```

を許容する。

---

## 5. 語彙伝播

```text
Player
→ Aが「石像」を得る
→ AがBへ使う
→ Bも観測
→ 局所共有語彙になる可能性
```

全員へ自動同期しない。

誰が誰から聞いたかを可能な範囲でprovenanceとして残す。

---

## 6. 命名対象

将来的には、

```text
物
場所
危険生物
食料
道具
現象
個体
集団
出来事
```

へ名称を与えられる余地を持つ。

---

## 7. Playerは神託ではない

世界観上「神の像」に見えても、

```text
Player = Truth
```

とはしない。

Base–Food初期教育で神の像が出す朝の生活cueは、Playerの自由発言とは別の有限なsystem-generated assessment channelとする。system側は精密World値を評価できるが、NPCへ渡すのは粗いFood指標だけであり、action command・canonical Truth・直接操作権限にはしない。

NPCはPlayer発言またはこの有限cueを、

```text
信じる
半信半疑で受け取る
忘れる
他個体へ伝える
自分で確認する
誤解する
無視する
```

ことができる。

---

## 8. Playerへの関係

Playerとの会話もExperience Historyになる。

```text
Playerが有用な情報を繰り返す
→ Playerへの採用傾向が変わる可能性

Player発言と経験が繰り返し食い違う
→ Playerの発言を採用しにくくなる可能性
```

```text
trust != truth
```

とする。

---

## 9. M_Bとの接続

以下はlocalな名称・意味候補の形成。canonical M_Bへの採用は別の有限契約による検査・選別・再構成が必要であり、Player発言による直接書換ではない。

```text
unknown target
+ current finite self structure
+ Player relation history
+ Player utterance
→ new name / meaning candidate
```

同じPlayer発言でも個体によって受け取り方が違ってよい。

---

## 10. 初期制約

プレイヤーに、

```text
NPC direct control
NPC state overwrite
forced teleport command
unconditional action command
complete internal-state view
truth-authority
```

を与えない。

プレイヤーは主として、

> **話しかけられ、答える存在**

である。

---

## 11. 世界観

現段階では、

> **拠点には昔から不思議なしゃべる像があり、生き物たちは時々そこへ行って話しかける。**

程度でよい。

像が本当に神なのか、装置なのか、なぜ話すのかは固定しない。

---

## 12. 採用理由

```text
NPCの自律生活を壊しにくい
+
Playerが世界へ参加できる
+
会話・語彙形成を観察できる
+
命名という軽い介入ができる
+
Playerへの信頼や誤解も関係として扱える
```

---

## 一文圧縮

Player statementはまずobservation/historyであり、World Truthでも `M_B` でもない。NPCが有限な検査・保持を経て現在採用した関係だけが `M_B` participantになり得る。Playerに直接のmodel書換権限を与えない。

> **プレイヤーは拠点内の不思議なしゃべる像として、生き物たちの質問に答え、未知の物や場所へ名前を与えられる。ただし、その言葉は世界の絶対真理ではなく、生き物が経験・関係・現在状態に応じて受け取る一つの会話入力である。**
