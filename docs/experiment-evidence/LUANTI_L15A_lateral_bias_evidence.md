# L15A — 左右バイアス単独実験Evidence

状態: 実Luanti主比較6run＋追加診断2run、専用22テストPASS。全体回帰で既存HTTP試験1件に接続中断、当該モジュール再試験26件PASS。
2026-09-28。基準 `f63d6a7`。[契約](../experiment-contracts/LUANTI_L15A_lateral_bias_contract.md)。

**同じ観測地形に対する弱い左右寄与で、一度の旋回選択とその後の終点が変わった。旋回振動と採取効率は改善していない。**
[短期方向維持v2](LUANTI_L15A_steering_evidence.md)とは別modeであり、その効果を左右biasの効果へ含めない。
今回の親制御は方向保持なしの探索接続v1で、v2の旋回打切り・継続stepも使わない。

## 単独の追加内容

個体のconfigureでleft / neutral / rightを明示し、run中固定する。
左右鏡像の組が元の最低方向を含み、physical・food・obstacle・totalの左右差が**それぞれ0.10以内**の場合だけ、
好む側へ−0.05、反対側へ＋0.05を加える。neutralは0。
正面が元の最低方向なら変更しない。欠測・除外方向はnullのまま。

各decisionは元の観測地形、適格性と成分差、左右寄与、合成後値、選択を別保存する。
短期方向維持はdisabled、その寄与はnull。直前の実旋回yawは診断に残すが選択へ使わない。
初期設定の弱い傾向を導入したもので、学習された好み・人間一般の利き側・personality全体の実装ではない。

## 主比較6run: 行動差なし

[主比較の全受付wire・World/runtime snapshot](../../tests/fixtures/luanti_l15a_lateral_replay.json.gz)。
草地2資源・自然林8資源、各12単位、3個体×2period、seed20260928。
A=steady/B=curious/C=restlessは全run固定。次の左右設定だけを変えた。
身体・資源はperiod間で継続する。故障注入はoff。

| World | 左右設定 A/B/C | run | 実turn | 実move | 連続逆旋回対 | biasによる選択変更 | 採取 |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| 草地 | neutral/neutral/neutral | `l14b-bd41f70466634ce6` | 202 | 39 | 176 | 0 | 0 |
| 草地 | left/neutral/right | `l14b-c7007a5dc7cb41a2` | 202 | 39 | 176 | 0 | 0 |
| 草地 | right/neutral/left | `l14b-d383a23929234b11` | 202 | 39 | 176 | 0 | 0 |
| 自然林 | neutral/neutral/neutral | `l14b-f6b5b80aaa3e4972` | 70 | 2 | 66 | 0 | 0 |
| 自然林 | left/neutral/right | `l14b-1021e45aaf0b40a6` | 70 | 2 | 66 | 0 | 0 |
| 自然林 | right/neutral/left | `l14b-6d82f35f801a4b40` | 70 | 2 | 66 | 0 | 0 |

turn/moveはFood接近の `observed_material_` 理由の**実結果**。同範囲のwaitは全run0。
逆旋回対は、移動等を挟まない隣接実turnが同じ位置で逆符号になった組。
独立Episode数ではなく、全ての探索旋回・歩いて戻るループを数えた指標でもない。

A/Cには適格な左右組が一つもなく、biasの数値寄与自体が0だった。
草地Bの1観測だけが適格だったが、Bは全主比較でneutral。
このため、同じWorld内の3条件で各個体の終点・移動指標にも差が出なかった。
「bias設定が違えば必ず動きが違う」という実装にはしていない。

## 主比較後の追加診断: Bにも左右設定を与えた

主比較を保存した後、幅・係数を変えず、草地の全員left / 全員rightを追加した。
[追加2runの再生記録](../../tests/fixtures/luanti_l15a_lateral_followup.json.gz)は、主比較後の探索的診断と明記した別provenance。
最初から予定した8runと扱わず、無効だった主比較を置き換えない。

| 条件 | run | Bのbias寄与が非0 | Bの選択変更 | Bの実turn/move | Bの逆旋回対 | Bの訪問セル | Bの終点(x,z) | 全体採取 |
| --- | --- | ---: | ---: | --- | ---: | ---: | --- | ---: |
| 全員left | `l14b-3dbaddf80fee42e3` | 1 | 0 | 78 / 18 | 62 | 10 | (7.2933, −4.1885) | 0 |
| 全員right | `l14b-2d3f3cf640ab47bd` | 1 | 1 | 78 / 18 | 63 | 9 | (1.5102, 0.9479) | 0 |

