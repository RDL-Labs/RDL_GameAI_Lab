# 情報処理モードと神経科学研究への接続メモ

2026-09-28。研究対応はHYPOTHESIS / DESIGN ONLY。
GameAIの[有限再活性化](../experiment-contracts/LUANTI_L15A_rest_reactivation_contract.md)と、脳ネットワークの同一性を主張しない。
文献確認は下記の原著を対象とした限定調査で、分野全体の網羅的レビューではない。

## 原著から得られる設計上の注意

1. Spreng et al. (2010), *Default network activity, coupled with the frontoparietal control network, supports goal-directed cognition*。
   内的な自伝的計画と外的課題で、制御ネットワークとの協調が異なる結果。DMNを「何もしていない状態」と同一視しない。
   [PubMed / 原著抄録](https://pubmed.ncbi.nlm.nih.gov/20600998/)、DOI:10.1016/j.neuroimage.2010.06.016。
2. Zhou, Duncan & Mitchell (2025), *Default mode network activation at task switches reflects mental task-set structure*。
   課題切替時のCore DMN応答と、学習された課題構造の関係を調べたfMRI実験。外向き/内向きの単純二択だけでは説明しない。
   [原著](https://pmc.ncbi.nlm.nih.gov/articles/PMC12319820/)、DOI:10.1162/imag_a_00515。
3. Su et al. (2025), *Neural dynamics of spontaneous memory recall and future thinking in the continuous flow of thoughts*。
   休止中の思考を発話するfMRI課題で、思考内容の遷移とdefault/controlネットワークの応答を検討。
   GameAIの記録には内容とモードの両方の遷移を残す、という設計上の参考にする。
   [原著](https://www.nature.com/articles/s41467-025-61807-w)、[原著PDF](https://www.nature.com/articles/s41467-025-61807-w.pdf)、DOI:10.1038/s41467-025-61807-w。

以上からの**設計上の推論**は、身体の休止、入力の参照先、記憶参照、行動権限を別の軸として扱うこと。
今回のenum切替・秒数・反応係数が、これらの研究から導出されたわけではない。
fMRI上の関係を、そのまま因果スイッチや神経機構の証明として移植しない。

## 今回実装する軸

| 軸 | 観測可能な項目 | 今回の範囲 |
| --- | --- | --- |
| 身体 | moving/turning/waited、疲労proxy、休憩期限 | 既存の身体結果・有限休憩 |
| 参照先 | 現在観測、本人の有限履歴、採用済みM_B | 最大16履歴走査・3記録保持 |
| 処理phase | external_observation/internal_reactivation/resume_review | 局所情報経路の実験名 |
| 遷移 | きっかけ、取得時刻、前phase、期限、優先割込み | 休憩と再開に明示接続 |
| 出力権限 | 評価だけ、地形への一時寄与、身体command | pickup等の既存priorityを維持 |

`body_resting=true`だけでDMNと呼ばない。内部参照中も感覚取得は止めない。
M_B参照は現在の適用条件内で行う。短期episodeの再活性化を、採用済みrelationやT1更新と混同しない。
同じ脳ネットワーク名を別の機能へ使うことを避けるため、コード名にはDMNを入れない。

## 後続研究の比較候補

- 同じ身体状態・同じ入力で、履歴参照予算だけ変えたときの選択・保留・機会損失。
- 身体が動いていても内部参照できる条件、停止中でも外的課題を維持する条件。
- 内部の内容遷移と外部の新規入力のどちらが切替を誘発したか。
- 連続的な重み付け/ネットワーク協調と、今回の離散phaseの比較。
- 記憶・神経・身体・履歴による切替傾向差。現在の固定規則を生得的機能とみなさない。

これらは未実装。まず再送を含む明示的な状態遷移、出典、権限の観測可能性を固定する。
