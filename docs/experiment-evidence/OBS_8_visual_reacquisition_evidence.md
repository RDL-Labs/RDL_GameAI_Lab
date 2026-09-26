# OBS-8 同一視覚チャンネルの再取得 — Evidence

実行日: 2026-09-26。開始基準: `1c2d3e14ba3870b349d12dbd8787307eb23b0e18`。
[実装契約](../experiment-contracts/OBS_8_visual_reacquisition_contract.md)の`obs8-v1`を検証した。

## 到達点

受理済み遠景frameと明示featureを参照し、純粋な回転計画を作り、実Luantiの身体yawを一度変更、
実回転を確認してから次の通常取得枠で共有distant_sensorを一度呼ぶ。
新frameを実Runtimeへ配送・受理した後、Pythonの純粋評価で対応角域と粗い色を検査する。
7A/7Bを行動起動に使わず、新しいHTTP endpoint・RW2行動hook・canonical接続を追加しない。

## 実Luantiの取得と操作

実行コマンド:

```powershell
powershell -ExecutionPolicy Bypass -File integrations/luanti/scripts/test-visual-probe.ps1
```

最終取得: `obs8-20260926-110536-033.snapshot.json`、
身体証拠: `obs8-20260926-110536-033.evidence.json`。
両方を変更せず`tests/fixtures/obs8_luanti_replay.json`へ出典付きで保存。
専用runは起動ごとのID、epoch=1。23frameを実Runtimeで受理、拒否0件。
各操作は元frameのacceptedを確認してから起動する。

| ケース | 結果 | 実行と取得 |
| --- | --- | --- |
| right / left | reobserved、各1件 | 指令±32.5度、実測±32.500000335度、各1回の回転・再取得 |
| removed / occluded | not_reobserved、各0件 | 元観測後にWorld対象を除去／遮蔽。新frameは完全取得 |
| multiple | reobserved、2件 | 粗い色・角域に適合する全特徴を保持 |
| overflow | acquisition_incomplete | 実センサーの4特徴上限を超過。適合の有無を確定しない |
| unloaded | acquisition_incomplete | 有限候補領域の未ロードvoxel。0件を不在へ変換しない |
| rotation_mismatch | aborted | 指令32.5度に対し実測30.500001418度。再取得0回 |
| expired / life_busy | not_executed | 起動時の期限・生活中フラグによる不実行。回転0回 |
| moved | aborted | 回転後に実ObjectRefを0.1 node移動。再取得0回 |
| profile_changed / pose_expired / priority | aborted | adapter条件を失効させる故障注入。再取得0回 |
| wrap | reobserved、1件 | 初期yaw179度、起動前にも実際に10度回転。元→起動の実測差を使い、±180度を跨いで再取得 |

生活中・優先処理・profile変更・姿勢失効は専用adapter入力への故障注入であり、
実RW2のスケジューラーや動的profileの実装を意味しない。期限超過はfixture時計条件の注入。
身体yaw・位置変更、Worldでの消失・遮蔽、共有センサー取得、HTTP受理は実行している。
対応証拠は再取得時の測定値を保持し、配送完了時の姿勢で上書きしない。

出力:

```text
OBS8 PASS: cases=15 frames=23 rotation_once=true sample_once=true ledger_capacity=16
```

最初の操作では、完了結果を呼出し側へ一度返さず同操作IDを再要求。
台帳の終了状態を再利用し、rotate/sampleを再び呼んでも身体変更・取得は実行されない。
新しい配送observation IDで同じ新frameを再送し、受付はnew_frames=1 → 0。
証拠にoperation_response_lost=true、delivery_new_frames=[1,0]、rotations=1、samples=1を保持。
実ネットワーク切断や、再起動を跨ぐ永続exactly-onceではない。

## 純粋制御と評価の試験

Luanti内の`visual_probe_checks.lua`: **51アサーションPASS**。
鮮度2秒・操作期限1.5秒・45度境界、生活中、姿勢対応欠落、並進・tilt・profile・時計変更、
実回転不一致／欠測、計画後の姿勢変化、取得枠外、次枠逸失、二重sample、ゼロ回転、円周境界を確認。
実機fixtureでは15操作に続く16件目の登録・17件目拒否、旧run・内容変更の拒否も確認した。
台帳上限検査に使う16件目は不実行であり、身体操作件数を増やさない。

`python -m unittest discover -s tests -p test_visual_reacquisition.py -v`: **18件PASS**。
実fixture replay、実storeへの再受理・重複配送、入力と出力の独立性、円周区間・端点接触、
比較不能、取得不完了との併存、完全な空記録、時刻・姿勢・profile・取得枠条件、入力拒否を検査。
not_comparableは実取得記録の証拠条件を合成変更して検査しており、15実機ケースの成功一覧に
新しい実Worldケースとして加えていない。未知方向・期限の厳密境界も合成試験として区別する。

固定3packetで評価あり／なしの行動応答・Experience・canonical snapshotが一致。
評価関数は入力snapshotを変更しない。これはPython固定入力の非介入試験であり、
Probeが身体姿勢を変えても実Worldの全行動列が不変という主張ではない。

## 全体と既存回帰

`python -m unittest discover -s tests -v`: **378件実行 = 332件PASS + 46件の意図的skip**。
ログ: `integrations/luanti/output/obs8-full-tests.log`。

次の実Luanti試験を最終実装後に再実行し、すべてPASS:

- `test-auditory-candidates.ps1`: 7B四状態、7A no_temporal_overlap。
- `test-observation-integration.ps1`: OBS-6E、拒否回復・応答消失再送new_frames=0・ack後のみ除去、A/Bのpickup/deposit/result完了。
- `test-audition-observation.ps1`: OBS-4C、窓分割・二重close・遅延拒否・上限partial。
- `test-distant-observation.ps1`: OBS-3、初回可視1・回転後0・遮蔽対象非表示。

## 限界と停止境界

専用fixtureはHTTP往復中にsim時計を止める。実時間通信待ちにはharness timeoutを設けるが、
進み続けるWorldでの通信遅延と身体操作期限の一般的な競合は今回未検証。
同じprofile・固定候補の有限視野における粗い記録再取得であり、画像認識・対象同定・精密化ではない。
回転中断後の自動復帰を行わず、最終身体状態を残す。

ブラウザー・GUIは今回未実行。聴覚からの問い生成、移動、追跡、生活中の自律起動、
永続台帳、canonical解釈・更新は保留し、この有限な取得・操作・評価の一周で停止する。
