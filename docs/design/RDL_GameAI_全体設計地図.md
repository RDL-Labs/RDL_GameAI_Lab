# RDL_GameAI 全体設計地図

*MASTER DESIGN MAP: canonical成熟度・NPC内部Layer・ゲーム機能・横断システムを分離して接続する。*

## 0. 文書の役割

この文書は設計体系の入口。4軸の配置、文書責務、接続関係を管理する。神経パラメーター、生活Phase、会話intent、canonical契約の詳細は各正本へ委ねる。

意味論は[Core reference](../semantic-reference/RDL_Core_T0_T1_reference.md)、実装状態は[canonical roadmap](../../notes/experiment-roadmap.md)、動作上の約束は[Runtime contract](../experiment-contracts/CURRENT_v23_runtime_contract.md)に依存する。

```text
A. Canonical RDL maturity
B. NPC internal layers
C. Game feature implementation
D. Cross-cutting systems

canonical maturity != game feature phase
Layer Profile != Core ontology != canonical M_B decomposition
```

ConceptとPlayer Roleは、この4軸を使って何を体験させ、どこから介入するかを定める別の責務である。

## 1. 正本文書への入口

| 位置づけ | 正本 | 責務 / 非責務 |
|---|---|---|
| 全体 | 本文書 | 配置とリンク。詳細仕様・Phase・契約は所有しない |
| 体験 | [Concept](RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md) | 世界観・生活体験。内部schemaを正本化しない |
| A | [Canonical Experiment Roadmap](../../notes/experiment-roadmap.md) | 実装成熟度・remaining boundary。生活機能順と別 |
| A | [Runtime Contract](../experiment-contracts/CURRENT_v23_runtime_contract.md) / [Evidence](../experiment-evidence/CURRENT_v23_runtime_evidence.md) | 有限な動作契約 / 確認証拠 |
| B | [Layering Profile](RDL_GameAI_NPC_レイヤリング_Profile.md) | Layer名・目的・時間スケール。Core primitiveではない |
| B | [Layer別設計計画](RDL_GameAI_NPC_レイヤー別設計計画.md) | 所有・更新・保持・snapshot・reviewed influence・比較受入 |
| B / D | [神経パラメーター設計図](RDL_GameAI_神経パラメーター設計図.md) | 操作的神経ラベル・DNA基準・動的状態・派生感度 |
| B / D | [感情・履歴・関係拘束](RDL_GameAI_感情・履歴・関係拘束モデル.md) | 履歴種別・派生表現。Hを感情にしない |
| C | [Game Feature Roadmap](RDL_GameAI_実装手順予定.md) | 生活機能の縦実装順と横断系の接続点 |
| C | [Base–Food循環完成計画](RDL_GameAI_Codex_BaseFood循環完成計画.md) | 完了した最初のBase–Resource参照実装 |
| D | [睡眠システム](RDL_GameAI_睡眠システム設計.md) | 回復・選別・圧縮・関連付け。睡眠自体はLayerでもT1でもない |
| D | [Communication](RDL_GameAI_簡易会話からプレイヤー介入まで.md) | intent・referent・DialogueTurn・lexicon・局所伝播 |
| 介入 / D | [Player Role](RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md) | 外部語彙・情報源と有限な自動生活cue。直接操作・Truth権限は与えない |
| 設計規律 | [設計手法](RDL_GameAI_設計手法.md) | 有限Boundary・provenance・検証方法・意味論の参照順 |
| 参照 | [旧村設計](RDLどうぶつの森風村シミュレーター設計文書.md) | historical source-mine reference。現行Concept・Playerを上書きしない |
| 整理記録 | [Document Status](DOCUMENT_STATUS.md) | 今回の分類・重複整理・保留理由 |

## 2. A: Canonical maturity

```text
implemented:
bounded observation → Purpose / finite B → RIB_B
→ same frozen pre-update M_B → F / F' → E
→ explicit finite review → unresolved H / retained H

unimplemented:
θ / M_Δ → Probe → Expansion → Inspection
→ Selection → Reconstruction → M_B'
→ finite-context authority / fresh re-entry
```

GameAI-local stateを増やしただけではcanonical authorityは増えない。Hは感情ではなく、reviewされた未解決残差。local action policyはcanonical diagnostic M_Bとは別経路である。詳細の成熟度は上表のroadmapを参照する。

## 3. B: NPC internal layers

```text
Generation / DNA
Neural Dynamics
Physical / Body
Experience / Relation History
Realtime / Current Context
```

これは存在論や一方向の固定階層ではなく、更新速度・保持・拘束伝播を比較するView。Neural Dynamicsは遅い基準と速い瞬間変動を持ち、Bodyも急変しうる。

```text
Generation / DNA
Neural Dynamics
Physical / Body
Experience / Relation History
Realtime self-side constraints
        ↓
finite adopted current relations
        ↓
       M_B
```

