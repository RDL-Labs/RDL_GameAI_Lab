# OBS-8 同一視覚チャンネル内の再取得 — 実装契約

状態: OPERATIONAL / obs8-v1 / 2026-09-26。
実装開始基準: GameAI `1c2d3e14ba3870b349d12dbd8787307eb23b0e18`。
専用fixtureと純粋評価を実装。以下の数値は契約案で固定したfixture値で、身体一般の能力値ではない。
実行結果と検証範囲は[Evidence](../experiment-evidence/OBS_8_visual_reacquisition_evidence.md)を参照。
OBS-6E・7A・7Bを変更せず、別目的として実装する。

## 1. 問いと権限

目的は`visual_reacquisition_after_yaw`、規則版は`obs8-v1`。
「一度取得した遠景特徴について、水平回転後の対応角域に、指定した粗い外観条件を
満たす特徴が新しい記録でも観測されるか」を問う。
試験側が受理済み元frame ID・frame内feature ID・操作ID・問いを明示する。
7Bの候補は起動条件にしない。重要度選択、自発的注意、音源と視覚の対応は扱わない。

出力は特徴条件を満たす記録の再取得であり、物体同一性・音源同一性・精密化ではない。
複数の適合特徴をすべて残す。候補数の減少、中央への移動を成功指標にしない。
各系設計としての有限Probeであり、T1全体、F/E/H生成、M_B更新の実装ではない。
[Core参照](../semantic-reference/RDL_Core_T0_T1_reference.md)の境界を維持する。

## 2. 有限予算と取得方式

| 項目 | 初版の固定条件 |
| --- | --- |
| 対象 | 同一run / epoch / agent、vision_distant / eye |
| profile | fixture-distant-enabled revision 1、model sampled-surface-v0.2（profile mode sampled_surface_v0） |
| センサー | 距離(12,64]、水平90度・垂直60度、方向5度区分、最大4特徴、既存遮蔽規則 |
| 並進 | 禁止。観測点は水平回転軸上。開始後の位置変化で中断 |
| 回転 | 一操作につき最大1回、指令と実測の絶対回転量とも45度以下 |
| 再取得 | 回転確認後の次の通常取得枠を1回だけ使用 |
| 周期 | 4 World tickごと。fixtureは1 tick=250000µs、同一world-sim時計 |
| 元frameの鮮度 | 起動時と再取得時とも取得時刻から2000000µs以内（境界含む） |
| 操作期限 | 起動から1500000µs以内（境界含む）に再取得を終える |
| 同時操作 | 個体あたり1件。実行中の生活行動がある場合は不実行 |
| 台帳 | 専用runあたり最大16操作。満杯なら新規操作を拒否し、既存IDを追い出さない |

通常取得枠をProbeに紐づけ、周期取得との二重sampleを禁止する。臨時sample、再試行、
取得不完了後の追加sampleはない。共有センサー全体で1枠1sample・最大4特徴を維持する。
同tick内の回転前sampleは再取得に数えず、実回転結果を確認した後の枠だけを使う。
枠待ちで期限を超える場合は中断し、予算を迂回して即時sampleしない。
配送・受付の遅延は鮮度を更新しない。取得が期限内でも受理前のframeは評価に使わない。
試験harnessの通信待ち上限は別の実時間timeoutとし、失敗を再観測なしへ変換しない。

## 3. 入力と姿勢対応の出典

元frameは受理済み・瞬間取得・SAMPLED・COMPLETE_WITHIN_PLAN・output_limited=false。
参照featureは既知のazimuth/elevation区間と既知のcolor_bandを持つ。
外観条件は元featureのcolor_bandと一致する値を問いに明示し、unknownをwildcardにしない。
IDは不透明な参照であり、文字列解析で姿勢や時刻を推定しない。
未知ID、他個体、run/epoch不一致、不正な問い、同操作IDの内容変更は入力拒否。
古い正当な記録・実行中の生活行動・姿勢対応不足は理由付き不実行と区別する。

身体側の限定adapterが以下の対応証拠を発行する。NPCの比較器へ対象World座標や対象IDを渡さない。

- 元frameの取得姿勢ref、起動姿勢ref、回転後取得姿勢ref。
- 各姿勢の同一clockでの取得時刻、agent/run/epoch、対応証拠IDと発行元。
- 元取得→起動、および起動→回転後の実測相対水平角。
- 並進・pitch/roll変化の有無、profile版、失効時刻、測定の角度誤差上限。
- 操作ID、指令値、実行開始・完了時刻、実測回転値、対応frame ID。

