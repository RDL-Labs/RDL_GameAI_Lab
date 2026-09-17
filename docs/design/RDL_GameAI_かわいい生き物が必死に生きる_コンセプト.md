# RDL_GameAI — かわいい生き物が必死に生きる

**文書種別:** Game Concept / DRAFT  
**版:** v0.1  
**位置づけ:** RDL_GameAI_Lab / GameAI-local design

**責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)から読む体験・世界観の核。
**依存・非責務:** 実装順は[生活機能ロードマップ](RDL_GameAI_実装手順予定.md)、内部構造は[Layer計画](RDL_GameAI_NPC_レイヤー別設計計画.md)、介入能力は[Player Role](RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md)が正本。以下の具体例は体験要件であり、schemaや実装済み機能の一覧ではない。

## 0. 一文コンセプト

> **かわいい生き物たちが、食料・休息・身体・安全・経験・仲間との関係に拘束されながら、危険生物も存在する小さな世界で、失敗し、助け合い、休み、回復しながら必死に暮らしている生活シミュレーション。**

ゲームの中心は最適行動でも強いNPCでもない。

> **「この子たちは、この世界で本当に暮らしている」**

と感じられることを目標とする。

---

## 1. 世界の基本温度

世界は基本的には穏やかで、かわいらしい。

```text
食べる
寝る
遊ぶ
仕事をする
物を拾う
誰かと過ごす
拠点へ帰る
```

一方で、

```text
食料不足
疲労
危険な場所
危険生物
負傷
行動不能
仲間の不在
```

が日常へ入り込む。

常時殺伐とさせず、普通の日常があるから危険や救助に意味が生まれる構造を重視する。

---

## 2. 生存の最低条件

```text
Food
Rest
Safety
```

を中心とする。

これらを独立ゲージとして閉じず、相互拘束を持たせる。

```text
空腹
→ 食料探索圧力上昇

EnergyReserve低下
→ 探索能力低下

負傷
→ movement capability低下
→ 同じ移動でも消耗増
→ safe placeの価値上昇
```

---

## 3. Energy

最低限、

```text
EnergyReserve
ActiveEnergy
```

を分ける。

### EnergyReserve

長期的な活動余力。食事・十分な睡眠・長時間休養で回復する。

### ActiveEnergy

現在すぐ使える短期余力。

```text
走る
逃げる
追跡する
重い物を運ぶ
救助する
```

等で急速に低下し、短時間休息で比較的速く戻る。

---

## 4. Safety / Danger

食料のある場所と安全な休息場所は一致しなくてよい。

```text
safe base
→ forage / explore
→ risky area
→ obtain food / materials
→ return home
```

危険生物は悪役ではなく、生態の一部として扱う。

---

## 5. Deathless main residents

主要なかわいい住民NPCには原則として死亡を置かない。

```text
hunger / fatigue / injury / danger
→ incapacitated
```

行動不能になった個体は他個体の救助を待つ。

```text
A incapacitated
→ B discovers A
→ rescue
→ return home
→ both retain experience
```

全員行動不能時だけfailsafeを使い、system warp自体は成功経験として記憶させない。

---

## 6. Injury / Recovery

負傷はHP減少だけでなく生活能力を拘束する。

```text
light injury
medium injury
severe injury
```

重傷では、

```text
bedridden
→ short walking
→ light work
→ normal activity
```

のように段階回復する。

療養中も世界から消えず、食事・睡眠・訪問・仕事代替等を通じて共同体との関係を維持する。

---

## 7. Missing / Search

将来目標として、

```text
usual bedtime
→ A is absent
→ routine deviation noticed
→ last-known history consulted
→ search
→ discover injured A
→ rescue
```

を置く。

全員へ「Aが倒れた」と通知せず、日常の破れから不在を発見する。

---

## 8. Hunting

狩りは戦闘ミニゲームではなく生活の延長とする。

```text
hunger
→ prey
→ chase
→ ActiveEnergy drain
→ prey escapes / retaliates
→ success
→ meat / hide
→ return / eat / rest
```

