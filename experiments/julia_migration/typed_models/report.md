# Julia局所モデルの型整理 — GoalState / AidPressure

状態: **FINITE REFACTOR / PARITY PASS**  
変更前: `bcbd7069caf88ff0889368b4e8e3289f8ed9ca08`  
実行コード: `c5958580c1cb89bd0f257d44413924a9d175aef3`  
[クラウド検証・測定](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38233221315)

## 変更した範囲

Juliaの援助目的・相手別方法について、文字列キーの状態辞書を`GoalState`と
`AidPressure`へ置き換えた。H・thresholdはInt、目的・model・dimensionはString、
相手別methodsは`Dict{String,GoalState}`。演算は構造体のフィールドを参照する。

既存契約の不透明なparent参照はAnyのまま、trialと各根拠の可変項目は辞書のまま残した。
完全に型固定された根拠グラフへの変更ではない。
AbstractDictとしての互換ビューで、比較用JSON・既存境界検査の出力形式を維持する。
Sleep・社会経験・身体の状態表現、行動規則・係数・丸め精度は変更していない。

各更新は従来どおりdeepcopyで所有する。コピー削減や共有化は今回行わない。
更新中の状態、以前返した状態、明示snapshot、呼出し元の入力を混線させない。

## 一致と所有の確認

- A2: **昼間4,860行、夜間終端54状態、最終18状態**がPythonと一致。
- A1: 5条件の局所H・社会期待・Sleep・翌日選択と境界拒否が一致。
- A0: 9,000step回帰PASS。
- Pythonの目的差・Sleep受理・終端検査: **13テストPASS**。
- Juliaの専用検査: **12アサーションPASS**。
  3/16/64件の全更新履歴が旧Juliaと一致。begin後に入力の入れ子データを変えても試行は不変。
  finishで元状態を変えず、後続状態の古い根拠やHを変更しても以前の状態・snapshotは不変。
  methodsの値がGoalStateであることも確認。

全リポジトリsuite・Luanti実機を再実行したものではない。ここでのM_B/Hは既存の
GameAI局所近似であり、canonical T1の採用権限や新しい推論を追加していない。

## 局所性能

固定した旧コミットからJuliaコードを抽出し、新旧を同じプロセス内の別moduleで実行。
同じworkloadを両moduleへ読み込み、各経験を順に追加して親・相手別Hを更新し、
2相手から選択する。成功・拒否・未実行を含む。履歴の照合は計時外。
新旧双方を準備実行した後、各15 sample、evals=1、上限2秒。
16件の条件では新旧の実行順を反転。Julia 1.13.1、単一thread、Ubuntu 24.04。

| 経験数 | 旧中央値 ms | 型付き中央値 ms | 旧／型付き | 旧割当 bytes | 型付き割当 bytes |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 3 | 0.265627 | 0.212307 | 1.251 | 158,888 | 141,656 |
| 16 | 3.610668 | 3.264601 | 1.106 | 2,722,304 | 2,652,816 |
| 64 | 42.471399 | 41.372645 | 1.027 | 38,944,616 | 38,423,024 |

割当bytesは処理中の累積割当量で、常駐メモリやピークRSSではない。
今回の局所処理では時間・割当とも減少したが、経験数が多いほど差は小さい。
特に64件の約3%差を一般的な速度保証としない。単一クラウドjobの有限測定である。
履歴辞書とdeepcopyを維持したままの型整理であり、A2全体やLW長期運転の高速化率ではない。

## 保存・再実行

artifact `julia-moving-social`の`typed-models/`に旧ソース、出典hash、全時間sample、
Julia検査結果を保存。`moving-social/`はA2の全比較記録。
取得ZIP SHA-256:
`296ac99d2a1545263f929a62b8fa1895fa56de58bd877c6e916837768c6df2a2`。
ローカル保存先`outputs/julia_migration/cloud-38233221315/`（Git管理外）。
GitHub artifact保持14日。再実行にはGit履歴から旧コードを抽出できるcheckoutが必要。

```sh
export RDL_LW_TIME_PROFILE=human_scale_v1 PYTHONHASHSEED=0 JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1
python -m experiments.julia_migration.moving_social.measure outputs/julia_migration/moving-social
python -m experiments.julia_migration.typed_models.measure outputs/julia_migration/typed-models
```

今回の停止点は型整理・同値性・局所測定。共有根拠やコピー削減を進める場合も、
過去snapshotの不変性と夜を越えた身体状態の比較を維持する。