訪問セルはWorld監査座標を2ノード四方に区切った補助計数。制御へ返していない。
A/Cは追加診断でも寄与0で、主比較と同じ指標・終点だった。
Bの全行動を含む移動距離は33.243→35.828だが、どちらも未採取なので効率改善とは解釈しない。

### 選択が変わった実観測

Bのsample_seq65で、両runの観測地形の各方向成分が一致していることを再生試験で検査した。
該当する左右45度の成分差はphysical=0、obstacle=0、food=total=約0.0525773。

| 方向 | 元のtotal | right寄与 | right合成後 |
| --- | ---: | ---: | ---: |
| −45度 | 11.0605859 | +0.05 | 11.1105859 |
| +45度 | 11.1131632 | −0.05 | 11.0631632 |

neutral/leftなら左45度、rightなら右45度を選んだ。
right runでは、実身体結果が `turned / yaw=44.999963686°`。指令生成だけで終了していない。
取得時刻・姿勢・本人のoperation IDを保った実行であり、作用再適用は1回へ制限された。
以後の観測と軌跡が分かれ、終点差が残った。

これは左右完全対称の実Worldではなく、**左右差が小さい実観測**の正例である。
完全対称入力と鏡像反転は別の合成Python試験で確認した。
単発の分岐から長期の探索域分担・集団性能・生物特性を主張しない。

## 権限・保存・検証

8run合計3072観測/command/result、各個体128件。全受付wireからcommand・decision・保存stateが再現した。
各runのsurface sensor19アサーション、ground5ray/obstacle8rayの監査、個体混線拒否、同操作再適用拒否が通った。
資源・所持品・World結果が一致し、今回の全runは採取0のまま保存した。
今回の8runでは故障注入off。遅延・応答消失回復を追加で実行したとは主張しない。

原snapshotのSHA-256と保存内容、実行時の関係ソースSHA-256をarchive時に照合した。
主比較後に追加した全員left/rightはharnessの設定選択肢であり、Runtimeの式・係数は変更していない。
`decision_links` は各実観測から次の実観測へ結び、末尾はnullとして保存する。
Worldの正確な座標・軌跡・残量は監査側のみ。個体の判断入力へ戻さない。

専用 **22テストPASS**。18件の局所試験＋4件の実記録検査。
対称入力、near幅の境界、成分の相殺、強いFood/obstacle/physical差、欠測・閉塞、左右鏡像、
ID/配列順の非依存、設定の凍結と拒否時非公開、再送、個体分離、hysteresisとの同時指定拒否を検査した。
neutralで旧実World記録のcommand・learning・M_Bが一致することも確認した。
既存採取・variation経路の同一入力比較はPASSだが、今回の新しい実World runで学習が起きたわけではない。

全体回帰は **907件実行 = 855 PASS + 51 intentional skip + 1 ERROR**、544.702秒。
唯一のERRORは既存 `test_resource_use_learning.ResourceUseTests.test_http_opt_in_scope_and_isolation`。
無効なendpointへの初回POSTで404を検査する箇所が、`ConnectionAbortedError / WinError 10053`となった。
該当HTTP実装と試験ファイルは今回変更していない。

コード変更なしで当該モジュールを単独再実行し、**26件PASS**、1.342秒。
同じ経路の404・200・422・snapshot取得を確認した。接続中断の根本原因は断定していない。
全907件を再実行して一括PASSを確認した結果ではなく、初回エラーと対象範囲の再試験を分けて記録する。
ログは `integrations/luanti/output/l15a-lateral-full-tests.log` と `l15a-lateral-http-recheck.log`（実行環境の出力、Git管理外）。

```powershell
python -m unittest discover -s tests -p test_terrain_lateral_bias.py -v
python -m integrations.luanti.tests.run_terrain_lateral --output integrations/luanti/output/l15a-lateral-matrix.json.gz
python -m integrations.luanti.tests.run_terrain_lateral --followup --output integrations/luanti/output/l15a-lateral-followup.json.gz
python -m unittest discover -s tests -v
python -m unittest discover -s tests -p test_resource_use_learning.py -v
```

個別起動は `run_multi_resource.run(..., lateral="mixed")` 等、または対応するRuntimeと
`test-learned-exploration-day.ps1 -MultiResources -LateralAssignment mixed`。
`neutral / mixed / swapped / left / right` を指定できる。offでは従来modeを維持する。
`MovementSteering` と同時指定しない。

## 到達点

有限な近同点への個体別寄与と、実Worldでの1回の選択分岐を確認した。
一方、主比較では差がなく、追加診断でも逆旋回は1対増え、採取は0だった。
**固定左右傾向は、短期方向維持の代替として検証されたわけではない。**
今回の単独実験で止め、両者の合成・連続運動・M_Bによる移動地形更新は別に扱う。
