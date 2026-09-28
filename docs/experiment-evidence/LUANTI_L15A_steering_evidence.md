# L15A v2 — 旋回振動の抑制Evidence

状態: FINITE STEERING ACCEPTANCE COMPLETE。実Luanti4run・専用21テスト・全体回帰PASS。2026-09-28。基準 `8fa5920`。
[契約](../experiment-contracts/LUANTI_L15A_steering_contract.md)。

**Food接近中のその場の逆旋回は減った。採取効率の改善は成立していない。**
旧版v1、修正版v2とも、同じ設定の草地・自然林で各3個体×2periodを実行した。
現在の地形計算・係数は変更せず、小差での方向保持、実旋回後の一歩の再検査、旋回連鎖の打切りを追加した。

## 実Worldの主比較

[4runの受付wire・World/runtime snapshot](../../tests/fixtures/luanti_l15a_steering_replay.json.gz)。
seed `20260928`、A=steady/B=curious/C=restless。各runは2×16秒、128観測/個体。
草地は近傍2資源、自然林は8資源、各地点12単位。身体・資源はperiod間にリセットしない。
4run合計1536観測/command/result、うちv2は768。全runの個体別wireを再生し、保存stateと完全一致した。

| World / 版 | run | 接近中の実turn | 実move | 実wait | 連続逆旋回対 | 最大連続turn | 採取合計 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 草地 v1 | `l14b-99c656739cf647b9` | 126 | 26 | 0 | 104 | 48 | 12 |
| 草地 v2 | `l14b-c77b3d70c05d4fe6` | 33 | 38 | 8 | 0 | 2 | 8 |
| 自然林 v1 | `l14b-6c537b31d2924362` | 70 | 2 | 0 | 66 | 24 | 0 |
| 自然林 v2 | `l14b-a2268c92747a4e41` | 17 | 20 | 2 | 0 | 2 | 0 |

計数は `observed_material_` 理由のturn/move/waitの**実結果**。
v1の「後方Foodへ従来規則で向き直す」も含めるため、[接続v1 Evidence](LUANTI_L15A_exploration_connection_evidence.md)の地形由来だけの集計より広い。
連続逆旋回対は、隣接する実turnの符号が逆で位置が変わらなかった組。独立Episode数ではない。
他の作用を挟むと連続数を切る。歩いて同じ場所に戻るループや、目印探索の旋回をこの0件に含めない。
最大連続数は今回の記録での値であり、期限・periodをまたぐ普遍的な上限の主張ではない。

v2の個体別結果:

| World | 個体 | 実turn | 実move | 実wait | 採取 |
| --- | --- | ---: | ---: | ---: | ---: |
| 草地 | A | 5 | 4 | 3 | 0 |
| 草地 | B | 17 | 23 | 3 | 0 |
| 草地 | C | 11 | 11 | 2 | 8 |
| 自然林 | A | 2 | 1 | 1 | 0 |
| 自然林 | B | 11 | 13 | 0 | 0 |
| 自然林 | C | 4 | 6 | 1 | 0 |

草地v2ではCの採取3形成＋2独立検査から、既存T1/M_Bの採用が成立した。
さらに予測確認に基づくvariationが1回起動し、資源が残る中で探索へ移った。
Aはv1で12採取、v2で0。Cの成功でこの低下を隠さない。自然林は両版とも未採取。
旋回を減らすだけでは到達・採取が改善するとは限らず、歩行ループと接近の早期保留も残る。

## 変更の根拠と権限

旧記録では、旋回後に前方と最低方向の差が約0.0154または0.0496しかないのに、45度を戻す例があった。
一方90度の反転は約0.96の差があり、小差保持だけでは足りなかった。
旋回でray標本が変わるため、直前に選んだ方向に一歩も進まず判断が反転する。

v2は小差0.10以内なら現在方向を保つ。それ以外でも、実旋回・現在姿勢・元操作期限を確認し、
同じFoodを現在観測でき、地表/障害物が許容条件内なら一歩だけ進める。
Foodが前方射影から外れた場合は、空のFood項で現在の地表/障害物を再検査し、その記録を分けて残す。
回転指令だけや過去の地表を現在の安全情報に使わない。

継続できない逆旋回、または一歩も進まない3回目の旋回はwaitにし、現在のapproachだけをperiod内で保留する。
他のFood全体を除外せず、負のExperienceや無価値M_Bを作らない。
部分取得・閉塞・姿勢不一致・期限切れ等は単体試験で検証。実Worldの全surface取得はcompleteだった。

草地v2ではAの最初のturn応答をRuntime受付後・身体適用前に破棄した。
同じ観測の再送は同一command、`new_observations=0 / new_frames=0`を返し、該当実turnは1回。
各作用の同一command再適用、他個体への誤配送、古いcallback再注入も検査した。
遅延によるexpiredは適用しない。在庫減少と個体別実pickup・所持品が一致した。

v1の故障起動は従来どおりAの最初のpickup、v2は最初のFood接近turn。
したがって故障時刻まで同一の対照ではない。独立runのHTTP時刻・資源競合もあり、統計的な効果量は主張しない。
故障はcallbackでの模擬であり、実ネットワーク断線ではない。

## 途中の試作を除外した理由

[2試作＋各直前v1対照の4run](../../tests/fixtures/luanti_l15a_steering_drafts.json.gz)も保存した。
最終版4runとは分け、当時のcontroller本文・source hash・原snapshot hash・除外理由を保持する。
試作の同一schema名を現行v2で再解釈してPASSとはしない。

- `l14b-4d775b6221474e47`: 前方Foodが空になると接近を早く止め、全個体0採取。
  予定したAのpickup応答消失も未発火。取得済みFoodの集合と前方射影を分離して修正した。
- `l14b-b62c8b9eca374cfd`: Cが8採取したがAは0で、同じ故障条件が未発火。
  さらに停止時に全Foodを除外していた点を、現在のapproachだけの保留へ修正した。
  故障注入は今回検査するturnへ明示変更し、最終4runを改めて固定して実行した。

未発火を故障回復PASSへ読み替えず、最終runで実際の破棄・再送・一回作用を検査した。

## 検証と再実行

専用 **21テストPASS**（2.392秒）。うち19件は局所制御、2件は同梱4runの再生・結果検査。
旧実記録の45/90度反転、左右対称、旋回直後の取得不足/新障害物/段差変化、実結果欠測、
Food集合変更、失効、連続旋回予算、他Foodの保持、個体分離、再送を検査した。
pickup・learning・M_B・variationの既存経路は同一入力比較でも一致した。
共有surface sensorの19アサーションは全4実runでPASS。

全体回帰: **885件実行＝834 PASS＋51 intentional skip**。444.032秒。
ローカルログ: `integrations/luanti/output/l15a-steering-full-tests.log`。

```powershell
python -m unittest discover -s tests -p test_terrain_steering.py -v
python -m integrations.luanti.tests.run_terrain_steering --output integrations/luanti/output/l15a-steering-acceptance.json.gz
python -m unittest discover -s tests -v
```

`run_multi_resource.run(..., steering=True)` または対応するRuntimeを起動した上で
`test-learned-exploration-day.ps1 -MultiResources -MovementSteering` を使う。
旧v1とL14Bの既定動作は保存し、修正版は明示opt-inとする。

今回も1ノードのstep、離散的なyaw変更という身体実装である。
角速度・加減速・旋回しながらの歩行を実装したわけではなく、連続曲線の自然な運動は未達。
一般的な回避到達・長期効率・M_Bによる地形重み・神経/疲労/社会寄与は別の後続課題とする。
