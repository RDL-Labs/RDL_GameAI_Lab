# 設定経路（撤去予定のテスト用処理）

`predator_cognition_parameters.jl`：動物単独 `--cognition` の候補初期値・区間・記憶上限。
選択と結果学習は人と同じBasicLoop/MethodNode等を使用。自己位置の正確な記憶、
休息の仮効用、固定区間、威嚇上限は残る。通常LWは既定OFF。
流用範囲・未接続部分は `experiments/lw_wildlife/predator_cognition_report.md`。

`predator_marking.jl`：動物単独の `--marking` のみ、既定OFF。
自他の匂い識別、設置/観測間隔、匂いによる回避と記憶帰路を暫定固定で試す。
世界の匂い表と個体の観測記憶を分離。将来は身体需要と経験MBへ置換する。
条件・未実装部分・10日ON/OFF結果は `experiments/lw_wildlife/animals_only_report.md`。

`predator_animal_trial.jl`：動物単独ランナー専用・通常LWは既定OFF。
食料相当量による狩猟/休息と、固定中心への接近度による威嚇/撤退を試す。
瞬時摂食、固定閾値、初期縄張りを使用。将来は身体・経験MBへ置換する。
条件と限界は `experiments/lw_wildlife/animals_only_report.md` を参照。

`wildlife_predation.jl`：`wildlife.predator_count=1`（既定0）で既存捕食FSMをLWへ接続。
観測された兎の追跡・接触捕食・固定休息。人への攻撃、捕食者の身体需要・繁殖は未実装。
`wildlife.predator` と `predation_deaths` へ記録する。将来は身体需要と観測・記憶MBの選択へ置換。
詳細は[野生動物設計](../../../docs/design/LW_Wildlife_Grazing.md)を参照。

`post_return_idle.jl`：当日の食料持ち帰り成功後、夜開始まで認知を止めて休息させる固定設定。旧条件は空帰還では適用しない。`post_return_meal=true`では帰還後の実食を必須にし、取り出し・加工・食事が終わるまで停止しない。空帰還後でも実食できれば停止可。既定false、[研修後の試験条件](../../../docs/design/LW_Acorn_Training_Quest.md)を参照。
既定OFF。適用範囲・観測停止・身体維持・記録先は[設計](../../../docs/design/LW_Configured_Post_Return_Idle.md)を参照。

**追加・有効化前にユーザーへ固定設定と目的を宣言し、ここへ隔離する。**
`configured_`関数として実装し、適用条件・介入内容・ON/OFFと既定値・記録先・
撤去方針を文書化する。実行前の条件一覧にも掲載する。
[必須ルール](../../../docs/design/RDL_Configured_Paths.md)に従い、通常の認知や学習の成果と混同しない。

2026-11-03：`daily_delivery=on` の目的選択を[当日の親計画](../../../docs/design/LW_Daily_Provision_Plan.md)へ接続。
一日で持ち帰るという実験目的、初期の採取／荷物／補給の重み、終了後の滞在は
`daily_delivery.jl`の設定経路。段階別の学習・不確実な記憶・確率選択はlearning側。

このディレクトリは、実験を成立させるために便宜的に与えた固定の判断・行動接続を置く場所。**埋め込みMBや学習経路の実装場所ではない。** [設計上の区分](../../../docs/design/RDL_Configured_Paths.md)を参照。