Layerは `M_B` の5つの排他的fieldではない。各module/store/world sourceは `M_B` と同一ではないが、そこから現在採用された有限な個体側拘束は `M_B` を構成し得る。raw current observationは基本的に `RIB_B` 側であり、現在priority・action commitment・短期保持関係など個体側拘束として成立したものだけを別のadmission境界で扱う。

設計上の関係:

```text
DNA → neural baseline distributions (μ / σ)
→ dynamic state (body + context + history + fluctuation)
→ derived sensitivity
→ attention / action / memory / consolidation bias
```

神経名称は操作的近似であり実在生物学の再現主張ではない。現行runtimeの固定retry profileはこの神経経路から導出されていない。

## 4. C: Game feature implementation

第一生活ラインはFood → Rest / Sleep → EnergyReserve / ActiveEnergy → Safety / Danger → Incapacitation / Injury → Rescue / Recovery → Hunting。Food・Rest・Energy・Safetyの有限slice、Food-Safety、Food-Rest、Continuous Life v0はoperationalである。Phase 5Aのincapacitation、5Bのbounded discovery、5CのRescue Goal / fixed-target approachまでoperationalである。次の境界はsafe-place deliveryとする。

第二生活ラインはMaterials → Tools → Crafting → Barter → Emergent Value。

具体的Phaseと受入はGame Feature Roadmap、完了したPhase 1詳細はBase–Food循環完成計画とEvidenceに置く。mock foodへのapproachが動くことと、Food生活循環が完成していることは別である。canonical成熟度の番号から生活機能の完成度を推定しない。

## 5. D: Cross-cutting systems

| 系 | 横断する対象 | 正本 / 接続 |
|---|---|---|
| World Time | 食事・休息・日中活動・夜間帰還・不在検出 | Game Feature Roadmap。runtime tickを日周期完成と同一視しない |
| Experience History / Relation Constraints | 行動結果・会話・対象との矛盾した関係 | 感情・履歴モデル / Layer計画 |
| Neural Dynamics | 注意・行動・保持・睡眠整理への偏り | 神経設計。B軸は状態owner、D軸は接続経路 |
| Sleep Consolidation | Body RecoveryとExperienceの選別・圧縮・関連付け | 睡眠設計 |
| Communication / Vocabulary | referent・発話・局所語彙伝播 | Communication |
| Player Intervention | 観測される語彙・情報入力 | Player Role → Communication |

横断系を生活Phaseやcanonical段階の一本線へ押し込まない。個別の有限実験で接続する。

## 6. 接続境界

### 履歴・睡眠

```text
raw Experience History
!= compressed relation constraints
!= sleep-consolidated relation candidates
!= canonical M_B

Sleep != Layer
Sleep != T1
Sleep → GameAI-side recovery / consolidation window
→ local relation candidates
→ separately reviewed formation path, only when contracted
```

raw履歴、派生候補、採用済み状態に別の所有・保持・provenanceを定める。忘却・一般化・誤接続は許容しても、履歴の黙示改変・参照破損・canonical authority混同は許さない。

### 会話・Player

```text
Player → Communication → lexical / informational input
Communication → DialogueTurn → Experience History
→ relation candidates → sleep consolidation

speaker meaning != listener internal state
utterance != truth
Player statement != World Truth
```

Playerは暫定的に拠点のしゃべる像。NPC直接操作・状態書換・強制移動・全知的世界アクセスを持たない。Workbenchの実験者向け観測・介入UIはPlayer能力とは別。

### 関係・個体差

関係対象はPerson / Object / Place / Space / Concept / Community。OXTは関係salience・保持等を偏らせる設計候補で、好感度やBそのものではない。正負・矛盾した関係を一つのfriendship scoreへ潰さない。

## 7. 現在地と次の判断

実装済みの有限sliceは、reviewed / retained H、approach結果履歴、opt-in retry influence、固定感度、movement_scale、Realtime観測、display-only Response Expression、minimal Food loop、default-off FoodNeed shadow admission。

Base–Food reference loop、Rest / Sleep、Energy、Safety、Food-Safety、Food-Rest、Continuous Life Evidenceはoperationalである。FoodNeed canonical promotionはshadow維持と判断した。Phase 5Aではsevere injury / incapacitationをGodot BodyStateへ有限記録し、Phase 5Bでは観測範囲内の別NPCだけがそのconditionを知る。Phase 5CではRescue targetを一度固定し、実World上で対象へ接近して `READY_TO_RESCUE` で停止する。次の実装優先はsafe-place deliveryであり、回復・成功扱い・旧Safety trajectory再開は導入しない。

## 8. 共通の不変条件

```text
semantic fallibility allowed
structural integrity required

SensitivityProfile / BodyState / RelationHistory != M_B by identity
finite adopted relations sourced from them may constitute M_B
semantic eligibility != current operational admission
OXT != B
AffectExpression != H
Novelty != ξ
```

誤認・誤一般化・誤命名・噂・妙な連想は観察対象。ID破損・provenance消失・参照不能・意図しないcanonical mutationはバグとして扱う。有限な受入を満たしても、全NPC挙動を説明し尽くしたとは主張しない。
