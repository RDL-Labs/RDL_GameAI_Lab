# 四層身体・生活・Sleep統合 v1

2026-10-04。基準9e7a8bb。軽量Worldのopt-in統合。

既存`timed_harvest`へ`--body-mode enabled`を追加。
探索・帰還・局所荷下ろし・継続選択・危険観測・夜間Sleepを同じrunで運転する。
body disabled経路は従来の移動/WorkScheduler契約を維持する。

## 操作時間と身体

BodySchedulerで歩行・climb・旋回・採取・waitをすべて1秒の操作として予約。
World/危険物体/通常観測は250ms刻みで継続し、完了前に身体操作は適用しない。
完了時の形状・資源・姿勢・期限を再検査する。busy中と完了同枠の観測は
ログに残し、新commandを発行しない。最終1秒には新規操作を始めず全受付を閉じる。
phaseをまたぐ操作はexpiredで作用せず、身体消費も回復も行わない。

body stateは日境界で初期化しない。wait完了の1秒だけ回復する。
Sleepのrest creditも、そのwaitの取得→実行完了の実測1秒を使う。
完了後から次観測までの空白時間を身体の休息として加算しない。
旋回の消費、摂食によるreserve補充、損傷・飢餓・死亡は今回未接続。

帰還は既存の目印/近距離dock観測に従う。return_unload_attemptがWorld側でも
拠点距離1.25以内で完了した場合だけ、未配送の実pickupを荷下ろしする。
Runtimeへ従来と同じ配送receiptを返しcarried数を更新。再送で再配送しない。

## Sleep材料と利用

本人の受理済み観測/command/resultから最大64観測を参照。
body modeでは最大6件をaction/outcomeごとに選ぶ。phaseは出典として保持する。
同じ歩行/旋回/waitをphaseごとに繰り返して6枠を埋めない。
通常modeは従来のaction/outcome/phase選択を維持する。

取得時locomotor（身体state、障害高さ、参照元）を保存し、climbも関係比較へ渡す。
上限外の経験は選ばれない場合がある。支持数は再評価では増やさない。
自動採用する局所action modelは、歩行/越え能力の可否・越え高さ・前方障害高さが
同じセルだけ照合する。身体条件なしの旧記録を身体条件ありの予測へ流用しない。
候補の歩行距離を.5へ変換してからSleep寄与を照合する。
身体ゲートで行動を置換した場合、未実行の元方法にH/route成功を付けない。

既存の食料/危険coverageが不明ならセル形成を保留する。
climb能力の習得、因果確定、canonical T1/M_B更新ではない。

## 再実行

`python -m integrations.lightweight.body_sleep_comparison`

3個体×3日、自然地形（縄張り+巡回あり）と拠点近くの低障害対照、各Sleep on/off。
通常CLIでもbody-modeと既存sleep-learning/sleep-auto-adopt等を併用できる。
body-scene food_barrierは実験者の初期配置で、個体へ座標正解を渡さない。
自動採用はselection-mode continuousとsleep-learningが必要。
帰還配送の検証構成はreturn-completion-mode enabledとorientation-mode enabled。