- `include.jl`：シミュレーションからの明示的な読み込み境界。
- `expression.jl`：身体状態と既存の恐怖から表情強度を出す固定の初期表出。行動の強制ではない。観測・援助候補の選択・結果更新はperception/decision/learning側に分離する。[仕様](../../../docs/design/LW_Expressions_And_Visual_Aid.md)。
- `item_actions.jl`：非食料の操作を確認する明示的な時刻表。`scene.configured_item_actions`を指定した試験だけで使用し、通常の配置入力では空。好み・収集報酬・自動収集は与えない。安全・食事・既存応答・夜間休息が決まったtickでは見送る。[非食料仕様](../../../docs/design/LW_Portable_Items.md)。
- `food_preparation.jl`：種類別食料を有効にした場合の初期レシピ知識と空腹時の加工・摂食。加工場所は拠点。原料の所持だけで帰還目的へ強制変更しない（2026-11-03に上書き分岐を撤去）。加工の自力発明ではない。疲労時と可食物所持・胃満杯時は休む。世界の数量保存・加工成立判定は`world/food_resources.jl`へ分離。[仕様](../../../docs/design/LW_Typed_Food_Processing.md)。
- `body_maintenance.jl`：空腹時のfood切り替え、回復後の帰還再開、即時摂食・取り出しの優先、定時休息・社会応答待ちの解除。
- `home_rest_reward.jl`：暫定的な「拠点で休める価値」。JSON設定`home_rest_reward: "on"`、rock_gate runnerでは`--home-rest-reward on`。既定off。拠点を観測でき距離1.25以内で60操作秒連続してrestを実行したときに5を加点。1個体1シミュレーション日1回まで。中断で連続時間をリセットし、外へ出ると帰還の記録との接続を解除する。身体の実際の回復量とは独立した設定値で、自然に学んだ好みではない。

休息報酬は、その訪問で最初に達成した帰還に寄与した方法へ分配し、対応する成功経路・経験束が残っていれば同じ値を記録する。別々の選択統計であり合算して三倍の価値にしない。休息によって帰還成功回数を増やさない。到着と休息の報酬は分離し、現在地で単に休めた場合も休息記録は残すが、存在しない帰還経路は作らない。日上限は短い出入りによる反復加点を防ぐ実験上の制約。

関数には `configured_` 接頭辞を付け、呼び出し側でも仮設処理と分かるようにする。数値閾値・目的の固定選択・テスト用の優先例外はここに置き、通常の判断ループへ散在させない。既存MBの確率選択や学習そのものは `decision/`・`learning/` に残す。これらの既存ディレクトリ全体を埋め込みMBとみなす意味ではない。

身体維持と初日の見回しを分離済み。既存の定時行動など他の固定処理は棚卸し・分離が未完了。物理的制約、身体の実行可能性、安全仕様を一括してここへ移すものではない。

互換性のため外部フラグ `--body-purpose on|off` と結果キー `body_purpose` は維持。内部名は `configured_body_*` に変更した。内部の旧関数名を直接呼ぶ外部コードには変更が必要。off時は目的切り替え・優先例外を適用しない。

将来の撤去では、この設定経路を無効にしてもMB間の圧と選択で必要な行動が成立することを別途検証する。フォルダ移動だけで自律的な上位MBが完成したとは扱わない。


初日の見回しは home_observation.jl に分離。--home-observation on で最初の1日だけ開始位置近傍の小移動と30度ずつの旋回を行う。安全・食事・夜間休息は優先し、翌日から通常探索に移る。開始位置をテスト用の移動範囲に使うが、拠点の構造や入口位置をMBへ直接与えない。

- `camp_landmark.jl`：初日の重要ランドマーク確認と帰還補助。scene.configured_camp_landmark=true、runner --camp-landmark-shortcut（--central-bonfire必須）で有効、既定off。開始1200秒以内に既知のテスト入口内外（home+(0,3)、home+(0,5.5)、home+(0,3)）を訪問する固定行程。これは実験側の座標を使う設定経路で、自律的な入口発見ではない。食事・安全・疲労・夜間休息の優先を維持。
- 実際の視野・遮蔽・形状レイで見える「橙・半径1以上・高さ4以上・発光」の単独対象を認識する。サイズ分類は実験上の観測モデルで、汎用画像学習ではない。松明は除外、複数一致は曖昧として不採用。初日にhome観測と対象観測の相対位置差1以内を確認すると、特徴と拠点の対応を保存。重要ランドマークの仮設記憶はhome_observation[actor].camp_landmarkに置き、日末保存対象。通常MBの学習による抽象化・転移ではない。
- 帰還目的でその特徴が再観測され、対応方向が移動可能ならconfigured_camp_landmark候補を追加。priority6、observation_log_prior=log(8)の固定補助（同じ他条件なら確率正規化前の重み8倍）。既存の方法学習・失敗評価・確率選択・衝突判定は適用。見えない対象の座標を帰還へ供給せず、観測だけで帰還成功や報酬を生成しない。初日の内外観測記録はチェックリストであり、一般的な入口関係グラフの自律形成を実装したものではない。

