# Luanti L12 — 本人の経験から採用した利用関係による警告差

**状態: IMPLEMENTED / FINITE ACCEPTANCE COMPLETE / v1、2026-09-27。**
実装・検査の記録は[L12 Evidence](../experiment-evidence/LUANTI_L12_learned_resource_use_relation_evidence.md)を参照。
基準はGameAI `ab82590d`（L11）＋`5ea508b`（Core参照同期）。
意味基準は[semantic reference](../semantic-reference/RDL_Core_T0_T1_reference.md)のCore `86a0d4f3`、
BASE v2.3.1 / SPEC v2.5、T1展開・検査選別・再構成。

関連: [L10のM_B採用経路](LUANTI_L10_sensory_learning_action_contract.md)、
[L10Cの共有資源](LUANTI_L10C_shared_food_learning_contract.md)、
[L11の有限警告](LUANTI_L11_boundary_defense_contract.md)、
[自己との関係拘束モデル](../design/RDL_GameAI_自己との関係拘束モデル.md)。

## 1. 問いと学ぶもの

**この相手がこの餌場で1単位を取得した後、定めた次の試行枠で本人の取得が成立する、
という関係を本人の独立Experienceから形成・検査・M_Bへ採用すると、次の同じ利用に対する警告が変わるか。**

「自分の継続利用と両立する」を初版では**次の1回の本人pickupの成立**へ限定する。
長期資源維持、栄養、利益の公平性、所有権、親密さ、相手の意図を推定したとはしない。
相手との関係は、この用途・餌場・行為・本人の試行条件に限る予測可能な対応である。

```text
相手の実pickupについての本人向けbounded通知
＋ その後の本人の実pickup試行・結果
→ 本人のExperience（1 Episode = 最大1支持）
→ 3形成Experienceの共通relation候補
→ 未使用の3 Experienceで検査
→ T1-A / B / C → inactive M_B' → 明示cutover
→ 新しい使用通知をactive M_Bで解釈
→ 明示した局所consumerが警告閾値へ有限に反映
→ LuantiのWARNING表示
```

初期に与えるのは、餌場を継続利用の対象とする固定条件、観測・試行手順、形成・検査基準、
予測を警告へ使うconsumerの規則。学習対象の予測値、親子／友人ラベル、`beneficiary_inclusion`は与えない。
履歴回数を直接inclusionへ書き込まず、候補の支持数だけで行動を変えない。
今回の固定基準で採用した関係から演繹的に適用する。基準自体の学習は範囲外。

## 2. 専用World装置と本人の経験

1runは同じWorldのA/B、一つの餌場、最大7独立Episode。学習者がobserver、他方がactor。
A/Bの役割を交換した別runも行う。学習者だけがこのrunのExperience・T1・M_Bを持ち、他方へコピーしない。
同一個体が複数の相手を同時に学び分ける試験はまだ行わない。相手参照は適用範囲の束縛として検査する。

- 各Episode開始時、Foodは1単位、双方の手持ちは空、位置・姿勢・身体条件を同じにする。
  observer位置を原点、actorとFoodを相対1nodeに置き、両者の固定pickup範囲1.25以内とする。
  並進・衝突競争は追加しない。絶対座標はWorld Evidence専用。
- profileはA=`fixture-life-sensory`、B=`fixture-life-sensory-compact`、revision 1。
  現行の近景半径は双方12。profile/clock/取得姿勢参照を本人別に保持する。
- 相手はFoodを実pickupし、entityを除去してその単位を手持ちに移す。
- 正例を作る装置条件では、相手が**取った同じ単位を餌場へ戻す**。手持ちから減らし、同じ単位参照で
  entityを一度再配置する。負例条件では、相手は手持ちに保持する。
  これは摂食後の復活でも無からの補充でもない。各時点で単位が存在する場所をWorld台帳で一意に追う。