初版は取得姿勢を直接記録できる静止Luanti fixtureに限定する。相対角は実行前後の
身体yawからadapterが算出し、指令値で代用しない。欠測・参照鎖の不連続・異なる時計は失効。
数値誤差許容は角度0.01度・位置0.000001 node以内とし、検査用許容であることを明示する。
対象へのWorld方位・距離・名称はadapter出力に含めない。身体姿勢の出典と対象の正解を分ける。
再起動・epoch変更で対応と操作実行権限は失効し、自動再開しない。

## 4. 回転先と評価角域

右向きを正とする局所方位規約をadapter境界で固定する。Luanti yawの符号をそのまま仮定せず、
左右回転のfixtureで確認する。元の方位区間をA、元取得から起動までの実測右回転をd0とすると、
起動時の対応角域はA-d0。円周区間は±180度で分割し、単純な大小比較にしない。
その中心を正面へ向ける一回の指令を求める。絶対値45度超は切り詰めず不実行。
ゼロ回転なら身体変更を省略し、次の通常枠で再取得する（変更回数0）。

実行後は元取得から再取得までの実測右回転dを使いA-dを再計算する。
対応証拠の累積誤差分だけ角域を外側へ拡張する。水平回転のみなので元仰角域は保持する。
変換するのは過去の観測方向であり、対象の現在位置ではない。
指令と実回転の差が0.01度超、実回転予算超過、移動や優先処理が起きた場合は中断する。
中断後に元姿勢へ自動復帰しない（それ自体が追加回転になるため）。身体の最終状態を記録する。

評価では、新frameの各特徴の方位・仰角区間が対応角域とそれぞれ正の幅で重なり、
color_bandが指定値と一致するものをすべて返す。区間端点だけの接触は適合としない。
これは量子化された記録区間の整合規則であり、区間内の実対象位置の一致ではない。
対応角域全体が新視野内に入ること、profile/model/距離・解像度・時計が維持されることを要求する。
取得範囲は既存の有限な固定候補fixtureに限る。COMPLETEを一般Worldの網羅性と解釈しない。

## 5. 状態と結果

操作状態、取得状態、問いの評価を別フィールドとし、単一successへまとめない。
想定遷移はrequested → validated → rotated → sampled → admitted → evaluated。
任意段階から理由付きnot_executed / abortedへ移れる。終了後は同操作を再開しない。

| 結果 | 条件 |
| --- | --- |
| reobserved | 条件・取得が完全で、記録区間と色が適合する特徴が1件以上。全参照を返す |
| not_reobserved | 条件・対象角域の取得が完全で、適合0件。検査した記録内の結論に限定 |
| not_comparable | 新frameはあるが、姿勢対応・時刻・角域包含などの評価条件が不成立 |
| acquisition_incomplete | 未取得、PARTIAL、UNAVAILABLE、output_limited。0件を負の証拠にしない |
| not_executed / aborted | 起動拒否条件または途中中断。再観測評価はnull |

複数の不成立理由を保持する。操作中に判明した失効はaborted、受理後評価で判明した
対応不成立はnot_comparable。取得不完了と比較条件不成立が併存するときは両軸に残し、
総合結果はacquisition_incompleteを優先する。結果には元・新frame、選択feature、問い、
姿勢対応の証拠、指令/実測値、時刻、取得枠、検査範囲、適合全件を保持する。
7Aの時間重なり規則を変更・流用せず、経時再取得として別の純粋評価関数を置く。

## 6. 操作IDと再送

操作IDはrun/epoch/agent内で一意。正規化requestを有限台帳へ登録してから身体操作へ進む。
同ID・同内容は進行中状態か保存済み結果を返し、回転・sampleを繰り返さない。
同ID・異なる内容は拒否。期限は最初の起動時刻で固定し、再送で延長しない。
frame配送の再送と操作の再送を別に検査する。frameの重複保存防止だけでは操作一回性を保証しない。
台帳は専用runのメモリ内に限定し、永続的exactly-onceは主張しない。
再起動後は旧runの操作を拒否するため、fixture開始時に新run/epochを必ず割り当てる。

