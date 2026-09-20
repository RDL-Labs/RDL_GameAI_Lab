# RDL GameAI Workbench (p5.js Viewer)

RDL_GameAI_Lab の状態をブラウザ上で視覚的かつ軽量に観測・検査するための p5.js ベースの Workbench（検査台）です。

## 境界契約 (Boundary Contract)
```text
GUI = Viewer Only
No Decision Authority
Raw Experience != Profile != Candidate != Canonical M_B
```
- このGUIはランタイムのコードを変更せず、推論・意思決定を行いません。
- 受け取った構造化スナップショットをそのまま射影して描画することに専念します。

## 起動方法

### 1. 静的Webサーバーでの起動（推奨）
ブラウザのローカルファイルセキュリティ（CORS）を回避するため、静的サーバーで起動します：

```bash
# gui-p5 ディレクトリで起動する場合
python -m http.server 8080 --directory gui-p5
```

ブラウザで `http://localhost:8080` を開きます。

### 2. データソース
- **Fixture (Mock JSON)**: ランタイム未起動時でも `gui-p5/fixtures/snapshot_mock.json` を読み込み、レイアウトや Sleep Window / Relation Profile の描画を確認できます。
- **Live HTTP (127.0.0.1:8765)**: `python -m runtime.bridge` が起動している場合、実ランタイムの API からスナップショットを定期取得します。

## 画面構成
1. **World View (左上)**: NPC A/B の位置、Base、Danger エリア、ベッド、エサの2D空間配置。NPCをクリックしてフォーカス切替可能。
2. **Agent Inspector (中央上)**: 選択した NPC の状態、FoodNeed メーター、Diagnostic Sidecar の保持熱 $H$。
3. **Sleep Memory & Relation Profiles (右上)**: 睡眠ウィンドウの状態（Cycle, Status, Source数）および、そこから射影された有限関係プロファイル（actor, target, context, action, outcome）。
4. **Raw Experience Timeline (下部)**: 改ざん不能な一次経験履歴（Immutable Source History）の時系列ノードレール。