- 本人は指定枠に必ず1回pickupを試みる。Foodが存在すれば実remove＋本人手持ち増分、なければ空振り。
  自分が試していない、結果欠落、取得状態不足、通信期限超過を非取得の経験へ変換しない。
- Episode終了後にだけ装置を初期化する。run内で本人の受理済み記録・M_Bと継続時計は保持し、run間は分離。

相手の返却／保持は実験者が有限にスケジュールする行動であり、相手も自律学習したとはしない。
この条件はactor実行器とWorld Evidenceにのみ渡し、予測・候補形成・検査の入力には渡さない。
候補が説明するのは同じ装置下での経験的対応であり、相手が親切だから成功したという原因同定ではない。

## 3. 時刻と取得の契約

Episode開始barrierで設定・参照登録を完了し、次の250000µs境界をTとする。
World時計はHTTP待ちでも進む。各身体作用は指定時点から250000µs未満の枠で最大1回、逸失時は中断。

| 操作 | 固定した枠 |
| --- | --- |
| 相手のpickup＋本人向け前後局所packet | T |
| 相手の返却（返却条件だけ） | T+1500000µs |
| 本人のpickup試行＋直接参加結果 | T+2000000µs |
| Episodeの結果受付期限 | T+3000000µs |
| 次Episodeの開始 | 現Episodeの結果受付と作用の終了後。前Episodeの不足を次へ持ち越さない |

警告判定へ使う現在入力は相手のpickup時に凍結する。まだ起きていない返却、本人の将来結果を先取りしない。
使用通知の新規受理は実取得から500000µs以内、警告開始は実取得から1000000µs以内。
返却はその後なので、警告判断は返却前の材料だけを使える。期限超過を静観としてPASSにしない。
開始前待機も含め、1runは最大35秒、EpisodeごとのWorld実行は最大3.5秒。

相手のpickupはL11と同じ`fixture-instrumented-local-use-v1`の本人向け通知を入口とする。
SensorFrameの件数からactorを同定する処理は追加しない。未登録参照、範囲外、部分取得は`unavailable`。
Food単位・actor・siteの識別は装置内の明示登録に限定し、一般的な物体追跡や個体認識とはしない。

本人の結果は別の直接参加receiptとし、本人operation/event、Episode、試行取得時刻、
対応する使用notice、単位取得の成否、実取得状態・出典を結び付ける。
World台帳の絶対位置、相手の手持ち全量、返却予定、scenario名、親密度の正解は含めない。
同じEpisodeのnotice・本人結果・返却は独立した3経験に数えない。

## 4. Purpose / B / 適用条件

専用の型と目的:

- Purpose: `predict-own-pickup-after-peer-use`。
- context: `l12-return-or-hold-apparatus-v1`。
- relation kind: `resource-use-continuation-v1`。
- 予測次元: `own_food_acquired`、取得成立1／完全な試行で非取得0。
- source kind: 計測された本人向け局所通知＋本人の直接参加結果。遠景色や聴覚候補は今回は選択しない。

適用境界にrun/epoch/observer/actor/site/action、profile ID/版、adapter版、clock、
本人の固定試行手順・相対時間枠・装置contextを含める。現在入力にも同じ境界の登録参照を要求する。
許可された手順そのものは既知の実験条件だが、その回の返却／保持と将来成否は条件キーに含めない。
別相手・別餌場・別行為・別profile・別runへ一般化しない。

段階ごとに`RIB_B`を明示取得する。beforeは相手の現在利用を条件とする予測、afterは本人の試行結果の解釈。
元packetをそのままM_BやRIB_Bと呼ばず、選んだ次元、coverage、時刻、姿勢、元IDを持つ断面を作る。
sourceの欠落／比較不能は値0にしない。

## 5. 形成・未使用検査・T1採用

各runで形成3件と検査3件をIDリストで明示指定する。Episode番号・名前で学習器がphaseを推測しない。
形成用・検査用のEpisode/元event/本人operationを分離し、ID付替えでも同じ作用を両集合へ入れない。

