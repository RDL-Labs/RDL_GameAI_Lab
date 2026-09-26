# RDL_GameAI — Luanti Integration / World Backend Transition Roadmap

## 0. Status

**ACTIVE INFRASTRUCTURE ROADMAP**

```text
L0 Environment Boot      COMPLETE
L1 Observation Bridge    COMPLETE
L2 Action Bridge         COMPLETE
L3+                      PLANNED
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
| L3 | ordinary Foodのobserve→approach→pickup→return→deposit | PLANNED |
| L4 | tasty Food、God Statue statement、risk region、beast、damage | PLANNED |
| L5 | Luanti consequence→Experience→Outcome Gradient→Local Bias | PLANNED |
| L6 | Luanti Experience→Sleep Profile→Deep Similarity→Candidate | PLANNED |
| L7 | Candidate→T1-A/B/C→M_B'→cutover→REENTERED | PLANNED |
| L8 | NPC A/BのExperience・Bias・Candidate・M_B分離 | PLANNED |
| L9 | Luanti長期life traceのp5 read-only表示 | PLANNED |
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

L0-L2ではRisky Tasty Food、Sleep、T1、Dynamic M_B、M_B-informed actionを
Luantiへ移植しない。full sandbox gameplay、crafting、large ecology、RGB-only
perception、general navigation、neural individuality、DNA、evolution、free
explorationも対象外とする。

## 10. 次の停止境界

L0-L2の実往復Evidenceを固定した後に停止する。次はL3 Ordinary Food Vertical
を独立契約として開始する。