## 7. 実装単位と受入試験

純粋な起動条件・回転計画・再取得評価を実装した。身体adapterと有限台帳は
専用Luanti fixture内に置き、既存共有distant_sensorを呼ぶ。新しい汎用HTTP行動endpoint、
RW2自動hook、GUI、聴覚連携を追加しない。Runtimeでは既存の受理経路を使う。

| 試験 | 確認すること |
| --- | --- |
| 特徴残存、左右回転、±180度跨ぎ | 実測変換の符号、予算内回転、回転後frame、適合参照 |
| 観測後に対象を消す／遮蔽する | 完全取得時だけnot_reobserved。World全体の不在を主張しない |
| 同じ粗い色の複数特徴 | 全適合を保持。単一物体へ同定しない |
| 未ロード領域・出力上限・取得失敗 | acquisition_incomplete、負の証拠なし |
| 元→起動姿勢の欠測・失効、実回転の欠測 | 不実行／中断。指令どおりと補完しない |
| 指令と実測差・並進・profile変更・生活優先処理 | 中断と最終身体状態。自動復帰なし |
| 鮮度2秒・終了1.5秒の境界と超過、配送遅延 | 取得時刻基準、再送による延命なし |
| 同tickの回転前取得・次周期枠 | 前frameを流用せず、全体で枠あたり1sample |
| 回転後の応答消失・操作再送・frame再送 | 回転1回、再取得1回、台帳結果再利用、保存重複なし |
| 台帳16/17、同ID異内容、run再起動 | 有限拒否・旧操作再実行なし |
| World対象ID・座標の漏洩検査 | 計画器と評価器は観測と身体対応証拠だけを使用 |
| 7A/7B・OBS-6E/4C/遠景の回帰 | 既存契約維持。専用fixture成功をRW2統合と呼ばない |

Evidenceでは純粋関数試験、身体操作、実Runtime受理、実Luanti取得、replayを区別する。
実回転結果が指令と一致しない負例を必ず含める。初版はこの一周で停止し、
聴覚候補からの問い生成、移動、追跡、意味判断、canonical接続は次の別契約とする。

## 8. 実装APIと検証の分類

`visual_probe.lua`の`plan(frame, feature, request, body)`は純粋な回転計画。
`new(run_id, epoch, agent)`が最大16件の台帳を作り、`start / rotate / sample / guard`が
各副作用前の状態遷移を管理する。`start`へのframeは専用fixtureが実Runtimeのaccepted応答を
確認したものに限る。このLua APIは未受理frameを受け付ける公開endpointではない。
身体adapterの入力も信頼する取得機構の出力であり、一般クライアントからの姿勢申告ではない。
計画後の姿勢変化、実測欠測、次回取得枠の逸失でも中断する。

Pythonの`runtime.visual_reacquisition.evaluate(snapshot, request, evidence)`は受理済みsnapshotと
身体証拠を受け取る純粋関数。source/new frame参照を解決し、取得・比較・操作の各軸を返す。
未受理targetや不正参照は`ProbeInputError`。入力・結果は独立したコピーで、永続storeはない。
requestはoperation_id / run_id / world_epoch / agent_id / purpose / rule_version /
source_frame_id / feature_id / color_bandのみ。対象World座標や対象IDは入力に含まれない。
Luaの台帳はsampledで取得を終了し、HTTP受理とPython評価はfixture harnessが続ける。
不実行・中断では評価はnull。取得不完了・比較不能ではmatchesもnullとする。

左右・消失・遮蔽・複数・overflow・実回転不一致・失効・優先処理等は実Luantiで確認する。
not_comparableの評価、期限の厳密境界、欠測、取得不完了との併存は固定記録の合成変更と
Lua純粋検査で確認する。全行を実World故障として実行したとは主張しない。
fixtureのsim時計はHTTP往復中に進めない。ネットワーク待ち時間は実時間harness timeoutで
分離する。長期運転・非同期World内の期限保証を検証したものではない。

応答消失は一度目の操作完了を呼出し側へ返さず再要求し、同時に感覚配送を新observation IDで
再送するfixture内注入。実ネットワーク切断ではない。回転・sampleの重複が起きないことと、
Runtimeのnew_frames=0を別々に確認する。再起動の確認は旧run要求の拒否であり、
プロセスcrashを跨ぐ永続exactly-onceを提供しない。