| 状況 | 判定 |
| --- | --- |
| 完全な形成3件の結果が全て同じ | その値を予測する候補を1件生成、formation_support=3 |
| 形成3件が不一致、または必要な証拠不足 | 候補を実行可能にしない。理由付き`no_candidate / formation_unavailable` |
| 形成候補に対し検査3件が全て比較可能・一致 | RETAIN、validation_count=3 |
| 検査3件が全て比較可能・1件以上不一致 | REJECT |
| 検査集合に未試行・取得不足・条件不一致がある | DEFER。比較できた一致／反例は個別診断へ残す |

検査不足で分母を減らさない。要求件数`validation_requested=3`と実際の比較可能件数を別記録し、
不足時は`validation_count=null`でDEFERする。全3件を比較できた場合だけ`validation_count=3`。
形成支持3と検査3を支持6へ合算しない。
本人の成功だけでなく、非取得3件→未使用非取得3件もRETAINする。**負の予測を採用することと候補REJECTは別。**

正式な採用は既存T1-A/B/Cとcutoverを使う。全材料のdispositionを明示し、current M_BはparentとしてRETAIN、
候補は上の検査結果、他の材料は初版の範囲に応じて理由付きDEFERとする。
RETAINなしではinactive artifactもcutoverも作らず、既存モデルと診断を保持する。
RETAINありでもinactive artifactだけでは予測・警告に使わない。

**M_deltaへの入口は自律化しない。** 既存L10と同じ明示review経路を使う。
最初のEpisodeの相手pickup前後に実取得した本人のcount packetを、同じcount用M_Bで比較する。
`visible_objects_count: 1→0`の差について、harnessがこの有限装置の未吸収残差1を明示reviewする。
他のzero次元はzero。既存base_theta=1、調整なしでH=1→M_deltaへ入る。
このreview規則は実験者が宣言した入口条件であり、Food消失が普遍的に不快・未吸収だという規則ではない。
誤った個体/model/assessment、未review、M_delta不成立ならT1入口を拒否する。

Experienceの成否・候補支持数・警告回数・L11 loadをHへ加えない。
候補がないrunもcanonicalの状態を勝手に巡航へ戻さず、未再構成として区別する。

## 6. 学習した予測と警告consumerの分離

`FrozenGameAIMB`に用途限定の`interpret_resource_use(section)`を追加する。
学習器が外部の別テーブルから既知結果を引いてM_B出力を名乗る方式にはしない。
active M_Bの採用済みtyped relationだけを使い、旧色relation・NERV/SOCのCandidateへ実行権限を付けない。

取得条件が完全だが未採用なら`unknown / values=null`。
採用済みの一致するrelationがある場合だけ`known / own_food_acquired=0 or 1`とその出典を返す。
異なる有効relationの衝突や適用条件不足では`unavailable`として、黙って一方を選ばない。

初版のconsumerは次の固定規則:

| M_Bの出力 | 局所反応へ渡す調整 | 記録上の区別 |
| --- | --- | --- |
| known / 次の本人取得1を予測 | 基準3へ+8、有効閾値11 | `learned_continuation_allowance` |
| known / 非取得0を予測 | 調整0、有効閾値3 | `learned_noncontinuation` |
| 完全な現在通知だがunknown | 明示的な初期規則、調整0・有効閾値3 | `baseline_unlearned`。非取得予測ではない |
| 現在通知不足／条件外／relation衝突 | 評価しない・許可なし | `unavailable`。正常な静観ではない |

この+8を学んだとはしない。予測をどこまで許容へ使うかはGameAI設計側の規則である。
既存L11の`beneficiary_inclusion`は固定関係用の別契約として維持する。
L12では上記の用途限定調整として名付け、親しい／親子／包含対象だと認定したとはしない。

