# RDL GameAI Workbench (p5.js Viewer)

RDL_GameAI_Lab の状態をブラウザ上で視覚的に観測・検査する I6 Viewer です。Runtime の意思決定や RDL 状態を計算・変更しません。

## Boundary Contract

```text
GUI = Viewer Only
No Decision Authority
Raw Experience != RelationProfile != CandidateRelation != Canonical M_B
Missing snapshot != inferred state
```

Live mode では Runtime が公開していない値を GUI 側で補完しません。特に現行 Runtime bridge は world position、Sleep S1 window、S2 Profile、S3 Deep Similarity を GET endpoint として公開していないため、それらは `NOT EXPOSED` と表示します。

## 起動

Live Runtime と同時に使う場合は同梱の read-only proxy を使います。

```bash
python -m runtime.bridge
python gui-p5/serve.py
```

ブラウザで `http://127.0.0.1:8080` を開きます。`serve.py` は静的 GUI を配信し、`GET /runtime/*` だけを `127.0.0.1:8765` へ転送します。POST / PUT / PATCH / DELETE は 405 で拒否します。

Fixtureだけを見る場合も `python gui-p5/serve.py` で起動できます。

## 現在の画面

- **World View**: Fixture の有限空間投影。Liveで位置が未公開なら捏造せず未接続表示。
- **Agent / Source Inspector**: Agent表示に加え、Live GET endpointごとの取得可否を表示。
- **Sleep Memory**: S1 finite window と S2 Relation Profile。Profileカードを選択すると relation の predicate/object/polarity/strength を表示。
- **Provenance Lineage**: Raw Experience → S1 Window → S2 Profile → S3 Similarity → Cluster/Candidate を別オブジェクトとして表示。未実装段階は `CONTRACT ONLY` / `NONE PRESENT`。
- **Raw Experience Timeline**: Experienceをクリックして、S1/S2へsource chainを追跡。

## Live GET

Viewer は現行 bridge から `/health`, `/v1/experience-snapshot`, `/v1/canonical-snapshot`, `/v1/rescue-snapshot`, `/v1/rest-snapshot`, `/v1/life-snapshot`, `/v1/food-mb-shadow` を read-only 取得します。無効化されたopt-in policyの404は正常な「未公開/未有効」状態として表示します。

## S3以降

`deep_similarity` snapshot が将来提供された場合に Lineage View へ差し込める構造にしてあります。GUI側で Similarity、Cluster、Candidate を生成することはありません。