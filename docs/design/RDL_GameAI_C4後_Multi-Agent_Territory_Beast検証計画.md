# RDL_GameAI C4後 Multi-Agent / Territory Beast検証計画

**Status:** Temporary validation phase before T1-A

## Purpose

C1-C4が少数fixtureへ過適合していないことを、個体数増加と一種類の
関係的危険環境で確認する。本検証は新しいcanonical authorityを作らない。

## Scope

```text
R1 3-agent fixture
R2 5-agent fixture
R3 10-agent fixture
R4 Territory Beast World model (complete)
R5 warning / chase / attack finite interaction (complete)
R6 3-5 agents + Territory Beast evidence (complete)
R7 C1-C4 regression review (complete)
```

ownership、shared-resource semantics、navigation/landmark memory、lost-state、
conversation、hierarchy、ecology、T1 selection、`M_B'` reconstructionは対象外。

## Multi-Agent acceptance

- Experience、Sleep window/candidate、Fast sourceをagent単位で分離する。
- assessment、model_ref、review path、theta、M_delta provenanceを追跡できる。
- candidateからcanonical reviewへの自動昇格を許可しない。
- agent数だけを増やして意味論を変えない。
- read-only snapshotで状態を変えない。
- capacity到達時にsilent evictionしない。

段階ごとに `semantic cross-agent leakage = 0`、`unexpected authority
promotion = 0`、`silent mutation = 0` をEvidence化する。

## Territory Beast boundary

Worldはbeast、territory geometry、local behavior、interaction outcomeを所有する。
NPCへ`danger=true`や`beast_is_dangerous=true`を直接渡さない。

```text
outside territory -> neutral
boundary crossed   -> warning
intrusion continues -> chase
close persistent intrusion -> attack
attack succeeds -> injury / forced retreat / possible incapacitation
```

Runtimeへ渡すのはentered territory、warning observed、chased、attack attempted、
injured、escaped等のbounded eventである。危険はbeast属性ではなくagent、beast、
territory、distance、action、context、outcomeの関係として扱う。

最低3個体でwarning後退避、warning無視からchase/injury、異なる条件での観測を
分ける。ここでは危険学習のcanonical採用を行わない。

## C1-C4 invariants

```text
Experience / Sleep candidate / Fast retrieval != canonical review
BodyState / injury / local threat value != theta_eff
danger outcome != automatic M_delta
```

`M_delta`入場はexplicit review、H、theta比較、rupture boundaryだけを通る。
p5はRuntime公開値のread-only表示、Godotを使う場合はWorld interaction resolver
に限定する。

## Stop conditions

cross-agent leakage、candidate自動昇格、ExperienceからHへの直接変換、危険結果
からM_deltaへの直接遷移、thetaへのBody/Threat暗黙代入、GET mutation、silent
eviction、個体数だけによる意味論変更があればT1-Aへ進まず修正する。

R1-R7完了後はT1-A material expansionへ戻る。