住民NPCとは別に狩猟対象を置き、肉や皮を得られるようにしてよい。

---

## 9. Objects / Materials

物はフィールド上に存在し、

```text
拾う
持つ
運ぶ
置く
落とす
渡す
他個体が拾う
```

ことができる。

初期素材候補:

```text
皮
木材
ツタ
```

物体には `item_id / type / location / holder / state / history / provenance` 等を持たせる余地を残す。

---

## 10. Tools / Crafting

道具は最初から一部世界に存在してよい。

```text
bag
rope
lantern
blanket
tent
stretcher
bandage
```

クラフト導入後は、

```text
木材 + ツタ → 担架
皮 + ツタ → 袋
木材 + 皮 + ツタ → 簡易寝床
```

などから始める。

発明そのものは初期必須にしない。

---

## 11. Barter

固定価格表を置かない。

```text
A indicates wanted item
B indicates wanted return
both accept
→ exchange
```

価値は、

```text
Object
× current context
× current need
× history
× relation
```

で変わる。

---

## 12. Glowing Stone / Emergent Value

フィールドに光る石を置く。

```text
少し珍しい
目立つ
きれい
何故か少し惹かれる
明確な必須実用品ではない
```

初めから貨幣にはしない。

```text
自分が欲しい
→ 他人も欲しい
→ barter
→ 他人の需要を学ぶ
→ 自分に不要でも保持
→ exchange-medium candidate
```

装飾・贈答・収集・執着に進んでもよい。

---

## 13. Communication / Vocabulary

NPC同士は有限な意味を伝えられる。

```text
GREET / CALL / POINT
REQUEST / OFFER
WARN / HELP / ACK
```

語彙を知らなくても対象の関係を認識できる。

```text
concept / relation
!= lexical label
```

語彙はNPC間で局所伝播し、全員へ自動同期しない。

---

## 14. Player

暫定的にPlayerは拠点のしゃべる神の像とする。

主な初期機能は語彙介入。

```text
NPC asks name
→ Player gives word
→ NPC acquires relation candidate
→ word may propagate
```

Player発言はTruthではない。

---

## 15. Sleep / Experience Consolidation

睡眠は身体回復だけでなく経験整理の契機とする。

SleepはLayerではなく横断回復・consolidationイベント。sleep != T1。詳細の所有・provenance・canonical接続境界は[睡眠設計](RDL_GameAI_睡眠システム設計.md)へ委ねる。

```text
Experience History
→ selection
→ compression
→ association
→ next-day relation structure
```

忘却・一般化・誤一般化・妙な連想を許容する。

その結果として個体固有の癖や不可解な行動が生まれてよい。

---

## 16. Neural Dynamics / Individuality

個性を固定Personalityラベルとして直接作らない。

```text
DNA neural baseline μ/σ
× current neural state
× Body
× Experience
× relation structure
× Sleep
× Current Context
→ behavior tendency
```

DA / 5-HT / OXT / NA とその下位サブタイプを、行動・注意・関係保持等への操作的近似として使う。

---

## 17. Semantic fallibility

このGameAIは間違ってよい。

```text
semantic fallibility allowed
structural integrity required
```

誤認・誤命名・誤一般化・噂・偏った関係・睡眠時の変な接続は世界現象として許容する。

一方、ID破損・provenance消失・参照不能・意図しないcanonical mutationはバグとして扱う。

---

## 18. RDL上の基本姿勢

食料・疲労・負傷・安全・道具・経験・関係等を完全独立したサブシステムへ閉じない。

ただしGameAI-localな状態を名前だけでCore `M_B` と同一視もしない。

有限な履歴・現在状態・神経力学・観測を通じて行動差が生まれ、canonical形成へ接続する場合は別途T1の有限な検査・選別・再構成を通す。

---

## 一文圧縮

> **かわいい生き物が今日を生きるための身体・危険・経験・関係を先に成立させ、そこへ会話・語彙・睡眠・神経力学・交換を横断的に重ねる。失敗や誤解も世界の一部として残し、履歴から個体差が育つ生活シミュレーションを目指す。**
