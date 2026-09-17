# RDL_GameAI — 簡易会話からプレイヤー介入まで

**文書種別:** Communication / Player Intervention Design  
**版:** v0.1  
**位置づけ:** RDL_GameAI_Lab / GameAI-local design

**責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)のD軸。intent・Expression・referent・DialogueTurn・lexicon・NPC語彙伝播。
**依存:** [Player Role](RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md)、[履歴モデル](RDL_GameAI_感情・履歴・関係拘束モデル.md)、[睡眠設計](RDL_GameAI_睡眠システム設計.md)。
**非責務・状態:** Playerの能力付与やcanonical形成の正本ではない。Communicationはdesign-onlyで、現行のdisplay-only Response Expressionは通信基盤ではない。

## 0. 目的

```text
NPC同士の簡易コミュニケーション
→ 指示対象・意味の共有
→ 簡単な会話
→ 語彙の伝播
→ プレイヤーによる新語・名称の介入
```

までを一つの実装線として整理する。

初期目標は自由会話AIではない。

> **個体が何かを伝えようとし、別個体がそれを観測し、自身の有限な関係構造のもとで解釈し、反応できること。**

---

## 1. 基本原則

```text
Aが伝えた意味
!= Bへ直接コピーされる内部状態

speaker meaning != listener internal state
utterance != truth
```

基本形:

```text
A current state
→ CommunicativeIntent
→ Expression
→ B observes
→ B interprets under own finite relation structure
→ response
```

聞き間違い・意味不明・referent取り違え・無視・不信・後の意味変化を許容する。

意味上の取り違えは候補・解釈状態として表現し、record ID・source・参照整合性は保持する。誤解を理由にprovenanceを失わない。

---

## 2. 初期Intent

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

これだけでも、

```text
救助
物の受け渡し
狩りの協力
危険警告
物々交換の基礎
語彙伝播
```

へ接続できる。

---

## 3. CommunicativeIntent

```text
CommunicativeIntent
- speaker
- listener
- intent_type
- referent
- purpose
- context
```

発話文より先に意味構造を持つ。

表現は後段で変換する。

```text
WARN(predator_03)
→ 「あぶない！」
→ 「にげて！」
→ 「そっちだめ！」
```

---

## 4. Referent

初期会話では自然言語生成より、どの対象を指しているかを優先する。

```text
speaker
listener
intent
referent
context
turn_id
```

referentが曖昧なら勝手に確定しない。

```text
UNKNOWN
UNRESOLVED
NOT_EVALUATED
```

を区別する。

---

## 5. DialogueTurn

```text
DialogueTurn
- turn_id
- conversation_id
- speaker
- listener
- intent
- utterance
- referent
- context
- provenance
```

必要に応じて、

```text
response_to_turn_id
confidence
interpretation_status
```

を加える。

---

## 6. 会話履歴

```text
Communication → DialogueTurn → Experience History
→ local relation formation candidates → Sleep consolidation
```

raw turn、圧縮relation、睡眠候補、canonical M_Bを分離する。canonical形成へ自動変換しない。

会話内容を永続Truthにはしない。

ただし、

```text
誰が
誰に
何を言ったか
```

はExperienceとして追跡できるようにする。

```text
AがBに危険を教えた
AがBへ物を渡した
AがBから名前を聞いた
```

などは後の関係形成や睡眠整理へ利用できる。

---

## 7. 初期語彙

最低限の共有語彙候補:

```text
これ
あれ
ここ
あっち
いる
いない
ほしい
あげる
こわい
あぶない
たすけて
たべる
ねる
いく
くる
はい
いや
```

世界内の完全な言語ではない。

---

## 8. 語彙と概念の分離

```text
語を知らない
!= 対象を認識できない
```

対象について、

```text
硬い
長い
持てる
燃える
```

等の関係を持っていても、「木材」というラベルを知らない場合がある。

```text
既存の関係構造
+
後から語彙ラベル
```

を許容する。

---

## 9. 語彙獲得と伝播

```text
Aが未知対象を見る
→ Bが「木材」と呼ぶ
→ Aが対象と語を同時観測
→ 語との関係候補が形成
```

一度聞いただけで完全定着させる必要はない。

語彙は全個体へ自動同期しない。

```text
A knows word
→ A uses word to B
→ B observes
→ B may acquire
→ local / group vocabulary
```

---

## 10. Player Intervention

プレイヤーは世界を直接操作する存在ではなく、初期には外部から語彙を供給できる存在として接続する。

```text
Player → Communication → lexical / informational input
Player statement != World Truth
```

暫定Player Interface:

```text
しゃべる神の像
```

NPCが未知対象へ遭遇した場合、

```text
A sees unknown object
→ does not know name
→ returns home
→ asks Player
→ Player says 「石像」
```

といった流れを作る。

---

## 11. PlayerはTruth Sourceではない

```text
Player「これは石像」
!= World Truth = 石像
```

NPC側では、

```text
Playerがこの対象を「石像」と呼んだ
```

という有限な観測・履歴として扱う。

よって、

```text
誤った名前
冗談
訂正
複数名称
NPC間の呼称不一致
過剰一般化
```

を許容できる。

---

## 12. Playerへの信頼

後段では、

```text
Player発言
+ 過去の一致 / 不一致
+ 個体自身の経験
```

から採用しやすさが変化してよい。

```text
Player trust
!= Truth判定
```

あくまで関係履歴の一つとする。

---

## 13. 睡眠との接続

会話・語彙も睡眠整理対象になり得る。

```text
DialogueTurn / naming experience
→ Experience History
→ sleep selection / compression
→ word / source / referent relation candidate
```

誤伝達や誤接続も許容する。

---

## 14. 実装順

以下はCommunication内の局所Step。生活機能のPhase、canonical roadmapのMaturityとは番号を共有しない。実装済み段階を示すものではない。

```text
Communication Step 1  GREET / ACK
Communication Step 2  CALL / POINT
Communication Step 3  WARN / HELP
Communication Step 4  REQUEST / OFFER
Communication Step 5  DialogueTurn / history
Communication Step 6  initial shared vocabulary
Communication Step 7  NPC vocabulary transmission
Communication Step 8  Player statue conversation
Communication Step 9  Player naming
Communication Step 10 naming-word NPC transmission
Communication Step 11 correction / disagreement
Communication Step 12 Player trust difference
```

---

## 15. 最小縦断実験

```text
Aが光る石を発見
→ AがBを呼ぶ
→ Aが石を指す
→ Bが同じ石を見る
```

次に、

```text
Aが名称不明の像を見る
→ 拠点へ戻る
→ Playerへ質問
→ Player「石像」
→ Aが語との関係候補を得る
→ 後日Bへ「石像」と使う
```

まで通す。

---

## 一文圧縮

> **まずNPC同士が有限な意味を伝達できる通信基盤を作り、その上へ語彙獲得と伝播を載せる。プレイヤーは拠点のしゃべる神の像として未知の物や場所へ名前を与えられるが、その言葉はTruthではなくNPCが観測した一つの情報として扱う。**
