# OBS-8B 継続WorldでのProbe実行権限 — 契約案

状態: DESIGN ONLY / DRAFT v0.1 / 2026-09-26。
基準: `6f8dde9366b91095151c8c7cbfe3fe3909724209`。
未実装・未検証。[OBS-8](OBS_8_visual_reacquisition_contract.md)初版はそのまま固定する。
次に作るのは自律的な注意ではなく、進み続けるWorldでの明示Probeと生活処理の調停である。

## 1. 問い・範囲・既存実装との差

視覚の問いはOBS-8の`visual_reacquisition_after_yaw`を維持する。
実取得時刻を扱う規則版は`obs8b-v1`とし、旧`obs8-v1`の時刻規則を緩めない。
実行調停の版を`obs8b-arbitration-v1`として別に記録し、7A/7Bを起動条件にしない。
身体水平回転は最大1回・45度、元記録の鮮度2秒、起動から取得終了まで1.5秒、
通常遠景周期4tick・1tick=250000µs、最大4特徴を変えない。

現行`multi_agent_food.lua`はHTTP callbackから`resolve_action`を直接呼び、
`life_sensory.attach`はpacket組立時に遠景も取得する。in_flight中はpacket組立を省略する。
従って通信と独立した通常視覚取得や身体操作の排他性は、現行8/6Eからは保証されない。
8Bのopt-in fixtureだけで、callbackを結果の受渡しに限定し、身体変更と取得をWorld側の
有限schedulerへ集約する。既存モードの通常動作・OBS-6E故障注入の期待値は変更しない。

## 2. 誰が許可するか

試験側だけが受理済みsource frame・feature・問い・operation IDを明示する。
個体ごとのarbiterが、起動時に以下を満たす場合だけProbe権限を発行する。

- 生活側が明示的にidleを申告している。in_flight=falseだけではidleとしない。
- 生活のintent・未解決action・HTTP待ち・結果報告待ちがない。
- 同個体の有効Probeがなく、元frameと身体対応・profileが有効。
- 指定した次回視覚枠が期限内で、台帳と配送予約の容量が残っている。

権限はrun/epoch/agent/operation ID/単調増加generation/有効期限に束縛する。
個体間で共有しない。生活intentの発生時点でProbe権限を失効させ、HTTP応答を待ってから
取り消す方式にしない。Probeは生活を止めるためのロックを取らない。
不許可はnot_executedと理由を返し、暗黙待ち行列や空き待ち再起動を行わない。

## 3. World時計と同時発生の順序

World時計はHTTP送信・callback遅延・応答消失に関係なくglobalstepのdtimeから進める。
wall clockや配送時刻で取得時刻を置き換えず、tick=floor(sim_us/250000)でスロットを決める。
frameにはsample時点のsim_usを記録する。tick境界への丸め戻しをしない。
現行8の評価器はcapture_us=tick×250000を要求するため、そのまま流用できない。
8Bではfloor(capture_us/250000)=sample_tick、sample_tick%4=0、回転完了より後、
かつ回転完了時刻から指定された次枠であることを別規則で検査する。
実取得が枠内でも鮮度・操作期限を超えたら不許可。方向・色の評価条件は8と同じ。
一つのglobalstepで複数tickを跨いでも、過去の姿勢で取得したframeを捏造しない。
最新の到達時点だけを処理し、飛び越した通常枠はmissedとして記録する。
Probeの指定枠を逃したらabortedで終了し、次枠へ移さない。無制限catch-upは行わない。

同一Worldステップでは以下の順に処理する。

1. 時計・身体状態を更新し、配送receiptとcallback受渡しを照合する。
2. 生活intent・優先処理・失効条件を反映してgenerationを更新する。
3. 期限・鮮度・姿勢・位置・profileを検査し、Probeを中断または新規許可する。
4. 有効な生活actionを優先して解決する。Probeが有効な場合だけ、その回転を解決する。
5. 回転結果と身体姿勢を測定し、当該通常取得枠を一度だけ処理する。
6. 取得済みframeの配送を進める。通信開始は次のWorldステップを止めない。

生活intentとProbe取得枠が同時なら生活優先。中断したProbe用に追加sampleを行わない。
生活側が姿勢を変えた後の通常sampleは保存できるが、中断Probeの再取得frameには紐づけない。
既に回転したProbeは元姿勢へ自動復帰しない。最終身体状態と中断理由を残す。

## 4. 取得枠の所有と通信からの分離

通常視覚samplerが(agent, channel, tick)の唯一の所有者。Probeはその枠の利用権だけを予約する。
通常取得とProbe取得で二度呼ばず、一つのframeにoperation参照を外部台帳から結ぶ。
同tickで回転前に取得したframeを再利用せず、回転完了より後の最初の通常枠だけを使う。
Worldが進んで予約枠を過ぎた場合、callbackの到着を理由に遡って取得しない。

