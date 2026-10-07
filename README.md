# RDL Game AI Lab

- [身体・社会生活の複数seed](docs/experiment-evidence/LW_body_field_seeds.md)：追加3seed×30日完走。全員最終reserve正・30日目に移動あり。1個体で途中枯渇後の近傍採取/食事回復を記録。

- [身体系の方法選択接続](docs/experiment-evidence/LW_body_method_field.md)：空腹/H・疲労を探索/帰還の既存候補へ合成。30日で9判断の最終操作選択差、全員の最終reserveは正。

- [80％からの空腹寄与](docs/experiment-evidence/LW_hunger.md)：局所M_Bで5秒ごとに充足比較、Hを食事/要求候補へ接続。30日採取100/食事99、全員の最終reserveが正。1seedの有限結果。

- [個人所持と粗い備蓄認識](docs/experiment-evidence/LW_personal_food.md)：30日完走。自動共有を止め、備蓄some以上で探索休止、減少後に再開。採取67/食事69、補給成功は全員ではない。

- [接続済み生活経路の30日統合](docs/experiment-evidence/LW_integrated_social_30d.md)：自然/共有拠点の2run完走。探索・危険・身体・Sleep・社会・拒否場を併走。共有側採取220/食事66、自然側採取0。遠隔救助等は未統合。

- [拒否関係場の生活適用](docs/experiment-evidence/LW_refusal_life.md)：3seed×3日でshadow/enabled比較。1seedで再要求から既存採取へ切替、総要求/譲渡/食事数は同じ。逆向きの正重み場面は0件。

- [拒否経験のHと関係場](docs/experiment-evidence/LW_refusal_relation_field.md)：実拒否2件を用いた共通32seed比較。再要求28→10、逆向き要求への譲渡28→10。固定された使用仮説の専用実験、通常生活へは未適用。

- [援助要求のE/H](docs/experiment-evidence/LW_aid_pressure.md)：拒否/応答未観測を目的・相手別方法へ蓄積。θ到達で同日中にB→Cへ再選択。3日要求31→5、譲渡2→3の有限比較。

- [探索・食事・通信・Sleep統合](docs/experiment-evidence/LW_social_life.md)：既存軽量探索で3個体3日。Sleep採用なしの要求先B→B→Bに対し、採用ありB→C→B、実譲渡2回。共有備蓄・食事・在庫保存も検証。有限opt-in。

- [最小コミュニケーション実験](docs/experiment-evidence/LW_minimal_communication.md)：要求→譲渡/拒否、手伸ばし→警告→再選択の5条件。保持食料の移転と消費を検証。通常探索・Sleep未接続。

- [主観的援助関係](docs/experiment-evidence/LW_aid_relations.md)：同じ拠点所属から、救助/無応答で個体別の援助期待と次の相手選択が変化。聞こえなかった場合も本人には無応答。有限専用実験、通常探索・Sleep未接続。

- [声による救助と救助者の行動不能](docs/experiment-evidence/LW_voice_rescue.md)：有限軽量Worldで救援声→接近→給食。救助者も消耗で歩行不能になる対照を確認。通常探索・Sleepへの統合は未実装。

- [エネルギー場の探索・Sleep接続](docs/experiment-evidence/LW_energy_connection.md)：同じ荷重/抵抗で候補costの有無を3日比較。自然地形の採取0、低障害の持帰り31→36。単一seedの有限結果。

- [簡易エネルギー消費場](docs/experiment-evidence/LW_energy_field.md)：抵抗・荷重・身体余力で有限候補のcost/実行可否を評価。2個体の資源移転と実消耗を検証。専用fixture、通常探索への自動接続は未実装。

- [2.5D SILN World・物理構造帯計画](docs/design/RDL_GameAI_25D_SILN_World_Plan.md)：DESIGN ONLY。World側モデルと個体M_Bを分離し、既存幾何・身体・積載を独立レイヤーへ整理。PW-0〜4は未実装。

- [重量・障害・荷物を置く](docs/experiment-evidence/LW_cargo_obstacle.md)：5個/6個の通過境界、実dropと再取得、帰還/逃走目的の候補差。有限専用実験、通常探索の重量台帳は未接続。

- [身体・生活・Sleep統合](docs/experiment-evidence/LW_body_sleep.md)：3個体×3日×4run。障害越え、荷下ろし、夜間参照を接続。自然地形でSleep由来の候補選択差59件、採取改善は未達。

- [探索と身体の接続](docs/experiment-evidence/LW_body_exploration.md)：既存探索Runtimeで低障害越え・休息・実採取・結果受付。4条件比較。専用opt-in、長期生活/Sleep統合は未検証。

- [見える食料と身体障害](docs/experiment-evidence/LW_visible_food_obstacle.md)：軽量World5条件。低障害越え、休息後の採取、高さ超過・遮蔽・蓄え枯渇を分離。固定初期能力の専用実験。

- [四層身体の最小構築](docs/experiment-evidence/LW_layered_body.md)：瞬発/持続/蓄え/肉体限界、歩行・走行・低障害越え・休息・食事の22操作fixture。探索AI接続は未実装。

- [Sleep自動採用・30日の日次評価](docs/experiment-evidence/LW_sleep_daily_30d.md)：3個体、同seed、採取84→121・持帰り60→111。180個体日の前日差を記録。日次Hフィードバックは未接続。

- [Sleep関係の自動採用実験](docs/experiment-evidence/LW_sleep_auto_adoption.md)：未検査の局所M_Bを翌日の候補順位へ接続。3日比較で88回の直接選択差、採取48→45・持帰り15→27。canonical T1採用とは別経路。

- [Sleep夜間接続・異種経験比較](docs/experiment-evidence/LW_sleep_learning.md)：軽量Worldで実装・3日比較。採取M_Bは夜間に採用、異種関係は共通/相違/欠測の診断まで。汎用関係の採用は未接続。

- [30日・時間補充比較](docs/experiment-evidence/LW_patrol_30d_regrowth.md)：3日ごと最大12単位、2 seed×縄張り/巡回追加。全4run完走。再採取は成立する条件があるが、後半の採取停止も記録。

- [縄張り＋巡回危険物体](docs/experiment-evidence/LW_dynamic_hazard_pair.md)：2 seed×5日、2体同時観測と継続選択を実行。追加脅威で持帰りが減るseedと増えるseedの両方を記録。

- [継続する局所方法選択](docs/experiment-contracts/LW_continuous_selection.md)：現行lightweight CLIは探索・帰還・警戒で回数切れ終端を撤去。局所E/H/θで方法を選び直す。[5日×4条件の結果](docs/experiment-evidence/LW_continuous_selection.md)では選択継続を確認、採取/帰還改善は未達。旧Python APIは再生互換のためlegacy既定。

- [長期探索の時間計測](docs/experiment-evidence/LUANTI_L15A_campaign_timing_evidence.md)：16日目を通過、23日目に送信待ち上限で中断。Runtime観測処理に2.05秒。受信済み69,887応答は再生一致、最終Runtimeとの差も保存。

