# OBS-9 観測基盤v1 統合受入 Evidence

状態: **PASS / 観測基盤v1 COMPLETE** / 2026-09-26。
実装開始点: `acf95badb22d1504d0adb0cdd7af2679c7f82f34`（OBS-9契約案）。
[契約](../experiment-contracts/OBS_9_observation_v1_completion_contract.md)のV1-01〜10を満たした。
「観測の精度は粗いが、GameAIの後段を研究するには十分な観測基盤」として、この有限範囲で固定する。
一般環境の完全観測・一般認識・任意の学習課題への十分性の証明ではない。

## 実装と責務

- `observation_v1_fixture.lua`: 専用mode `observation_v1`。進み続けるWorldでRW2の既存resolverを実行する。HTTP callbackは受渡しだけを行う。
- `observation_v1_sampler.lua`: 近景packetの取得、共有`distant_sensor`、`audition_window_sensor`、`audition_transmission`を使う唯一の取得経路。配送時は取得済み近景packetを再利用する。
- `probe_arbiter.lua`: OBS-9では全感覚pending64件を一つだけ所有。予約1件も64件に含む。配送4件、個体別in-flight/mailbox各1、台帳32、trace256。旧8Bの既定8件は維持。
- `continuous_visual_controller.lua`: 明示的`obs9-v1`だけに2種類のlife profileを許可。回転1回・45度、通常遠景枠1回、鮮度2秒・操作期限1.5秒、操作台帳16を維持。
- `runtime.observation_v1.evaluate`: 受理済み元/新frameと身体証拠の純粋評価。source/targetは同profile ID/版を要求。旧8/8Bの許可表・時間規則、7A/7Bを拡張しない。

追加取得の問いは試験側の明示起動。7B起動・自律注意・追跡・canonical解釈への自動接続はない。
遠景の正確なWorld位置は共有センサー内部とfixtureの配置にだけ使い、計画器・評価器へ渡さない。

## 実Luanti 8run

Windows / Luanti 5.17、実NPCのyaw・位置、World node、共有センサー、HTTP Runtimeで実行。
各runの取得・身体作用は6秒未満。250000µs窓の最後の聴覚記録は、6秒までに受信済みのbufferを閉じて確定する。
終了後は新規身体作用・センサー読出しを行わず最大5秒だけ配送をdrainする。
各runで108frame = A/B各（近景24＋聴覚24＋遠景6）。Probeのframeは遠景6件の一つであり、別取得ではない。
8run合計864frame。全runで両者のpickup・帰還・deposit・結果受付が完了し、pending/予約は0。
拒否は`faults`の意図的な感覚拡張拒否1件のみで、その後回復。他7runは0件。

| ケース | run ID | 評価 | 回転 / Probe取得 | pending＋予約の最大 A / B |
| --- | --- | --- | --- | --- |
| normal | `obs9-20260926-125755-520` | reobserved | 1 / 1 | 3 / 3 |
| swap | `obs9-20260926-125802-705` | reobserved | 1 / 1 | 3 / 3 |
| delayed | `obs9-20260926-125809-638` | reobserved | 1 / 1 | 16 / 3 |
| preempt | `obs9-20260926-125816-588` | aborted: life_priority | 1 / 0 | 3 / 3 |
| same_slot | `obs9-20260926-125823-575` | aborted: life_priority | 1 / 0 | 3 / 11 |
| faults | `obs9-20260926-125830-753` | reobserved | 1 / 1 | 14 / 13 |
| removed | `obs9-20260926-125837-687` | not_reobserved | 1 / 1 | 3 / 3 |
| partial | `obs9-20260926-125844-647` | acquisition_incomplete | 1 / 1 | 3 / 3 |

正常系はA、`swap`はBのcompact profileでProbeを実行。他個体の生活は併走する。
指令32.5度に対し実測32.50000033521246度。`preempt`は回転後、`same_slot`は取得枠と同じWorld stepで生活intentが優先される。
中断時の予約を解放し、通常遠景取得は続けるが中断したProbeの成果には数えない。
`removed`は元取得後に実nodeを除去。`partial`は実nodeを増やして共有遠景センサーの最大4特徴を超え、coverage=PARTIAL/output_limited=trueとなる。
`delayed`は再取得後、ackより前に実生活actionで身体が動く。評価には取得時の身体証拠を使用し、配送時位置で上書きしない。

## 結合故障とID単位の回復

`faults`は同じrunで、Aの送信見送り、Bの感覚拡張だけの拒否、旧生活権限の失効、Aの成功応答消失、callback受渡し遅延、旧callback再注入を実施。
World時計と三感覚は待ち中も進む。故障注入はharness/callback層であり、実ネットワーク切断・再順序化を測った試験ではない。

Aの`delivery:4`で次の3frameをRuntimeが保存した後、応答全体を破棄した。行動もackも適用しない。
全IDはprefix `obs9-20260926-125830-753:npc_a:`を持つ。

| 段階 | ID末尾（順序保持） | new_frames | pending総数 | 除去 |
| --- | --- | --- | --- | --- |
| 成功応答を破棄 | audition:4 / vision_local:5 / vision_distant:2 | 3 | 3 | 0 |
| 保留した消失通知をconsume | 同上 | 応答なし | 13 | 0 |
| `delivery:5`の明示ack | 同上 | 0 | 14 → 11 | 該当3件のみ |

