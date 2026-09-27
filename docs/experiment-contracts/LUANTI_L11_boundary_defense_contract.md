# Luanti L11 — 関係条件と反復間隔による有限な境界防衛反応

**状態:** IMPLEMENTED / ACCEPTANCE PASS / v1、2026-09-27。
実Luantiの主比較24run・56 pickup、同席・範囲外の対照2runを実施した。
以下は固定契約であり、実測結果・再現手順・検証範囲は[Evidence](../experiment-evidence/LUANTI_L11_boundary_defense_evidence.md)に記録する。

**基準:** GameAI `2727ebb7`（[L10C](LUANTI_L10C_shared_food_learning_contract.md)受入完了）。
Eの呼称はCore [`86a0d4f3`](https://github.com/Aporapeiron/RDL_Core/tree/86a0d4f3b83c0d08cd8bd6eba0b1ea70a637bd33)
のSPEC v2.5「差」に合わせた。L11自体は参照pin・canonicalの計算・schemaを変更しない。
L11完了後、[semantic reference](../semantic-reference/RDL_Core_T0_T1_reference.md)は独立した名称・参照同期として同Core版へ更新した。

関連: [自己との関係拘束モデル](../design/RDL_GameAI_自己との関係拘束モデル.md)、
[既存Territory Beast](TERRITORY_BEAST_world_contract.md)。
既存beastのWorld側warning→chase→attack表は、この実験の反応器として再利用しない。

## 1. 問いと停止点

**同じ餌場への同じ取得行為でも、使用者との関係と反復間隔によって、本人の警告の出方が変わるか。**

初版は、固定した関係条件と固定反応profileを、現在の干渉評価・残存・警告へ接続する機構試験とする。
「子供」「他人」「所有者」というラベルから行動を直接選ばない。初期関係を与えたことを、経験から
関係を学んだ結果とは呼ばない。生物の本能・感情・親子関係を再現したという主張もしない。

明示的な未来予測を起動条件にせず、現在の知覚された利用に対する評価から反応できる経路を試す。
学習済みM_Bによる予測から応答を調整する経路、関係自体の形成・改訂は後続の別契約とする。
既存L10Cの学習経路と並べて検査可能な局所機構であり、canonical M_Bの外に新しい推論系を完成したとは扱わない。

## 2. 同じWorld条件と、独立に変えるもの

- 同じLuanti WorldにA/Bと一つの餌場を置く。1runでは一方がdefender、他方がuser。
- defenderは並進せず、userが近景範囲内でFoodを1単位ずつ実取得する。初版の「使用」はpickupによる
  entity除去とuserの取得済み数の増加で定義し、摂食・栄養・空腹解消はモデル化しない。
- 1回の使用につき一つの実Foodを配置し、次の予定使用枠でだけ次のFoodを補充する。警告や通信に応じて補充しない。
  1runは最大3単位。単発条件は1単位だけ。各単位の生成・除去・取得増分をWorld Evidenceで照合する。
- 使用直前のFood量、相手の動作・位置・距離、本人の身体条件、餌場との結びつきは同じにする。
  累計取得数は記録するが、評価量・閾値の入力にはしない。
- profileはA=`fixture-life-sensory`、B=`fixture-life-sensory-compact`、revision 1。
  両profileでactorと資源が取得範囲に入る固定配置を使い、agentごとの取得条件を保存する。
- relation/profile/間隔を指定した各runは独立に初期化する。通信待ちでもWorld時計を進める。
- 主比較をA=defender/B=userで行い、同じ12条件をB=defender/A=userでも繰り返す。
  役割交換では取得時の相対配置を同じにし、名前・entity登録順に対する分岐を検査する。

使用者は試験側の同じ有限スケジュールで動く。警告後も予定の使用を続け、反応器への入力列を保つ。
今回検査するのは本人が警告を出したことまでであり、相手が意味を理解した、従った、餌場を防衛できたとはしない。
既存Food生活の同時競争、自由な採食選択、恒常的な複数個体社会は受入範囲に含めない。

## 3. 誰が使用したかを取得する境界

現行の近景SensorFrame payloadは`visible_count`のみ。件数の減少や近くにいる相手だけから、
「この相手が取った」と推定してはならない。遠景・聴覚の特徴から個体同定を補完することも禁止する。

初版では、**専用fixtureの近景範囲内の使用観測通知**を新たに用意する。
Luantiの実pickup adapterが、作用直前・直後の本人向けbounded packetを取得し、実際に成立した
1単位取得を、その場で可視参照へ結び付ける。これは汎用的な視覚行動認識ではなく、
実験装置が取得動作を計測する専用adapterである。通知を既存SensorFrameへ偽装しない。

| 通知の記録 | 制約 |
| --- | --- |
| scope | run / epoch / observer / clock / notice ID / 実作用event ID |
| 参照 | 観測したactor、餌場、今回のFood単位のfixture-local参照。明示登録の出典を保持 |
| 取得 | capture_us、順序seq、profile/revision、取得時姿勢参照、before/after packet ID |
| 作用 | `observed_unit_taken`、単位数1。実作用が成立した場合だけ生成 |
| coverage | actorと作用前の資源が本人の近景半径内、actorが作用後も範囲内、関係づけを記録できた状態 |
| limitations | `fixture-instrumented-local-use-v1`。既存近景と同じ半径条件で、一般的な遮蔽・行動認識能力を主張しない |

同一World stepの前後取得は同じcapture_usでもよいが、before→作用→afterの順序を記録する。
両packet、成立した作用、通知を別々に保存し、Runtimeで参照の一致・既知のscope・完全性を検査する。
通知内へ世界座標、隠れた意図・所有・親子タグ、親密さの正解、勝者ラベル、相手のM_Bを入れない。
固定relationは別途登録した初期条件として参照し、感覚取得の成果に混ぜない。

観測範囲外・作用不成立・参照不足・取得不完了では「侵害なし」や負荷0の正常観測を捏造せず、
`unavailable`と理由を記録する。部分的な入力は評価・警告権限へ進めない。
単なる同席・接近だけでは通知を作らない。未観測の使用を後からWorld Evidenceで補填しない。
Observation v1は完了基準を維持し、この通知を新しい汎用感覚やv1の追加必要条件にはしない。

## 4. 二つの関係と局所反応profile

起動時に、版と出典を持つ読み取り専用のfixture設定を登録する。

1. **本人↔餌場**: この有限試験中、継続利用を維持する対象。全条件で同じ。
2. **本人↔使用者**: この餌場の取得行為に限る受益者の包含条件`beneficiary_inclusion`を0または1とする。
   0は包含なし、1は非常に深く結びついた相手による利用を許容する条件の操作的代替。

scopeは`(run, defender, actor, resource_site, observed_unit_taken)`。汎用好感度ではなく、
この行為に限る関係条件とする。0を敵意、1を全行為への許可とはしない。
登録がない相手は0へ補完せず`unavailable: relation_unconfigured`。
関係値・profileはrun中に変更せず、同IDの設定変更を拒否する。

reaction profileは`lower_threshold` / `higher_threshold`の2条件。
名前は表示であり、同じ数値設定なら名前を変えても結果は一致する。
生得性・DNA・NERVパラメーターからの導出は今回扱わない。

## 5. 現在評価・残存・閾値を別に記録する

初版では**関係を変えても1回の評価量と減衰率は変えず、警告閾値だけを変える**。
評価量・残りやすさ・閾値を同時変更して、「なぜ反応しなかったか」を不明にしない。

| 項目 | 固定値・計算 |
| --- | --- |
| 局所状態 | `defense_load`、開始時0。意味はこのfixtureの防衛反応用の残存評価量 |
| 有効な1単位使用 | `appraisal_increment = 4` |
| 解消 | 取得時刻間の実経過1秒あたり1、下限0 |
| 基準閾値 | lower=3、higher=9 |
| 関係の作用 | `warning_threshold = base_threshold + 8 * beneficiary_inclusion` |
| 判定 | 更新後のloadが閾値以上、かつ当該runで未発行なら警告許可を1件発行 |
| 警告後 | loadを強制リセットせず、その後の観測も記録。追加警告は出さない |

```text
before = max(0, previous_load - elapsed_seconds)
after  = before + appraisal_increment
warn_eligible = after >= warning_threshold
```

内部は1単位=1000000の整数で保持する。解消量は経過µsと同数の内部単位なので、
World step分割やHTTP順に依存する丸めを入れない。更新時刻は通知の取得時刻であり配送時刻ではない。
毎tick再加算せず、異なる有効な作用eventを一度ずつ扱う。時間を巻き戻す通知は拒否する。

各記録に、取得事実、適用関係、profile、増分、経過時間、解消量、更新前後load、
有効閾値、閾値到達、警告許可、World実行結果を分離して残す。

**`defense_load`はCoreのHではなく、この閾値はCoreのθではない。**
直接の「嫌」の操作的評価をEへ変換せず、E/H/assessment/M_delta/T1を自動生成しない。
将来、予測した使用条件と後続解釈を比較してEを扱う場合は、同じ更新前M_Bと比較条件を別途固定する。
現行の不快系の反応、Eの検出、保持限界による再編は別々に観測できるものとしておく。

## 6. 実Luanti比較の固定条件

共通の開始時点T以降、下記の予定枠をWorldで実行する。T前に設定・参照登録を完了し、
以後の使用スケジュールをHTTPの成否や警告で動かさない。各予定時点から250000µs未満の枠内で
最大1回実行し、枠を逸失したrunは不成立とする。取得時刻は実際のsim_usを残し、予定時刻へ丸めない。

| 入力列 | 予定使用時点 | 予定時点どおり取得した場合のload計算例 |
| --- | --- | --- |
| single | T | 4 |
| dense | T, T+250000µs, T+500000µs | 4, 7.75, 11.5 |
| spaced | T, T+5000000µs, T+10000000µs | 4, 4, 4 |

実機のloadは実取得間隔から再計算して検査する。spacedは最大の枠内遅延があっても
前の4単位が解消する間隔、denseは同じ許容遅延内で下表の到達順が変わらない間隔とする。

次の表は**警告を許可する最初の使用番号の期待値**。`—`は取得を完了したうえで閾値未到達。
実行遅延や失効で警告できなかったケースは`—`へ混ぜない。

| relation | profile | threshold | single | dense | spaced |
| --- | --- | --- | --- | --- | --- |
| inclusion=0 | lower | 3 | 1 | 1 | 1 |
| inclusion=0 | higher | 9 | — | 3 | — |
| inclusion=1 | lower | 11 | — | 3 | — |
| inclusion=1 | higher | 17 | — | — | — |

**2関係×2profile×3入力列×2役割配置=24独立run、計56回の実使用**を受入対象とし、実行済み。
包含された相手でもlower/denseでは閾値へ達し、親しい相手を無条件免除しないことを確認する。
数値は機構を見分けるfixture設定であり、動物の反応量や生物学的閾値の推定値ではない。

## 7. 警告権限・配送・有限予算

警告はNPCの有限な表示動作とする。World側で250000µsのwarning表示を設定し、entityの
表示状態のreadbackと実行時刻を保存する。logを出すだけ、JSONで成功を返すだけでは実行PASSにしない。
威嚇音の伝達、相手の意味理解、追跡、攻撃、負傷、強制退避を追加しない。

- 評価器はRuntime、身体・表示の実行はLuanti World step。HTTP callbackは受渡しだけ。
- 最大1警告/run。許可はrun/epoch/defender/actor/site/notice/operation IDに結びつけ、
  本人・参照・期限をWorld側で再検査し、副作用前に消費する。
- 通知は取得から500000µs以内に新規受理。警告の実行期限は元通知の取得から1000000µs。
  再送で取得時点・期限を更新しない。
- 同じ通知の完全再送は同じreceiptを返し、load・event数・警告を増やさない。
  同IDの内容変更、他run/observer/actorへの付替えは拒否し、公開状態を部分更新しない。
- 完全再送は新規受付期限後でも既存receiptを返せるが、Worldで期限切れの作用は実行しない。
  応答消失後の再送と、実行後の旧callback再注入を別に検査する。
- 通知が順序逆転した場合は後着の古い未受理通知を拒否し、過去へ巻き戻して計算し直さない。
  主比較に欠落・順序拒否・期限超過があればrun不成立。取得不能を正常な静観として集計しない。
- 初版の有限storeは最大8通知・最大1警告許可/run。容量超過は明示拒否し、古い記録を黙って捨てない。
  台帳はprocess内のみ。再起動をまたぐ一回実行保証や一般ネットワーク回復は範囲外。
- T以後のWorld実行は最大12秒、配送後処理を含むrunは最大17秒。待機でWorld時計を止めない。
- 食物取得数、評価イベント数、警告許可数、警告実行数を別々に照合する。
  警告が失効しても評価済みの事実を消さず、`threshold_reached / action_expired`を記録する。

取得・警告・結果の入出力とWorld Evidenceを分けて保存し、前者だけでRuntimeの再生ができるようにする。
World内部座標や予定する期待結果を、再生評価器の補助辞書へ渡さない。

## 8. 実装単位と受入項目

実装ファイル・入口:

- `runtime/boundary_defense.py`: 型・参照検査、純粋な評価step、有限store、警告許可。
- `runtime/bridge.py`: 明示opt-in modeと隔離snapshot/通知/結果入口。既存学習modeと同時起動しない。
- Luanti `boundary_defense_fixture.lua` / `boundary_defense_trial.lua`: 実Food作用、本人向け通知、
  継続時計、有限警告実行、World Evidence。既存shared Food制御の一回性設計を再利用する。
- 専用起動・検査script、Python/Lua局所試験、実取得通知の無改変再生fixture。

以下を受入項目として固定する。全項目の確認範囲をEvidenceで区別し、Python・代替adapterのLuaを実World試験と混同しない。

1. 24runで予定した関係/profile/間隔/役割の対照を取り、56回の実取得と個別通知を対応づける。
2. 同じ作用列で評価増分・減衰が一致し、関係差は閾値だけに作用する。
3. 単発・累積・時間による解消の期待表を満たす。包含ありでも頻繁な使用に反応する条件を残す。
4. 単なる同席、Foodを取らない動作、actor範囲外、部分取得、未登録relationから警告を捏造しない。
   局所試験に加え、同席・範囲外は専用World対照runを各1件行う（主比較24runとは別集計）。
5. 名前・Episode番号・relation/profile表示名の変更で選択が変わらず、A/Bの役割を交換しても式に従う。
6. 実警告表示は最大1回。許可だけ・失効・静観・取得不能・未完了を区別する。
7. 通知・callback・結果の再送、応答消失、古い/他個体の応答で負荷や表示を重複させない。
   少なくとも1主runに受理後応答破棄→同通知再送→new_event=falseを含める。
8. 閾値の等号、解消後0、時間逆転、期限・容量・異なるscope・同ID改変をPython/Luaで検査する。
9. 同じ既存packet列について機構の有無で旧Action/InteractionHistory/canonical/NERV/T1の状態が一致する。
   Worldが変わった別入力同士の全状態一致は要求しない。
10. 全体Python試験とL10Cの5scenario実機回帰、OBS-9 faults実機回帰を通す。
    共有した既存モジュールを変更する場合は、その変更に対応するL10/L10B等の回帰も追加する。

上記10項目は有限契約内でPASS。Python23試験、Lua36アサーション、実Luanti26run、
未改変の通知・HTTP応答・World記録の再生を保存した。全体629件=578 PASS＋51 intentional skip。
警告はentityのnametagを`WARNING`へ設定し、250000µs後以降の最初のWorld stepで消去する。
表示開始・消去ともObjectRefのproperty readbackを検査する。クライアント画面の描画や相手の理解は受入対象外。

HTTPは`--boundary-defense --sensory-run-id RUN`で明示起動する。
`/v1/boundary-defense/configure`・`observe`・`result`と`/v1/boundary-defense-snapshot`を隔離し、
既存学習modeとの併用を拒否する。noticeの不足を`unavailable`として保存する場合も順序と容量を消費するが、
負荷の解消時刻は最後の有効な評価から計算する。`unavailable`で時間経過を消さない。

## 9. その次に学習へ戻す条件

次工程は[L12契約](LUANTI_L12_learned_resource_use_relation_contract.md)で具体化・実装した（有限受入完了）。
本人の次回取得を予測する用途付き関係を使う。以下のL11停止境界と固定関係機構は維持する。

L11で固定関係による反応差を確認した後、本人の独立した利用・干渉・相手との相互作用のExperienceから、
どの関係を形成・検査・採用するかを別契約で定める。形成用と未使用検査用を分け、同event再送で支持を増やさない。
採用前後で、同じ現在観測に対する評価または閾値が変わったかを検査する。

今回の`beneficiary_inclusion`を、経験回数に応じて直接書き換える「学習」にしない。
NERVの感度、T1-Bの選別傾向、CoreのE/H/θ、警告の局所閾値を自動接続しない。
所有・親子・社会的意図の同定、自律注意、一般Goal/Trajectory、関係の長期学習は、この停止点の先にある。
