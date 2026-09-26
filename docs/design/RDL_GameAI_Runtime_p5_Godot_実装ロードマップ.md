# RDL_GameAI — Runtime / p5 / Godot 実装ロードマップ

**文書種別:** Cross-Surface Implementation Roadmap  
**版:** v0.1  
**基準HEAD:** `ae4a44e`  
**Core同期対象:** `RDL_Core@3270982`  

## 0. 実行面の責務

```text
Python Runtime
= 意味論・有限状態遷移・Core接続

p5 Workbench
= read-only観測・比較・provenance・debugging

Godot
= 身体・空間・World interactionとの統合試験
```

p5はゲーム画面ではない。今後はRDL内部機構を比較可能にする観測装置として育てる。表示要求を理由にRuntime状態やWorld truthを捏造せず、mutation endpointも追加しない。

GodotはS4までの実World縦断を証明済みである。F1からDynamic M_BまではRuntimeを主戦場とし、Godotの新規統合はG1まで原則停止する。既存の回帰試験は継続する。

## 1. 実装順

| Phase | 対象 | Runtime実装 | p5 | Godot | 完了条件 |
|---|---|---|---|---|---|
| S1 | Sleep Window | accepted Experienceを有限window化 | 観測 | 不要 | 完了 |
| S2 | Profile | ExperienceからRelation Profile | 観測 | 不要 | 完了 |
| S3 | Deep Similarity | Similarity Observationからcluster、shadow CandidateRelation | 観測 | 不要 | 完了 |
| S4 | Sleep Vertical | 実Sleep完了からS1-S3接続 | 観測 | 統合確認済 | 完了 |
| F1 | Fast Retrieval | 活動時L0/L1検索、top-k、Inspector出力 | 主観測面 | 後回し | 完了: action非介入で決定論的に再現可能 |
| F2 | Fast-Deep Cycle | 前夜candidateを翌日のFast検索から再発見 | 主観測面 | 不要 | 完了: source chainを一周追跡可能 |
| C1 | Core同期 | `3270982`のSILN、`theta_eff`、`H`、`M_delta`をGameAI契約へ翻訳 | 表示準備 | 不要 | 完了: authority境界固定 |
| C2 | Review Path | `RIB_B/RIB_B' -> F/F' -> E -> explicit review -> H` | 比較表示 | 不要 | 完了: H生成経路をcandidate系から分離 |
| C3 | `theta_eff` | GameAI-localな実効保持境界を有限モデル化 | H/theta表示 | 不要 | 完了: provenanceを分離して`H < theta_eff`と`H >= theta_eff`を判定 |
| C4 | `M_delta` | 破断時だけ再編相へ遷移 | 状態遷移表示 | 不要 | 完了: explicit review時だけ通常状態と再編相への入場を分離 |
| V-MA | C4後Multi-Agent検証 | 3/5/10 agentsでExperience・Fast・Sleep・C1-C4分離を再検証 | 観測 | 不要 | 完了: cross-agent leakage修正、再現Evidence固定 |
| V-TB | Territory Beast検証 | relationとして生じるwarning/chase/attackを有限World fixture化 | 観測 | 不要 | R4-R7完了: 3/5 agents combined ExperienceとC1-C4回帰を固定 |
| T1-A | T1材料展開 | CandidateRelation、履歴、unresolved等を有限材料化 | 材料一覧 | 不要 | 完了: active M_deltaから全材料をUNINSPECTEDで凍結 |
| T1-B | 検査・選別 | retain / reject / defer | レビュー面 | 不要 | 完了: 全材料を根拠・evidence・revision付きで明示選別 |
| T1-C | Reconstruction | 新しい`M_B'`を構成 | before/after比較 | 不要 | 完了: old `M_B`を不変保存しinactive artifactを新規生成 |
| DMB-A | Dynamic `M_B` inactive cycle | Experience/candidate系とcanonical rupture系をT1-Aで合流し`M_B'`まで追跡 | 主観測面 | 不要 | 完了: causal分離付き一周Evidenceを固定 |
| DMB-B | Cutover / Re-entry | inactive `M_B'`のauthority切替と通常相への復帰 | before/after比較 | 不要 | 完了: parent archive、新model activation、fresh window、REENTEREDを固定 |
| DMB-C | Multi-Agent regression | 2個体が独立にDMB cycleとre-entryを完了 | 比較表示 | 不要 | 完了: candidate/model/archive/M_delta/window非混線 |
| G1 | Godot再統合 | 身体・空間・実行動から同じ経路を確認 | 補助 | 再開 | 完了: Godot実観測からDMB cutoverとfresh re-entryを固定、local action不変 |
| G2-A | 長期生活・単一個体 | Food / Safety / Sleepとdynamic `M_B`を同一Worldで接続 | 補助 | 主統合面 | 完了: day 1生活、Sleep、cutover、day 2 cueなし自律を固定 |
| G2-B | 長期生活・複数個体 | 独立した複数日の生活とdynamic `M_B`を接続 | 補助 | 主統合面 | 完了: A/Bのcandidate/model/archive/M_delta/habit非混線を固定 |
| RTF-1..4 | Risky Tasty Food参照 | ordinary/tasty Food、source付き神像statement、Territory consequence、Experience provenance | 補助 | World配置 | 完了: action/canonical非介入の有限縦断を固定 |
| OGB-1..5 | Outcome Gradient / Local Bias | relation別gradient、bias形成、mixed保持、agent分離、Sleep材料投影 | 補助 | 不要 | 完了: finite provenanceとcanonical/action非介入を固定 |
| OGB-6 | Local Bias Sleep Profile | Bias材料を専用Relation Profileへ純粋変換 | 補助 | 不要 | 完了: mixed保持、agent分離、candidate非生成を固定 |
| OGB-7 | Local Bias Deep Similarity | 同一agentの3〜6 Profileをpairwise比較 | 補助 | 不要 | 完了: match/difference/conflictと有限provenanceを固定 |
| OGB-8 | Local Bias shadow Candidate | 全Profile共通relationから候補を最大1件形成 | 補助 | 不要 | 完了: mixed非相殺、conflict未解決、T1/M_B/action非昇格を固定 |
| OGB-9 | Local Bias T1 Projection | mixed candidateをrelation別の独立T1-ready candidateへ投影 | 補助 | 不要 | 完了: 明示T1-A投入、UNINSPECTED、provenance、非自動採用を固定 |
| NERV-0 | Neural Individuality / Exploration | future contract only。個体差・探索性を少数の神経感度差から創発 | 未着手 | 不要 | DEFERRED / POST-NEURAL: 現行learning loopとM_B-informed behavior後に再評価 |
| L0-L2 | Luanti World Backend | reproducible boot、finite observation、finite action resolution、next observation | 補助 | regression fixtureへ移行 | 完了: Luanti 5.17実HTTPでapproach→pickupを固定 |
| L3 | Luanti Ordinary Food | 既存BaseFoodLifePolicyでFood取得・Base帰還・deposit・result admission | 補助 | regression fixture | 完了: exact stock非漏洩、Luanti実HTTP縦断を固定 |
| L4 | Luanti Risky Tasty Food | source付き発話、territory、beast、World-owned warning/chase/attack・injury | 補助 | regression fixture | 完了: danger belief非導入の実HTTP consequence縦断を固定 |