失われたframe IDを固定して次の新しい生活packetへ再添付し、その間の新規frameは別にpendingへ残す。
この3件は保存snapshotに各1件だけ存在する。ID・順序・ack前の保持・無関係frameの保持をassertする。
同じ操作IDの終了後再要求でも回転/取得回数は変わらない。
新しい要求後に旧callbackを再注入しても、新しいin-flightとpending集合を維持する。
旧権限世代の生活応答は身体へ適用しないが、正当な配送ackはその配送のframe集合にだけ適用する。

## 10項目の対応

中心となる実行assertionは`integrations/luanti/tests/check_observation_v1.py`、境界試験は`observation_v1_checks.lua`と`tests/test_observation_v1.py`。

| ID | 結果 | assertion / 証拠 |
| --- | --- | --- |
| V1-01 | PASS | 全runでA/Bのprofile ID/版を検査。共通の初期短音[0,10000)µsをAだけ検出、Bは検出せず。normal/swapでProbe役割交換。Luaでprofileコピー・個体別状態を検査 |
| V1-02 | PASS | 全8run、両個体で3channel・各54件。生活actionとProbe・取得が同じ時計で進む |
| V1-03 | PASS | 取得元864件と保存frameの全field一致。取得時刻、検出単位の区間/姿勢、coverage/上限を検査。欠落窓はLua合成試験でPARTIAL |
| V1-04 | PASS | 保存schemaのallowlistとWorld正解fieldの再帰禁止検査。正確位置/音源IDを混入したframeをRuntimeが拒否するPython試験 |
| V1-05 | PASS | 全runの実測回転<=45度、操作1回、通常枠の唯一性、終了後同操作再送の無作用 |
| V1-06 | PASS | preempt/same_slotの再取得0、中断理由life_priority、予約0、両者の実生活復帰・完了 |
| V1-07 | PASS | delayed/faults/same_slot。三感覚継続、旧世代actionなし、実行delivery ID一意、旧callbackが新要求を壊さない |
| V1-08 | PASS | faultsの3frameがnew_frames=3→0。ack前保持、ID順序・該当集合のみ除去。全108件の再受理でも追加0のPython試験 |
| V1-09 | PASS | 実Worldのremoved/partial/preempt、保存済み証拠のpose.validを変更した合成not_comparable。複数理由・matches=nullを保持 |
| V1-10 | PASS | 8run全てのA/Bがpickup・return・deposit・causal result受付完了。全行動列の一致は要求しない |

profileの近景半径は両者12、聴覚gainは1/0.25。近景12/8をこの統合runの差とは主張しない。
視覚条件は従来8Bと同じで、profileを明示的に切り替えた合成同等記録の評価一致も検査する。
`not_comparable`と複数理由の試験は保存済み実取得記録の身体証拠を合成変更したもので、実Worldの姿勢測定失敗ではない。
固定3packetの評価あり/なしで行動応答・Experience・canonical・sensory storeが一致するPython試験もPASS。実World全行動列一致とは別。

## 再現と回帰

```powershell
foreach ($scenario in @('normal','swap','delayed','preempt','same_slot','faults','removed','partial')) {
    powershell -ExecutionPolicy Bypass -File integrations/luanti/scripts/test-observation-v1.ps1 -Scenario $scenario
}
python -m unittest discover -s tests -p test_observation_v1.py -v
python -m unittest discover -s tests -v
```

- OBS-9 Lua合成境界: **163 assertions PASS**。64件（予約込み）・65件目拒否、再送ID保持、profile変更、欠落窓など。旧8Bの50 assertionsも同時PASS。
- OBS-9 Python: **17 tests PASS**。実Luanti8runの再生を含む。
- 全体: **407件実行 = 361 PASS + 46件の意図的skip**。
- 実Luanti回帰: **8B全6ケース、8の15ケース、7B、6E生活統合、4C聴覚窓、遠景OBS-3、近景profile試験すべてPASS**。
- 7Aの14試験、7Bの18試験と各保存済みreplayも全体試験でPASS。7A/7Bの意味・許可表に変更なし。

`tests/fixtures/obs9_luanti_replay.json`は8runの受理済みsnapshot全体と取得元・adapter evidenceを保持する。
World対象位置は含まない。配列の空値はwireと同じく[]へJSON整形するが、frame値の合成補正・選別はしない。
provenanceに設計基準commit・実行日・取得コードのSHA-256を記録。実行コードとこのEvidenceを含むcommitを固定基準とする。
ローカルログは`integrations/luanti/output/obs9-*`、全体試験ログは`obs9-full-tests.log`。

## ここで停止する範囲

このCOMPLETEは短い有限fixtureで後段研究を始めるための観測側の受入完了である。
自律的な起動、7Bからの起動、一般姿勢変換、精密認識、嗅覚、追跡、長期永続化、再起動をまたぐ一回実行保証、任意ネットワーク障害は含まない。
取得不完了・比較不能・再観測なし・中断を保持する基盤を固定し、次の設計対象を神経・解釈・Goal・Trajectoryへ戻す。
追加観測能力は具体的な用途が必要になった場合の別契約とし、v1の完了条件に後付けしない。
