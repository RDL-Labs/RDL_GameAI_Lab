# RDL_Enterprise — ゲーム用AI転用パーツ一覧

READMEには現れていない、`src/` 以下の実装全体（rdl_core / rdl_enterprise / rdl_simulation の3層、合計約830K）を実際にクローンして把握した上でのパーツ棚卸しです。層ごとに「元の役割」と「ゲームAIとしての転用イメージ」を対にしています。

---

## 層0: rdl_core — 意味論エンジンの核（T0/T1）

業務ドメインに依存しない、フレームワーク非依存の基礎契約群。ここが一番「鉱石として純度が高い」層です。

| モジュール | 主要な部品 | ゲームAI転用イメージ |
|---|---|---|
| `contracts.py` | `BoundaryContext`, `CommitmentRecord`, `EvidencePolarity`, `Provenance` | NPCの「何をいつ・何を根拠に確信したか」を記録する基礎単位。デバッグ・説明可能AIに直結 |
| `relation_types.py` | `NodeDescription`, `NodeDescriptionGraph`, `RelationObservation` | NPC間・NPCと世界の関係グラフ。ソーシャルシムの関係ネットワークにそのまま使える |
| `trigger_types.py` | `TriggerDescription`, `observe_exact_keys`, `exact_key_matches` | キーワード/条件完全一致トリガー。会話イベントや行動条件分岐の最小単位 |
| `similarity_types.py` | `RelationConstraintProfile`, `RelationSimilarityObservation` | 「今の状況は過去のあの状況に似ている」という類似性判定。汎化行動の基盤 |
| `evolution_types.py`（最大72K） | `StructureCandidate`, `StructureInductionResult`, `ConditionalFunctionCandidate`, `PatternSlotKind`, 各種`compile_*`関数 | **NPCの学習パイプライン本体**。観測パターンから条件付き行動規則を帰納し、検証してコンパイルする一連の流れ。RPGの「経験から学ぶNPC」の核にできる |
| `rupture_types.py` | `RuptureObservation`, `record_rupture_observation` | 「これまでの前提が崩れた」ことの記録。NPCの認識ショック/驚きイベント |
| `promotion_types.py` / `activation_types.py` / `deactivation_types.py` | `PromotionDecision`, `ActiveCompiledMB`, `DeactivationRecord` | 新しい行動規則を「試験→採用→現役化→廃止」する状態遷移。習慣形成・忘却のモデル化に |
| `runtime_types.py` | `evaluate_runtime_rupture`, `ConditionalRelearningRequest`, `RelearningEvidenceAnalysis` | 実行中に「規則が現実と合わなくなった」ことを検知し、再学習を要求する仕組み |

---

## 層1: rdl_enterprise — 応用層（T2/T3）。実務色は強いが構造は転用しやすい

| モジュール | 主要な部品 | ゲームAI転用イメージ |
|---|---|---|
| `h_state.py` | `HeatVector`, `HState`（ノード別/グローバル別に予測誤差・入力誤差を重み付け蓄積、閾値θで発火） | **NPCのストレス/苛立ち/警戒度メーター**にほぼそのまま使える。カナリア用の隔離蓄積（お試し行動が本番状態を汚染しない）もそのまま利用可 |
| `mb_graph.py` | `MBNode`, `MBGraph`, `IntegrityError`, 凍結（`ReadOnlyDict/List`）機構 | **NPCの記憶・知識グラフ**。ハッシュ整合性検証つきスナップショットは「記憶の改ざん検知」やセーブデータ整合性にも使える |
| `cascade.py` | `CascadeConfig`, `InterpCascade`（閾値越えで段階的に深い解釈へ進む） | NPCの**注意の逐次深化**（ちらっと見る→注視→反応）を素直にモデル化できる |
| `canary.py` | `CanaryManager`, `CanaryDeployment`, `ActionLedger`, `CompensationExecutor` | **新しい行動パターンの試験導入と自動ロールバック**。NPCが新戦術を試して悪化したら即座に元の行動に退避する仕組みに直結 |
| `shadow.py` | `ShadowPredictionPair`, `ShadowResolutionTriplet`, `ShadowEvaluator` | 現在の行動 vs 代替行動案を**反実仮想比較**。「もし別の判断をしていたら」を評価するAIの内省ロジック |
| `promotion_gate.py` | `ProposalState`, `PromotionPolicy`, `PromotionGate` | 新しい行動/知識の正式採用を審査する状態機械。学習した戦術がすぐ実戦投入されず「見習い期間」を経る設計に |
| `attention.py` | `ReviewRequest`, `HumanAttentionGate` | 「自律的に処理しきれず人間（プレイヤー）の判断を仰ぐ」ゲート。協力プレイやマネジメント系ゲームのAI相談機能に |
| `conflict_inbox.py` | `StructuralConflict`, `StructuralConflictInbox`（読み取り専用・解決はしない） | NPCの**「気になること」リスト**。矛盾を検知するだけで即座に反応しない=溜め込み型の心理モデルに使える |
| `durability.py` | `PerturbationStressChecker`, `AuthorityBoundaryChecker`, `DurabilityHarness` | 摂動を与えてNPC行動が破綻しないか検証するテストハーネス。QA・バランス調整用ツールとして流用可 |
| `action_feasibility.py` | `ActionFeasibilityStatus`, `inspect_joint_action_feasibility` | **複数NPCの協調行動が実行可能か**を、必要効果と行動効果の照合だけで判定する軽量ロジック |
| `dialogue_probe.py` | `ProbeIntent`, `GeneratedQuestion`, `DialogueObservation`, `reconstruct_dialogue_structure` | NPCが曖昧な発話に対して**確認質問を生成する**仕組み。会話NPCにほぼそのまま使える |
| `social_adapter.py` | `SocialRawInput`, `SocialFixture`, `SocialFixtureAdapter` | プレイヤー発言やイベント入力を正規化・匿名化するアダプター。入力の前処理層として流用可 |
| `simulation_adapter.py` | `EnterpriseSimAdapter` | Runtime本体と下記rdl_simulationのWorldを繋ぐアダプター。**ここが実質「ゲームAI化」の直結ポイント** |
| `authority.py` | `AuthorityContext`（actor_id, role, scope, actor_type, authenticated_by） | 「誰の指示でどこまで自律的に動けるか」の権限モデル。プレイヤー指示 vs NPC自律判断の境界設計に |