## 拠点一巡経験のMB化（初期版）

`--camp-experience-mb`（--camp-landmark-shortcutと--central-bonfire必須）で有効。既定off。旧版の固定priority6/log8候補を併用しない。入口内→入口外→入口内→拠点内左→右→中央近傍を固定見学する。ここだけは既知のテスト座標を使う。中央近傍で実際に60操作連続休息できたら一回限り20の初期報酬を付ける。食事の虚偽記録、仮想の備蓄/寝床、歩行ごとの報酬は追加しない。

観測場面を`mb_map.place_mb.members`、実際に記録されたMB遷移を`links`、観測順を`sequence`として有限保持する（最大512場面/512遷移/1024順序）。初期報酬は`mb_place:camp`の通常MethodNodeへ一回加算。以後は既存の方法報酬・失敗H・失敗反発で評価され、固定8倍補助はない。初期報酬と完了時刻は別途監査記録に残し、帰還成功回数は捏造しない。

初日に観測した特徴とhomeの対応を、まとまりを呼び出すキーとして使う。再観測時に拠点MBをactiveにし、実際に見えた相対方向・距離を記憶する。視野から消えても自己移動receiptで推定を更新し、通常の帰還候補を出す。不確実性3超または背後なら確認用scan、実際にhomeへ到着したらactive解除。見えない物体の世界座標は参照しない。新しい視野での一致が無ければ未活動MBは勝手に起動しない。

これは固定の初期経験による場所MBの初期版である。場面と遷移をまとめて保存するが、内部の全関係を一般的なグラフ推論で復元する機構ではない。今回はランドマークとの学習済み対応と自己移動見積もりによって帰還候補を作る。食事・別建物の用途学習や場所MBの自動分割統合、別世界への転移は未検証。固定見学・初期報酬は設定経路、保存と想起はlearning/mb_place.jlに分離。

2026-11-04：routine_actions.jl と return_purpose.jl に定時帰還、夜間・応答待機、拠点作業、近距離採取、旧非MB移動を隔離。適用条件・OFF方法・残る設計定数は [棚卸し](../../../docs/design/LW_Configured_Policy_Audit.md) を参照。

- sleep_gate.jl：拠点と観測した場所での夜の実行済み休息から朝まで外界入力を停止する暫定固定ルール。scene.sleep_external_gate既定true。身体・内部記憶整理は継続。[仕様](../../../docs/design/LW_Sleep_External_Gate.md)。
- collapse_gate.jl：reserve<=0の間、観測・判断・学習と睡眠整理を停止。scene.collapse_cognition_gate既定true、falseで比較可能。死亡とは判定せず、代謝・消化・他者からの物理的譲渡・世界時間は継続。reserve>0なら次tickから通常の認知対象に戻る（通常の睡眠条件は別）。受け取った食品を自動で食べる処理は加えない。counts.collapsed、mb_map.collapse_gate、events.configured_ruleに記録。将来、身体モデルが独立した意識状態を持てばこのreserve判定を置換する。

- acorn_quest.jl：拠点見学後、ドングリ取得→帰還→由来を確認した納品を進める研修用の目的切替。scene.configured_acorn_quest既定false。日次納品目標との併用不可。移動は通常MB、加工は含まない。[仕様・試験](../../../docs/design/LW_Acorn_Training_Quest.md)。
  追加研修はscene.configured_acorn_tasting（既定false）：2個納品→生食→もう1個を加工→加工物を食べる→果実を食べる。指定種類の取り出し・食事は固定研修として介入する。満腹・作業制限・材料・場所の実行条件は通常処理が検査する。

