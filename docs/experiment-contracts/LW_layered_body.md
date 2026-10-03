# 四層身体の最小構築 v1

2026-10-04。基準280919f。FINITE BODY FIXTURE IMPLEMENTED。

目的: 瞬発系・持続系を日常操作の基盤にし、蓄えと肉体限界で支える。
生理学的ATP濃度、栄養学、動物種の実測能力を再現したモデルではない。

| 層 | state/算出量 | 初版 |
| --- | --- | --- |
| 瞬発系 | burst 0〜10 | runで3、climbで4消費。walkでは消費しない |
| 持続系 | strain 0〜1 | walkで.03、runで.18、climbで.15増加 |
| エネルギー限界系 | reserve 0〜100 | walk .1、run .5、climb .4消費。食事1単位で20補充 |
| 肉体限界系 | damage 0〜1 | 移動距離・越えられる高さ・瞬発容量・回復率を制限 |

各操作は1秒。未損傷時walk .5、run 1.5、climb 1.0距離、最大越え高さ.6。
同時に両系が作用する。strain>.8ならrun/climb不可、strain=1ならwalk不可。
能力不足はbody_limited、幾何障害はblockedで分離。blockedの試行にも.05蓄え消費。
body_limitedによる不実行では操作消費を加えない。

restの回復係数は`min(1,reserve/20)*(1-damage)`。
瞬発系を最大2、strainを最大.15回復し、そのためreserveを最大.05消費する。
reserve=0では待つだけで回復しない。eatは蓄えだけ増やすため即時全力復帰にならない。
damageはfixture設定値で、負傷発生・治癒は未実装。休息/食事で損傷は消さない。
基礎代謝・飢餓死・危機時のθ変更・個体別係数もまだ接続しない。

## Worldと責務

`runtime/layered_body.py`は純粋な身体遷移。
`integrations/lightweight/body_fixture.py`は既存World.direction/segment_hitを使い、
実際に平面位置を変え、個体のinventoryを食事分だけ減らす。
runは全移動区間を衝突検査し、途中の物体を飛び越えない。
climbは区間内の全障害が許容高さ以下、かつ着地点が空いている場合だけ成立する。
これは低障害を越える平面近似であり、跳躍軌道や着地衝撃のシミュレーションではない。
高さと真の位置はWorld側の成否判定専用。NPCへ提供する意思決定入力はまだ未接続。

操作ID再送は同一receiptを返し、移動・消費・回復・食事を重複しない。
同ID内容変更、時計逆行/重複、新規操作の個体不正は拒否。各個体の状態を分離する。

現行30日探索のmove結果は1単位固定で、今回の距離可変receiptをそのまま通せない。
したがって現行探索・Sleep・日次評価の挙動は変更していない。
まず身体単体を成立させ、次に観測可能な能力/状態と操作契約を探索へ接続する。

[試験記録](../experiment-evidence/LW_layered_body.md)
