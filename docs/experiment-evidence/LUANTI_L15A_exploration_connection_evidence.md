# L15A — 現行探索への接続Evidence

状態: FINITE CONNECTION ACCEPTANCE COMPLETE。実Luanti接続・専用18テスト・全体回帰PASS。2026-09-28。基準 `7ca3018`。
[契約](../experiment-contracts/LUANTI_L15A_exploration_connection_contract.md)。

## 成立した循環

既存L14Bの探索runで、本人のFood観測＋新しい有限surface ray取得からL15Aを計算し、
既存command/controllerを通して一回の旋回または移動を実行し、次slotの再観測へ戻った。
独立したデモ身体ではなく、共有資源を探索する既存の3個体に明示opt-inで接続した。

目印探索・pickup・採取経験の形成/検査/T1採用は既存経路を使う。
現在のM_Bを地形の重みへ投影したわけではない。未知・疲労・社会関係も未接続。
Phase 1の係数・入力schema・純粋計算は変更していない。

## 実Luantiの記録

[受付wireとWorld/runtime snapshotの再生記録](../../tests/fixtures/luanti_l15a_connection_replay.json.gz)。
実行前に固定した3runをすべて保存した。後から成功runだけを選択していない。
各runは2period×16秒、3個体×128観測/command/result。計1152観測、うち地形接続modeは768観測。
各接続観測で地表5ray＋障害物8rayを同じ観測slotに取得し、個体・時刻・姿勢をbindingした。

| run | terrain | A取得 | B取得 | C取得 | 合計 | 残量 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `l14b-6bd217f0dd13495d` meadow・近傍2資源・faults | on | 12 | 0 | 0 | 12 | 12 |
| `l14b-c6118ab9452849b1` woodland・8資源 | on | 0 | 0 | 0 | 0 | 96 |
| `l14b-d9680ad275624c15` meadow・近傍2資源・faults | off | 10 | 7 | 7 | 24 | 0 |

各資源の初期量12、seed `20260928`、profileはA=steady/B=curious/C=restless。
on/offのmeadowは同じ設定から開始する独立runで、HTTPタイミングや共有資源への競合まで同一には固定していない。
この一組から統計的な性能差や一般的な個体傾向を主張しない。

地形由来のcommandに限定すると、結果は次のとおり。

| run | 個体 | 実turn | 実move | 実wait |
| --- | --- | ---: | ---: | ---: |
| meadow on | A | 24 | 1 | 0 |
| meadow on | B | 36 | 20 | 0 |
| meadow on | C | 14 | 5 | 0 |
| woodland on | A | 12 | 0 | 0 |
| woodland on | B | 24 | 0 | 0 |
| woodland on | C | 22 | 2 | 0 |

地形由来合計132turn＋28move。これ以外に既存の目印探索等の移動がある。
近傍資源onではAが実pickupを12回行い、既存の3形成＋2独立検査からM_B採用が成立した。
枯渇後には従来の予測差が記録され、モデル利用のinvalidatedも起きている。
「地形計算を呼べた」だけでなく、既存採取・結果報告・学習の循環が継続した範囲である。

## 権限と故障回復

on/off両meadowの既存故障注入を実行した。
Runtime成功応答消失後の同一観測再送、旧callback再注入、意図的な受渡し遅延を含み、
新規保存なしの再受付、同操作の再実行なし、他個体controllerでの拒否を検査した。
Aには期限超過の結果が各2件あり、失効した応答を身体へ適用していない。
これはcallbackでの故障注入であり、実ネットワーク切断ではない。

全runで在庫減少と実pickupが一致し、所持品・受付済み結果・操作IDが個体別に一致した。
全受付wireを同じRuntimeへ再生し、command/decision/modelを含むsnapshotが一致した。
原snapshotのSHA-256、実行基準commit、関係ソースのSHA-256を再生記録に保持している。
archive時に原ファイルと保存内容、ソースhashの一致を検査した。

## センサーと判断の検査範囲

実Luanti内でsensorの代替readを使った19アサーションもPASS。
平地、空、未ロード、左右の障害物、全方向閉塞、最大547read、出典を検査した。
これは合成地形のsensor単体検査。自然Worldの効果比較や独立した左右配置試験とは分ける。

実World記録の地形channel coverageは768観測すべてcompleteだった。
partial/unavailableの非補完、閉塞wait、左右配置に応じた反対旋回、対称同点waitはPython/上記sensor試験で検証した。
実Worldでこれら全状態を発生させたとは主張しない。

Python専用18テストPASS（1.458秒）。
現行の学習・variation・Foodなし目印探索を同一入力で比較し、command/result/learning/M_Bが一致する。
地形適用時の移動差、教示外/後方Foodの扱い、再送競合・個体混線・入力不正・部分公開なしも検査した。
うち2テストは同梱実World記録の受付再生と有限結果の固定である。

全体回帰: **864件実行＝813 PASS＋51 intentional skip**。534.628秒。
ローカルログは `integrations/luanti/output/l15a-connection-tests.log` と `l15a-connection-full-tests.log`。

```powershell
python -m unittest discover -s tests -p test_terrain_resource_exploration.py -v
python -m integrations.luanti.tests.run_terrain_resource --output integrations/luanti/output/l15a-connection-matrix.json.gz
python -m unittest discover -s tests -v
```

## 残った課題

**今回の結果は移動性能の改善を示していない。** 近傍資源ではonの合計12取得に対しoffは24取得。
自然林の2periodは全個体0取得だった。

同じ位置で連続する地形由来の逆向きturn対も残る。
meadow Bで14対、woodland Bで23対・Cで20対を観測した。
これは隣接する操作対の数で、独立した失敗Episode数ではない。
旋回によって身体相対rayと合成面が変わり、次の最低方向が反転しうる。今回のtie処理だけでは振動を抑えられていない。
有限接近予算24操作は継承したが、一般的な回避成功・経路到達・探索効率を保証しない。

したがって新modeはopt-inの接続基準として保存する。既存L14Bの既定動作を置換しない。
次の移動改善は、局所慣性・判断差の許容幅・停滞検出などを別に固定し、
同じ観測/配置の対照で、固定右折や隠れたWorld情報を使わず改善できるか検査する。
拡張計画の身体状態・社会relation・未知価値の実装へ同時に広げない。
