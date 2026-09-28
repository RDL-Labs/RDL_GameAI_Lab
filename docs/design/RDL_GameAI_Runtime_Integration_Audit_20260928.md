# Runtime全体接続の棚卸し — 2026-09-28

照合基準: `2bf7c1b`。コード・起動経路・契約の静的調査。今回World/テストは再実行していない。
これは接続状態の監査であり、個別実験の受入を取り消したり、新しい統合完了を宣言する文書ではない。

## 結論

実体は「全機能が常時動く一つのNPC」ではなく、共有部品を使う複数の有限実験経路。
分離は権限混線を防いでいるが、ある経路の完成を次の経路が自動継承するわけではない。
現在の30日版も全機能統合版ではない。次は機能追加より、既存資産の接続契約を先に揃える。

## 1. 実行経路の地図

| 経路 | 主な入口・所有者 | 接続済みの役割 | 他経路へ自動接続しない部分 |
|---|---|---|---|
| 通常bridge / 生活系 | [bridge](../../runtime/bridge.py)、life/food-rest/rescue policy | 個別opt-in生活、InteractionHistory、canonical sidecar、Sleep/fast retrieval等 | 起動flagごとに条件あり。すべて同時有効ではない |
| OBS-9 | Luanti [init](../../integrations/luanti/game/rdl_game/mods/rdl_bridge/init.lua) → multi_agent_food | 全感覚生活・Probe・通信/生活調停の有限統合 | 現在の探索fixtureとは別モード |
| L7/L10/L12 | [luanti_outcome](../../runtime/luanti_outcome.py)、[sensory_food_learning](../../runtime/sensory_food_learning.py)、[resource_use_learning](../../runtime/resource_use_learning.py) | 各用途の経験・検査・明示T1/cutover・作用 | 適用schema/目的が違う。汎用学習バスではない |
| NERV | [neural_outcome](../../runtime/neural_outcome.py) → neural_candidate → neural_t1 → neural_selection | 神経由来Bias・候補・T1-A/Bの有限受付/検査 | この系列のT1-C/行動統合を他系列の成功で代用しない |
| SOC | repeated_rescue / rescue_selection / [selection_guided_rescue](../../runtime/selection_guided_rescue.py) | 固定候補・経験保持・選別差を救助条件選択へ | NERV/canonical T1は非接続。援助要請の学習でもない |
| L13のEpisode間探索学習 | [LearnedExplorationSeries](../../runtime/learned_exploration.py) | day closeで出典付き経験・候補・独立検査・条件付き採用 | 一つのWorldで夜を過ごす現在版とはライフサイクルが違う |
| L14/L15連続資源探索 | [MultiResourceHandler](../../runtime/multi_resource_http.py)、agent派生群 | 本人観測・採取・有限harvest学習・移動地形 | 通常bridgeのInteractionHistory/Sleep endpointを継承しない |

Luanti initはfixtureごとに分岐して起動する。`multi_resource_exploration`と
`observation_v1`は同一実行モードではない。現在版はground/food/distant/skylineを使用し、
OBS-9の三感覚・Probe一式をそのまま載せたものではない。

## 2. 現在の移動系は直列ではなく枝分かれ

コードのclass継承を簡略化（Loop側にも対応する派生あり）:

```text
FiniteExploration
  └ ResourceExploration
     └ PredictableResourceAgent  ← 本人採取記録・harvest M_B・variation
        └ TerrainResourceAgent
           ├ LateralResourceAgent
           ├ TieBreakResourceAgent
           └ SteeredResourceAgent
              ├ RestResourceAgent
              │  └ ReactivatingAgent
              │     └ ReassessingAgent
              └ DayCycleAgent
                 └ CampaignAgent  ← 今回の30日版
```

根拠: [steering](../../runtime/terrain_steering.py)、[rest](../../runtime/movement_rest.py)、
[reactivation](../../runtime/rest_reactivation.py)、[reassessment](../../runtime/goal_reassessment.py)、
[day cycle](../../runtime/landmark_day_cycle.py)、[campaign](../../runtime/landmark_return_campaign.py)。

- 30日版は休憩・再活性化・目的再評価の**兄弟経路**。それらを通過しない。
- lateral、tieもsteeringへ自動合成されない。
- reversal reviewにはsteering側の明示hookがあるが、day-cycle fixtureはそのmodeをoffに制限。
- Luanti fixtureのday-cycle guardがrest/reassessment/lateral/tie/reversalの同時有効化を禁止する。
  これは単なる未使用importではなく、現行契約による分離。

## 3. Sleep / 休憩 / 夜間という名前の違い