- [6個体の連続探索](docs/experiment-evidence/LUANTI_L15A_six_agent_world_evidence.md)：B/C/Eが各12単位、B/Eが帰還。16日目に観測枠逸失で中断、正常完走は未達。

- [現在採取状態の実走行](docs/experiment-evidence/LUANTI_L15A_current_harvest_world_evidence.md)：16日目に観測枠逸失で中断。36単位・2便。不在と過去成功の併存を実機で確認。

- [現在の採取状態](docs/experiment-contracts/LUANTI_L15A_current_harvest_state.md)：現在の「ない／不明」を成功経験から分離。採取関係モデルの再構成は別工程。

- [30日M_B接続比較](docs/experiment-evidence/LUANTI_L15A_model_field_30d_evidence.md)：両条件24単位・2便。実M_B採用後に資源枯渇で失効、場への適用0件。通信受入は未達。


- [採用済みM_Bから移動場への有限寄与](docs/experiment-contracts/LUANTI_L15A_model_movement_field_contract.md)：連続探索のopt-in。既存の採取関係を確認へ向かう寄与として利用。
**強さだけでなく、履歴から理解できる個体差や意外性を持つGameAIを実験する。**

目指す体験は、かわいい生き物が小さな世界で食べ、休み、失敗し、助け合い、回復しながら暮らす生活シミュレーション。現在動くものは、そのための有限な実験Workbenchであり、完成した生活ゲームではありません。

## Start here

1. [全体設計地図](docs/design/RDL_GameAI_全体設計地図.md): 4軸と各文書の正本
2. [Game Concept](docs/design/RDL_GameAI_かわいい生き物が必死に生きる_コンセプト.md): 体験・世界観
3. [NPC Layer Plan](docs/design/RDL_GameAI_NPC_レイヤー別設計計画.md): 状態の所有・更新・保持・検証
4. [Canonical Experiment Roadmap](notes/experiment-roadmap.md): 実装成熟度と残る境界
5. [Current Runtime Contract](docs/experiment-contracts/CURRENT_v23_runtime_contract.md): 現行動作の有限契約
6. [Base–Food循環完成計画](docs/design/RDL_GameAI_Codex_BaseFood循環完成計画.md): 完了した参照生活ループ
7. [ρ活用指南](docs/design/RDL_GameAI_ρ活用指南.md): 観測解像度をGameAIへ導入する際の判断基準
   - [ρ解像度遷移設計](docs/design/RDL_GameAI_ρ解像度遷移設計.md): 目的・曖昧性・操作段階に応じた局所LOW→MID→HIGH→低ρ復帰のDESIGN ONLY
8. [コード抽象度・道具的関数階層](docs/design/RDL_GameAI_コード抽象度・道具的関数階層_案.md): I0 PrimitiveからI6 Adapterまでの実装責務と依存方向
9. [p5.js Observation Workbench](gui-p5/README.md): read-only I6 Viewer。Experience→Sleep Window→Profile→CandidateのprovenanceとLive GET endpoint状態を可視化
10. [Runtime / p5 / Godot実装ロードマップ](docs/design/RDL_GameAI_Runtime_p5_Godot_実装ロードマップ.md): F1からDynamic M_B、Godot再統合までの実行面・authority・停止条件
11. [Luanti Integration Roadmap](docs/design/RDL_GameAI_Luanti_Integration_World_Backend_Transition_Roadmap.md): L0-L4 bridge、Luanti主統合面への移行、Godot regression fixture化

生活機能の追加順は[Game Feature Roadmap](docs/design/RDL_GameAI_実装手順予定.md)、コード内の抽象度と依存方向は[道具的関数階層案](docs/design/RDL_GameAI_コード抽象度・道具的関数階層_案.md)で管理します。

## Four separate axes

| 軸 | 管理するもの |
|---|---|
| A. Canonical RDL maturity | RIB_B / frozen M_B / E / review / H、将来のT1・authority |
| B. NPC internal layers | Generation / DNA、Neural Dynamics、Physical / Body、Experience / Relation History、Realtime / Current Context |
| C. Game feature implementation | Food・Rest・Energy・Safety・Rescue等の生活機能 |
| D. Cross-cutting systems | World Time・Communication・Vocabulary・Player・Sleep Consolidation等 |

canonical maturity != game feature phase。Layer ProfileはCore ontologyでもM_Bの分解定義でもありません。Neural Dynamicsは内部状態の配置先であり、その影響経路は横断系としても検査します。睡眠は第6Layerではなく横断更新イベントです。

各Layerは、現在の有限なagent-side関係・parameterの出所、更新速度、保持時間、provenanceを整理するViewです。owner module / store自体は `M_B` ではありませんが、宣言したBoundaryで明示的に採用された現在関係は `M_B` を構成し得ます。現行canonical runtimeはFoodNeedを含む全parameterをまだoperational admissionしていません。

## Current implementation

