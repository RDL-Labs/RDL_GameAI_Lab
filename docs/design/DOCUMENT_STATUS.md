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
| [会話](RDL_GameAI_簡易会話からプレイヤー介入まで.md) | current design / phase ambiguous | intent・referent・DialogueTurn・語彙。Communication Stepは生活Phaseと別 |
| [Player](RDL_GameAI_暫定プレイヤー役割_しゃべる神の像.md) | current draft | 外部語彙・情報入力、直接操作・Truth権限なし |
| [設計手法](RDL_GameAI_設計手法.md) | partially stale | 設計規律・有限検証・semantic fallibility / structural integrity |
| [canonical roadmap](../../notes/experiment-roadmap.md) | partially stale | Maturityごとのimplemented slice / remaining boundary |
| [README](../../README.md) | duplicate / partially stale | 入口・実行案内。詳細は正本へ |
| [旧村設計](RDLどうぶつの森風村シミュレーター設計文書.md) | legacy / concept overlap | historical referenceとしてsource-mine対応表を保持 |

全文統合・削除対象はなし。地図・README・Layer計画内の重複詳細のみ正本へ委譲する。
旧村設計は既存参照と採掘元の対応表を残すため移動せず、現行Concept / Playerより優先しないと明示する。

## 今回の変更境界

変更対象は `README.md`、`docs/design/`、`notes/experiment-roadmap.md`。
前回から未commitの層間分離テスト、契約・Evidence・semantic reference変更は保全し、今回改変しない。
DNA・動的神経状態・睡眠・会話・生活機能の詳細は設計候補であり、文書整合によって実装済みに昇格しない。

## 残す表記と未実装範囲

- Layer計画の改訂履歴にある旧Layer名は名称変更の記録として保持する。
- 既存Sensitivity契約の旧Layer名とExperience契約の「Next 2」は過去の有限sliceの参照表記として残す。今回は契約の再承認・内容変更を行わず、現行配置と成熟度は設計地図・canonical roadmapで示す。
- 動的神経モデル、睡眠整理、会話、DNA、θ / M_Δ / T1は未実装。これは文書の同期漏れではなく、実装境界として明記したもの。

## 検証

- 対象15文書のローカルリンク113件、見出しアンカー1件、コードフェンスを確認。エラーなし。
- Godot 4.7.2の実HTTP連携4件を含む既存65テスト成功、skipなし。
- runtime / godot / tests / experiments / contracts / evidence / semantic-referenceの追跡ファイルは作業前autostashとの内容差分なし。前回の未追跡層間分離テスト・契約も編集せず保持。
- 未解消競合なし、git diff --check成功。新規commit・pushは実施していない。
