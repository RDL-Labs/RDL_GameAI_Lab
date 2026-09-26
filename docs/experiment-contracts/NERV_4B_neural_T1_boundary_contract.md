# NERV-4B 神経由来CandidateとT1検査材料の境界契約

状態: **IMPLEMENTED / N4B-01〜10 PASS** / 2026-09-26。
[受入Evidence](../experiment-evidence/NERV_4B_neural_T1_boundary_evidence.md)。
基準: `714df257`。[NERV-4A Evidence](../experiment-evidence/NERV_4A_neural_candidate_evidence.md)。

## 1. 問いと停止点

問いは「指定経験に共通して残った神経由来の関係を、raw根拠と神経条件を失わず、T1で個別に検査できる材料へ変換できるか」。
初版は純粋な材料準備と、専用の明示受付によるT1-Aの`UNINSPECTED`まで。
T1-Bの自動retain/reject/defer、T1-C再構成、M_B更新、Goal/Trajectory・行動変更は実装しない。
候補があること、支持が3件以上あることからM_deltaを発生させない。

## 2. 参照した仕様と現在の実装

RDL_Coreのローカルcommit `327098256a29e3f82f2a8649a6ec0202fd68a6c4`を参照した。

- `00_T0_基盤層/T0最低動作仕様 (SPEC).md`: F/F'は同じ更新前M_Bによる解釈。Outcome GradientをE/Hへ代入しない。
- `01_T1_SILN操作層/T1_SILN展開.md`: 問い・境界を先に設定し、有限な材料から候補を展開する。
- `01_T1_SILN操作層/T1_検査と選別.md`: 目的・制約・許容損失を確認して検査し、retain/reject/deferを判断する。同じ生成過程を共有する証拠の独立性を過大評価しない。

[Lab側の意味参照](../semantic-reference/RDL_Core_T0_T1_reference.md)を併用する。
これはCoreを変更する契約ではなく、GameAIの有限な接続条件である。

現行コードの境界:

- `project_local_bias_candidate`は旧schemaのみ受け、新Candidateを拒否する。
- `T1MaterialExpansionStore.expand`はactive M_delta・model_ref・assessment・個体を照合するが、local Candidateのschemaを限定しない。
- `T1MaterialSelectionLedger.inspect`は全材料への明示dispositionとbasis/evidenceを要求する。神経由来の根拠を自動評価する検査器ではない。

従って「任意の入口から新Candidateが物理的に入らない」とは主張しない。
基準commitでは正式な神経由来受付が未定義だった。NERV-4Bでは下記の専用入口のみを正式経路とし、汎用Python APIをセキュリティ境界とは扱わない。
既存raw経路の許可schemaや既定動作を変更しない。

## 3. 二種類の根拠の身分

| 根拠 | 記録するもの | 導いてはいけないこと |
| --- | --- | --- |
| raw | Experience/event参照、記録されたOutcomeから既存規則で形成した勾配・context | World全体の真実、canonical RIB_B/F/E/H |
| neural | 同じrawから固定parameter・規則により残った方向・強度・抑制理由 | 対象の客観的価値、canonical E、採用済み関係 |

rawとneuralは独立な2票ではない。支持単位はdistinct Experienceで、NERV-4Aの3〜6を保持する。
rawが非zeroでもneural_filteredなら、その個体の共通関係への未支持であり反証ではない。
raw_zeroも経験の不存在ではない。神経条件で消えた関係をrawだけで復活させ、新しいCandidateへ混ぜない。
同一の神経signatureが再現されても、一般化・因果・定常性の証明とはしない。

## 4. 純粋な準備入口

入口: `prepare_neural_t1_materials(materials, candidate_request)`。
任意のCandidate辞書を信用する入口は作らない。
`build_neural_candidate`を再実行し、前段compilerによる全材料検査を含めて結果を再構成する。
選択外材料も不正なら拒否。前段の入力拒否と正常な候補なしを混ぜない。

出力schema: `nerv-t1-preparation-v1`。

- `candidate_formed`なら共通relationごとに最大4件の子材料を作り、`ready_for_inspection`を返す。
- 他の3状態なら`no_inspection_materials`、子材料0件。元のstatus・理由・全診断を保持する。
- 元Candidate/result IDと再構成結果全体を保持し、子材料は元Candidate・relation別signature・支持Experience/raw/projection/Bias/eventを指す。
- 子材料schemaは`nerv-t1-relation-material-v1`。parameter全内容・規則・context・run/agent・cycle/tickを保持。
- 各支持Experienceについてraw dimensionとneural dimensionを一組として保持する。元Experience本体を持たない場合は参照として扱い、履歴本文を捏造しない。
- 除外relationの支持群・抑制・zero・不一致は親診断に残す。子材料がないことを負の証拠へ変換しない。
- 子材料は`UNINSPECTED`、authorityは検査材料のみ。`common_relation_signature`等の既存構造を使っても旧schemaを名乗らない。

IDは規則版・元結果全内容・relationから決定する。入力順序で変えず、入出力のmutable aliasを作らない。
前段の最大128 projection/32 Bias・選択最大6・最大15組/60判定を維持し、子材料は最大4。切り詰めや全履歴自動探索はしない。
この準備関数は保存・M_delta判定・T1-A展開を行わない。