- Canonical diagnostics: bounded observation → finite B → RIB_B → frozen M_B → F/F' → E → explicit finite residual review → H / retained H。
- GameAI-local behavior: 有限なapproach結果履歴、任意のhistory retry policy、固定1/3/5 tick profile、Godot所有のmovement_scale、現在観測。
- First game feature: [minimal Food loop](docs/experiment-contracts/FOOD_minimal_loop_contract.md)。FoodNeed → approach → pickup → eat → world消費 / Need低下。
- Current direction: Restの固定target・interrupt復帰に加え、RestNeed + 明示window + safe place → sleep → 回復を実縦断した。Sleep Consolidationは明示cycleのS4 shadowとして実装済みで、World Timeとaction authorityは未実装。
- Operational assisted slice: 粗いcueからBase–Foodを完遂し、follow / ignore結果を分離する。deposit成功を有限経験として保持し、2成功後のみcueなしのlearned relationから同じ一周を自律起動できる。generic保留・再開、Threat profile差、Novelty三応答と復帰、両端の調整用extreme profile比較まで実装済み。
- Reference status: [Base–Food completion evidence](docs/experiment-evidence/BASE_FOOD_reference_loop_evidence.md)と[ρ v0.x evidence](docs/experiment-evidence/RHO_v0_reference_evidence.md)を固定。FoodNeed canonical promotionはshadow維持、ρ追加展開はdeferred。
- Observation resolution: [ρ contract](docs/experiment-contracts/RHO_observation_resolution_contract.md)でFood / RestのLOW / MID / HIGH、版付きprofile、packet sidecar、provenanceを実装。default actionとcanonical pathは非介入。Restの二重opt-in実験のみ候補記述へ接続済み。
- Rest behavior: opt-in隔離modeでGodot所有RestNeedがtick増加し、独立した[有限target selection](docs/experiment-contracts/REST_target_selection_contract.md)が一度だけ候補を選ぶ。[ρ Rest candidate実験](docs/experiment-contracts/RHO_rest_candidate_description_contract.md)はLOW/HIGHで候補記述だけを変え、同じselectorから異なるtargetを得る。Trajectoryはgeneric interrupt後も同じtargetへ復帰する。Food priorityは未接続。
- Sleep behavior: opt-in隔離modeで `RestNeed >= 0.85`、明示sleep window、bounded safe placeが揃った時だけPlazaへapproachしてsleepする。GodotがRestNeedを回復し、`consolidation=not_run`を記録する。
- Energy: opt-in時のみGodotが独立したActiveEnergy / EnergyReserveと個体別ActiveEnergyCapacityを所有する。実移動はActiveEnergyだけを消費、short restはActiveEnergyだけを小回復、Sleepは両方を回復し、ActiveEnergy回復はcapacityで止まる。reserve移送と行動選択への接続はまだ行わない。
- Phase 3 status: [Energy Evidence](docs/experiment-evidence/ENERGY_phase3_reference_evidence.md)で参照実装を閉じた。次の生活境界はSafety / Dangerで、具体的AcceptanceなしにEnergy内部を拡張しない。
- Safety: opt-in隔離modeでGodot所有のstatic danger zone、または別fixtureのmoving threatをbounded contextへ投影する。NPC Bはsafe Plazaを固定targetとして `flee`、exposure消失後も継続し、Plaza到達の後続観測で `idle / COMPLETE` に戻る。moving fixtureは位置だけを更新し、predator ontology・負傷・Energy連携はまだ行わない。
- Safety selection: Godotはsafe/uncertainと有限距離bandの候補記述だけを渡す。Runtimeの独立selectorが `safe > uncertain`、同安全度なら近い候補を一度だけ選び、その後の順位変化はTrajectory targetを変えない。
- Danger selection: Godotは現在接触中のdanger sourceと `low / medium / high` だけを渡す。Runtimeは支配sourceを有限選択してprovenanceへ残すが、safe target・Energy・負傷には権限を持たない。
- Workbench visualization: [V1-V3 contract](docs/experiment-contracts/WORKBENCH_visualization_contract.md)でNPC・Object・Threat・Placeを簡易図形化し、選択NPCの観測円、既存committed target線、static danger領域を表示する。World truth・Runtime decision・canonical sidecarには非介入。Inspector V4は目視評価後まで保留。
- Continuous life: Phase A〜Eでresult因果拘束、Safety通常CLI、実三周Food自律、inspector/simulation分離、Food-Safety有限統合まで成立。Phase Fの[長期縦断証拠](docs/experiment-evidence/CONTINUOUS_LIFE_reference_evidence.md)では、別Shelterへの退避を含む成功→通常成功→cueなし自律完走を同一NPC/Runtime/Worldで確認する。Phase Gでは優先Godot縦断をCI固定する。一般Need arbitrationは未実装。
- Food × Rest: 明示opt-inの[有限Coordinator](docs/experiment-contracts/FOOD_REST_continuous_life_contract.md)で、Food保持中の高RestNeed→Food保留→別Rest Hutでshort rest→現在関係からFood再評価→Plaza帰還/depositを確認する。固定閾値による最初の比較sliceであり、一般Need arbitrationではない。
- Incapacitation Phase 5A: 専用[Safety failure contract](docs/experiment-contracts/SAFETY_incapacitation_contract.md)で、3回のfixture-controlled failed flee→Godot-owned severe injury / incapacitated→後続Runtime actionのidle拘束を確認する。通常Safetyへは非介入で、Rescue / Recoveryは未実装。
- Rescue Phase 5B: [bounded discovery contract](docs/experiment-contracts/RESCUE_bounded_discovery_contract.md)で、観測範囲内の別NPCだけがincapacitated conditionを受け取る。global通知、Rescue Goal、搬送、回復は未実装。
- Rescue Phase 5C: [Goal / Trajectory contract](docs/experiment-contracts/RESCUE_goal_trajectory_contract.md)で、bounded discoveryからtargetを一度固定し、対象へ接近して `READY_TO_RESCUE` で停止する。搬送・治療・回復は未実装。
- Rescue Phase 5D: [safe-place delivery contract](docs/experiment-contracts/RESCUE_safe_delivery_contract.md)で、対象保持、固定safe targetへの搬送、World-owned delivery記録、後続観測によるCOMPLETEまで通す。治療・回復は未実装。
- Rescue Phase 5E: [staged recovery contract](docs/experiment-contracts/RESCUE_staged_recovery_contract.md)で、安全地点滞在中の有限4段階回復をGodot BodyStateが所有する。回復後は旧Safety trajectoryを盲目的に再開せず、現在関係で再評価する。
- Rescue Phase 5F: [multi-agent reference evidence](docs/experiment-evidence/RESCUE_multi_agent_reference_evidence.md)で、NPC Bの行動不能からNPC Aの発見・一度だけの救助・搬送・段階回復までを同一World/Runtimeで固定する。回復中conditionは再救助候補から分離する。
- Sleep S1-S4 + Fast F1/F2の記憶循環に加え、C1でCore `3270982`のauthority境界を固定した。C2では[Canonical Review Path](docs/experiment-contracts/CANONICAL_review_path_projection_contract.md)として`RIB_B/F/RIB_B'/F'/E/review/H`を追跡し、C3では[finite theta_eff](docs/experiment-contracts/CANONICAL_theta_effective_contract.md)を独立評価する。C4では[finite M_delta transition](docs/experiment-contracts/CANONICAL_M_delta_transition_contract.md)としてexplicit review時だけ再編相へ入場し、p5へread-only表示する。本線の次段はT1-A。
- T1-A前の[Multi-Agent / Territory Beast検証](docs/design/RDL_GameAI_C4後_Multi-Agent_Territory_Beast検証計画.md)はR1-R7完了。3/5/10 agentsの分離、Fast cross-agent境界、danger labelを持たないWorld fixture、warning/chase/attack、direct/observer Experience、C1-C4非介入をEvidence化し、本線へ復帰した。
- [T1-A Material Expansion](docs/experiment-contracts/T1_material_expansion_contract.md)ではactive `M_delta`からcurrent `M_B`、RIB history、unresolved residual、same-agent Candidate/Experienceを不変bundleへ展開し、全材料を`UNINSPECTED`でT1-Bへ渡す。
- [T1-B Material Selection](docs/experiment-contracts/T1_material_selection_contract.md)ではbundle全材料を根拠・evidence・revision付きで`RETAIN / REJECT / DEFER`へ明示選別する。T1-B単独の`RETAIN`は採用ではなく、T1-Cへの明示入力となる。
- [T1-C Reconstruction](docs/experiment-contracts/T1_reconstruction_contract.md)ではretained parent/candidateから別identityのinactive `M_B'`を生成する。old `M_B`、active registry、`M_delta`は不変のままDMB-Aへ渡す。
- [Dynamic M_B Inactive Cycle](docs/experiment-contracts/DYNAMIC_MB_inactive_cycle_contract.md)ではExperience/candidate系とcanonical rupture系をT1-Aでのみ明示合流し、inactive `M_B'`まで一本のprovenanceを固定した。ExperienceがHを生成したとは扱わず、DMB-Bへ明示入力する。
- [Dynamic M_B Cutover / Re-entry](docs/experiment-contracts/DYNAMIC_MB_cutover_reentry_contract.md)ではparentをarchiveし、`M_B'`をactive evaluatorへ切替え、fresh comparison windowで通常相へ戻す。これはgame action authorityではなく、DMB-Cでmulti-agent回帰を確認する。
- [Dynamic M_B Multi-Agent Regression](docs/experiment-contracts/DYNAMIC_MB_multi_agent_regression_contract.md)では2個体が別candidate・model・archive・`M_delta`・fresh windowで一周することを確認した。local actionはcutover前後で不変。
- [G1 Godot Dynamic M_B Reintegration](docs/experiment-contracts/G1_Godot_dynamic_mb_reintegration_contract.md)ではGodot所有の身体・空間・実行動から既存DMB経路へ再接続し、cutover後のfresh Godot比較とlocal action不変を固定した。
- [G2-A Long-Life Dynamic M_B](docs/experiment-contracts/G2A_long_life_dynamic_mb_contract.md)では同一Godot Worldでday 1のFood/Safety、実Sleep、明示DMB cutover、day 2のcueなし自律Foodを接続した。
- [G2-B Multi-Agent Long-Life](docs/experiment-contracts/G2B_multi_agent_long_life_contract.md)では同一World/Runtime内のNPC A/Bが別candidate・model・archive・`M_delta`・habitを保ち、それぞれ翌日のcueなし自律Foodを完走した。実行は決定論的な直列fixtureである。
- [Risky Tasty Food Reference](docs/experiment-contracts/RISKY_TASTY_FOOD_reference_contract.md)ではordinary/tasty Food、物理的Territory関係、source付きGod Statue statement、既存warning/chase/attack/injury、Food関係付きExperienceを同一参照fixtureへ置いた。statement・Experience・Dynamic `M_B`にaction authorityはない。
- [Outcome Gradient / Local Bias](docs/experiment-contracts/OUTCOME_GRADIENT_local_bias_contract.md)ではRisky Tasty Foodの物理結果をacquisition/return/injury/reward別gradientへ投影し、正負を相殺せずagent-owned Local Biasとして有限保持する。Sleepには材料投影のみで、Candidate・canonical・actionへ自動接続しない。
- [Local Bias Sleep Relation Profile](docs/experiment-contracts/LOCAL_BIAS_sleep_profile_contract.md)ではagent-owned Biasを既存S2とは別の専用Profileへ変換する。mixed正負と全source chainを保持し、SimilarityやCandidateはまだ生成しない。
- [Local Bias Deep Similarity](docs/experiment-contracts/LOCAL_BIAS_deep_similarity_contract.md)では同一agentの3〜6 Profileを有限比較し、全Profileに共通するrelationからshadow CandidateRelationを最大1件だけ形成する。conflictは未解決のまま記録し、candidateをT1・M_B・actionへ自動昇格しない。
- [Local Bias T1 Candidate Projection](docs/experiment-contracts/LOCAL_BIAS_t1_projection_contract.md)ではmixed shadow candidateをrelation別の独立CandidateRelationへ投影する。T1-Aへの投入はactive M_delta下の明示操作だけで、全材料はUNINSPECTEDから始まり、自動選別・採用・action化しない。
- [Luanti L0-L2 Bridge](docs/experiment-contracts/LUANTI_L0_L2_bridge_contract.md)ではLuanti 5.17の単一NPC Worldから有限観測を既存Runtimeへ送り、`approach`と`pickup`をLuantiが解決して次の観測を返す実HTTP往復を固定した。Luantiを今後の主World統合面、Godotをdeterministic regression fixtureとして扱う。
- [Luanti L3 Ordinary Food](docs/experiment-contracts/LUANTI_L3_ordinary_food_contract.md)では既存BaseFoodLifePolicyをLuanti Worldへ接続し、低在庫cue→Food取得→Base帰還→deposit→因果拘束されたresult admissionを実HTTPで完走した。exact stockはLuanti内に留める。
- [Luanti L4 Risky Tasty Food](docs/experiment-contracts/LUANTI_L4_risky_tasty_food_contract.md)ではsource付きGod Statue statement、tasty Food、territory relation、beastを観測し、既存policyのapproachに対するLuanti-owned warning→chase→attack→medium injury→forced retreatを実HTTPで固定した。danger beliefや学習はまだ導入しない。
- [Luanti L5 Outcome Learning](docs/experiment-contracts/LUANTI_L5_outcome_learning_contract.md)では実Luanti attack factを明示admitし、既存Territory Experience→Outcome Gradient→Local Biasへ接続した。acquisition・return・injuryのrelation-local biasを形成するが、action・canonical authorityへは接続しない。
- [Luanti L6 Sleep / Deep Candidate](docs/experiment-contracts/LUANTI_L6_sleep_deep_candidate_contract.md)では同一個体の3つの実Luanti outcomeを既存Local Bias Profile・Deep Similarityへ通し、support 3のshadow CandidateRelationを形成した。Sleepは明示起動で、T1・M_B・actionへ自動昇格しない。
- [Luanti L7 Dynamic M_B Cycle](docs/experiment-contracts/LUANTI_L7_dynamic_mb_cycle_contract.md)ではLuanti由来候補と独立canonical ruptureをT1-Aで明示合流し、relation別候補の選別、inactive `M_B'`、cutover、parent archive、fresh `REENTERED`までを固定した。cutoverはgame action authorityを変更しない。
- [Luanti L8 Multi-Agent Separation](docs/experiment-contracts/LUANTI_L8_multi_agent_separation_contract.md)ではagent・Sleep結果・candidate・assessmentを明示参照し、A/BのExperience・候補・model・archive・`M_delta`をRuntime/adapter境界で分離した。実Luanti World内の複数entity同時生活はまだ主張しない。
- [Luanti L9 p5 Read-Only Trace](docs/experiment-contracts/LUANTI_L9_p5_read_only_trace_contract.md)では選択agentのExperience→Bias→Sleep→Candidate→T1→active modelを既存GET snapshotから表示する。欠落段階や未公開World位置をGUI側で補完せず、mutation/action authorityを追加しない。
- [Luanti RW1 Multi-Agent World](docs/experiment-contracts/LUANTI_RW1_multi_agent_world_contract.md)では実Luanti同一World内のA/Bが別packetで相互をbounded観測し、それぞれ専用Foodへapproach/pickupする縦断を固定した。一般social AIや複数個体learningはまだ導入しない。
- [Luanti RW2 Multi-Agent Food Life](docs/experiment-contracts/LUANTI_RW2_multi_agent_food_life_contract.md)では専用Food/Baseを保ったまま、A/Bが同一World・Runtimeで独立にpickup、return、deposit、causal result admissionまで一周する。
- [Observation System Integration Plan](docs/design/RDL_GameAI_Observation_System_Integration_Plan.md)のOBS-0〜4Bでは、隔離store、個体別近景、有限遠景、最小聴覚と動的受信窓を実装した。聴覚はemit時の位置・姿勢でagent別bufferへ保持し、半開window、遅延配送、overflow欠落を扱う。音源同定・感覚融合・行動接続は未実装のまま保つ。
- Display: action・body・history由来のResponse Expression。心理的感情推定や行動権限ではありません。
- [Luanti L10 sensory learning action](docs/experiment-contracts/LUANTI_L10_sensory_learning_action_contract.md)は、受理済み遠景条件と実取得結果からrelationを形成・独立検査し、既存T1で採用したM_Bの予測を有限Food試行／保留へ接続する。明示opt-inの専用fixtureであり、OBS-9のA/B生活調停への常設統合や自律reviewではない。[Evidence](docs/experiment-evidence/LUANTI_L10_sensory_learning_action_evidence.md)。
- [Luanti L10B multi-agent learning](docs/experiment-contracts/LUANTI_L10B_multi_agent_learning_contract.md)は、同じ継続WorldのA/Bで経験・M_B・身体権限を分離する。逆の経験による行動差、片方だけのモデル採用、応答待ち中の他方の進行を実機3run・72 Episodeで検証。[Evidence](docs/experiment-evidence/LUANTI_L10B_multi_agent_learning_evidence.md)。共有資源や社会学習は保留。
- [Luanti L10C shared Food learning](docs/experiment-contracts/LUANTI_L10C_shared_food_learning_contract.md)は、共有Foodの実取得競合と、本人のM_Bによる選択が相手の結果にも作用する有限実験。実Luanti5run・60共有Episodeで検証。[Evidence](docs/experiment-evidence/LUANTI_L10C_shared_food_learning_evidence.md)。色条件による本人の学習であり、他者理解・所有・自律再学習は未接続。
- [Luanti L14A continuous resource](docs/experiment-contracts/LUANTI_L14A_continuous_resource_contract.md)は、実の見本と用途だけを教示し、一地点2単位の在庫・身体・所持品を30期間引き継ぐ。枯渇後も探索を続ける前提基準で、木の特徴の帰納とSleep/T1/M_B反復更新は未接続。[Evidence](docs/experiment-evidence/LUANTI_L14A_continuous_resource_evidence.md)。
- [Luanti L15A Phase 1](docs/experiment-contracts/LUANTI_L15A_subjective_movement_terrain_contract.md)は、現在の有限なFood・障害物・地表入力から5方向の主観的移動地形を純粋計算する。成分別出典・欠測・同点を保存する。純粋関数単体は身体操作の権限を持たない。[Evidence](docs/experiment-evidence/LUANTI_L15A_subjective_movement_terrain_evidence.md)。
- [L15Aの探索接続](docs/experiment-contracts/LUANTI_L15A_exploration_connection_contract.md)は、現在のFoodへの接近を地形計算から既存L14Bの身体操作へ渡すopt-inモード。3個体の実Luanti短期runで接続・採取・学習を確認。[v1 Evidence](docs/experiment-evidence/LUANTI_L15A_exploration_connection_evidence.md)。
- [L15A v2の旋回制御](docs/experiment-contracts/LUANTI_L15A_steering_contract.md)は、小差での方向保持・実旋回後の一歩の再検査・有限な旋回打切りを追加。実Luantiの草地/自然林で連続逆旋回を抑制したが、採取効率の改善は未達。離散的な身体操作は継続。[Evidence](docs/experiment-evidence/LUANTI_L15A_steering_evidence.md)。
- [L15Aの左右バイアス単独実験](docs/experiment-contracts/LUANTI_L15A_lateral_bias_contract.md)は、個体別left/neutral/rightを近同点の別寄与として追加。主比較6runでは差なし、追加2runで1回の実旋回選択と終点が分岐。振動・採取効率は改善せず、方向保持v2と合成していない。[Evidence](docs/experiment-evidence/LUANTI_L15A_lateral_bias_evidence.md)・[拡張計画v0.3](docs/design/RDL_GameAI_Luanti_Subjective_Movement_Terrain_Extension_Plan_v0.3.md)。
- [L15A ξ_tie単独](docs/experiment-contracts/LUANTI_L15A_tie_break_contract.md)は、有効な近同点へ再現可能な微小摂動を加え、最大3判断・750ms保持する。実Luanti5runと応答消失後の一回作用を検証。主比較は選択・逆旋回・採取に差なし、停滞改善は未達。[Evidence](docs/experiment-evidence/LUANTI_L15A_tie_break_evidence.md)。
- [今後の移動計画](docs/design/RDL_GameAI_Movement_Next_Steps.md): [反復shadow](docs/experiment-contracts/LUANTI_L15A_repetition_shadow_contract.md)の[保存9run・3減衰条件](docs/experiment-evidence/LUANTI_L15A_repetition_shadow_evidence.md)で、予定往復も除外せず要求差を確認。
- 後続の[有限休憩](docs/experiment-contracts/LUANTI_L15A_movement_rest_contract.md)は実装済み。[実Luanti4条件＋故障run](docs/experiment-evidence/LUANTI_L15A_movement_rest_evidence.md)で、疲労・反復による実wait、観測継続、回復、再開を検証。主比較は全て採取0件で、探索改善は未確認。睡眠・生理的疲労モデルは未実装。
- [Finite goal reassessment](docs/experiment-contracts/LUANTI_L15A_goal_reassessment_contract.md): one extra review after rest, without resetting the eight-goal budget. [8 actual World runs](docs/experiment-evidence/LUANTI_L15A_goal_reassessment_evidence.md) yield six new subgoal selections and body actions; no memory-driven command difference or harvest improvement.
- [Rest/contact comparison](docs/experiment-evidence/LUANTI_L15A_rest_obstacle_evidence.md): four actual Luanti runs. Persistent contact remains applicable; removal invalidates the observed context. Goal-budget wait remains authoritative; zero terrain applications or action changes.
- [休憩中の再活性化](docs/experiment-contracts/LUANTI_L15A_rest_reactivation_contract.md)を明示opt-inで追加。[実機3run](docs/experiment-evidence/LUANTI_L15A_rest_reactivation_evidence.md)で内部参照/再開検査のモード切替は成立、地形寄与・行動差は0件。[研究接続メモ](docs/design/RDL_GameAI_Cognitive_Mode_Research_Map.md)はDMN等との対応を仮説として分離。
- [主観的移動地形の拡張計画v0.2](docs/design/RDL_GameAI_Luanti_Subjective_Movement_Terrain_Extension_Plan_v0.2.md)は、身体状態・未知への反応・社会relation・学習済み予測・広域価値を出典別に扱う後続設計。現行Phase 1の実装範囲は変更しない。
- [拡張計画v0.7・対話追記](docs/design/RDL_GameAI_Luanti_Subjective_Movement_Terrain_Extension_Plan_v0.7.md)のξ_tieは上記の有限実装まで完了。停止・再観測、寄り道、当初目的の後回し／非参照、反復反応の減衰差と渦からの切替はDESIGN ONLY。予測の一致・局所的な不足・記憶を分離し、復帰や脱出を保証しない。取得・判断周期とL14B profileは変更していない。
- [Luanti L14B multi-resource](docs/experiment-contracts/LUANTI_L14B_multi_resource_contract.md)は、3個体・8地点各12単位の共有資源を継続探索する。各自の採取経験3形成＋2検査からT1/M_Bへ一度採用し、予測確認に対する固定感度差を有限探索要求へ渡す。Coreの予測差と局所的な刺激の差は別に保持する。[Evidence](docs/experiment-evidence/LUANTI_L14B_multi_resource_evidence.md)。同じ条件で探索seedを変えた[偏りの比較](docs/experiment-evidence/LUANTI_L14B_seed_evidence.md)も記録する。
- [Luanti L13W multiple Food](docs/experiment-contracts/LUANTI_L13W_multi_food_exploration_contract.md)は、L13Vの地形・探索・学習を維持してFoodを1個から固定5地点へ増やす。複数同時観測を有限に受理し、発見日数・支持数・取得数を区別する。[Evidence](docs/experiment-evidence/LUANTI_L13W_multi_food_exploration_evidence.md)。
- [Luanti L13V neighborhood exploration](docs/experiment-contracts/LUANTI_L13V_neighborhood_exploration_contract.md)は、目印へ接近した地点から二方向の有限往復を行い、完全な未発見だけを別日検査→T1/M_Bへ渡す。同じ取得条件での再探索省略を、同一履歴・cutover有無の実World対照で検査する。一般的な場所不在や自律帰還ではない。[Evidence](docs/experiment-evidence/LUANTI_L13V_neighborhood_exploration_evidence.md)。
- [Luanti L13U landmark exploration](docs/experiment-contracts/LUANTI_L13U_landmark_exploration_contract.md)は、現在観測した粗い面特徴を小目標として保持し、実回転・移動後に再観測する。見失い・複数候補・通行不能・near取得を分け、Food関係の学習は既存Sleep/T1/M_B経路へ残す。[Evidence](docs/experiment-evidence/LUANTI_L13U_landmark_exploration_evidence.md)。
- [Luanti L13T natural exploration](docs/experiment-contracts/LUANTI_L13T_natural_exploration_contract.md)は、道のない草地・起伏・木立・岩・水辺へL13Sの探索学習を接続。1段step・3D実測・実ノード遮蔽を扱い、地形図をRuntimeへ渡さず別日3回発見／最大30日まで実行する。[Evidence](docs/experiment-evidence/LUANTI_L13T_natural_exploration_evidence.md)。
- [Luanti L13S learned exploration](docs/experiment-contracts/LUANTI_L13S_learned_exploration_contract.md)は、色追従を与えない有限試行→発見日のExperience→日末Sleep→別日の経路検査Probe→T1/M_B→次回選択を接続する。別Episodeで3回発見まで、最大30日。検査Probeと採用済み選択を区別し、一般的な道の意味は学習済みとしない。[Evidence](docs/experiment-evidence/LUANTI_L13S_learned_exploration_evidence.md)。旧L13A/Rは回帰基準として保持。
- [Luanti L13R repeated exploration](docs/experiment-contracts/LUANTI_L13R_repeated_exploration_contract.md)は実装・有限受入完了。4系列・62実Luanti run。道ありは初日発見、道なしは保持／リセットとも30日未発見。各日は拠点・身体・Runtimeを初期化し、本人記録を分離保持。固定探索規則は履歴を使わず、学習による行動差は未接続。[Evidence](docs/experiment-evidence/LUANTI_L13R_repeated_exploration_evidence.md)。
- [最大30日の持ち帰り試験](docs/experiment-contracts/LUANTI_L15A_return_campaign_contract.md)は、同一Worldを継続し、A/B/C合計で新しい資源の持ち帰り3便に達したら終了する。数量と便数、手持ちと帰還済みを分離する。
- [塔の目印と昼夜サイクル](docs/experiment-contracts/LUANTI_L15A_landmark_day_cycle_contract.md)は、同一WorldでA/B/Cの探索・帰還試行・夜間休止を3日通す専用経路。位置・在庫・目印記憶を保持し、迷子も残す。夜間整理はcanonical Sleep/T1へ未接続。[Evidence](docs/experiment-evidence/LUANTI_L15A_landmark_day_cycle_evidence.md)。
- [Luanti L13A finite exploration](docs/experiment-contracts/LUANTI_L13A_finite_exploration_contract.md)は実装・有限受入完了。昼間の色タイル帯・遠景の山・局所Food観測と相対移動を、実Luanti9run・441取得記録で検査。帯ありは取得、帯なし等は時間切れ。固定追従規則であり、経路記憶・M_B学習は[後続計画](docs/design/RDL_GameAI_Luanti_Exploration_Plan.md)。[Evidence](docs/experiment-evidence/LUANTI_L13A_finite_exploration_evidence.md)。
- [Luanti L12 learned resource-use relation](docs/experiment-contracts/LUANTI_L12_learned_resource_use_relation_contract.md)は実装・有限受入完了（12run・84Episode、実警告10回）。本人の次回取得について形成3件・未使用検査3件からrelationをT1/M_Bへ採用し、同じ現在利用への警告差を検査する。[Evidence](docs/experiment-evidence/LUANTI_L12_learned_resource_use_relation_evidence.md)。親密さ・所有の認識は扱わない。
- [Luanti L11 boundary defense](docs/experiment-contracts/LUANTI_L11_boundary_defense_contract.md)は固定関係による有限な警告機構。実Luantiの主比較24run・56 pickupと同席／範囲外2runで、関係・閾値・反復間隔による警告差を確認。[Evidence](docs/experiment-evidence/LUANTI_L11_boundary_defense_evidence.md)。専用計測通知を使い、関係学習・Core E/H/θ・攻撃への接続は含めない。
- [自己との関係拘束モデル](docs/design/RDL_GameAI_自己との関係拘束モデル.md)は、人・道具・場所・共同体に共通する関係を、保持・文脈別の適用・距離や重みの要約に分ける将来設計。所有・親密さ・所属の記録案と比較実験を整理した。**design-only、実装・受入は未実施**。
- Deferred: 一般的なcanonical行動権限、DNA・動的神経値・会話、栄養・一般在庫・飢餓等の広い生活機能。

