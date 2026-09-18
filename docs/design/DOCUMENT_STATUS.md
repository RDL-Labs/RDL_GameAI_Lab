# Design Document Status

確認日: 2026-09-17。基準: upstream `19ce133` と前回の未commit文書同期・層間分離検証。
これは棚卸し記録であり、実装成熟度の正本は[canonical roadmap](../../notes/experiment-roadmap.md)。

| 文書 | 整理前の分類 | 今回の扱い / 責務 |
|---|---|---|
| [全体設計地図](RDL_GameAI_全体設計地図.md) | partially stale / duplicate details | 4軸と正本リンク。詳細は各責務文書へ委譲 |
| [Profile](RDL_GameAI_NPC_レイヤリング_Profile.md) | partially stale | 名称・目的・時間スケールをNeural Dynamicsへ同期 |
| [Layer計画](RDL_GameAI_NPC_レイヤー別設計計画.md) | partially stale / duplicate details | 所有・更新・保持・比較。上流v0.3とローカル成熟度修正を統合 |
| [感情・履歴](RDL_GameAI_感情・履歴・関係拘束モデル.md) | partially stale | 派生感度・表現・履歴種別の分離 |
| [神経](RDL_GameAI_神経パラメーター設計図.md) | current design / status unclear | 操作的ラベル・DNA μ/σ・動的状態・派生感度。design-only |
| [睡眠](RDL_GameAI_睡眠システム設計.md) | current design / status unclear | Layerでない横断更新イベント。design-only |
| [Concept](RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md) | current design | 体験の核。schema・Phaseの正本ではない |
| [生活機能順](RDL_GameAI_実装手順予定.md) | current plan / navigation incomplete | 生活Phaseと横断系、canonical成熟度の分離 |
| [Base–Food循環完成計画](RDL_GameAI_Codex_BaseFood循環完成計画.md) | completed reference plan v0.3 | 神の像の粗いcueからNPC自身の予測・Goal・Trajectory・経験・自律化へ進むBase–Food参照loop |
| [Base–Food assisted contract](../experiment-contracts/BASE_FOOD_assisted_loop_contract.md) | reference baseline complete | Phase 1-8、interrupt三系統、Novelty復帰、両端preset比較まで。Evidence固定済み |
| [Base–Food completion evidence](../experiment-evidence/BASE_FOOD_reference_loop_evidence.md) | current evidence | 実Godot/HTTP 111 tests、Stage 1-4、FoodNeed shadow維持判断、Rest開始境界 |
| [ρ活用指南](RDL_GameAI_ρ活用指南.md) | current guidance / Food projection and selection operational | ρをdomain別Observation Adapterとして使う境界、Base–Food回帰、Rest本適用、禁止する近道 |
| [ρ observation contract](../experiment-contracts/RHO_observation_resolution_contract.md) | Food projection and versioned selection operational | 同一WorldのLOW/MID/HIGH有限観測差、NPC別選択、exact値非漏洩、world/action/canonical非介入 |
| [FoodNeed M_B Admission計画](RDL_GameAI_FoodNeed_M_B_Admission実装計画.md) | PR 1-3 operational | opt-in acquisition、immutable relation、shadow F/F'/E、default-off loopback bridge。global sidecar接続は未実装 |
| [会話](RDL_GameAI_簡易会話からプレイヤー介入まで.md) | current design / phase ambiguous | intent・referent・DialogueTurn・語彙。Communication Stepは生活Phaseと別 |
| [Player](RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md) | current draft | 外部語彙・情報入力と有限な自動生活cue。直接操作・Truth権限なし |
| [設計手法](RDL_GameAI_設計手法.md) | partially stale | 設計規律・有限検証・semantic fallibility / structural integrity |
| [canonical roadmap](../../notes/experiment-roadmap.md) | partially stale | Maturityごとのimplemented slice / remaining boundary |
| [README](../../README.md) | duplicate / partially stale | 入口・実行案内。詳細は正本へ |
| [旧村設計](RDLどうぶつの森風村シミュレーター設計文書.md) | legacy / concept overlap | historical referenceとしてsource-mine対応表を保持 |

全文統合・削除対象はなし。地図・README・Layer計画内の重複詳細のみ正本へ委譲する。
旧村設計は既存参照と採掘元の対応表を残すため移動せず、現行Concept / Playerより優先しないと明示する。

## 今回の変更境界

### M_B参加意味論（2026-09-17）

- Layer docs: current。5 Layerは `M_B` の外部状態系や5分割ではなく、関係の出所・更新速度・保持時間・provenanceを整理するViewへ改訂。
- Food contract: FoodNeedはsemantic `M_B` participantとしてintended。現行canonical count-sidecarへのadmissionはdeferred。
- Cross-layer contract: 現行runtimeのfrozen `M_B` をlocal変更が黙示mutationしないことの分離契約。Body / Neural / History由来relationの永久除外は主張しない。
- Runtime authority、graph mutation、θ / M_Δ / T1 cutoverは変更なし。

### Assisted-to-autonomous Base–Food方針（2026-09-18）

- 神の像はWorldの精密Food状態を粗い生活cueへ圧縮するが、NPCへaction commandを与えない。
- NPCはcueを有限観測として受け、自身のM_Bで解釈・短期予測し、Goal / Trajectory / Commitment / Phaseを形成する。
- 毎朝cue → Base–Food完遂 → 従う/無視の結果 → 経験hook → cueなしの自律起動まで検証済み。
- generic / Threat / Novelty割り込み、復帰、固定個体差、extreme tuning比較まで検証済み。
- FoodNeed shadow PR4はEvidence review後もshadow維持。次の再検討点は非Food生活loopの成立後。
- sharing / spoilage / individual IDs / hunting / social / multi-resource実装は今回含めない。

変更対象は `README.md`、`docs/design/`、`docs/experiment-contracts/`、`notes/experiment-roadmap.md` と層間分離テストの説明文。runtime / Godot挙動、Evidence、semantic referenceは変更しない。
DNA・動的神経状態・睡眠・会話・生活機能の詳細は設計候補であり、文書整合によって実装済みに昇格しない。

## 残す表記と未実装範囲

- Layer計画の改訂履歴にある旧Layer名は名称変更の記録として保持する。
- 既存Sensitivity契約の旧Layer名とExperience契約の「Next 2」は過去の有限sliceの参照表記として残す。今回は契約の再承認・内容変更を行わず、現行配置と成熟度は設計地図・canonical roadmapで示す。
- 動的神経モデル、睡眠整理、会話、DNA、θ / M_Δ / T1は未実装。これは文書の同期漏れではなく、実装境界として明記したもの。

## 検証

- README、docs、notesのMarkdown 29件についてローカルリンクとコードフェンスを確認。エラーなし。
- Godot 4.7.2の実HTTP連携5件を含む既存70テスト成功、skipなし。
- runtime / godot / experimentsの追跡ファイルは差分なし。test変更は層間分離acceptanceの意味を明示するdocstringのみで、assertionと挙動は不変。
- 未解消競合なし、git diff --check成功。新規commit・pushは実施していない。
