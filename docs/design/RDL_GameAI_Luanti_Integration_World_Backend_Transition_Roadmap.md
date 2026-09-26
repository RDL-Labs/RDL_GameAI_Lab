# RDL_GameAI — Luanti Integration / World Backend Transition Roadmap

## 0. Status

**ACTIVE INFRASTRUCTURE ROADMAP**

```text
L0 Environment Boot      COMPLETE
L1 Observation Bridge    COMPLETE
L2 Action Bridge         COMPLETE
L3 Ordinary Food          COMPLETE
L4 Risky Tasty Food       COMPLETE
L5 Outcome Learning       COMPLETE
L6 Sleep / Deep Candidate COMPLETE
L7 Dynamic M_B Cycle      COMPLETE
L8 Multi-Agent Separation COMPLETE
L9 p5 Read-Only Trace     COMPLETE
RW1 Multi-Agent World     COMPLETE
RW2 Multi-Agent Food Life COMPLETE
OBS-0..6E Acquisition / Display / Delivery COMPLETE
OBS-7A..8B Comparison / Candidates / Probe COMPLETE
OBS-9 Observation v1 Integrated Acceptance COMPLETE
L10                       DEFERRED
```

Godotはdeterministic reference / regression fixtureとして保持する。Luantiを
primary rich World integration surfaceとして育てる。

観測基盤v1は[OBS-9 Evidence](../experiment-evidence/OBS_9_observation_v1_completion_evidence.md)の
実Luanti8run・864frameで固定した。観測能力の追加を止め、神経・解釈・Goal・Trajectoryの検証へ戻る。

## 1. 移行位置

```text
Current OGB / T1 work
-> Luanti L0-L2
-> learning loop on Luanti
-> Dynamic M_B on Luanti
-> M_B-informed behavior
-> neural substrate
```

World backendへの依存を限定した状態で導入し、Runtime semanticsをLuanti固有
実装へ固定しない。

## 2. 全体構成

```text
Luanti World
-> Luanti Observation Adapter
-> Finite Observation Packet
-> Python Runtime / RDL_GameAI
-> finite action request
-> Luanti Action Adapter
-> World resolution
-> next observation

Runtime state -> p5 read-only observation
```

Python RuntimeはExperience、Outcome Gradient、Local Bias、Sleep、Candidate、
T1、Dynamic M_B、将来のGoal / Trajectoryを保持する。Luantiはbody、position、
movement、collision、terrain、entities、inventory、health、damage、resource
existence、World event、action resolutionを保持する。

## 3. Observation / Action Boundary

Vision v0はLuantiの構造化情報から作る有限視覚とする。

```text
FOV finite
max distance finite
visible entities <= 16
visible regions <= 32
```

初期action vocabulary:

```text
turn
move
approach
pickup
wait
```

`action request != World consequence`を維持し、Experienceは実際のWorld result
から形成する。

## 4. 最小World

L0-L2は`npc_a`と`ordinary_food`だけを持つ。L3以降でBase、God Statue、
safe area、North Grove、tasty food、beast-like entity、risk regionを段階的に
追加する。

God Statue statementはsource付き情報でありWorld Truthではない。Luantiの
hostile flagやnode IDをNPCのdanger beliefやconceptとして直接渡さない。

## 5. Migration Phases

| Phase | 内容 | 状態 |
|---|---|---|
| L0 | repository-owned game/mod、local World、config、launch/test scripts | COMPLETE |
| L1 | self body、inventory、finite vision、recent eventsの観測bridge | COMPLETE |
| L2 | finite action request、Luanti resolution、next observation | COMPLETE |
| L3 | ordinary Foodのobserve→approach→pickup→return→deposit | COMPLETE |
| L4 | tasty Food、God Statue statement、territory relation、beast、warning/chase/attack、damage | COMPLETE |
| L5 | Luanti consequence→Experience→Outcome Gradient→Local Bias | COMPLETE |
| L6 | Luanti Experience→Sleep Profile→Deep Similarity→Candidate | COMPLETE |
| L7 | Candidate→T1-A/B/C→M_B'→cutover→REENTERED | COMPLETE |
| L8 | NPC A/BのExperience・Bias・Candidate・M_B分離 | COMPLETE |
| L9 | Luanti長期life traceのp5 read-only表示 | COMPLETE |
| RW1 | 実Luanti同一World内のNPC A/B独立観測・移動・pickup | COMPLETE |
| RW2 | 専用Food/BaseによるA/B独立pickup→return→deposit→result | COMPLETE |
| OBS-0..2 | 個体別SensorProfile、共通frame隔離、既存近景の設定化 | COMPLETE |
| OBS-3 | observer-local方向区間、粗い見え方、実voxel遮蔽による有限遠景 | COMPLETE |
| OBS-4 | 短音window、同一cell混合、壁減衰、個体gain差、overflow記録 | COMPLETE |
| OBS-4B | emit時受信、agent別buffer、半開window close、姿勢保持、遅延配送 | COMPLETE |
| OBS-4C | window跨ぎ分割、close冪等、late拒否、検出上限の欠落記録 | COMPLETE |
| OBS-5 | p5個体別・感覚別read-only表示、独立取得時刻、欠落状態 | COMPLETE |
| OBS-6 | RW2生活＋近景＋遠景＋聴覚の統合回帰 | COMPLETE |
| OBS-7A/7B | 比較適格性・隣接聴覚窓の有限候補 | COMPLETE |
| OBS-8/8B | 有限視覚Probe・継続Worldの生活優先調停 | COMPLETE |
| OBS-9 | 全感覚生活＋Probeの10条件、観測基盤v1固定 | COMPLETE |
| L10 | M_B-informed Goal / Trajectory / Action | DEFERRED |

