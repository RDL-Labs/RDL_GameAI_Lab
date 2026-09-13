# RDL_Demos — ゲームAI素材棚卸し

`https://github.com/HermannDegner/RDL_Demos` をクローンして中身を確認した上での棚卸し。`RDL_Enterprise`が「業務AI用に磨かれた抽象エンジン部品」だったのに対し、こちらは**すでに動いている生き物・仮想世界そのもの**という、別角度の素材。

---

## 全体構成

```
RDL_Demos/
├── rdl_system/     RDL中核概念の最小参照実装（JS, core/profiles/experiment）
├── demos/          ブラウザ上のビジュアルシミュレーション（8本）
├── rdl_bot/        CLIチャットボット（既存メモ sumitsuku-ai の実装参照先）
└── rdl_village/     簡易村シミュレーター（Python, 外部依存なし）
```

`rdl_bot`は既に`[[sumitsuku-ai]]`として棚卸し済みのため、本文書では割愛。

---

## 層A: rdl_village — 完成度の高い村NPCシミュレーター（Python）

`RDL_NPC行動決定システム`と`RDL_簡易村シミュレーター`の設計をほぼそのまま実装した、外部依存ゼロのPythonコード。**設計文書と実装が一致している**ため、そのまま参照・流用しやすい。

| モジュール | 主要な部品 | ゲームAI転用イメージ |
|---|---|---|
| `core.py` | `HVec`, `XiPool`, `Boundary`, `LeapEngine`, `ErrorLedger`, `BasalHeat`, `Phase`(Enum) | H_vec/ξ/Leapという抽象概念の**具体的リファレンス実装**。他プロジェクトへ移植する際の一次ソースにできる |
| `npc.py`(80K) | `VillageNPC`, `BasalDynamicsSystem`, `UpperContextSystem`, `BodyState`, `ScheduleBlock` | NPCの四層意思決定サイクル本体。**そのままキャラクターAIの核として移植可能な粒度** |
| `action.py` | `RelationalAction`, `ActionCandidate`, `MovementPlanner`, `PhysicalConstraintLayer` | 13方向移動を関係勾配込みで評価する仕組み。最短経路ではなく「知覚F＋予測場」から動きを決める設計 |
| `relations.py` | `RelationState`(方向つき: A→B ≠ B→A), `ActionPattern`, `ActionMemory`, `RelationMemorySystem` | 好感度一軸に頼らない多軸関係モデル。ソーシャルシムの人間関係システムにそのまま使える |
| `dialogue.py` | `DialogueIntent`, `DialogueEvent`, `DialogueNode`, `RelationalDialogueSystem`, `build_vocabulary()` | LLM非依存の語彙ノード対話。表示文を再解析せず構造化イベントを直接交換 — **軽量な会話NPCの雛形** |
| `perception.py` | `Perception`, `PerceptionSystem`, `PlaceMeaning`, `ResourceBelief`, `PredictionField` | NPCは物理世界の真値を直接見ず、知覚経由の予測場だけを使う。「認識のズレ」自体をゲームメカニクスにできる |
| `world.py` | `VillageClock`, `Place`, `ResourceNode`, `ResourceCycleSystem`, `PlaceSystem`, `PhysicalWorld` | 場所の意味・危険性をNPCへ直接渡さない環境レイヤー |
| `profiles.py` | `BoundaryCoeffs`, `NodeCoeffs`, `HCoeffs`, `LeapCoeffs`, `DialogueCoeffs`, `NeuroProfile`, `Profile` | 係数を個体・用途ごとに差し替え可能にするプロファイル機構。**NPCの「気質」の実装単位** |
| `simulation.py`(56K) | `VillageEventBus`, `OutcomeEvaluator`, `VillageSimulation`, `VillageObserver` | 同一tick内の意思決定順が恒常的優位を生まないよう、意図をまとめて提出してから解決する仕組み |
| `richness.py` | `measure(simulation)`（entropy, JS divergence, day drift） | 生存率ではなく「生活の豊かさ」を測る指標群 |

### 付属ドキュメント（設計思想として濃い）

- **`RDL_生命らしさ評価指針`** — 生存率を目的関数化した結果「退屈(D4)実装が生存率を下げた＝退屈は純コスト」という誤った結論に陥った失敗例を起点に、生命らしさを**生存／行動レパートリー／個体分岐／意味の個体差／生活構造の日次変化／破断位置の多様性**の6軸ベクトルへ分解。単一スカラーへの圧縮を明確に戒める
- **`破断検査`** — 成功した修正だけでなく失敗した試行列も過程ごと保存する方針の記録

---

## 層B: demos — 1メカニズムずつ切り出したブラウザ実験（p5.js / 素のJS）

すぐ触れる・すぐ見せられる粒度の小型プロトタイプ群。ゲームの「1機能デモ」としてそのまま使える。

| デモ | 焦点 | 転用イメージ |
|---|---|---|
| `ecology-gradient-world` | 草が食料と隠れ場を兼ね、覚醒状態で意味が変わる | 状態依存で同一オブジェクトの意味が変わる仕組み |
| `ecology-limited-senses` | 視覚・音・遮蔽を分離した情報制約 | ステルス/索敵ゲームの知覚モデル |
| `ecology-multi-resource` | 水場を追加し空腹・渇き・危険を競合させる | 複数欲求のトレードオフAI |
| `rabbit-active-threat` | 追跡する脅威に対する退避とアンカー行動 | 捕食者からの逃走AI（p5.js, `sketch.js`で完結） |
| `rabbit-resource-relocation` | 資源転移により永続的な安全地帯を崩す | 「安全地帯に居座らせない」バランス調整の仕組み |
| `relational-ecology-lab`(=RDL Living Field) | 上記全要素＋H_vec＋因果ログを統合、共通`RelationalAgent`型で5 Rabbit+1 Predator | 既存メモ`[[rdl-living-field]]`と同一。**統合済みの完成形デモ** |
| `ecology-parameter-search` | 81条件を比較し生存・介入・脱出からパラメータ選定 | パラメータチューニング用のグリッドサーチツール |
| `warp-navigation` | 失敗をH_vecとして場に残し、非ユークリッド空間の経路をフローとして学習 | 迷路探索・道順学習AI。「傷跡が残る地形」という珍しいメカニクス |

`rdl_system/core`（`index.mjs`）は上記デモ群が共有する最小参照コア（`Boundary`/`MBNode`/`HVector`/`LeapEngine`/`MBGraph`のJS版）。`rdl_system/profiles`が係数プロファイル、`rdl_system/experiment`が係数探索・耐久指標を担当。

---

## RDL_Enterpriseとの相補関係（メモ）

- **RDL_Enterprise**にあって**rdl_village**に無いもの: `canary.py`+`shadow.py`（新戦術を試して失敗したら自動ロールバック）、`promotion_gate.py`（見習い期間を経てからの正式採用）——rdl_villageのξ探索・Leapは「跳躍する」までで、跳躍後の安全網が薄い
- **rdl_village**にあって**RDL_Enterprise**に無いもの: 実際に動く身体（知覚・移動・関係・対話）と、生存至上主義を戒める評価指針
- 将来組み合わせるなら「Enterpriseの安全装置をrdl_villageの生き物に被せる」方向が筋が良さそう（次回検討事項として保留）

---

*生成元: `https://github.com/HermannDegner/RDL_Demos`（2026-09-13時点のmainブランチをクローンして解析）*
