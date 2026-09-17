# RDLどうぶつの森風村シミュレーター設計文書
## Historical Reference

**位置づけ:** 旧村コンセプトとsource-mine対応表の参照資料。現行設計の正本ではないため、既存リンクを保ってこの場所に残す。
**依存・責務:** [全体設計地図](RDL_GameAI_全体設計地図.md)から参照する採掘候補・設計経緯。下記の「現在」やCore v2.3表記は旧整理時点の記述を含む。
**非責務:** 現行の[Concept](RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md)、[Player Role](RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md)、[生活機能順](RDL_GameAI_実装手順予定.md)、[canonical roadmap](../../notes/experiment-roadmap.md)を上書きしない。住人型Player・贈物・仲裁の旧案は初期Player能力として採用しない。

## 1. コンセプト

`RDL_Demos`（特に現行 `rdl_village`）、`RDL_Enterprise`、`RDL_Human` の現在実装・設計規律を素材として使い、**実験可能な内部構造を保ちつつ娯楽性の高い「ゆるい村生活」**を目指す。

目標体験:

> 「この村、ちゃんと昨日を引きずってるな」「ちょっと拗ねてるな」「仲裁したら少し関係が戻った」

Core記号を感情メーターやゲーム変数へ直接翻訳しない。

```text
Core H != mood meter
Core ξ != curiosity / unknown count
static StructuralConflict != E != H
Human Attention != H
legacy Village HVec / XiPool / LeapEngine != current Core primitives
```

## 2. 既存パーツの現在のマッピング

| 役割 | 主な利用パーツ | 出典 | 現在の読み方 |
|---|---|---|---|
| NPC生活・身体 | `VillageNPC`, body/schedule systems | current `rdl_village` | 生活AI素材。legacy loadをCore Hと呼ばない |
| 関係履歴 | `RelationState`, `RelationMemorySystem`, `ActionMemory` | `rdl_village` | 多軸・方向付き関係の実装素材 |
| 対話 | structured dialogue system | `rdl_village` | LLM非依存の構造化会話素材 |
| 知覚・予測場 | `PerceptionSystem`, `PredictionField`, `PlaceMeaning` | `rdl_village` | world truthとagent側モデルを分離する素材 |
| 世界・資源 | clock / place / resource systems | `rdl_village` | living-world substrate |
| シミュレーション | simultaneous resolution / seeded run / logs | `rdl_village` | 公平なtick解決・再現可能実験素材 |
| Canonical finite path | `v23_*` modules | current `rdl_village` | `B/RIB_B/F-F'/E/review/H/M_Δ/T1/authority/re-entry` の参照実装 |
| Structural conflict | conflict inbox | Enterprise | GameAI-localな未処理課題候補。E/Hとは分離 |
| Staged trial | canary / shadow / promotion | Enterprise | 必要時のInspection / deployment tool |
| Provenance / durability | RIBSection / frozen context / persistence patterns | Enterprise v2.3 | later GameAI canonical runtimeの設計参考 |
| Human sensitivity hypotheses | SFO-related, secure-base, context/time-scale models | Human v2.3 | T3仮説。Core primitiveへ昇格させない |
| 豊かさ観測 | `richness.measure` 等 | `rdl_village` | 単一survival scalarを避ける評価素材 |

旧 `Enterprise HState` を「軽い不機嫌・すね・興奮」そのものとして転用する設計は採用しない。

## 3. Core v2.3との接続

```text
world / relation interaction
↓
bounded observation packet
↓ acquisition under Purpose / finite B
RIB_B
↓ explicit frozen M_B
F / F'
↓
E
↓ finite assessment
unresolved only
↓
H
```

現在のGameAI Lab runtimeは **E / explicit finite review / H / retained H** と、最小のlocal History・Sensitivity・Body・Expressionまで。村ゲームの心理的感情や長期学習が実装されたという意味ではない。θ / M_Δ / T1は未実装。

## 4. 村生活の主要システム

### 4.1 飢餓・身体状態

死なない村を前提に、飢餓・疲労・快適さ等は **GameAI-local body state** として扱う。

```text
hunger
energy
comfort
activity_need
```