固定retry profileは神経値から導出したものではありません。設計上の「DNA μ/σ → dynamic neural state → derived sensitivity」と現行実装を区別します。

[Runtime evidence](docs/experiment-evidence/CURRENT_v23_runtime_evidence.md)と[層間分離契約](docs/experiment-contracts/CROSS_LAYER_separation_contract.md)が確認範囲を示します。保持はprocess-localであり、再起動永続化を意味しません。

## Semantic boundaries

意味論の基準は[Core reference](docs/semantic-reference/RDL_Core_T0_T1_reference.md)の同期点 `86a0d4f3`（BASE v2.3.1 / SPEC v2.5、E＝差。比較条件とT1権限を維持）。Demos・Enterprise・Humanは素材・仮説の参照元、General ModulesのLayeringは整理補助です。

```text
Engine state != observation != RIB_B != M_B
F / F' use the same frozen pre-update M_B
Structural Conflict != E != H
nonzero E != unresolved by definition
H != emotion / Human Attention
Novelty != ξ
Player statement != World Truth
semantic fallibility allowed; structural integrity required
```

誤認・誤命名・誤一般化は設計上許容しますが、参照破損・provenance消失・意図しないcanonical mutationは許容しません。詳細は[設計手法](docs/design/RDL_GameAI_設計手法.md)へ。