- 加工練度は行動を固定しないゲーム成長則のため、`../game_rules/proficiency.jl`へ別隔離。scene.game_proficiency（typed_food時に既定true）で有効。特殊技能MBの予測品質を通常候補へ接続する。固定研修と技能成長を混同しない。詳細は上記の加工研修文書「ゲーム用の技能MBと加工品質」を参照。

魚・塩の研修：`configured_fishing_training` + `configured_salt_tasting`。
魚を食べ、所有する岩塩の外見と塩味を経験してから釣り1回と帰還。塩紹介は既定OFF。
釣果は修了条件にしない。手順はfishing_training.jl、詳細はdocs/design/LW_Acorn_Training_Quest.md。

## 帰還後の取引判断と認知停止（2026-11-05）

`scene.configured_trade_idle=true` はコスト削減用の暫定設定（既定false）。
`post_return_idle=true`、`post_return_meal=true`、物品取引ONが必要。
帰還後の食事を終え、取引判断が見送りになった場合、通常の外界観測と候補生成を停止する。
日次開始上限で提案できない場合も、未処理の受信提案がなければ停止できる。
取引の成立・拒否を強制するものではなく、評価・選択は既存のMBが行う。

停止中は接触可能な相手からの有効な提示を軽く確認し、届いた場合は通常判断へ戻す。
自分の提示の結果待ちも停止しない。睡眠・倒れた状態の停止を解除するものではない。
身体更新・消化・食品期限・外界時間は継続。翌日には判断済みフラグを解除する。
停止中の自発的な再考や新しい空腹による起動は未実装であり、この実験制御の限界。
一般的な休息・注意モデルではない。退屈や自発行動導入時に置換する。

実装は `configured_paths/trade_idle.jl`。`mb_map.configured_trade_idle` に判断日時と
通知による起動数、既存の `configured_post_return_idle.ticks` に停止tick数を記録する。
物品・倉庫の見える範囲は変更しない。食品だけの取引と人間関係機構は今回OFF。
`experiments/fishing/longrun.jl OUTPUT DAYS abundant trade-on idle-on` で有効化できる。

## 加工中の相手への提示前待機（2026-11-05）

`scene.configured_trade_work_wait` は既定false、釣り実験ランナーでは取引ON時にtrue。
`configured_paths/trade_work_wait.jl` に仮置きの理由・切替設定・将来の置換方針をコメント化。
新規提案を選んだ相手が直前tickで加工継続中だった場合、提示を発行せずrestで待つ。
物理取引も日次開始回数も消費せず、未実行の選択を成功・失敗として学習させない。
作業終了後は条件を再評価し、元の相手や数量を強制しない。提示前なので期限は始まらない。
高優先行動は先行し、夜・翌日・接触喪失・受信提案によって待機を解除する。
既存の逆提案や受諾にはこの待機を適用しない。提示後の移動拘束も今回の範囲外。
直前tickの実行結果を読むため開始直後は1tick遅れる場合がある。
将来は声かけ、相手の返答、待つか離れるかのMB選択に置換する。
記録は `incidental_items.<actor>.configured_work_wait` の entries/ticks/released/cancelled、
行動イベントの `configured_rule=wait_before_trade_offer`。

### 提示後の返答待ちと同時移動（2026-11-05追記）

提示前待機版30日の実行不能5件は、4件が提示者の返答前移動、1件が提示と同tickの
相手の移動だった。このため同じ `configured_trade_work_wait` 設定に以下を追加した。
有効な送信済み提案があり相手と取引接触できる間、他の上位行動がなければその場でrest。
受諾・拒否・期限切れ・離別で待機対象がなくなる。受信応答は待機より優先。
また全個体の計画確定後、相手がwalk/run/climb予定なら新規提示を実行前に見送る。
物理取引と日次回数は発生させず、失敗学習もしない。次tickは再評価する。
相手の計画を直接参照する暫定固定であり、将来は声かけへの応答で開始を合意する。
記録は `reply_ticks`、`departure_deferrals`、eventsの `wait_for_trade_reply` /
`defer_trade_departing_partner`。上位の安全行動などによる中断までは禁止しない。
27項目の単体検査PASS。新しい30日での実行不能件数の再評価は未実施。