## 6. Repository Boundary

初期prototypeは以下へ配置する。

```text
RDL_GameAI_Lab/integrations/luanti/
```

game/mod、config、scripts、tests、docsを切り出し可能な構造に保つ。Luanti本体、
world database、logsはGit管理しない。安定後に`RDL_Luanti_Workspace`へ独立
させられる。

## 7. Authority Boundary

```text
Luanti state != M_B
Luanti node/entity ID != NPC concept
Luanti hostile flag != NPC danger belief
observation packet != RIB_B by identity
Experience != E or H
Outcome Gradient != E
Local Bias != H
Candidate != adopted relation
Luanti action adapter != canonical evaluator
```

## 8. Godot Freeze Policy

Godotコードは削除しない。既知のdeterministic referenceとsemantic regressionを
保持し、新規World featureの主統合はLuantiへ移す。Godot側は必要な回帰修正を
除きfreezeする。

## 9. Deferred Scope

L0-L4ではSleep、T1、Dynamic M_B、M_B-informed actionを
Luantiへ移植しない。full sandbox gameplay、crafting、large ecology、RGB-only
perception、general navigation、neural individuality、DNA、evolution、free
explorationも対象外とする。

## 10. 次の停止境界

L9でLuanti由来の内部状態をagent単位でp5へread-only表示した。RW1では実Luanti
同一WorldにA/Bを置き、別packetとbounded visibilityを固定した。RW2では専用の
Food/Baseを保ち、両個体がpickup、return、deposit、causal result admissionまで
独立に完了する。次のL10 `M_B`-informed behaviorは保留を維持する。RW2は共有資源、
一般social AI、Sleep/learning統合を意味しない。

次の実装系列は[Observation System Integration Plan](RDL_GameAI_Observation_System_Integration_Plan.md)
に従う。OBS-0〜2では既定profileでRW2を維持し、異なる近景radiusによる個体別
観測差までを実装した。OBS-3では方向区間と粗い色だけを出す有限遠景、実voxel遮蔽、
向き変更、exact distance / World座標 / source ID非漏洩を実Luantiで固定した。OBS-4では短音window、
同一cell混合、壁減衰、個体gain差、overflowのPARTIAL記録を固定した。OBS-4Bではemit時の姿勢で
agent別bufferへ受信し、半開window、音源消失、回転、境界event、遅延配送を一周した。OBS-4Cではwindow跨ぎ音を
overlap比で分割し、duplicate closeの冪等化、closed windowへのlate event拒否、8件検出上限時のPARTIAL記録を固定した。
OBS-5ではp5へagent/channel別の独立取得時刻、姿勢参照、coverage、output limitをGET-only表示した。
OBS-6では同一Luanti World/RuntimeでRW2生活とA/B別local/distant/auditionを併走し、
両個体のpickup/deposit/result、実feature/detection、独立取得時刻、意図的拒否1件からの回復、sensory無効RW2互換を固定した。
遠景と聴覚は単独fixtureと生活統合の双方から同じsensor kernelを利用する。ここでいう互換は
有限生活Acceptanceの完了を指し、全action列の同一性までは主張しない。
OBS-6CではWorld初期配置を一度だけにし、音響voxel伝達も共通化した。聴覚windowの確定を
HTTP配送から分離し、agent別64frameの有限pending queueを介して配送見送り時も取得時刻を保持する。
壁・対象消失・2tick配送見送りを実Luanti回帰へ含めた。
OBS-6Dではlocal/distant/auditionを同じ有限queueへ置き、1配送を古い順4frame以下に制限した。
Runtimeの明示sensory receiptがacceptedの場合だけ除去し、拡張拒否・送信前失敗では保持して後続観測へ再配送する。
4tick見送り、遠景周期との重なり、拒否回復、transport retryを実Luanti回帰へ含めた。
OBS-6EではRuntime受理後の成功応答をLuanti callbackで破棄し、同じ4frameの再送を
new_frames=0で受理、ack後だけpendingから除去する実機回帰を固定した。
`23d4d2ad`を短いRW2生活試験用の観測基盤の区切りとする。
次は[解釈・利用側の設計](RDL_GameAI_Sensory_Interpretation_Use_Plan.md)へ戻り、
OBS-7Aの純粋な比較適格性診断と固定replayまでを実装した。
[OBS-7A Evidence](../experiment-evidence/OBS_7A_comparison_eligibility_evidence.md)で
合成正例と実Luanti由来の比較不能を区別する。7B/8は保留であり、
感覚間照合・行動接続・一般的な長期保持を実装済みとは扱わない。
