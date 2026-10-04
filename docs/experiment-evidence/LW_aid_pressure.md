# 満たされない援助要求のE/H

2026-10-04。基準888cedb。既存social_camp、3個体3日、Sleep採用ありを固定し要求Hのみ比較。

| 要求H | 要求 | 明示拒否 | 実譲渡 | 食事 |
| --- | ---: | ---: | ---: | ---: |
| disabled | 31 | 27 | 2 | 10 |
| enabled | 5 | 2 | 3 | 11 |

enabledの1日目はB→B→C→C。Cへの最初の切替時にはSleepモデルはまだ空で、
Bへの要求方法H=2、援助取得目的H=2、θ=2になっている。3日目はCへ1要求。
効率改善の一般則ではなく、この初期配置と固定応答傾向での有限結果。
両条件の操作別食料保存、身体操作非重複PASS。

## 契約

既存 `runtime.goal_difference` のbegin/finishを使用するGameAI-localな試行比較。
F=期限内援助受領1、F'=givenなら1、refuse/期限内応答未観測なら0。
後二者は別evidenceを維持し、意図的拒絶へ統合しない。未実行要求は比較保留でHを増やさない。

目的「援助を得る」と方法「この相手へ要求する」の双方へEを一度加算。
成功時は当該方法と援助取得目的のHを0へ戻す。別相手への方法Hを消さない。
日替わり・Sleep・待機・再送では解消しない。最大192件の受理済み要求記録を参照する。
既存goal_differenceと同じ局所Hで、canonical T1/Coreへの自動更新ではない。

方法Hがθ=2に達した場合、現在の援助期待scoreからmin(2,H/θ)を減点する。
親の援助取得目的Hもθに達したら、既存活動へ戻る候補score=0.25を追加する。
見える他者の要求候補を削除せず、新しい移動権限や観測していない相手を追加しない。
既存活動とはその判断で既存探索/帰還等が提案した操作であり、待機もあり得る。
Sleepは別途、本人の履歴から関係期待を更新する。同日Hの処理をSleepへ先送りしない。

`social_pressure=False` で旧比較を再現。旧social_life_comparisonはこの条件を明示固定し、
以前の保存Evidenceを上書きしない。統合モードの新規実行では要求Hが既定で有効。

再実行: `python -m integrations.lightweight.aid_pressure_comparison`
保存: `tests/fixtures/aid_pressure/`。専用4件を含む関連38テストPASS。
全体suite・Luanti実機・長期運転は未実施。