## Run

```bash
python -m runtime.bridge
```

p5.js Viewerは別端末で `python gui-p5/serve.py` を起動し、`http://127.0.0.1:8080` を開きます。GUI側proxyはGETのみをRuntimeへ転送し、状態変更要求は受け付けません。

Assisted Base–Food実験は明示的に有効化します: python -m runtime.bridge --base-food-life

Godot 4.7で [project.godot](godot/rdl-game-ai-workbench/project.godot) を開き、Run Projectを実行します。RuntimeモードでPython bridgeに接続します。MockモードはGodot単体です。

履歴の行動影響は任意です。

```bash
python -m runtime.bridge --history-influence --retry-profile npc_a=long --retry-profile npc_b=short
```

観測IDを再利用するWorkbench Reset後はRuntimeも再起動してください。API・容量・review・停止境界の詳細は[現行契約](docs/experiment-contracts/CURRENT_v23_runtime_contract.md)と各機能契約を参照します。

## Verify

```powershell
$env:GODOT_BIN = 'D:\Godot\Godot_v4.7.2-stable_win64_console.exe'
python -m unittest discover -s tests -v
```

GODOT_BINなしではGodot連携テストはskipされます。テスト成功は宣言した有限Boundary内の確認であり、全ゲーム挙動やRDL理論の証明ではありません。

