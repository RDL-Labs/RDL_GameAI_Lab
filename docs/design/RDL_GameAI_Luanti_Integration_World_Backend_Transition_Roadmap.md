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
OBS-0..2 Observation Base PLANNED
OBS-3..6 Extended Senses  PLANNED
L10                       DEFERRED
```

Godotはdeterministic reference / regression fixtureとして保持する。Luantiを
primary rich World integration surfaceとして育てる。

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
| OBS-0..2 | 個体別SensorProfile、共通frame隔離、既存近景の設定化 | PLANNED |
| OBS-3..6 | 遠景、最小聴覚、p5表示、統合回帰 | PLANNED |
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
に従う。初回はOBS-0〜2だけを実装し、既定profileでRW2を維持しつつ、異なる
近景radiusで個体別観測差が生じるところで停止する。遠景、聴覚、p5表示は別作業、
感覚間照合と行動接続はさらに後続とする。
