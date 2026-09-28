# L15A — 休憩中の再活性化・モード切替の検証

2026-09-28、基準 `60f2464`。[契約](../experiment-contracts/LUANTI_L15A_rest_reactivation_contract.md)。
研究への将来接続は[モード研究ノート](../design/RDL_GameAI_Cognitive_Mode_Research_Map.md)で区別した。
現在の実装は有限情報経路の切替であり、DMNや神経ネットワークの再現ではない。

## 実Worldの結果

同じ草地配置・seed・3個体steady・疲労休憩・2期間で、再活性化disabled/enabledを実行。
各1run、実取得時刻に揺れあり。別配置のenabled故障runを追加し、計3run・9個体run・1152観測。

| 条件 | 記憶取得回数 | 保持した記録延べ数 | 再開検査 | 地形へ寄与 | 再活性化による選択差 | 採取 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| disabled / 主比較 | 0 | 0 | 0 | 0 | 0 | 0 |
| enabled / 主比較 | 13 | 36 | 13 | 0 | 0 | 0 |
| enabled / 別control＋故障 | 17 | 51 | 17 | 0 | 0 | 12 |

主比較の実移動距離は両方とも合計71.557。効率改善・採取改善を示す結果ではない。
故障runは2資源地点の別配置なので、12採取を再活性化の成果へ帰属しない。
主比較enabledはexternal_observation 319判断、internal_reactivation 52判断、resume_review 13判断。
別control＋故障はそれぞれ299/68/17判断。各個体の通常取得128件は維持された。

主比較の再開13件のうち、10件は現在の優先条件または地形が寄与対象外、3件は適用できる方向記録なし。
記録の外観条件・姿勢対応が一致せず、過去の移動成功を別位置の進行方向へ一般化しなかった。
新しい行動を出すための閾値変更、World座標の追加、姿勢対応の補完は行っていない。

## M_Bとの境界

主比較では採用済みM_Bなし。故障runのCは既存経路で採取relationを学習したが、
内部参照の評価時にはno_adopted_modelまたはmodel_invalidatedとなり、scope内knownの実例はなかった。
scope内known・遠方でunknown・失効・model変更は、既存採用経路から実際にM_Bを作るPython試験で確認した。
採取モデルから経路の誘引を作る処理はない。単発blocked記録の+0.5は一時的な固定appraisal規則で、新しい学習則ではない。

## 実装・検証の範囲

- 身体の休止状態と処理phaseを別欄で保存。内部参照中も通常観測を受ける。
- 休憩開始時の最大16履歴を走査し、本人の受信済み結果を最大3件保持。model_refを凍結。
- 再開時に期限・姿勢・現在観測・model参照を再検査。priority割込みではcacheを破棄。
- 同じ姿勢・見え方でのblocked moveが一時costを作り、合成地形でmove→turnへ変わる正例を検証。
- 欠測、観測による方向除外、他個体、未来の結果、再送、競合、予算、入力/出力分離を検査。

専用13テストPASS（3.537秒）、既存関連72テストPASS（19.878秒）、各exit code 0。
関連回帰は有限休憩・反復shadow・履歴診断・steering・terrain接続。
3runの全受理wireと最終stateを完全再生し、寄与0の各runを旧休憩Runtimeへも再生した。
全observe応答・学習・採用model・sensory store・身体結果が一致した。
リポジトリ全体テストは今回未実施。

初回enabled実行後、観測キー中のtupleがJSONでlistになるため、Python stateとの同一性検査が失敗した。
キーをJSON形式へ正規化して修正し、その実機runの全wire・保存stateが修正版と一致することを確認して採用した。
行動規則や実機結果の書換えはしていない。修正履歴は成果物provenanceにも保持する。

成果物: `tests/fixtures/luanti_l15a_rest_reactivation.json.gz`。

```powershell
python -m integrations.luanti.tests.run_rest_reactivation --output tests/fixtures/luanti_l15a_rest_reactivation.json.gz
python -m unittest discover -s tests -p test_rest_reactivation.py
```

## 現在地

「外部観測→内部の有限参照→再開時の検査」のモード切替は実Worldで成立。
この条件で経験参照が実World行動を変えること、探索の改善、神経科学的妥当性は未検証/未成立。
次の課題は適用可能な本人記録が成立する取得条件と関係モデルであり、記憶を使うために不足した対応を補わない。