## Repository

```text
docs/design/                design map and responsibility documents
docs/semantic-reference/    pinned Core reading
docs/source-inventory/      source-mine evaluations
docs/experiment-contracts/  finite runtime contracts
docs/experiment-evidence/   verification records
notes/experiment-roadmap.md canonical maturity
runtime/                   local action runtime and diagnostic sidecar
godot/                     world and interaction workbench
integrations/luanti/        primary World backend prototype and finite bridge
gui-p5/                    read-only p5.js observation / provenance viewer
experiments/                bounded prototypes
tests/                     acceptance tests
```

[文書棚卸し](docs/design/DOCUMENT_STATUS.md)に整理理由を記録しています。


### Campaign history storage follow-up

Completed-night sharing preserves all 69,887 replay responses and six public states.
The six-agent live run reached day 30 but stopped on pending capacity; full World
export timed out. Long-run acceptance remains incomplete. See
[history-storage evidence](/docs/experiment-evidence/LUANTI_L15A_campaign_history_storage_evidence.md).


### 軽量Worldへの探索接続計画（2026-09-29）

[計画表](/docs/design/RDL_GameAI_Lightweight_World_Plan.md)を追加。DESIGN ONLY。
Python仮想World＋既存ReturnCampaign＋p5再生を段階実装する。
まず3個体・有限視覚・身体操作・増分ログを接続し、最大30日／3資源持帰りを観察する。
目標Hの接続はWorld差し替え後の別工程。canonical Sleepの統合済みとは扱わない。
Luanti長期負荷対策は保留し、節目の契約確認に残す。