8Bでは既存OBS-8のprofileを維持する。生活用fixture-life-sensoryへ許可表を広げない。
まず独立した視覚Probe fixtureに既存RW2の生活intent/action解決経路を接続し、
Aのidle→生活優先への遷移と、Bの生活継続を検証する。
OBS-6Eの全感覚統合へProbeを差し込むことは別段階であり、聴覚や近景の周期変更はしない。

## 5. 遅延応答と失効した権限

callbackは身体を動かさない。送信時のrun/epoch/agent、request ID、generationを結果に紐づけ、
World側で現在の権限を検査してから一度だけ解決する。
失効generationや終了operationの遅い結果は記録のみ。回転・取得・生活actionの再実行をしない。
失効した生活応答も実行せず、生活側が現在状態から新しい観測要求を作る。
Probe側が古い生活actionを取り置いて後から実行することはない。

感覚受付receiptと行動実行権限は独立する。遅い応答でも、その配送に含めたframe IDだけを
accepted確認後にackできる。失効した行動を捨てたからといって、受理済みframeを未受理扱いしない。
receiptはdelivery IDと送信時ID集合に束縛し、新しいin_flightの集合を誤って除去しない。
再送は新しい配送IDに同じframeを載せる。操作IDは維持し、回転や取得回数を増やさない。

身体操作は期限内にsampledで終了し、その時点で身体権限を解放する。
新frameがその後に受理されても、取得時刻が期限内なら過去のProbe評価は可能。
配送待ちを理由に操作期限を延長しない。取得後の生活行動は、保存した取得時姿勢証拠を変更しない。
配送拒否・未受付はdelivery軸に残し、not_reobservedとしない。
取得後の中断要求は終了した身体操作を取り消さず、新しい身体権限の問題として扱う。

## 6. 有限容量と結果の軸

初版の試験は1run最大6秒（24tick）、A/B各1個体、operation台帳最大16件/個体。
個体ごとにHTTP in_flightは1件、callback受渡しは1件、視覚pendingは最大8frame。
送信中もWorld・通常視覚枠は進む。Probe許可時に新frame用1件のpending容量を予約する。
満杯なら新規Probeを不実行。通常sampleを保持できない場合はdropと取得枠を記録し、
既存未ack frameを捨てない。取りこぼしをCOMPLETEな空frameへ変換しない。
HTTPは最大3秒、run終了後の実時間drainは最大5秒とし、超過は試験失敗またはdelivery未完了。
新規起動・身体変更はrun終了で止め、残る配送だけをdrainする。

操作、取得、比較、配送を別軸で記録する。8と同じ評価結果の区別を使い、調停記録として
許可/失効generation、intent発生時刻、予約/実取得tick、callback受信/消費時刻、
回転/取得回数、bodyの最終状態、配送ID別ack集合を追加する。
capacity・busy・失効を「候補なし」「再観測なし」へ変換しない。
永続台帳や再起動越しのexactly-onceは作らず、旧run要求は拒否する。

## 7. 受入試験計画（未実施）

| 条件 | 必須の証拠 |
| --- | --- |
| HTTP callbackを1秒以上遅らせる | 待ち中もsim_us/tick増加、通常視覚取得が進む。取得時刻を配送時刻にしない |
| 元frameの受付が鮮度超過後に届く | 不実行、回転0回。受付の遅さで過去frameを若返らせない |
| 許可前に生活intentまたはHTTP待ち | not_executed。in_flight=falseだけの誤許可なし |
| 回転後・予約枠前に実際の生活intent | Probe中断、再取得0回、生活actionが有効generationで実行 |
| 生活intentと取得枠が同ステップ | 生活優先、Probeと通常samplerの二重取得なし |
| 取得後に生活が身体を動かし、後から受付 | 取得時姿勢で評価。現在姿勢へ書き換えない |
| 旧generation応答を新要求の後に消費 | 旧身体作用0回、配送ackは旧deliveryのIDだけ |
| 操作結果消失・frame応答消失・再送 | 回転/再取得各最大1回、new_frames=0の受理、期限不変 |
| 大きなdtimeで予約枠を飛び越す | 中断、過去sample捏造なし、次枠への移替えなし |
| pending満杯・台帳16/17・run終了 | 有限拒否、未ack保持、drainによる新規身体作用なし |
| AでProbe競合、BでFood取得・帰還・deposit | 個体別排他、B完了、Aも中断後に生活へ戻れる |
| OBS-8・7B・6E・4C・遠景回帰 | 基準を維持。全行動列の一致は成功条件にしない |

遅延・消失はcallback受渡しの故障注入から始める。実ネットワーク切断とは呼ばない。
実Luantiの時計・身体・生活action・取得・実Runtime受理と、合成境界試験をEvidenceで分ける。
実装はこの調停までで停止し、自律起動、7B接続、意味判断、移動Probe、canonical接続は追加しない。