増分4・毎秒1の解消・整数micro-unit・250000µs警告表示はL11と同じ。
本試験の反応区間は新規notice1件、load初期0、最大1許可／1実表示に絞る。
形成・検査中は明示的に反応実行を無効化し、履歴取得と現在反応の切替をscenario結果から決めない。
現在反応区間の開始はharnessが明示し、以後はモデル・基準・負荷初期値を凍結する。

反応receiptに元notice、RIB_B、frozen model_ref、採用relation/candidate、T1 selection/artifact/cutover、
consumer版、調整理由、増分・load・閾値を残す。要求側からinclusion・予測値・閾値調整を上書きできない。
L11の設定凍結を緩めず、L12専用opt-in adapterで純粋な評価stepとWorld表示controllerを再利用する。

## 7. 同じ現在利用での対照と再入

以下6scenarioをA=observer/B=actorとB=observer/A=actorで行う。
**受入規模は12独立run×7Episode=84Episode。主runは各7回の相手pickupと7回の本人試行。**

| scenario | 形成3件 | 未使用検査3件 | 採用 | 現在利用の予測 | 単発WARNING期待 |
| --- | --- | --- | --- | --- | --- |
| positive_active | 取得3 | 取得3 | RETAIN→cutover | 取得1 | なし（閾値11） |
| positive_inactive | 同上 | 同上 | 同じRETAIN→inactive止まり | unknown | あり（閾値3） |
| negative_active | 非取得3 | 非取得3 | 負の予測をRETAIN→cutover | 非取得0 | あり（閾値3） |
| negative_inactive | 同上 | 同上 | 同じRETAIN→inactive止まり | unknown | あり（閾値3） |
| heldout_counterexample | 取得3 | 取得2＋非取得1 | REJECT、cutoverなし | unknown | あり（閾値3） |
| heldout_incomplete | 取得3 | 取得2＋取得証拠不足1 | DEFER、cutoverなし | unknown | あり（閾値3） |

`heldout_incomplete`は実Worldでは返却・本人pickupを行い、1件の本人向け結果取得を故障注入で不完了とする。
そのWorld成功を後から学習入力へ補填しない。実際の身体成功と学習に使用可能な証拠を分けて記録する。

第7Episodeの初期Worldと相手の行動列は**全scenarioで同じ**にする。
相手がpickup→T+1.5秒枠で返却→本人がT+2秒枠で試行する。警告を相手の予定へ反映しない。
以前の返却／保持の差だけからモデルを形成し、現在の成否・scenario名を予測へ先渡ししない。

独立run間のID・実時刻は異なるため、wireが文字通り同一とは主張しない。
これとは別に、同じ受理済み形成・検査・現在noticeを二つの再生instanceへそのまま渡し、
cutover有無だけを変える対照を必須にする。反応計算の入力となる現在断面・履歴・局所定数が完全に同じで、
active modelと採用出典だけが異なることを検査する。inactive artifactへ行動権限を渡す抜け道を作らない。
名前変更対照は参照を一貫して付け替え、予測・判定・閾値・表示回数の不変性を検査する。
IDから生成するartifactハッシュ自体の一致は要求しない。

現在の本人結果は、判断時の同じ更新前M_BによるF/F'比較として保存する。
positive_activeは1→1でE=0、negative_activeは0→1でE=+1を期待する。
unknown側は`not_comparable / E=null`、不完全な結果も数値0にしない。
採用した非取得予測が外れ得る対照を含め、学んだ相手の性質が普遍的真理になったとはしない。
この補助境界のEは記録までとし、count用Hや二回目のT1へ自動投入しない。

## 8. 一回性・容量・途中失敗

- 1run最大8 Episode資料、32 bounded packet、8使用notice、8本人結果。主比較は7 Episode。
  前後packetは相手pickup用2＋本人試行用2で各Episode4件、計28件。count比較は同じ受理済みpacketを参照する。
  上限超過は明示拒否。古い経験や不足資料を黙って削らない。