| 処理 | 入力と起動 | 出力・権限 | 30日版との関係 |
|---|---|---|---|
| [SleepConsolidationCoordinator](../../runtime/sleep_consolidation.py) | 受理済みInteractionHistory、事前window、安全なsleep decisionと対応result | 有限relation profile/Deep shadow candidate。単独でaction/T1権限なし | 未接続 |
| [LuantiOutcomeCoordinator.consolidate](../../runtime/luanti_outcome.py) | Outcome→Biasの明示sleep_cycle | LocalBias profile/Deep候補。別の明示t1_cutover入口あり | 未接続 |
| NERV build_sleep_profile | 神経由来の保存材料 | 専用型のSleep入力材料。旧型へ黙って変換不可 | 未接続 |
| LearnedExplorationSeries.close_day | 完了Episode、形成/検査用day | l13s-episodic-sleep記録、条件付きcanonical採用 | 未接続 |
| finite rest + reactivation | 実移動負荷/反復、本人の短期記録 | wait→有限参照→一時地形寄与/再開評価 | 現在のday-cycleとは別branch |
| 今回の夜間 | 時計phase、当日非wait操作の最大16記録 | wait、独自疲労proxy回復、参照付きログ保存 | `canonical_sleep=not_connected`, `admission=none` |

したがって今回を「既存Sleepによって翌朝の学習が進む30日統合」と呼ばない。
夜間の`local_records_reviewed`はログの選出・保存であり、候補検査や採用ではない。
一方、現在版に学習が全くないわけでもない。継承元の[PredictableResourceAgent](../../runtime/multi_resource_exploration.py)
は本人の採取結果を保持し、[harvest_predictability.build_admission](../../runtime/harvest_predictability.py)で
3形成+2検査の5操作から限定的なharvest M_Bを採用し得る。これは夜間Sleepとは別の経路。
経路の存在と、特定runで実際に採用されたことも区別する。

## 4. 状態所有・寿命の不揃い

| 状態 | 現在版の所有者・寿命 | 注意点 |
|---|---|---|
| World位置/資源/在庫 | Lua World、全期間継続 | 日付で転送・資源再生成しない |
| 観測・命令・結果 | FiniteExploration、個体別run中保存 | 通常InteractionHistoryと別schema。HTTP snapshotのhistory={}はこの不在を表す |
| 探索/接近/blocked局所状態 | ResourceExplorationの判断状態 | period/phaseの移行で初期化される。失敗関係を長期採用したこととは違う |
| 帰還操作予算 | DayCycleAgent、日次 | 日次更新はSleepの効果ではない |
| 採取学習/model | PredictableResourceAgent、run継続 | 移動のblocked学習・旋回学習とは別 |
| 疲労 | movement_restとday_cycleに別実装 | 両方を載せると二重課金/回復・別閾値の危険。現状は合成していない |
| 夜間参照 | DayCycleAgent、日ごと最大16件を累積 | 検査材料への受付・翌日の選択への投影はない |
| canonical state | 各専用coordinator/sidecar | 同じM_Bという名称でもmodel_ref・目的・個体・採用権限を省略して統合不可 |

## 5. 優先して直すべき整合性

1. **説明と起動構成の対応**: 「最新版＝全部入り」の誤解を避ける。
   各runnerに何を有効化したか、外したか、state ownerを明示する。
2. **夜間とSleepの接続**: 移動ログを既存Experienceへ名前だけ変えて投入しない。
   source/result/episode単位、欠測、再送、比較目的を契約化してからadapterを作る。
3. **身体・モードの二重管理**: fatigueの単一ownerと一回課金、夜/休憩/再活性化の優先関係が必要。
   継承の付替えだけでは各`_decision`の状態更新・gateの順序が衝突する。
4. **局所予算と長期経験**: 翌日再試行できることと失敗を覚えることを分ける。
   何を日次更新し何を保持するかを一覧化し、比較対照を置く。
5. **文書の成熟度表記**: 全体設計地図にT1一式が未実装という古い記載があった。
   有限T1実装の存在と、現在探索への用途別接続の有無を分けて修正する。
6. **長時間の実行条件**: 最新30日runはexpired 86/stale 5でclean timing不合格。
   新しい統合効果を判断する前に同時刻・同条件の対照を可能にする必要がある。

分離されていること自体を不具合と断定しない。独立実験の価値は保持し、接続未検証を可視化する。

## 6. 次の統合順（提案、未実装）

- 最初に、連続Worldを本線として使う構成表を固定する。夜間待機版を対照として保存。
- 次に、同じ個体の一日の操作結果から何を既存Sleepへ渡せるか決める。
  適合しない材料は保留し、既存Sleep側のschemaや意味を黙って緩めない。
- 身体回復と記憶処理を別軸にし、疲労ownerを共有する。
- その後、夜間整理なし/ありで翌朝の候補・model参照・実行差を比較する。
  日次予算の更新条件は両群で同じにする。
- 休憩・再活性化・目的再評価は一段ずつ接続。lateral/tie/社会/NERVを同時投入しない。

今回の棚卸しではruntime/schema/係数を変更しない。全体を一度に作り直す提案でもない。