---

## 層2: rdl_simulation — すでに「ゲーム的」なシミュレーション基盤（T4）

ここが一番わかりやすく、**ほぼそのまま流用できる**層です。実務色がほとんど無く、汎用の離散イベントシミュレーション基盤として書かれています。

| モジュール | 主要な部品 | ゲームAI転用イメージ |
|---|---|---|
| `agent.py` | `Persona`（name, cohort, **expertise**, **patience**, **feedback_reliability**, **ambiguity**）、`SimAgent`基底、`UserAgent`, `AuthorityAgent`, `EnvironmentAgent` | **パラメータ化された性格モデルそのもの**。忍耐度が低いと放置(離脱)しやすい、曖昧さが高いと発言にノイズが乗る、信頼性が低いと自分の状況を誤認する——RPGのNPC性格パラメータ設計に直結 |
| `clock.py` | `SimulationClock`（tick制、`minutes_per_tick`） | 汎用の仮想時間進行クロック |
| `events.py` | `EventType`（USER_TICKET, AI_RESPONSE, USER_FEEDBACK, AUTHORITY_DIRECTIVE, ENVIRONMENT_CHANGE, TIMEOUT_TRIGGER, SCHEDULED_METRIC, CUSTOM）、優先度付き`EventQueue` | 汎用の離散イベントキュー。イベント種別を差し替えるだけでゲームイベント基盤になる |
| `world.py` | `SimulationWorld`（Clock+EventQueue+Agents+Metrics+ReplayLoggerの統合体） | **ゲームワールドのメインループそのもの** |
| `metrics.py` | `DailySnapshot`, `SimMetricsCollector`（コホート別の解決/失敗/未解決件数、コストTier、熱レベル、θ_eff、平均κ、慣性を日次追跡） | NPC群やプレイヤー行動のコホート分析ダッシュボードにそのまま使える |
| `replay.py` | `TraceRecord`, `SimTraceLogger`, `SimulationReplayer`, `ReplayResult` | **条件固定の再現可能なリプレイ機構**。デバッグ・バグ再現・実況収録に有用 |
| `scenario.py` | `SimulationRunContext`（seed, clock_start, 各種ハッシュ）、`ScenarioPack`（ABC） | シナリオパックの抽象基底＝**ステージ/マップ設計の型** |

---

## 特に「鉱石として濃い」上位5パーツ

1. **`agent.Persona`** — 忍耐度・熟練度・曖昧さ・信頼性の4軸だけで多様な行動が出る、驚くほど省コストな性格モデル
2. **`h_state.HState`** — ノード別/グローバル別に隔離できる熱（ストレス）蓄積器。カナリア隔離の仕組みがそのまま「試し行動が本性格に影響しない」設計に使える
3. **`canary.CanaryManager` + `shadow.ShadowEvaluator`** — 新戦術のお試し導入・反実仮想比較・自動ロールバックのセット。NPCの「新しいやり方を試して、ダメなら元に戻る」学習ループそのもの
4. **`world.SimulationWorld` 一式**（clock/events/metrics/replay） — ゲームループとして即座に転用できる完成度
5. **`evolution_types.py`の構造帰納パイプライン** — 観測→パターン抽出→条件付き規則の帰納→検証→コンパイル、という学習の一連の流れが型として揃っている

---

## 逆に「実務の重さ」が強く、ゲームでは剥がしてよさそうな部分

- `atlassian_jira_provider.py`, `workflow_connector.py`, `workflow_provider.py`（外部業務システム接続）
- `authority.py`の`authenticated_by`（idp_sso, mfa, passkey等）— 実世界の認証方式に強く紐づく部分
- `canary.py`内の`WebhookCompensationClient`, `SlackCompensationClient`（通知チャネル）

---

*生成元: `https://github.com/Aporapeiron/RDL_Enterprise`（2026-09-13時点のmainブランチをクローンして解析）*