### LW-1 軽量World接続（2026-09-29）

Pythonの有限2D Worldから既存ReturnCampaignへ直接接続。3個体・3日、各768観測を約2.37秒で実行。採取・持帰り・モデル形成は0件。
[契約](/docs/experiment-contracts/LW_1_planar_world.md) / [Evidence](/docs/experiment-evidence/LW_1_planar_world_evidence.md)。
p5再生は次工程、目標H・canonical Sleep接続は未実装。Luantiと同一物理・同一センサーとは扱わない。


### LW-2 記録再生

既存p5ワークベンチ配下にCanvas読取専用ビューを追加。全景／個体取得情報、時刻指定、速度変更、JSONL/gzip読込みに対応。
[検証記録](/docs/experiment-evidence/LW_2_replay_evidence.md)。Runtime・World判断は変更なし。


### LW-3 30日比較完了

M_B移動寄与disabled/enabledとも約30秒で30日完了。採取・持帰り・モデル形成0、全行動一致。
遠景partialに伴う取得不完了待機が多数で、学習効果の適用機会はなかった。
[Evidence](/docs/experiment-evidence/LW_3_paired_campaign_evidence.md)。Hは未接続、次は有限観測と判断条件の整理。


### LW 遠景角域化の限定比較

opt-in `--distant-mode patches`を追加。連続する同色・同距離帯だけを結合し、4件超過はpartialを維持。
30日disabledは完了、行動差0。有効条件はプロセス異常終了で未完了。
[Evidence](/docs/experiment-evidence/LW_3_distant_patches_evidence.md)。Runtime/Hは変更なし。


### 軽量World 疎配置

`--layout sparse`を追加し30日完走。取得不完了待機0、Cが食料を308観測・138単位移動、採取0。
資源配置は固定し物体/障害物のみ減らした。密配置は以前の完走ログとの比較。
[Evidence](/docs/experiment-evidence/LW_sparse_layout_evidence.md)。Runtime/Hは変更なし。


### LW 食料接近の場切替

`--approach-mode enabled`で、観測済み食料への接近時にsoft obstacle寄与を0.1倍。衝突・物理除外は維持。
30日完走、Cは食料0.843単位まで接近したがground partialでpickup前に待機。採取0。
[Evidence](/docs/experiment-evidence/LW_approach_field_evidence.md)。H/学習規則は変更なし。


### LW 時間を持つ採取

opt-in timed_harvestで距離1.25以内→0.5秒作業→完了時判定。30日完走、Cが12採取・1地点枯渇、帰還0。
学習の観測条件は維持しrecords/M_B0。[Evidence](/docs/experiment-evidence/LW_timed_harvest_evidence.md)。
作業中も取得を続け身体操作を抑制。新イベント形式のviewer対応は次工程。


### LW 時刻帰還の成立

opt-in skyline-subraysで塔のサンプリング隙間を軽減。採取後の探索継続・時刻帰還によりCが2回、24単位持帰り。
30日採取60、CのM_B形成あり。3回目持帰りは未達、学習効果への単独帰属なし。
[Evidence](/docs/experiment-evidence/LW_time_return_evidence.md)。H/帰還規則は変更なし。


### LW 無限資源比較

`--inexhaustible`で資源を減らさず実行。Cは同じ餌場で32/34/30採取、3日目の3回持帰りで終了。
移動距離36/30/28、M_B形成0のため学習による経路短縮とは扱わない。既存累計96上限は維持。
[Evidence](/docs/experiment-evidence/LW_inexhaustible_evidence.md)。

## 初期能力の設計

[初期能力と経験学習の境界](docs/design/RDL_GameAI_Initial_Capabilities.md)（DESIGN ONLY）を追加。昼夜の粗い相対方位を初期能力として与える案と、経験から学ぶ場所・経路・目印関係を分離。runtime変更なし。


2026-09-29: [初期方位感覚の有限実装](docs/experiment-evidence/LW_initial_orientation_evidence.md) — 昼夜共通30度幅の入力と既存再見回しの左右選択へopt-in接続。3日比較で旋回差、採取・帰還改善なし。上記DESIGN ONLYは導入前履歴。方向記憶・帰還利用・Luantiは未接続。