これらをCore Hへ直接加算しない。高飢餓は食料行動の優先度、移動速度、dialogue tone、attention / action bias等へ影響できる。

### 4.2 構造衝突

```text
食べたい vs 誰かへ渡したい
休みたい vs 誘いに応じたい
買いたい vs 貯めたい
```

`StructuralConflict` 的なrecordはGameAI-local inboxとして使える。

```text
StructuralConflict != E != H
```

即解決せず、後続interaction・選択・履歴へ接続する。

### 4.3 軽い嫉妬・不和

単一「嫉妬値」を人格中核へ置かず、関係履歴・attention imbalance・current contextから表層反応を形成する。

候補relation axes:

```text
trust
closeness
recent_hurt
attention_imbalance
repair_support
```

一時的不和と長期親密度を同一軸へ潰さない。

### 4.4 仲直り / recoverability

```text
natural decay
shared activity
player mediation
gift / care
trusted companion effect
safe place effect
```

Human由来のsecure-base仮説は、この回復可能性を考えるT3素材として使える。

### 4.5 感情表現

```text
interaction history
+ relation history
+ sensitivity profile
+ body state
+ current context
+ unresolved provenance when present
↓
AffectExpression / ActionBias / DialogueTone
```

禁止:

```text
fear -> H += x
jealousy -> H += x
hunger -> H += x
```

## 5. 個体差

候補:

```text
novelty_sensitivity
threat_sensitivity
attachment_sensitivity
stability_preference
recoverability_sensitivity
social_rejection_sensitivity
```

同じ出来事でも履歴と感度で反応が分かれることを狙う。

## 6. プレイヤーの役割

プレイヤーは強制的な管理者ではなく、**観察者・特別な住人・時々の相談相手**。

主な関わり:

- 食べ物や贈り物
- 会話
- 仲裁
- 一緒に過ごす
- 相談への応答

EnterpriseのHuman Attention workflowをそのままNPC心理へ移植せず、必要ならGameAI-local consultation mechanicとして再設計する。

## 7. 日常の流れ

```text
朝
→ routine / place selection

昼
→ work / hobby / social interaction
→ body needs may bias action

途中
→ conflict / invitation / gift / failure
→ relation history updates

夕方
→ familiar-place / trusted-relation effects

夜
→ reduced activity
→ history remains available for later interpretation
```

「夜に一括で人格更新」のような固定処理をCore要件にしない。

## 8. Richness / interestingness

単一スカラーへ圧縮しない。

```text
behavior variety
individual divergence
history dependence
relation dependence
place meaning drift
daily variation
repair / reconciliation patterns
readability
surprise
recoverability
rupture diversity
```

```text
survival rate != whole success
randomness != interestingness
maximum conflict != richness
```

## 9. 現在からの実装順

```text
current canonical: RIB_B / frozen M_B / F-F' / E / review / H / retained H
current local: finite history / fixed sensitivity / body / derived expression
next: cross-layer separation acceptance
then: explicit θ / M_Δ / T1 reconstruction contract
then: finite-context authority
then: long-run richness
```

村の全感情システムを先に実装しない。

## 10. 後で採掘するEnterprise機構

具体的な破断が出た場合のみ導入候補:

```text
Canary
Shadow
Promotion
Durability
Replay persistence
Structure induction
```

これらはCore primitiveではなくInspection / deployment / durability tool。

## 11. 避けること

意味上:

- `HState/HVec`を気分メーターとしてCore Hへ同一視
- `XiPool`をCore ξとして利用
- static conflictをE/H化
- observation packetを無条件にRIB_B化
- nonzero Eを自動unresolved化
- Human AttentionをNPC心理熱へ同一視

体験上:

- プレイヤーへ強い管理義務を負わせる
- 一度の出来事で関係全体を永久破壊
- 常時喧嘩・嫉妬を最大化
- 最適生存行動だけへ収束

## 12. 一文圧縮

> **現行の村シミュレーター設計は、Demosのliving-world素材とv2.3 finite-context runtime、Enterpriseのprovenance/durability規律、HumanのT3仮説を分離して組み合わせ、履歴が読めるが固定されない日常AIを作る。**