## 5. T1-Aへの明示受付

別の明示入口: `expand_neural_t1_materials(materials, candidate_request, binding, m_delta_state, model, review_path, store)`。
この入口も準備関数を内部実行し、呼出し側が改変したprepared辞書をそのまま受け入れない。

bindingにはrun_id/agent_id、transition_id/model_ref/assessment_id、purpose、boundary_ref、criteria_refを必須とする。
初版purposeは`inspect_neural_common_relations`固定。boundary_refとcriteria_refは次段で検査条件を追跡する参照であり、文字列の存在だけで適合性が証明されたとはしない。
run/agentは神経材料と一致、残りのcanonical参照は指定した現行状態・model・review_pathと一致させる。
canonical側にrun情報がない場合も暗黙推測せず、呼出し側の明示run bindingとして出典を残す。
呼出し側は現在のcanonical snapshotを渡す責務を持つ。本入口が検査するのは渡された参照同士の整合性であり、
外部の最新状態・偽造snapshotの真正性を認証しない。boundary_ref/criteria_refの意味的適合性も未検査である。

active M_deltaと凍結したcanonical参照を既存T1-A経路で検査し、同じ個体の子材料だけを渡す。
元Candidate集合全体を一つのrelationとして渡さない。
初版の同一transitionにはこの神経材料集合を一度固定し、別内容で既存bundleを上書き・追記しない。
旧経路ですでに使われたtransitionへの追加は競合として拒否し、旧材料を捨てない。
同じ完全な入力の再送は同じbundle、変更再送は拒否。容量満杯なら明示不成立で、部分展開を公開しない。
候補なしでは空の神経展開を作らず、その診断を返す。汎用canonical材料だけの展開とは別の結果にする。

bindingと親診断は凍結bundleの子payloadから追跡可能にする。
T1-A展開後も子材料のdispositionは`UNINSPECTED`。既存T1-Bへ自動でレビューpayloadを生成しない。
T1-Cやcutoverへの新しい接続は作らない。

## 6. 後続の検査・選別で必要な条件

NERV-4Bでは以下を診断資料として準備するだけで、dispositionを計算しない。

| 検査する問い | 扱い |
| --- | --- |
| 元記録と投影が再現するか | 改変・欠落は入力拒否。候補の意味を反証したことにはしない |
| 指定した経験集合で知覚関係が共通か | NERV-4Aで確認した局所的性質として保持 |
| 現在の問い・boundary・モデルに適用できるか | 別の検査基準・証拠が必要。不足なら後段でdeferできる |
| rawにあるのにneuralで消えたか | 神経条件依存の未支持。自動rejectの理由にしない |
| 複数の根拠は独立か | raw/projection/Biasは同一経験に由来。支持を加算しない |

今後retainを定める際には、用途・適用域・許容損失・反例条件・モデルとの対応を別契約で固定する。
RETAINも採用・M_B更新そのものではない。parameter差からT1採用差やNPC行動差が出たとは扱わない。

## 7. 実装時の受入条件

**全件PASS。** Python固定再生と既存T1 fixtureで検証した。専用12テスト、全体468件実行＝422 PASS＋46 intentional skip。

| ID | 必須検査 |
| --- | --- |
| N4B-01 | 四隅parameterから関係別材料が形成され、元Candidateの関係数・支持を保存 |
| N4B-02 | raw/neuralの対応と固定parameterを追跡し、独立2票へ水増ししない |
| N4B-03 | 3一致+1抑制、全抑制・zero、文脈差・経験不足を保持。除外関係を復活しない |
| N4B-04 | 未選択を含む改変・混線・欠落・旧schemaを拒否。偽Candidateの直接受付なし |
| N4B-05 | 6経験/4子材料の上限、前段容量超過拒否、順序不変ID、入出力独立 |
| N4B-06 | active M_deltaと全binding照合。inactive・別個体・古いmodel/assessment/transitionを拒否 |
| N4B-07 | 同入力再送で同bundle、変更再送/旧bundle競合/容量超過で部分更新なし |
| N4B-08 | 子材料は全件UNINSPECTED。自動選別・再構成・cutoverを呼ばない |
| N4B-09 | 親診断と全出典を凍結bundleから追跡可能。候補なしを空Candidateとして展開しない |
| N4B-10 | 準備で全store不変、明示展開でT1-Aのみ変化。既存行動・canonicalモデル・旧Sleep不変、全体回帰PASS |

Luanti/HTTPは今回再実行していない。自律起動、長期保持、神経由来の再構成はこの受入の対象外。

## 8. 実装配置

`runtime/neural_t1.py`に2入口を追加。既存T1-Aのcanonical検査とstoreを再利用する。
明示受付結果は`expanded_for_inspection / no_inspection_materials / capacity_rejected`。入力不正・競合は例外。
容量超過時は既存storeの拒否counterのみ増加し、bundle集合は変更されない。
親の全診断を最大4個の子payloadへコピーして凍結する。新しい診断storeや自動hookは作らない。
process内の明示的な逐次呼出しを対象とし、並行transaction・永続化・restartをまたぐ受付保証は追加しない。