返答待ち版の初回30日試験は10日完了後、11日目の同時移動見送りで停止。
行動の差し替えが親の集計情報 `trail_parent` を落とし、後続記録でKeyErrorとなった。
`trail_parent` / `bundle_parent` を保持し、提案固有の学習traceは持ち越さない修正を追加。
回帰検査を含む30項目PASS。失敗出力は保存し、新規出力で30日を最初から再実行する。

## 最大3回の交渉調整（2026-11-05）

`scene.configured_negotiation` は既定false、釣り実験では取引ON時にtrue。
設定経路 `configured_paths/negotiation.jl` に理由・設定・将来の置換予定を明記。
初回をround=0とし、同じroot_idで最大3回の条件調整を許可する。round=3でも受諾可能。
現条件を受諾できず実行可能な調整案がある場合は、即打ち切りより調整を固定で優先する。
調整案なし、または上限後は打ち切り可能。成立は強制しない。
候補の主観評価と数量近傍生成は既存MBを使用する。世界側も上限を検査する。
旧モードfalseは上限8と従来の拒否候補を維持する。

`portable_items.negotiations.counts` に started / adjusted / mismatch / agreed / ended /
interrupted を累積保存。root_idで交渉を追跡し、調整に伴う旧提示の不一致は ended に
加算しない。従来のcounts.declinedは互換性のため残し、交渉拒否率の分母分子には使わない。
提示ごとの不成立経験は学習材料として残す。30秒の総期限は調整でも延長しない。
将来は改善見込み・交渉費用・Hによる継続判断へ置換する。
単体21項目PASS（3回後の成立、4回目禁止、打ち切り、期限切れ、資源保存）。

## 人間関係との併用（2026-11-06）

釣り長期ランナーの既定を `social_relationships=true` に変更した。
第6引数 `social-off` で以前の比較条件へ戻せる（設定をconditions.jsonへ保存）。
親しさ・援助・取引経験、表情観測、対人MB、対人接近・援助判断の既存機構を有効化する。
単なる好意係数の追加ではなく、行動候補も変わるため、速度と成立率は実験で確認する。

帰還後停止は通知起動を持つ `configured_trade_idle=true` の場合に限り併用可能。
取引通知に加えて、知覚と同じ有効期間内の未処理の社会メッセージでも起動する。
この起動条件はコスト削減用の固定制御の拡張で、通常の注意認知の実装ではない。
睡眠・倒れた個体の停止は従来どおり。食品だけの別取引機構は引き続きOFF。
単体15項目PASS。人間関係ONの長期効果は未評価。

初回のON動作確認で、対人接近と援助予測が「食品価値は非負」を要求する旧前提により停止。
腐敗食品などの負の主観価値を保持して受け取れるように修正した。対人接近は期待利益が
正の場合だけ候補にし、援助予測では負の期待値／実績も記録する。関連7項目PASS。
停止した初回・2回目の出力は残し、v3-smokeを正常性確認の対象とする。
# 作業中の状況依存割込み遮断（2026-11-06）

`task_interrupt.jl` の `configured_task_interrupt` を釣り・加工の集中継続へ接続。
`scene.task_interrupt_shield` は既定true。falseなら動体検出時に従来どおり再観測。
食料不安と本人の作業進捗を直接利用する暫定固定であり、MB学習で生まれた行動ではない。
応答距離だけを縮小し、身体・完了・phase・定期確認による解除は残す。
設定値は同ディレクトリの `parameters.jl`。診断は本人MBの `task_focus` に保存。
将来は作業期待・観測矛盾に基づく注意配分へ置換する。
詳細と検証は [集中観測報告](../../../experiments/fishing/task_focus_report.md) を参照。
