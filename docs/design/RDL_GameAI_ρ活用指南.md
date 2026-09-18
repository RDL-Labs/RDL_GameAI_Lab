# RDL GameAI ρ活用指南

**文書種別:** Design Guide  
**状態:** current guidance / implementation deferred  
**起点:** `RDL_GameAI_ρ活用設計_v0.1` を現行GameAI Lab境界へ咀嚼  
**対象:** Base–Food回帰実験、Rest / Sleep以降のbounded observation設計

## 1. この指南の役割

GameAIにおける `ρ` は、有限なBoundary `B` の内部で、NPCがWorldの関係差をどこまで細かく区別できる観測として受け取るかを調整する概念である。

```text
Godot World truth
-> Boundary B
-> Observation Resolution Adapter (ρ)
-> bounded observation
-> RIB_B
-> NPC-side interpretation
-> Goal / Trajectory / Interrupt
```

`ρ` は行動命令でも、知能値でも、正確性でも、Truth量でもない。高い `ρ` は利用可能な区別を増やし得るが、良い解釈や正しい行動を保証しない。

## 2. 実装上の配置

最初の実装では、`ρ` をRuntime action policyやcanonical modelへ埋め込まない。Godotが所有する精密World状態を有限観測へ変換するObservation Adapterの設定として扱う。

```text
MockStateProvider / future World Provider
  owns exact world state

ObservationResolutionProfile
  owns finite LOW / MID / HIGH projection rules

Runtime policy
  receives only the projected bounded observation
```

候補となる責務は次のとおり。

- NPC別・領域別の有限profileを選ぶ。
- 同一World状態からprofileに応じた有限schemaを生成する。
- `profile_id`、domain、level、rule versionをprovenanceへ残す。
- exact world valueを観測packetへ自動的に漏らさない。
- profile変更をBoundary変更やcanonical model変更として扱わない。

## 3. 領域別に分ける

`ρ` を全能力の単一scalarへ潰さない。

```text
ρ_food
ρ_rest
ρ_threat
ρ_novelty
ρ_space
ρ_time
```

あるNPCがFood差を細かく区別できても、ThreatやSocialの差を同じ解像度で扱えるとは限らない。領域間の相関は、観測で必要になった時に別途検証する。

## 4. Base–Foodでの回帰実験

Base–Food参照loopは完成済みであり、ρそのものを検証する安全な回帰実験場として使える。最初は行動差ではなく、同じWorldから異なる有限観測が生成されることだけをAcceptanceにする。

```text
same world state
+ same Boundary B
+ different ρ_food
-> different bounded observations
```

最小の投影例:

| Level | NPCへ渡す区別 |
|---|---|
| LOW | `enough / needs_supply` |
| MID | `enough / low / critical / empty` |
| HIGH | band + `decreasing / stable` + known-site condition |

HIGHでも、初期実験では正確な在庫量を渡さない。高解像度とWorld truthの直接開示は別の設計判断である。

### Base–Food Acceptance

1. World stateとBoundaryを固定する。
2. `ρ_food` だけを変える。
3. observation packetの有限差を確認する。
4. Godot world、既存action policy、canonical snapshot、Hが変わらないことを確認する。
5. profile provenanceから投影規則へ追跡できることを確認する。

Goal形成タイミングや行動差は、この観測差が固定された後の別Acceptanceとする。

## 5. Rest / Sleepでの本適用

次の生活機能では、Food固有のstock、carry、depositをコピーせず、Observation Adapter構造だけを再利用する。

```text
ρ_rest LOW
-> tired / not_tired

ρ_rest MID
-> rested / tiring / tired / exhausted

ρ_rest HIGH
-> fatigue band
 + worsening / stable
 + reachable rest context
 + safety distinction
 + completion margin
```

次を同一視しない。

```text
ρ_rest != RestNeed
ρ_rest != sleep pressure
ρ_rest != salience
ρ_rest != H
```

Sleep生活行動とSleep Consolidationも引き続き別系統とする。

## 6. Threat / Noveltyへの接続

現在のinterrupt policyはfinite candidateの`salience`を比較する。`ρ` はそのsalienceを直接増減させず、candidateを形成する前段の観測detailへ作用する。

```text
World stimulus
-> ρ-dependent distinction
-> bounded Threat / Novelty observation
-> NPC-side interpretation
-> candidate salience
-> continue / hold / inspect / divert
```

例:

```text
ρ_threat LOW  -> danger / not-danger
ρ_threat HIGH -> distance-band + approaching/leaving + direction

ρ_novelty LOW  -> known / unknown
ρ_novelty HIGH -> shape/motion/location/context differences
```

`novelty salience != ρ_novelty`、`interrupt threshold != ρ` を不変条件とする。

## 7. M_B / RIB_B / Hとの境界

- `ρ` profile moduleやstoreそのものは `M_B` ではない。
- ρ-dependent observationから採用された現在関係は、宣言されたBoundaryで `M_B` 構成要素になり得る。
- `RIB_B = function(B, ρ)` をRDL一般定義として固定しない。
- 高ρで差が増えても、未解消残差やHが自動的に増減するとは限らない。
- `ρ -> infinity` を完全観測や `ξ -> 0` として扱わない。

FoodNeed shadowを含む現行canonical系は、ρの初期実験では変更しない。

## 8. 学習・DNA・Neuralは後段

将来、経験によって以前は同一視していた状態差を区別できるようになる可能性はある。ただし、初期実装で `ρ` の変化を学習の一般定義にしない。

```text
fixed finite profile
-> observation difference evidence
-> behavior experiment
-> only then plasticity candidate
```

以下は設計候補として保留する。

- Experienceによるdomain別ρの変化
- DNAによる初期傾向や可塑性
- fatigue / attention / neural stateによる一時変動
- 世代継承や社会学習

現在のretry profile、Threat profile、Novelty response、extreme tuning presetを遡ってρ由来と呼ばない。

## 9. 導入順

1. `ObservationResolutionProfile` の有限契約を作る。
2. `LOW / MID / HIGH` とrule versionを固定する。
3. Base–Foodで観測packet差だけを証明する。
4. default action/canonical非介入を証明する。
5. Rest / Sleepへ同じAdapter構造を適用する。
6. 必要になった領域だけGoal timingやinterrupt差を検証する。
7. 学習によるprofile変化は独立計画として判断する。

## 10. 禁止する近道

- 高ρを「賢い」「優秀」と表示しない。
- exact world valueをHIGHへ無条件に渡さない。
- ρをsalience、Need、Trajectory persistence、interrupt thresholdへ直結しない。
- ρ profileをcanonical `M_B`へ自動admitしない。
- Boundary変更とρ変更を同じ実験で同時に行わない。
- 行動差だけを見て観測差のprovenanceを省略しない。
- LOW / MID / HIGHを生物学的な固定分類として扱わない。

## 11. 判断基準

ρを導入する価値があるのは、次の問いを明示できる場合である。

> 同じ有限World条件について、NPCが区別可能な関係差を変えると、観測・解釈・行動のどこが変わるか。

この問いがない場合、単なる情報量増加やparameter追加としてρを導入しない。

## 12. 一文圧縮

> GameAIにおけるρは、Godot Worldの精密状態を直接NPCへ渡すためではなく、有限なBoundary内でどの関係差まで区別可能なbounded observationとして投影するかを制御する横断的なObservation Adapter概念である。