## 2. 直近の順序

```text
F1 Fast Retrieval
-> F2 Fast-Deep Cycle
-> C1 Core同期契約
-> C2 Review / H
-> C3 theta_eff
-> C4 M_delta
-> T1 Selection / Reconstruction
-> Dynamic M_B
-> Godot再統合
```

## 3. p5観測項目

p5は実装済みのread-only snapshotだけを表示する。段階に応じ、次を追加する。

```text
M_B before
RIB_B / RIB_B'
F / F'
E
explicit review / H
theta_eff
M_delta
Candidate materials
retain / reject / defer
M_B after
```

各表示はsource ID、version、authority、statusを保持する。空状態、未評価、拒否、保留を同じ表示へ潰さない。

## 4. 固定境界

```text
CandidateRelation != E != H
CandidateRelation != M_delta != M_B'
Similarity result != review result
H >= theta_eff != automatic reconstruction result
p5 display != authority
Godot World truth != Runtime inference
```

F1/F2は検索とprovenance確認までで停止し、action influenceを解禁しない。C1はCore概念の翻訳契約を先に固定し、コードを先行させない。T1ではold `M_B`を破壊的更新せず、入力材料と選別結果を追跡可能にして新しい`M_B'`を生成する。

## 5. 現在地

```text
S1-S4 COMPLETE
F1 COMPLETE
F2 COMPLETE
C1 COMPLETE
C2 COMPLETE
C3 COMPLETE
C4 COMPLETE
V-MA / V-TB COMPLETE
T1-A COMPLETE
T1-B COMPLETE
T1-C COMPLETE
DMB-A COMPLETE
DMB-B COMPLETE
DMB-C COMPLETE
G1 COMPLETE
G2-A COMPLETE
G2-B COMPLETE
RTF-1..4 COMPLETE
OGB-1..5 COMPLETE
OGB-6 COMPLETE
OGB-7 COMPLETE
OGB-8 COMPLETE
OGB-9 COMPLETE
NERV-0 CONTRACT ONLY / NERV-1..9 DEFERRED
LUANTI L0-L4 COMPLETE / L5 NEXT
```

詳細なF1/F2 Acceptanceは[Sleep / Fast-Deep Experience Loop実装計画](RDL_GameAI_Sleep_FastDeep循環実装計画.md)を正本とする。
