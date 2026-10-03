# 軽量Worldの有限危険対処 v1

2026-10-03。`finite-moving-hazard-safety-v1`。opt-in、軽量Python World専用。
[計画](../design/RDL_GameAI_Moving_Hazard_Safety_Plan.md)のS1/S2およびS3の小さな比較を実装。
全計画完了・生存保証・canonical M_B更新ではない。

## 入力と初期能力

`violet_hazard`を既知危険外観として初期設定する。縄張りfixtureでは`violet_warning`も同じ既知危険として許可する（[追加契約・Evidence](../experiment-evidence/LW_territorial_hazard.md)）。観測は同じrun/agent/observation/capture/pose/body revisionへ束縛。
前方180度、距離12以内、Worldの既存遮蔽検査を通した最大1特徴。方向は15度刻みの区間、距離帯はnear<=4、watch<=8、far<=12。
World座標・個体ID・未来軌道・接触結果は個体入力に含めない。規則版が固定sensor条件も識別する。Observation v1のSensorFrame拡張ではない。

前方を15度間隔・距離4で検査し、遮蔽があればcoverage=partial。これは有限な局所確認で、全空間の安全証明ではない。partialでも実際に取得した特徴は対処に使えるが、空であることは解除証拠にならない。
サンプル周期は既存250ms。採取作業中もWorld取得を続けるが、Runtime判断は作業完了後。

## 対処

near/watchを観測すると通常目的を保留し、`activity_phase=safety`へ移る。farだけでは起動しない。

- near: 観測方向から離れる側へ90度旋回。現在の地面取得がcompleteで、その方向がsampledかつ段差絶対値<=0.5の場合だけ。
- 旋回後: 実回転結果が指令と対応し、新しい前方地面が取得できた場合だけ1歩。古い方向を並進後へ流用しない。
- watch/far: 待機して再観測。
- 見失い/空/partial: 見回し。partialは解除確認へ加算しない。
- 身体結果の対応欠落: `safety_uncertain`として待機。

1安全episodeあたり最大32移動・旋回操作、開始から16秒。16操作以降は移動を増やさず見回しに限定する。上限到達は`safety_unresolved`。時計・観測・評価は続けるが、操作予算を自動リセットしない。日付変更でも解除しない。

解除はcompleteなfarを2判断連続で取得、または実測90度旋回後のcompleteな空観測を合計360度確認した場合だけ。途中の可視危険・partial・移動・対応欠落で空観測の累積を解除する。限定確認後は現在時刻・帰還未達・携行品から通常判断を再計算する。元commandを再発行しない。
予算切れ後もfar確認が成立すれば復帰可能だが、空の同一方向を見続けるだけでは復帰しない。

2026-10-03追加: opt-inの[警戒モード評価](../experiment-evidence/LW_warning_mode_review.md)では、維持根拠が更新されない状態を局所Hとして評価し、閾値で暫定解除できる。これは上記の安全確認による解除とは別経路。既定disabledでは従来規則を維持する。

## 実行順序と保存

既存の同期World実行器を使う。旧通常判断の次に安全判断を優先し、旋回後一歩・局所候補ownerを通常phaseのまま継続しない。操作ID再送は既存の実行済み結果を返す。
開始済み採取はキャンセルしない。最大500msの作業を完了して結果を受理し、次判断から対処する。非同期callback・未実行commandキューの世代失効を実装したという主張はしない。

食料目的・携行品・採用モデル・保存経路を保持する。安全割込みだけで経路support/Hを変更しない。ただし割込み直前の実blockedは対応があれば残す。
途中の経路記録はoverflow扱いとしてそのtripの新規経路支持を抑止し、安全移動を元経路の成功として加算しない。配送自体は受理できる。
食料/帰還の未達trialに割込み印を残し、未確認結果はdefer。実際に確認済みの成功は保持する。局所HをCore Hへ昇格しない。

## fixtureと停止境界

危険はWorld時刻で動き、NPCの反応に追従しない。64秒/日のうち2〜10秒だけ出現するcrossing、同窓で静止するpersistent、56〜64秒のnight、初日には出現せず2日目以降資源付近を横切るroute_crossingを用意。
出現窓外では除去する有限fixtureであり、生涯連続の捕食者ではない。負傷・死亡・追跡・危険性学習・任意数脅威は未実装。

`disabled`は従来経路、`shadow`は診断保存のみ、`enabled`は行動介入。shadow中の診断遷移は、対処した場合の反実仮想ではない。
遮蔽で解除できず長期保留になる限界を含む。これは次の対処候補拡張の材料であり、停滞解消完了とは扱わない。

検証と再実行方法: [Evidence](../experiment-evidence/LW_moving_hazard_safety_evidence.md)。
