# 考察と研究メモ

仕組みの捉え方、対話から生まれた仮説、生物研究から得た着想を残す。実装を決める前の考察を、設計・実験記録とつなぐための入口。

## 文書の置き場所

| 場所 | 内容 |
| --- | --- |
| `docs/reflections` | 考察、研究メモ、未確定の仮説、今後確かめたい問い |
| `docs/design` | 設計案、責任境界、採用した仕組みと実装範囲 |
| `docs/experiment-contracts` | 実験条件と判定方法 |
| `docs/experiment-evidence` / `experiments` | 実験結果、再現材料、検証記録 |

各考察には日付と状態（検討中・保留・設計へ反映・再検討など）を添える。研究で観測されたこと、GameAIへの解釈、未解決の問いを区別する。設計へ反映した場合は対応する文書・実験へのリンクを追記し、考察だけで実装済みと扱わない。

新規ファイル名は `YYYY-MM-DD_topic.md` を目安にする。過去の考察は元の場所と履歴を保ち、この索引から参照する。実装へ進める際の基準は[共通実装方針](../design/RDL_Common_Relational_Policy.md)。

## 考察一覧

| 日付 | 話題 | 状態 |
| --- | --- | --- |
| 2026-10-30 | [目的に関係するMBの実効質量と行動の安定](2026-10-30_goal_related_mb_mass.md) | 設計仮説・実装保留 |

## 関連する既存資料

- [目的関連の観測目印](../design/LW_Goal_Related_Cues.md)：成功経路と目的の関係を目印候補へ反映する有限実装。
- [MB強化の非線形性](../design/RDL_GameAI_MB_Reinforcement_Nonlinearity.md)：経験の証拠と、選択へ作用する強さの分離。
- [合成的感情仮説](../design/RDL_GameAI_Compositional_Emotion_Hypothesis.md)：複数の目的・身体・関係から生じる状態の考察。
- [神経パラメーター設計図](../design/RDL_GameAI_神経パラメーター設計図.md)：基準特性・現在状態・学習された関係の設計案。受容体名は操作的な近似として読む。
- [ρと感度と経験](../design/RDL_GameAI_Rho_Sensitivity_Experience.md)：何を区別するか、差への反応、経験による更新。
- [持ち運べる物と目的外行動](../design/LW_Portable_Items.md)：余裕・退屈の未解決課題、過去の実験、ADHD研究のメモ。