- 1runの形成要求・T1 bundle・再構成・cutoverはそれぞれ最大1系列。完全再送は既存結果を返す。
  phaseごとの中断状態と既存T1記録を保持し、途中失敗を採用完了と返さない。
  同一要求の再開は凍結済みの同一出典を使い、別bundleや別artifactを足さない。
  cutover成功までは親M_Bを維持し、補助の警告設定だけが先に切り替わる状態を公開しない。
- 結果のidentityはrun/epoch/observer/Episode/operation/eventを束縛し、同eventの別名登録、
  形成／検査の重複、他個体・別site・別行為への付替えを拒否する。
- 短いcallback遅延・受理後応答破棄→同通知再送を少なくとも1実runに入れる。
  再送でExperience支持・load・閾値・警告・cutoverを増やさず、元時刻・期限を更新しない。
- 警告のcallbackは受渡しだけ。World stepでscopeと期限を確認し、副作用前に権限消費。
  許可数と実表示数、表示readbackと消去、旧／他個体callback拒否をL11と同様に記録する。
- 35秒のrun期限や指定作用枠を逸失した主runは未完了として落とす。quiet結果へ集計しない。
  永続化・任意のネットワーク故障・再起動保証は追加しない。

## 9. 実装単位と受入

実装ファイル:

- `runtime/resource_use_learning.py`: 本人資料の受付、断面取得、形成・独立検査、T1 binding、反応consumer。
- `FrozenGameAIMB.interpret_resource_use`: typed relationの有限解釈。count解釈・L10色境界は維持。
- `resource_use_fixture.lua` / `resource_use_trial.lua` / `resource_use_checks.lua`、`test-resource-use-learning.ps1`。通常modeと同時起動しない。
- `check_resource_use_learning.py` / `capture_resource_use_learning_replay.py`、`tests/fixtures/luanti_l12_replay.json`。
- `/v1/resource-use/{configure,observe,record,review,learn,begin,result}`とread-only snapshot。
- Python/Lua局所試験、無改変の受理済み要求・結果の再生JSON、実機Evidence。

受入項目:

1. 12runの84 Episode、同じ単位のpickup／返却／本人取得の保存則と実結果を確認。
2. 同じ初期条件で返却／保持から本人の異なる経験を取得。未来のWorld条件・正解ラベルを予測へ渡さない。
3. formation_support=3とvalidation_count=3を分離。再送・別名event・未試行で支持を水増ししない。
4. 取得／非取得の候補を対称に検査し、RETAIN・REJECT・DEFER、unknown、取得不能を区別。
5. 既存のM_delta→T1-A/B/C→inactive artifact→cutover→fresh re-entryをprovenanceで追える。
6. positive active/inactiveで同じ現在利用に対する実WARNING差。作用前のfrozen予測と許可・表示を照合。
7. 同一記録再生のcutover対照、役割交換、Episode/actor/site名変更で、名前や順番による答えの分岐を排除。
8. 負の予測の反例を同じM_BのE=+1として保持。反応負荷・H・次のT1へ自動変換しない。
9. 部分取得、scope違い、支持不足、期限・容量、途中失敗、応答消失と旧callbackの局所・実機検査を区別。
10. 全体Python、L11全26run、L10C全5scenario、OBS-9 faultsの実機回帰。
    共通M_B解釈・cutoverを変更するためL10全3対照とL10B全3scenarioも実行。

受入10項目は有限な契約範囲でPASS。専用26試験、実Luanti12run・84Episode、全体655件=604 PASS＋51 skip。詳細と既存回帰はEvidenceに記録する。断面には実取得µs、姿勢、各入力coverage、元packet/event ID、選択次元を残す。

## 10. 停止境界

到達目標は「本人の経験から形成・独立検査して採用した用途付きrelationが、同じ現在利用への有限反応を変える」。
親密さや所有を認識した、生得的な防衛が学習で完成した、警告によって相手を制御したとはしない。
未経験の相手・場への一般化、NERV由来のSelection傾向、関係の長期変動、失敗後の再学習循環、
自律review／睡眠、全感覚生活への常設統合は別契約とする。
