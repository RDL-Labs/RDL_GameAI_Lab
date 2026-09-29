# Nested local M_B operation and selection v1

状態: FINITE LIGHTWEIGHT IMPLEMENTED。固定された初期の局所モデル。canonical T1/M_B採用機構の置換ではない。

## モデルの入れ子

既存の食料確保／帰還goalを上位に置き、その下のsurvey・approach・work・repositionを各々の局所モデル運用単位として記録する。
最大2 family × 4種類。実際に使ったnodeを生成し、model名・問い・期待結果・出典・Hを保持する。
身体実行器、通信、全既存M_Bの自動変換は行わない。今回の初期モデルをExperience由来の採用済みモデルへ昇格させない。

| 局所モデル | 固定した問い・F=1 | 実結果F′ |
|---|---|---|
| survey | 次観測で粗い見え方が変わるか | 本人のground/landmark/Food外観の変化 |
| approach | 一歩が成立するか | 身体結果moved |
| work / food | 取得できるか | 身体結果acquired |
| work / home（有荷） | 荷下ろしできるか | 受理済みunload receipt |
| work / home（空荷） | 局所到達を確認できるか | 現在到達観測＋wait結果 |
| reposition | 位置または見え方を変えられるか | 身体movedまたは粗い観測変化 |

見え方は相対的な局所色・取得状態・目印の角域／距離帯・Food外観／粗い距離で比較。
姿勢IDが変わっただけでは変化としない。視覚変化は新しい知識や食料取得の証明ではない。
各問いは初期に与えた用途付き運用仮説。取得不足を一般的な不在判定へ変換しない。

## 差・残存・選択

直前に凍結した局所モデル・問いを使い、本人の次観測と対応する身体結果から一度評価。
対応不能、stale/expiredはdefer、H不変。成立ならE=0/H=0、不成立ならE=1/H+1（上限32）。
Hはnode別、日跨ぎ保持。別nodeの成立でまとめて消さない。直近32比較をdecision内へ保持し、全履歴はrunログで追える。
同一観測再送は既存Runtimeが同commandを返す。上位Hへ下位Hを加算しない。

候補枯渇・取得不足等の明示waitのとき、固定評価を使用:
- 現行方式 score=1。
- reposition score=現行node H/2 + 上位goal H/threshold - 1 - reposition node H/2。
- 厳密に上回る場合のみ既存有限repositionへ提案。同点は現行方式。

目的の未達は代替を促し、代替自身の未解消差は抑制する。これは有限な固定選択規則であり学習済み最適方策ではない。
候補が勝っても現在の方向別身体観測、身体対応、1日16追加操作枠を満たさなければ実行しない。
新しい移動枠を作らず、既存の探索／帰還reposition枠を共有する。
採取・接近など既存の実行判断、到着済み待機、夜間・orientationは上書きしない。
成功した位置変更後は新しい観測による通常判断へ戻る。

これにより、探索中のcompleteだが目印候補なしという待機も、位置変更の提案へ接続する。
大目標の変更・放棄、任意階層の再帰的モデル生成、canonical E/H/θの再定義、T1自動起動は未実装。
「全てのM_Bに同じ運用構造を持たせる」は設計方向であり、この初版でリポジトリ全体へ適用済みとはしない。

CLI: `--nested-model-mode enabled`、既定disabled。
[Evidence](../experiment-evidence/LW_nested_local_models_evidence.md)