2026-09-29: [初期方位30日比較](docs/experiment-evidence/LW_initial_orientation_evidence.md) — seed20260930・3個体、あり／なし双方完走。Aの112見回し中28回が左、総移動は53/3/2で同じ、採取・配送0。B/Cの取得不完了待機は継続。改善未確認、runtime変更なし。


2026-09-29: [取得不足からの有限位置変更](docs/experiment-evidence/LW_incomplete_reposition_evidence.md) — opt-in実装。現在の身体観測と反復残存で方向選択、追加操作16/日。seed20260930の30日で採取0→48、配送0のまま。BでM_B形成。方向別許可と反復効果は未分離。40テストPASS、Luanti未接続。


2026-09-29: [局所帰還完了と候補拡張](docs/experiment-evidence/LW_local_return_evidence.md) — 有限opt-in実装。塔nearで止めず局所接近・実荷下ろし確認。帰還停滞でも位置変更。30日で48採取・48持帰り4便、Cは採取0だが帰還位置変更44操作。初回不成立も保存。48テストPASS、Luanti未接続。


2026-09-29: [全個体の資源共用](docs/experiment-contracts/LW_shared_resource_access.md) — 既存動作を契約・manifest・回帰で固定。所有／利用権なし、共通残量と取得競合は維持。採取規則変更なし。


2026-09-29: [入れ子の局所モデル選択](docs/experiment-evidence/LW_nested_local_models_evidence.md) — 有限opt-in。survey/approach/work/repositionごとに問い・結果・Hを保持し、上位Hと代替Hから位置変更を提案。30日60採取・60配送8便、Cも1単位と後半毎日の並進。58テストPASS。canonical再構成・全既存M_Bの統一・Luantiは未接続。


2026-09-29: [局所モデル3seed比較](docs/experiment-evidence/LW_nested_seed_evidence.md) — 追加2run＋既存1run、各3個体30日。全270個体日に並進、終日並進0なし。採取・配送72/96/60。効率は判定対象外、World配置だけ変更。

2026-09-29: [成功目印による翌日再訪](docs/experiment-evidence/LW_food_revisit_evidence.md) — `--food-revisit-mode enabled`で有限実装。日越し成功記憶→目印再観測→採取→帰還を単純軽量Worldで確認。自然配置では曖昧性/見失いから探索へ復帰、安定往復は未成立。資源無限を明示した比較、38テストPASS。

2026-09-29: [往路・帰路の双方向候補と成功支持](docs/experiment-evidence/LW_directional_routes.md) — `--directional-route-mode enabled`。実配送ごとの方向別支持、支持0の逆順候補、現在の塔/Food優先。軽量自然Worldで逆順操作は食料38/帰還23、配送改善は未成立。48 tests PASS。

2026-09-29: [双方向経路の30日比較](docs/experiment-evidence/LW_directional_routes_30d.md) — 無限資源・同seed。なし1396/あり981採取・配送、支持蓄積あり。あり側に終日並進0が16個体日発生し、Aは25〜30日目に連続。単なる期間延長による安定往復改善は未成立。最初5日のcommand列一致を監査。

2026-09-29: [複数目印の関係場合成](docs/experiment-evidence/LW_relation_field_evidence.md) — `--relation-field-mode enabled`。2点以上の角度関係と現在terrain/目標を5方向へ合成、owner保持と旋回後一歩を追加。58 tests PASS。軽量30日で関係寄与523操作、終日並進0は16→1個体日、配送981→807。効率改善は未成立。

2026-09-29: [発見後の経路安定性監査](docs/experiment-evidence/LW_route_stability.md) — 保存30日ログ再解析。配送区間A13→9/B16→22/C16→13。Bの既知地点利用は継続、A/Cは再採取までの移動増。固定往復への収束は未成立。runtime変更なし。

2026-09-29: [経験による経路候補の相対重み](docs/experiment-evidence/LW_route_weight.md) — 関係場v2。成功支持/Hから有限weightを計算し、比較可能な代替候補が強まれば旧候補の相対寄与が低下。未使用減衰なし。65 tests PASS、軽量5日完走、集計はv1と同じ。

2026-10-03: [動く危険物体と安全確保M_B](docs/design/RDL_GameAI_Moving_Hazard_Safety_Plan.md) — 有限実装・軽量World 7run比較。[Evidence](docs/experiment-evidence/LW_moving_hazard_safety_evidence.md)。初期危険知識から食料目的を保留し、退避・待機・再観測後に再選択。既知経路横断で2回の解除・再開、遮蔽条件ではunresolvedも残る。82 tests PASS。長期複数seed・Luanti移植は未実施。

2026-09-29: [M_B強化の非線形化メモ](docs/design/RDL_GameAI_MB_Reinforcement_Nonlinearity.md) — DESIGN ONLY。証拠量・更新量・現在寄与を分離し、説明力とDifferenceから更新逓減が生じるかを検査する方針。現行supportは飽和カウンタ。runtime変更なし。

2026-09-29: [合成的感情の仮説](docs/design/RDL_GameAI_Compositional_Emotion_Hypothesis.md) — HYPOTHESIS / DESIGN ONLY。M_B・評価機・関係別Hから恐怖と好奇心の併存、退避後の問いの再選択を検査する案。感情ラベルを制御入力にせず、未知を自動的にE/Hへ変換しない。

2026-09-30: [動的ρの具体案](docs/design/RDL_GameAI_ρ解像度遷移設計.md) — §24–27に食料接近・障害物場・聴覚を追記。保存情報の再解釈と新規取得を分離し、局所詳細化の処理量・比較可能性・見逃しを検査する計画。未実装。

2026-09-30: [世界履歴のアイディア](docs/design/RDL_GameAI_World_History_Idea.md) — DESIGN ONLY。草地の通行痕が重なって道になる例から、環境に残る作用履歴を整理。個体記憶・World状態・監査ログを分離し、初版候補は外観変化のみ。

2026-10-03: [固定縄張り反応物](docs/experiment-evidence/LW_territorial_hazard.md)を軽量Worldへ追加。侵入→接近→可視威嚇→退去後帰巣。5日×3条件、91 tests PASS。enabledで5回の安全解除・再開。動物学習・負傷は未実装。

2026-10-03: [有限採取場×縄張り比較](docs/experiment-evidence/LW_finite_territory.md)。8地点各12単位、うち1地点が縄張り内。5日×3条件、総採取60は同じだが対処ありの配送56・携行4。資源利用時期/個体が変化し、安全未解決も残る。

2026-10-03: [警戒モードの局所H評価](docs/experiment-evidence/LW_warning_mode_review.md)を追加。維持根拠の未更新→H→閾値で暫定解除。有限資源5日比較でAが携行4個を配送、全員normal終了。99 tests PASS。安全の証明とは区別。

2026-10-03: [縄張り内採取場1→3地点比較](docs/experiment-evidence/LW_territory_resource_density.md)。総96単位を保持し2地点を移設。5日×4条件。3地点・対処ありは46採取/36配送、Bは可視威嚇下で10携行・安全操作予算切れ。関連41 tests PASS。
