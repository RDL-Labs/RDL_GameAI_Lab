# L15A — 同じ障害への再開検査

2026-09-28、基準 `259a26f`。[契約](../experiment-contracts/LUANTI_L15A_rest_obstacle_contract.md)。

## 結果

実Luantiの4比較run、12個体run、768通常観測。各runは16秒の同じ草地・seed・3個体steady。
Aはslot23に実nodeで移動を阻まれ、24〜27の4枠を実waitし、28で再開した。
被験体へ命令列を渡したり、結果をblockedに置換したりしていない。

| Aの条件 | 実blocked | 再開時の記録適用 | 潜在cost | 地形適用 | 選択変更 |
| --- | --- | --- | ---: | ---: | ---: |
| 存続・disabled | あり | 内部参照なし | 0 | 0 | 0 |
| 存続・enabled | あり | 適用可能 | 0.5 | 0 | 0 |
| 除去・disabled | あり | 内部参照なし | 0 | 0 | 0 |
| 除去・enabled | あり | 外観変化で対象外 | 0 | 0 | 0 |

存続では本人の同じ姿勢・同じ粗い見え方で、blocked記録が適用可能になった。
前回の一般草地比較の「方向記録なし」から、この段階は一つ進んだ。
ただし再開時は既存の `landmark_goal_budget` でwaitとなり、地形も評価対象外だった。
`current_priority_or_geometry` として介入せず、目的の予算を記憶で解除しなかった。
障害存続/除去ともenabled/disabledの各個体の全command種別・量・reasonが一致した。
全runで採取0。Aの実移動距離は10.414。脱出、探索改善、学習による行動差は確認していない。

## 除去の意味

slot27に実nodeを元のairへ復元しreadbackした。slot28の実験者専用監査では、
存続は `unsupported_or_obstructed`、除去は `supported_step` だった。
これは再開時の実前方移動ではなく、既存身体resolverによるWorld監査である。

除去により目印fanのgray近景が変わり、現在の観測キーも変化した。
enabledは `observed_context_changed` によって潜在costを0にした。
したがって「除去を知って通行可能と推論した」ではなく、「過去の失敗記録を同じ条件として適用しなかった」。
その後の実行はwaitのままなので、除去後の通過成功を実証したとも扱わない。

予備段階では低い地形rayから、除去後も観測が同じ可能性を考えた。
最初の除去runで目印fanの変化を確認し、検査側の全条件同一外観という想定を修正した。
World/Runtimeを変えず、その保存runを完全再生して採用。訂正をprovenanceに残した。

## 検証と停止境界

全4runで既存の全wire再生、最終state一致、身体・sensor・stock・有限休憩の監査を実施。
再送と他個体権限の既存guardも維持する。新しい障害条件で通信故障の注入は追加していない。
専用テストでは実記録再生、目的予算への非介入、観測変化による失効、
実記録に合成のblocked地形を組み合わせた現在方向除外を検査する。

専用4件を含む `test_rest*.py` 29テストPASS（5.683秒）、関連回帰72テストPASS（32.811秒）、各exit code 0。
関連回帰は有限休憩・反復shadow・履歴診断・steering・terrain接続。リポジトリ全体テストは未実施。

成果物: `tests/fixtures/luanti_l15a_rest_obstacle.json.gz`。
主比較の前にpersistent/enabled予備1runも実施。これを4runの独立反復として水増ししない。
Runtimeの行動規則は今回変更なし。次に必要なのは、予算を使い切った探索目的をどう再評価するかの契約であり、
記憶costの係数を増やすだけでは今回のwaitを解決しない。

```powershell
python -m integrations.luanti.tests.run_rest_obstacle --output tests/fixtures/luanti_l15a_rest_obstacle.json.gz
python -m unittest discover -s tests -p test_rest_obstacle.py
```
