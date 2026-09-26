# OBS-8B 継続WorldでのProbe調停 — Evidence

実行日: 2026-09-26。実装開始基準: `b5f3cd28d55eb11368bc98b306e38df242de94b9`。
[契約](../experiment-contracts/OBS_8B_continuous_world_probe_contract.md)の専用6秒fixtureを実装・検証。
評価規則はobs8b-v1、調停規則はobs8b-arbitration-v1（保存記録のprovenanceにも記載）。

## つないだ経路

8Bモードではglobalstepのdtimeから時計を進め、HTTP待ち中も通常視覚取得を継続する。
受理済み元frameから明示起動し、個体別arbiterが生活intent・待ち状態・期限・容量を検査する。
身体操作はWorldステップで一度だけ許可し、通常samplerが唯一の取得枠を所有する。
callbackは結果をmailboxへ渡すだけで、身体を直接動かさない。
既存multi_agent_foodのpacket生成・Food/Baseへのaction解決・deposit結果受付を利用した。

新しい自律判断や生活profileの感覚許可は加えていない。A/Bの視覚はfixture-distant-enabledのまま。
OBS-6Eの全感覚生活統合へProbeを追加したものではない。
旧8の公開評価入口とtick境界の厳密条件は維持し、共通評価内部のみを共有した。
8Bは実取得時刻のfloor(capture_us/250000)で枠を照合し、旧記録の時刻を丸め直さない。

## 実Luanti 6ケース

実行: `powershell -ExecutionPolicy Bypass -File integrations/luanti/scripts/test-continuous-probe.ps1 -Scenario <scenario>`。
各ケースは独立した新run。全ケースでA/Bがpickup・帰還・deposit・結果受付まで完了。
各runのRuntime拒否は0件、drain後のpendingは0件。合計70frameを受理。

| scenario | Probe結果 | 回転 / Probe再取得 | 全通常視覚frame数 |
| --- | --- | --- | --- |
| delayed | reobserved | 1 / 1 | 12 |
| preempt | aborted: life_priority | 1 / 0 | 12 |
| same_slot | aborted: life_priority | 1 / 0 | 12 |
| stale | not_executed: stale_source, pose_mapping_unavailable | 0 / 0 | 12 |
| loss | reobserved | 1 / 1 | 12 |
| jump | aborted: missed_acquisition_slot | 1 / 0 | 10 |

通常取得は中断後も生活の姿勢で継続するが、中断Probeの再取得には数えない。
各個体・各取得tickでsampleは一度だけ。全frameの取得時刻はrunの6秒未満。
6秒閾値を跨いだステップから身体作用を停止し、約6.07秒等の終了記録は受付drainを含む。

### 待ち中の進行と、取得後の身体変化

delayedはcallback受渡しを実測1176688µs保留した。その間にもAの通常視覚frameが増えた。
新frame取得後、受付確認前にAが実際の生活actionを実行したことを時刻で検査している。
評価は保存した取得時姿勢を使い、後の移動量で過去frameを不適格にしない。
staleは元frameの応答を実測2174569µs保留し、到着後に元frameを若返らせず不実行となった。
実際の保留時間はglobalstepでの消費までを含むため、注入値1.1秒／2.1秒より少し長い。

### 生活優先と、古い応答の排除

preemptは回転後・次枠前に生活intentを開始。same_slotは取得tickと同ステップに生活intentを開始し、
生活優先でProbeを中断した。既存Runtimeのactionを既存RW2 resolverで実行し、A/Bとも生活完了。
intentの起動時刻は試験側の明示スケジュールであり、自律的な生活／注意の判断ではない。

same_slotではBの実生活応答を保留中にgenerationを変更し、古いgenerationのactionが
一度も身体へ適用されないことを確認。新しい観測要求から生活を継続した。
さらにAの新要求送信後に保存した旧callbackを再注入し、新しいin_flightとpending ID集合が
そのまま残ることをassertした。古い行動は実行せず、ackは該当deliveryのIDだけを対象とする。
これはcallback受渡しの故障注入であり、ネットワーク層の順序逆転を実測した主張ではない。

### 消失と取得枠の逸失

lossは再取得frameの最初の成功応答全体をcallbackで破棄。pendingを保持し、別delivery IDで
再配送してnew_frames=0の受理を確認。終了操作の同ID再要求でも回転・再取得は各1回。
操作結果の再要求はfixture内APIの台帳再利用を検査するもので、公開操作HTTP endpointはない。

jumpは時計へ650000µsを一度加え、大きなdtimeによる枠逸失を注入。tick4をmissedと記録し、
過去sampleを捏造せず、次の枠へProbeを振り替えない。生活intentは後に開始して原因を分離した。

## 保存記録と出典

`tests/fixtures/obs8b_luanti_replay.json`に6つのsnapshotと調停証拠を無改変で同梱。
元ファイルは`integrations/luanti/output/`以下。snapshotと同名prefixの.evidence.jsonも保存。

| scenario | snapshot |
| --- | --- |
| delayed | obs8b-20260926-115644-792.snapshot.json |
| preempt | obs8b-20260926-115651-625.snapshot.json |
| same_slot | obs8b-20260926-115658-442.snapshot.json |
| stale | obs8b-20260926-115705-243.snapshot.json |
| loss | obs8b-20260926-115712-091.snapshot.json |
| jump | obs8b-20260926-115718-982.snapshot.json |

World対象座標・対象IDは回転計画と評価に渡さない。生活packetは従来のFood/Base情報を使うが、
Probeのrequest・身体証拠・保存SensorFrameへの漏洩がないことを検査した。

## 境界試験と回帰

Luanti内のprobe_arbiter_checks.lua: **50アサーションPASS**（各runで同じ50件を実行）。
旧generationの排除、deliveryごとのack、新in_flight保持、行動権限の一回消費、
明示idle・HTTP待ち・結果報告待ち、8件pendingと予約、二重枠、実測欠測時の予約解放、
枠飛越し、台帳16/17、旧run、不正参照、run停止後drain、再送理由不変、応答ID不一致を確認。
容量上限や一部の不正入力はこの合成検査であり、実Worldでqueueを飽和させた実測ではない。

`python -m unittest discover -s tests -p test_continuous_visual_probe.py -v`: **12件PASS**。
6実記録のreplay、実store再受理と重複、実取得時刻保持、旧8の厳密性、枠終端と次枠逸失、
過去姿勢での評価、コピー独立、比較不能と取得不完了の併存、入力拒否・World情報非混入を検査。

`python -m unittest discover -s tests -v`: **390件実行 = 344件PASS + 46件の意図的skip**。
ログ: `integrations/luanti/output/obs8b-full-tests.log`。
既存実Luanti回帰も全てPASS:

- OBS-8: 15ケース・23frame、回転・sample一回性。
- OBS-7B: 四状態と7Aのno_temporal_overlap。
- OBS-6E: 拒否回復、応答消失後new_frames=0、ack後のみ除去、A/B生活完了。
- OBS-4C: 聴覚窓分割・二重close・遅延拒否・上限partial。
- OBS-3: 遠景の初回1件・回転後0件・遮蔽対象非表示。

## 停止境界

有限な専用6秒runでの明示起動と生活優先の調停まで。
通常ネットワークの切断・任意の遅延分布・長期運転・永続exactly-once・GUIは今回未検証。
試験側のintent発生やgeneration変更をNPCの自律判断と呼ばない。
自律注意、聴覚候補からの起動、全感覚生活統合、移動Probe、追跡、canonicalへの解釈・更新は保留。
