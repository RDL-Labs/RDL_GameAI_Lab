# 数値設定の配置と意味

2026-11-06。現行値を保った隔離の第1段階。数値を変える改善ではない。
同じ値でも、身体限界・感覚・行動判断の意味が違うものは同じ定数へ結合しない。

以後の新規実装・変更でもこの分類を基準とする。具体的な開発規則は
[AGENTS.mdの数値設定の実装基準](../../AGENTS.md#数値設定の実装基準)に記載。
定義時に意味・単位・根拠・適用範囲を記録し、将来の状況依存の調整も基準値と分離する。

| 分類 | 定義場所 | 主な値と単位 | 意味／将来の扱い |
|---|---|---|---|
| 身体動作 | `src/body/parameters.jl` / `BODY_ACTION` | 歩行0.5、走行1.5（世界距離/tick）、作業消費0.1×RS、作業疲労0.01×SS | 既存のゲーム身体。消費・回復・実行限界をまとめる。認知の閾値ではない |
| 岸辺の釣り（低負荷版） | 同上 `fish_reserve`, `fish_strain_recovery` | 消費0.025×RS、疲労回復0.015×SS×回復係数 / tick | 加工から分離。投げる・回収を含む待ち主体の平均負荷という暫定ゲーム身体。回復係数は休息と同じ備蓄・損傷依存。基礎代謝は別途。疲労1・損傷1・必要reserve未満では不可。強制選択や休息禁止は加えない |
| 走行・登攀の限界 | 同上 `run_max_strain`, `climb_max_strain` | 各0.8、`<=`で実行可能 | 同値だが別の身体能力として保持。疲労の正規化範囲0〜1は式のまま |
| ナビゲーション時の休息判断 | `src/lw/configured_paths/parameters.jl` / `CONFIGURED_LIMITS.navigation_rest_strain` | 0.8、`>=`で休息 | 暫定固定判断。身体の作業限界1とは別。将来は残り作業や要求と比較する。今回の休息・釣り進捗リセットは未変更 |
| 集中観測 | `src/lw/parameters.jl` / `TASK_ATTENTION` | 再確認64,000,000μs、reserve低下2、動体距離8、速度0.05/ tick | 作業中の感覚と再確認。個性差なし。動体応答距離のみ下記の状況調整あり |
| 作業割込み遮断 | `src/lw/configured_paths/parameters.jl` / `TASK_INTERRUPT_RULES` | 至近距離2世界単位、不安尺度1、必要性重み1、進捗重み1 | 暫定固定。食料不安と本人の作業進捗で応答距離を縮小。学習・ホルモンではない |
| 採集試行の診断履歴 | `src/lw/parameters.jl` / `ACQUISITION_TRIAL_RULES.history_limit` | 終了試行64件/個体 | 記録容量だけの暫定上限。行動を64回で中止する規則ではない。現在試行・方法/場所要約とは別 |
| 食料不安・援助 | 同上 / `FOOD_SECURITY_RULES` | 許容比0.25、係数4、指数2、維持床70、残差帯0.1食、再確認64秒、自力重み4 | 内部の不足予測と表出不安を分離。身体の物理制約ではない。予測の床と援助の身体基準は別名 |
| 釣りゲーム | `src/lw/game_rules/fishing_parameters.jl` | 180作業tick、基礎0.25、技能加算0.20、直近32試行、事前8試行、予測確率下限0.01 | 全て現行値。予測下限は実釣果確率の保証ではない |
| 交渉の固定制限 | `src/lw/configured_paths/parameters.jl` | 条件調整3回、旧方式8回 | `configured_negotiation`の既存切替を保持。将来は継続の期待・費用で判断 |

## 既に名前付きの設定

- `src/data/food_ids.jl`: `FOOD_PROCESS_TICKS`。生ドングリ／生魚は各120作業tick。
- `src/lw/world/food_quality.jl`: `FOOD_LIFETIME_DAYS`。果実5日、生ドングリ30日等。
- `src/body/digestion.jl`: 栄養組成、`NUTRIENT_TARGET`等の身体・味設定。
- `experiments/fishing/river_scene.jl`: 地図別釣果率。世界の実験条件であり、個体の予測や感度ではない。

これらは配置を変えず参照先を明記した。釣り予測や身体へ重複して新しい値を作らない。
`RS`、`SS`等の既存公開名は維持。整数／浮動小数点の型、演算順、比較の等号も維持する。
設定表は読み取り専用の定数であり、シミュレーション途中の変更機能ではない。

## 援助の資源観測（2026-11-06）

`src/lw/parameters.jl` の `AID_RESOURCE_RULES` は認知側の初期仮説。
倉庫へのアクセス見込み0.75、未観測の資源可用性0.5、色あせ食料の係数0.5、
相手の困窮に対する留保係数2。相手の内部必要量や承諾を直接決める値ではない。
`reply_window_us=5_000_000` は既存の援助応答期限と同じ5秒で、
取り出し・手渡しの実行計画も要求発行時からの期限内に限る。
相手の備蓄数量は `log1p` で文脈へ格納し、種類別数量・可食量・劣化量・手持ち有無を区別する。

## 兎的生物の繁殖（2026-11-06）

`src/ecology/lw_grazing/reproduction.jl` の `RABBIT_LIFE` に世界・身体の試作用数値を集約。
1日17280tick、妊娠31日、離乳28日、成熟150日、初期180日齢、年365日／繁殖期240日、
受容14/16日、遭遇距離6、妊娠確率0.2/日、繁殖energy下限70、離乳後回復7日、産仔3〜6。
妊娠投資1energy/日、幼体消費4energy/日、授乳目標8energy、効率0.75、母体維持床35、
授乳距離1.5、幼体体高0.1／成体0.4。身体の値は実測カロリーではない。
`allocation_limit=10000` は割当数による実験停止であり、出生の候補重み・生態的上限ではない。
固定待機と授乳帰巣は `configured_rabbit_nursing!`。詳細は `LW_Wildlife_Grazing.md`。

## 未隔離の範囲

リポジトリ全域の数値を隔離済みとはしない。MB照合・探索上限・忘却、消化内部の補正、
社会評価の他の係数、見学の移動距離・時間等にはリテラルが残る。
例えば `mb_chunks` の利用抑制、`experience_bundles` の疲労区分、固定見学中断にも0.8がある。
意味と所有層を確認して段階的に移す。全てを身体の0.8へ置換してはならない。
ID、配列添字、幾何の角度変換、正規化の0/1、件数加算の1等は一律に設定化しない。

## 検証

隔離前のソースを `outputs/parameter-isolation-20261106/before` に保存し、同一入力で比較。
身体4,515項目、認知・釣り575項目、計5,090項目で数値・状態が完全一致。
身体は7行動、負荷、抵抗、遮蔽、0.8前後の境界と代謝を含む。
別途、集中・加工133項目、交渉21項目、食料不安159項目を検査。
この段階では30日試験は再実行せず、性能改善やBの救済を主張しない。

## 兎の帰巣ポテンシャル（2026-11-06）

`src/lw/configured_paths/wildlife_reproduction.jl`の`RABBIT_POTENTIAL`。
body_radius=0.25は既存の衝突身体半径と同じ世界距離、influence=1.2は表面からの反発範囲（未満）。
repulsion=1.4、progress_floor=0.15（前進力が以下なら局所回避）は試験用の固定係数。
反発は範囲端で0へ連続的に落ちる二乗形。回避角は45/90/135/180度、左右順はID偶奇。
epsilon=1e-9は零距離除算保護。巣引力は単位方向。暫定固定・繁殖ON帰巣だけに適用する。

初期妊娠の世界配置：`wildlife.initial_pregnancy_days`は妊娠済み日数の配列（既定空、各1〜30）。
`experiments/fishing/longrun.jl`のmixed-pregnancy条件は26/21/16/11/6日、初期雌5体へ適用。
開始前投資は既存pregnancy_energy_per_dayと日数の積。自然分布の実測値ではなく実験初期条件。

初期幼体: `wildlife.initial_young_count=0`（0〜6、成体数へ加算）、
`initial_young_age_days=7`（1〜27日）。実験用初期状態。身体energyは既存milk_target=8を使う。
LWランナーmixed-familyでは成体30＋7日齢5体。開始21日後が離乳境界、28日後が母親の再交尾可能時刻。

## LW捕食者接続（2026-11-06）

`configured_paths/wildlife_predation.jl` の `WILDLIFE_PREDATOR` は暫定ゲーム設定。
sight=16、cover_attenuation=0.8、scan_amplitude=π/2、scan_period=12tickは
既存方向視覚実験と同じ。body_height=0.6は捕食者の草遮蔽・人側観測用の初期体高。
event_limit=128は直近イベント保持上限で、総捕食数は別に累積する。
既存捕食FSMの移動0.22/追跡0.5/攻撃1.0、追跡60tick、攻撃3tick、回復120tick、
捕食後休息8640tick、接触半径0.55、捕食確率0.28（逃走中）/0.78は今回変更しない。
現実の種への適合値ではなく旧実験の仮設定。捕食者の生理実装時に再検討する。
`wildlife.predator_count` は既定0、現版は0/1のみ。位置指定は世界初期条件である。

## 動物単独・捕食者身体と縄張りの試験（2026-11-06）

`src/lw/configured_paths/predator_animal_trial.jl` の `PREDATOR_ANIMAL_TRIAL`。
実験専用・通常LWはOFF。基準消費600g相当/17280tick、移動追加0.1g/距離単位、
初期900g、容量1800g、狩猟開始600g未満、成体捕食900g。
幼体食料量は体高比の3乗・最低5%。全て較正前のゲーム身体パラメータ。
縄張り半径20、視認距離12、防衛差0.1、撤退速度0.3/ tickは暫定固定判断。
詳細・撤去方針・実験結果は `experiments/lw_wildlife/animals_only_report.md`。

動物単独捕食者の威嚇上限: `PREDATOR_ANIMAL_TRIAL.warning_duration_ticks=60`、
`warning_cooldown_ticks=600`。単位はシミュレーションtick。開始時刻との差が60以上で終了、
終了時刻＋600以上で再開可。暫定固定判断であり生物学的な推定値ではない。
短い見失いで期限をリセットしない。適用は動物単独ランナーのみ。通常LWは未接続。

## 捕食者マーキング試作（2026-11-06）

`PREDATOR_MARKING`（`src/lw/configured_paths/predator_marking.jl`）、動物単独 `--marking` のみ・既定OFF。
世界: cell_size=4m、lifetime_ticks=51840（3日）、deposit=1、capacity=4。
暫定観測: smell_radius=4m、sniff_interval_ticks=30、memory_limit=128。
暫定行動: mark_interval_ticks=600、arrival_radius=3m、return_min_strength=.2、
avoidance_margin=.1、local_familiarity=.5、speed=.22距離単位/tick。
値は種の測定値ではなく試作用。近傍セルだけ観測、記憶は観測時のコピー。
記憶の忘却にも3日を使用するが、世界の真の残存時刻を与えない。
距離による信号/帰路評価はstrength/(1+distance)。1は初期の距離正規化尺度。

## 捕食者の共通認知アダプター（2026-11-06）

`PREDATOR_COGNITION`（`predator_cognition_parameters.jl`）、動物単独 `--cognition`、既定OFF。
共有BasicLoopへ渡す候補評価係数: food_weight=3、rest_weight=2、rival_weight=2、
place_prior=.5、rest_benefit=.2、hunt_prior=.3、tolerance=.05。
食料相当量の正規化: food_value_scale=900、food_pressure_scale=600。
区間: episode_ticks=600、decision_ticks=60（対面区間）、移動は共通mb_travel_seconds。
場所記憶: place_limit=16、place_cell=8、arrival_radius=3、move_speed=.22、history_limit=64。
いずれも初期試験値。身体の厳密な疲労モデルや生物学的較正値ではない。
狩猟期待効用のみ実経験平均へ更新。共通関数を変更せず、局所到着と親Hを分離する。
詳細は `experiments/lw_wildlife/predator_cognition_report.md`。

## 捕食栄養倍率と収支監査（2026-11-06）

動物単独ランナー `--prey-nutrition`（既定1.0、有限の正数）。
成体の食料相当量900へ乗算し、幼体も既存の体高比による量へ同じ倍率を適用する。
1.5実験では成体1350。実測の肉重量ではなく暫定栄養単位であり、通常LWへ自動適用しない。
容量1800、消費、判断係数は独立。容量超過は既存のdiscardedに計上する。
収支検査は `balance_atol=1e-7` と `balance_rtol=1e-10`。
長期のFloat64逐次加算誤差を許容する診断値で、資源そのものを補正しない。
各報告のbalance_residualに初期量＋摂取−残量−消費を保存する。

## 獲物の地表痕跡（2026-11-07）

`configured_paths/prey_scent.jl` の `PREY_SCENT`。通常LW・animals_onlyの既定はOFF。
`prey_scent_compare.jl`でのみON/OFFを比較する。風・拡散・個体識別なし。
cell_size=4距離単位、radius=6、deposit_interval=30tick、sniff_interval=30tick、
lifetime=17280tick（1日）、deposit=1、capacity=4、minimum_signal=.05、arrival_radius=1。
生存兎のセルへ静止中も付着、セル内で混合し、参照/再付着時に線形減衰する。
有限地図上のセル辞書は個体履歴数で増えない。嗅ぐ時は近傍25セルのみ照会。
観測はセル中心・強度・観測時刻だけ。獲物IDや現在位置は渡さない。
暫定固定の探索方位補助: hunt/SEARCH中だけ、近傍で観測した強い匂いのセルへ向ける。
視認後のCHASE/ATTACK/RECOVERと、休息・既知地点移動を上書きしない。
嗅いだセルへの到着を捕食成功として学習しない。親側は既存の捕食実績で評価する。
将来は人も含む共通の感覚・注意・MB候補選択へ移す。現時点は設定経路による試作。

## 強い獲物臭による慎重探索（2026-11-07）

`PREY_SCENT_CAUTION`、`PreyScentWorld(n;cautious=true)`で有効。既定false。
strong_signal=.6以上でSEARCH速度を0.22からspeed=.08距離単位/tickへ落とす。
前tickに嗅いだセルへの注視を次tickの既存視覚確認へ渡す。視覚は元から毎tickであり、
検査回数・視距離・解像度ρそのものは増やさない。対象を既に視認追跡していればそちらを優先。
強い匂いを慎重に調べた累積unconfirmed_ticks=120tickで視認できなければ、
その時調べているセルをcooldown_ticks=600tickだけ候補から除外し、通常探索へ戻す。
他のセルでも未確認時間は引き継ぐ。実際のCHASE/ATTACKへ移ったら未確認時間をリセット。
世界側の匂いは消さず、個体側の一時的な見込み低下として保存する。
暫定固定でありMB学習や生物学的較正値ではない。将来は残差と探索候補の更新へ置換。
観測ログ: cautious/caution_ticks（個体別）/rejected（全体）。
人には未接続。音・相手の速度に応じた発見率・攻撃幾何は今回変更しない。

## 速度による視認距離係数（2026-11-07）

`configured_paths/motion_visibility.jl` の `MOTION_VISIBILITY`。
`G.prepare!(...;motion_speed=true)`でウサギが人/捕食者を見る条件へ適用。既定falseで旧二値を維持。
stationary=.55、saturation_speed=.5距離/tick。未追跡時の係数は
0.55＋0.45×clamp(前tickの対象実変位/0.5,0,1)。追跡中は1。
静止0.55、慎重移動0.08で0.622、通常探索0.22で0.748、追走0.5以上で1。
指令速度ではなく実際に移動した量なので、障害物で動けなければ静止相当になる。
発見確率ではなく既存視認距離への倍率。草・視野・遮蔽は既存条件をそのまま使う。
速度は物理m/sでも網膜角速度でもない暫定モデルで、固定生理係数として隔離。
音、対象の姿勢/足の動き、人の観測側、捕食者が兎を見る側にはまだ適用していない。
人を対象とする場合も同じ式を利用可能だが、今回の比較は人0体。
将来は共通感覚の観測間隔・角速度・経験に応じたモデルへ置換する。

## 捕獲直前の局所見積もり（2026-11-07）

`configured_paths/predator_local_hunt.jl` の `LOCAL_HUNT`。動物単独 `local_hunt=true` のみ、既定OFF。
視認距離radius=6以内で詳しい候補を展開。実際に見えた位置履歴だけから速度を推定し、
history_ticks=20以内の履歴、velocity_cap=.7距離/tickに制限。未観測の世界速度は読まない。
horizon=3tick、attack_speed=1、approach_speed=.35、side_angle=π/3、contact_radius=.55。
攻撃の各予測stepを既存H.clearで判定するため、身体幅・水・境界の正確な短距離地形を直接参照する暫定近道。
地形観測MBによる誤差や部分遮蔽率は未実装。通常の広域探索にはこの計算を追加しない。
攻撃・接近・左右・待機を共通BasicLoopの確率選択へ渡す。
attack_priority=4、approach_priority=2、wait_priority=-1、cost_weight=.2、expected_capture=.6。
接近候補の評価には距離改善量と次の攻撃が成立する見込みの加点1を使用（暫定尺度）。
攻撃中も視認位置を更新し、次の一歩は予測位置までの距離を超えない。
見失い/予測経路不成立はabort_unseen/abort_forecastとして攻撃失敗を記録。
攻撃成否は局所BasicLoopの予測結果へ返す。移動成功は局所方法だけ更新し、捕獲成功や親報酬にはしない。
親の狩り評価は既存の実際の摂取結果を使用。休息の固定報酬問題は今回未修正。
log_limit=128の候補履歴と累積選択件数を保存。局所状態ONのチェックポイントは6要素tuple。
将来は予測地形・相手の不確実性・文脈別成功経験をより共通のMBへ統合する。

## 待機を子MB試行として保持（2026-11-07）

局所狩猟ON時のwaitを共通action_trialで保持。目標は同じ視認対象に対して
捕獲可能な局所経路が観測・予測できる状況になること。待った時間そのものを成功にしない。
wait_forecast_ticks=20tickは暫定初期見積もりで学習値ではない。選び直しで延長せず、
経過・消費を同じ試行へ加算。目標出現でachieved、見失い/範囲外/期限未達でfailed、親変更/死亡はinterrupted。
局所resolve_method!だけ更新（成功でも捕獲報酬なし・親H不変）。
親の既存狩り試行も継続して実時間・実消費を計上し、子のHを追加で転送しない。
次の候補選択では失敗したwaitの方法Hが作用する。
移動可能な後方候補withdrawも追加し、攻撃/前左右が塞がっても待機だけになりにくくする。
withdraw_priority=0、速度はapproach_speedを共用。攻撃見積もりが既に成立する時は待機候補を出さない。
これら候補/初期期限は隔離された暫定設定。親の休息報酬問題は別件で未修正。
wait_recordsには対象・status・reason・凍結見積もり・経過・消費を保存（直近128件）。
countsにwait_ticks、wait_achieved/failed/interruptedを累計。active_waitに進行中試行を保存。
比較でwaitは選択回数、wait_ticksは継続時間であり、旧版の毎tick選択回数と混同しない。

## 動物の境界反発（2026-11-07）

`src/lw/configured_paths/wildlife_boundary.jl` に暫定固定設定として隔離。
世界の境界を直接知るショートカットで、学習や視覚から生じた反発ではない。
`wildlife.boundary_gradient` は通常LWでは既定false、animals_onlyの世界生成では既定true。
scent_runは既存比較を保つため既定false。scent_motion_longrunは既定ON、
`--no-boundary-gradient` でOFF。各実行のconditionsに設定と係数を保存する。
幅8世界単位、強度2、身体余白0.25。各辺からの距離dに対し
`2*clamp(1-d/8,0,1)^2` を内向きの方向ベクトルとして足して正規化する。
速度は変えず、中央では元の向きをそのまま返す。角では二辺を合成。
ウサギの探索・逃走、捕食者の通常移動・攻撃、局所攻撃と接近候補の予測に接続。
休息・待機を移動させず、水・障害物・境界の物理衝突判定も維持する。
獲物の未来位置は従来どおり観測速度の直線外挿であり、獲物の旋回予測まで実装したわけではない。
将来は観測された地形や活動範囲の関係勾配へ置換する。現在は人の移動には適用しない。
Worldにフラグを保存するため新しいチェックポイントでON/OFFを保持できる。
旧チェックポイントは型が異なるので、その実験の凍結ソースで読み込む。

## 捕食者の固定休息利益を撤去（2026-11-07）

PREDATOR_COGNITION.rest_benefit=.2を削除。休息の期待利益は0、実績は
実際の消費/food_value_scaleを負にした値だけとする。共通resolve_prediction!で
休息による報酬追加・親H軽減・方法H軽減はいずれも0になる。
許容幅以下の消費は新たなHを増やさず、超過時は既存の共通式で増える。
休息の局所完了（相手が見えていない）は維持するが、身体回復や親目的達成の利益を意味しない。
休息候補の初期priority（rest_weight=2）、600tick区間、休息場所記憶と訪問は変更していない。
疲労/回復の実状態がないため、将来その導入時に実測された回復利益を評価する。

## 捕食経路の局所修正（2026-11-07）

局所狩猟ON（従来の実験フラグ）に適用。予測が捕獲を保証しなくても直近1歩が通行可能なら
既存攻撃を継続する。3tickの攻撃区間は延長しない。直近が塞がれた時はroute_blockedで
その方法だけ失敗として閉じ、同じ観測対象への左右・接近・後退・待機をそのtickで再選択。
子方法の失敗を親の捕食Hへ直ちに転送しない。親の試行ID・固定見積もり・時間・消費は維持。
空振り・逃げられた・物理衝突でも局所狩猟の終了処理で120tickの回復を解除し、同じ対象へ
CHASEで戻す。局所狩猟OFFの旧身体状態機械には従来の回復待ちが残る。
対象が見えている限り近い別個体へ自動交換せず保持。見失っても既存history_ticks=20内は
最後の観測地点を手掛かりとして追う。観測期限後は探索/別の観測対象へ移行可能。
未観測の現在位置や生死は読まない。局所範囲外の視認対象へはapproach_speed=.35で再接近。
親の既存600tick区間での再評価は維持し、経路修正のたびに親期限を延長しない。
初回攻撃開始には従来の捕獲見込みを要求する。今回緩和したのは開始済み攻撃の継続条件。
候補の角度・優先度・期限・地形の直接参照は既存の暫定固定設定で、将来は観測MBと身体負担の評価へ置換。
countsにuncertain_continuation、route_blocked/unseen/out_of_range、route_retryを記録。
攻撃のmissesは捕食全体の失敗ではなく、その攻撃区間の非捕獲終端として数える。

## 有利な位置からの確率捕獲（2026-11-07）

世界規則はconfigured_paths/probabilistic_capture.jlへ隔離。通常はOFF、動物実験の
scent_motion_longrun.jl --local-hunt --probabilistic-captureでON。
ONではLocalHuntの3歩先の接触予測を呼ばず、現在観測位置への通行・到達範囲だけで
攻撃機会を判定。攻撃中は視認した対象への向きを更新し、既存3tick区間の最後に1回抽選。
各tickは実際に移動し、その距離を食料消費へ計上。失敗時も休止せず同じ対象への候補へ戻る。

世界側の成立条件: 対象が生存、距離<=2.5、視線と身体幅付き直線経路が通ること。
経路は0.5単位以下で分割し水・境界・障害物を検査。条件不成立は確率0、抽選なし。
成立時の確率は base=.1 + 近さ*.4 + 未警戒*.2 + 背後度*.1 + 相対接近速度*.15 - 草遮蔽*.1、
[.05,.9]へ制限。近さ=clamp(1-distance/2.5,0,1)、背後度は獲物の向きと接近方向、
相対接近速度は実際の直近変位（1単位/tickで正規化）。警戒はALERT/FLEE。
草遮蔽は[0,1]へ制限。全係数は未較正のゲーム設定で、動物生理の再現値ではない。
抽選時の距離/確率/不成立理由を世界イベントへ診断記録するが、候補選択には渡さない。
捕獲できる範囲内の最終動作を抽象化したもので、従来の接触半径.55まで一致を要求しない。
妊娠投資の損失、死体数、捕食栄養の処理は従来の共通経路を使う。

個体側の初期予測は別定義CAPTURE_ESTIMATE。観測距離1.25以内/外と、観測速度の接近/離脱で
4文脈に分け、近距離事前値.6、遠距離.3、事前サンプル2として成功/失敗から更新。
評価への重み2。新規攻撃の期待値は選択時に固定。接近候補にも見積もりの差を加える。
世界の正確な確率や未観測の警戒状態は読まない。向き/警戒/遮蔽ごとの主観学習までは未実装。
場所がよければ必ず成功することも、成功率が低ければ試行できないことも要求しない。
局所捕獲失敗のHは方法側だけ、親の維持/捕食は実摂取と経過・消費で評価する。
capture_experienceは[試行数,成功数]で保存。countsにprobability_capture/missと
capture_draw/blocked/out_of_reach/target_unavailableを累積する。

## 捕食者MBの世代継承実験（2026-11-07）

configured_paths/predator_mb_inheritance.jlへ実験者による選抜・コピーを隔離。
通常実行では無効。predator_generations.jl SOURCE_RUN OUT GENERATIONS DAYSでのみ実行する。
生存中tick数（deadモードを除く合計）が長い個体を親に選ぶ。同率は個体番号の小さい方。
上限日数で生きている個体は寿命未確定（censored）として記録し、上限を寿命と断定しない。
新世代は同じ世界・資源・ウサギ初期配置を再生成し、親の記憶を独立deepcopyして2体へ。

継承: 親維持/局所捕食BasicLoopの方法H・閾値・報酬・失敗経験・選択順序、場所記憶、
狩り実績見積もり、獲得方法/場所の評価要約、捕獲4文脈の試行/成功数。
初期化: 身体・空腹・親H・試行/受領証/一時ログ・直近観測・追跡対象・匂い・待機。
場所のseenは親世界の最終tickを引いて相対時刻へ移し、未来の記憶にしない。
獲得評価はsites/methods要約だけコピーし、last_result_usや進行試行を持ち越さない。
子同士・親子の辞書や方法ノードは共有しない。識別子と乱数系列は子ごと・世代ごとに新規。
判断seedは20261106/20261107 + 1000*世代 + 個体番号、捕獲seedは20261106 + 1000*世代 + 個体番号。
ウサギ/地形seedは固定、捕獲乱数と判断乱数は世代ごと変更。突然変異は加えない。

これは同じ環境への記憶継承・選抜実験で、生物学的遺伝や未知マップへの汎化ではない。
生存差には初期位置・遭遇・抽選・2個体間の競合も含まれる。
選抜を繰り返しても改善を保証せず、MB効果の厳密比較には同じ乱数の未継承対照が別途必要。
各世代の初期/日末/最終状態、親と選抜理由、継承経験、打切り情報、処理時間を保存する。

世代継承ランナーの第5引数generation_offset（既定0、非負整数）で世代番号を継続できる。
例: 前回generation-3を入力し、20 30 3を指定すると第4～23世代を追加実行する。
判断/捕獲乱数も通算世代番号に従い、続行時に第1世代の系列を再利用しない。
conditionsのsourceには実際の親チェックポイントのディレクトリを記録する。

## 継承MBと未経験MBの対応比較（2026-11-07）

inheritance_paired_compare.jlで第23世代の選抜個体を固定し、これ以上の親選抜はしない。
シードコード101～110を事前指定、各コードで未経験/継承を各2体・30日上限で比較する。
地形とウサギ初期乱数は固定、判断/捕獲乱数はコードで変更し、ペア内は同じ系列を使う。
初期の世界・身体・資源を再帰的に値へ展開し、辞書をソートして内容ハッシュを比較。
乱数生成器はコピーから64個のUInt64を取り出して系列一致を検査（本体は消費しない）。
Julia Serializationのバイト列はキャッシュ/メタデータ等を含み得るため一致判定に使わない。
初期loop seedもペア内で一致を検査。動きが変われば後続の乱数消費順は分岐し得る。

主指標は各ペア2体の平均生存日数の継承－未経験差（30日打切り平均）。
早期死亡は3日以内と事前定義し、副指標として率を比較。30日生存も別記する。
2体は相互作用するため統計単位は10シードのペア。ペアを復元抽出するbootstrap10000回の
95%区間と、全2^10通りの符号反転による両側値を参考に計算する。
固定した親MB・地形での探索的比較であり、別の親や地形への一般化ではない。
実行順はシード偶奇で交互にし、速度比較を主目的にしない。

## 捕食者の単一休息地点（2026-11-07）

`PREDATOR_COGNITION.single_rest_place=true` は暫定固定の候補数制限。
`configured_paths/predator_rest_place.jl` に隔離。最初の休息地点を保持し、既存の複数記憶は
経験数・最終経験時刻・キー順で1地点へ正規化。falseで従来の複数記憶を許可する。
日次cognition出力に設定と地点を保存。帰還の強制や休息報酬の追加ではない。
将来は目的と場所選択の階層化、住処変更の学習へ置換する。

訂正（同日）：`single_rest_place` は休息場所の記憶制限ではなく想起幅1を表す。
場所固定・旧MB削除を撤回。現在の共通MB重みが最大の休息先だけを候補へ渡す。
複数地点は既存の記憶上限内で保持・更新・継承し、経験が変われば想起先も変わる。
関数名は `configured_predator_rest_candidates!`。falseで全候補を渡す。

## 共通の昼夜視覚（2026-11-07）

`src/perception/ambient_vision.jl` の `AmbientVision.RULE` に種別係数を集約。
昼の視認距離に対する夜の倍率はhuman=.25、predator=.65、rabbit=.50。
未較正のゲーム仮設定であり、生理測定値や全種一般の夜行性を示す値ではない。
共通式 `dark_range + (1-dark_range)*illumination`。照度入力は0..1の正規化値。
現状は昼1/夜0の二段階で、0は夜の基準明るさを意味し完全無光の物理照度ではない。
通常LWはclock.day_usとphase_boundaries_us[3]で切替。動物単独の既定は17280秒/日、11520秒から夜。
日境界で昼に戻る。黄昏、月光、天候、暗順応は未実装。倍率1にすれば当該種の夜間減衰を無効にできる。
視野角・遮蔽・草・動き/追跡による既存補正へ乗算する。嗅覚・身体衝突・記憶の座標は変更しない。
人は食料、他者、危険、拠点、地面模様、目印形状、遠景、動体/野生動物、地面/携行物品へ接続。
公開倉庫の内容閲覧は既存の拠点検査ショートカットのまま。近距離の移動可能性/地面抵抗判定も既存の身体予測として残す。
光源自体の発光検出は既存方式を維持。周辺物体を照らす局所照明場は今回未実装。
捕食者は獲物・同種相手、兎は人/捕食者の視認に共通係数を適用。
遠景の予測/間隔観測は照度が変われば新規観測し、昼の視界を夜へ流用しない。
動物のsnapshotと世代実験条件に係数を保存。構造体レイアウトは変更しない。

## 共通身体核と捕食者身体版（2026-11-07）

`src/body/physiology.jl` のexert/recoverを人と捕食者で共有。身体の更新のみを担当し、移動幾何や行動選択は含めない。
人のwalk/run/climb/rest/metabolizeが共有核を使用。人の既定係数・判定は維持。
捕食者の仮係数は `configured_paths/predator_physiology.jl` のPREDATOR_BODYに隔離。
burst上限10、休息回復burst2/tick、strain0.15/60/tick、回復低下の食料尺度360。
移動疲労0.001/実距離、攻撃疲労0.003/tick・burst消費0.6/tick。
休息の追加消費0.05*(64/17280)*18/tickを回復係数で補正。従来の基礎600/日と移動0.1/距離も継続。
食料容量1800の単位を維持し、身体reserveと旧foodは同じ収支更新の鏡像。毎実行前に一致assert、消費/捕食は一度だけ計上。
strain=1またはdamage=1で移動不能。攻撃開始には3tick分のburstが必要。実行中に不能になった攻撃は局所失敗で閉じる。
身体版はscent_runのshared_body=trueで既定ON、falseで旧実験へ戻す。
生理サイドカーはチェックポイントtupleの7番目（1〜6の既存要素は維持）、初期状態はphysiology-initial.jls。
世代コピーでは身体を新規生成し、学習済みMBだけを引き継ぐ。既存TrialPredator/PredatorMindの型レイアウトを変えず、旧学習済み保存を読める。
身体版での再開は7番目のphysiologyもanimal_trial_step!へ渡すこと。省略すると旧身体経路になる。
これは現在の動物単独・学習済み実験の接続。通常LWの単純捕食FSMや兎へ身体版を自動接続したものではない。

休息需要=strain+瞬発力の不足率。休息基礎優先度は固定2から4*需要へ置換、空腹反発は従来どおり。
需要<=1e-6ならrest/visit_rest候補は出さない。場所記憶は保持する。
休息の予定時間は回復速度から算出し1〜600tickへ制限（600は固定滞在時間ではなく既存試行上限）。
回復完了、または開始時より空腹重みが既存許容幅0.05を超えて増した時は再考。行動を強制的に狩りへ切り替えない。
休息の実績は実際の需要低下から食料消費を差し引き、見積もりと共通resolve_prediction!で比較。
昼夜は視覚条件のまま。睡眠時刻の強制、消化・死体保存・損傷発生/自然治癒は今回追加していない。

## 食料需要による無益な獲得候補の抑制（2026-11-07）

`configured_paths/predator_food_demand.jl`。動物単独の身体版で既定有効、shared_body=falseで旧挙動。
暫定固定: 既存initial_food=900を備蓄目安とし、不足量と予測基礎消費を比較する。
不足量が予測消費以下ならhunt/visit_food候補を外し、無報酬idleを候補へ追加する。
探索の消費は既存episode_ticks=600、餌場移動は移動見積もり+600、idle再評価はdecision_ticks=60。
狩りの期待値も学習見積もりを不足量で上限化し基礎消費を引く。ただし過去の低い見積もりだけで
空腹時の探索まで閉ざさない（候補の需要判定は不足量対消費）。移動追加消費はまだ予測に未算入。
経路・成功記憶は保持。待機は基礎代謝のみ、回復報酬なし。疲労回復候補や同種相手対応は残る。
胃の満腹ではなく備蓄需要の近似。消化・貯食・将来需要へ置換予定。通常LWの単純FSMには未接続。
候補のfood_demand_forecastと試行記録に予測を保存する。抑制された候補は選択記録に残らない。

## 動物単独実験の草資源倍率（2026-11-07）

既存wildlife.grass_scaleをanimal_trial_world/scent_run/世代runnerへ接続。
世代runner第7引数（既定1.0、有限正数のみ）。今回の実験では3.0を指定。
初期量とセル容量を倍率化するため、既存2日で容量分を戻す再生式の絶対再生量も同倍率。
草のセル配置・密度特徴・地形・初期個体配置・兎の消費/選択は変更しない。
これは世界資源条件であり固定行動ではない。conditions/resultに倍率を記録。
旧実験の凍結入力は変更しない。量不足と行動上の餌への到達問題は別途検証する。

## 人あり世界への学習済み捕食者の実験接続（2026-11-07）

専用runner `humans_learned_predators.jl INPUT DONOR_GENERATION OUTPUT DAYS [DONOR_INDEX=2]`。
通常LWへ自動適用せず、凍結ソースの接続点だけを変更する。人の設定経路・研修条件を入力から保持。
実験者が指定したMBを2体へ独立コピーする暫定設定。身体/急性親H/進行中試行/知覚は初期化。
人側のrosterを入力と接続し、兎は成体95+初期幼体5、草3倍、捕食者は学習済み2体。
従来の単純捕食FSMはpredator_count=0で無効化し、二重捕食・二重更新を避ける。
動物単独の更新をprepare/advanceへ分離して、人の観測と行動の間に同じ実装を接続。
兎は人と捕食者へ反応、人は兎/捕食者を動体・外見として観測。捕食者から人への攻撃、
人の狩猟、捕食者の人に対する威嚇は未接続。動物単独の相互作用と区別する。
捕食者cohort（MB・局所状態・身体・匂い・乱数）は日次checkpointの同じ直列化グラフへ追加。
人の30日生活を見るため捕食者全滅でも停止しない。実験入力/条件/凍結ソース/日別進捗を保存。

## 人の残留臭による局所反発（2026-11-07）

`configured_paths/human_scent.jl`、HUMAN_SCENTへ仮係数を隔離。
人あり専用runner第6引数trueでON、既定false。通常LW/動物単独は自動ONにしない。
暫定固定: 人臭の負の価値（捕食者3/兎2）は未学習。将来は種差・経験MBにより更新する。
4mセル、60tickごとに各人の現在セルへ0.5加算、容量4、17280tick=1日で線形消失。
場の更新だけが実在位置を使う。動物は半径8m内の残留臭セル中心と減衰強度だけを参照し、
現在の人座標、拠点ラベル、未観測の遠方マークは参照しない。風・壁による拡散遮断は未実装。
距離減衰(1-d/8)^2による外向きベクトルを、既存移動方向へ加算。多数セルの合成反発は種の係数で上限化。
捕食者は移動/追跡/飛びかかり/退避/記憶地点への移動に適用。衝突検査と実消費は既存の物理更新が担当。
兎はSEARCHの移動のみ、授乳帰巣の既存ポテンシャルに重ねる。視認によるFLEEは既存の逃走を優先。
休息/採食/睡眠中の強制移動、幼体の巣離脱、人側の固定認知停止解除はしない。侵入禁止ではない。
`HumanScentField`は捕食者cohortに保持し、日次checkpointへ保存。日次human_scentに
マーク数、deposit数、種別sample/signal/turn数を記録。回数は遭遇数ではなく関数適用回数。
専用18項目PASS（局所性・残留・減衰・実移動・保存・OFF更新一致）。wildlife CIへ追加。

## 固定の濃い拠点臭と弱い通過跡（2026-11-07）

ユーザー指定により拠点を固定匂い源に変更。上記初版の残留臭設定を本節の値で更新。
`HumanScentField(camp=scene.home)`で拠点中心の常設源を設定（強度4、半径8m、減衰なし）。
人ありrunnerの人臭ON時に接続。人が不在でも維持し、匂い源の存在は世界の固定条件。
動物へは半径内の勾配として作用し、拠点ラベルによる禁止/強制退避はしない。
`HumanScentField()`は拠点源なし。runner第6引数falseなら匂い系全体OFF（既定false）。
通過跡は60tickごと0.05、セル上限0.2、寿命600tick。通過跡の合成勾配も0.2を上限とし、
人が通る道全体を強い回避帯にしない。拠点源はこの通過跡上限の対象外。
既存の種別係数（捕食者3/兎2）・衝突/消費・移動時だけ作用する範囲は維持。
この常設源は暫定固定として設定経路に隔離。将来、居住・施設・経験の仕組みへ置換する。
条件ログfixed_camp_scent、日次human_scent.campとruleに記録、checkpointにも保存。
HumanScentFieldの保存構造を更新したため、新仕様は新規開始用。旧保存は当時の凍結コードで読む。
専用27項目PASS（人不在での維持・時間不変・弱い跡/強い拠点の分離・局所性・保存・通過跡の重複上限など）。

## 捕食者の川越し直接接近見積もり（2026-11-07）

`configured_paths/predator_water_approach.jl`、`PREDATOR_WATER_APPROACH`。
local_hunt接続時の暫定固定（enabled=true、falseで従来動作）。sample_step=0.5mは直線の最大標本間隔。
観測した獲物/最後の観測位置への線分に水面があれば、その直接接近候補を除外する。
既存局所狩猟同様、地形の実値参照を使う近道であり、認識学習の実装済み宣言ではない。
対象/現在地が変われば再評価。永久的な獲物除外、捕食親の失敗/H追加、休息への切替は行わない。
他の到達候補がなければ既存SEARCHへ戻す。外側の旧選択器による同tick再取得を防ぐ。
進行中のATTACKは既存の成否判定を維持。橋・広域迂回・泳ぎの評価は未実装。
将来は地形MBからの不確かな見積もり/迂回候補へ置換。
条件ログdirect_water_approach、LocalHunt.countsのwater_direct_rejected（候補tick）と
water_target_released（追跡解除）に記録。保存型は変更しない。

## 逃走観測からの追走/離脱（2026-11-07）

`configured_paths/predator_pursuit.jl`のPREDATOR_PURSUIT。統合実験はcohort.pursuitsを接続してON。
animal_trial_prepare!/advance!のpursuits=nothingがOFF（動物単独の既定）。人側の判断は変更なし。
連続観測位置から獲物の外向き速度を推定し、0.1m/tick超を暫定の逃走判断とする。
未観測なら判定保留。獲物の内部状態・真の速度は選択に渡さない。
共通BasicLoopでpursue/abandonを選ぶ。初期係数は進展2、疲労3、未解消残差1。
空腹、身体疲労、20tick内の予測接近率、代謝＋移動費を候補評価へ使う。
追走0.85m/tick、見積もり20tick、許容距離差0.5m、実移動1mあたり瞬発力0.2/追加疲労0.002。
既存の距離比例エネルギー消費に加えて、同じBody.exertで瞬発力と疲労を更新する。
予測は開始時固定。20tick経過時の距離残差を子MBのHへ一度だけ渡し再選択する。
獲物停止・観測喪失・身体限界・親目的変更で子を終了。捕獲範囲到達は子のみ成立、報酬0。
捕食親へ局所到達を食料獲得として転送しない。攻撃抽選と捕獲報酬は従来どおり。
離脱対象は暫定20tick再取得を抑制、停止を観測すれば早期解除。永久除外ではない。
種別速度・身体係数・判定幅・時間は暫定固定として隔離。将来は身体較正/経験/文脈へ置換。
予測不能や経路失敗を世界の真値で正解判定せず、川の暫定通行見積もりは前節のまま。
条件pursuit_decision、日次predator_pursuitsのcounts/records/Hに記録。
新sidecarもcohort内でcheckpoint保存。旧再現比較は既存状態を保持した明示移行のみ。

## 追跡の局所成功と餌場の不成果（2026-11-07）

`predator_pursuit.jl`は捕獲距離到達を追跡方法の成功証拠として渡す。
子目的と方法の未解消Hは解消するが、過去のfailure_H_totalは保持し、completion_reward=0。
食料確保の親Hや捕獲実績は接近だけで成功にしない。

`configured_paths/predator_food_site.jl`のPREDATOR_FOOD_SITEは認知版で既定enabled=true。
falseで蓄積/反発とも無効。暫定係数scale=.25、tau=3、指数上限8（数値発散防止）。
反発=.25*expm1(min(8,u/3))。u=1/3/6/9で約.099/.430/1.597/4.771。
未解消不成果uは既知餌場の半径place_cell=8m内で実際にhuntした時間600tickを1単位とする。
重なる場所には最近傍の1地点だけ帰属。同距離はキー順で決定。再選択や到着では増えない。
短時間の探索はeffort_ticksへ持ち越す。移動/休息/死亡時間は対象外。
世界の獲物数を参照せず、本人の位置と場所記憶・狩猟時間・摂取だけを使う。
捕獲で得た実摂取量/(hunt_prior .3 * food_value_scale 900)を未解消量から引く。
小型幼体67.5なら.25単位、成体1350なら5単位（容量超過分は成功栄養に含めない）。
端数は探索時間へ戻す。勾配は整数単位で更新する暫定実装で、連続感度モデルではない。

保持は既存mind.estimatesのfood_site:<site>:unresolved/effort_ticks名前空間。
旧checkpointは未登録=0から開始し、過去の空振りを推測して後付けしない。
food_site_evidenceとして日次mind報告、候補にはfood_site_repulsionを保存。
餌場visit候補のpriorityにだけ減点し、位置/到達経路/acquisitionの到達実績は維持。
食料目的以外の通過や退避経路には適用しない。huntの方向場への直接適用は未接続。
将来は場所半径/必要探索時間/期待栄養の単位を経験とρへ接続する。

## 兎の接近残差H試作（2026-11-07）

`H.RabbitApproachPolicy()`を`H.step!(...;policy=...)`または
`LWGrazing.advance!(...;grazing_policy=...)`へ渡して明示ON。既定は従来FSM。
`configured_paths/rabbit_approach_parameters.jl`のRABBIT_APPROACH:
移動見積もりspeed=.2m/tick、minimum_ticks=10、許容距離distance_band=.25m、
H上限32、温度尺度2、個体別セル記憶上限64、診断履歴64。
自己位置と近傍8セル観測は既存のショートカットで、将来は経験/ρの見積もりへ置換。

見積もりは選択時の距離/.2（最低10tick）で固定。SEARCH実行tickだけを数え、
期限でmax(0,実距離−予測距離−.25)/max(.25,初期距離)を、そのセルのHへ一度だけ加算。
再観測/再選択ではHを消さない。目標セルへ実際に入ったときだけその接近Hを解消。
休息・採食・睡眠・警戒・逃走・授乳帰巣の強制SEARCHは接近評価を進めない。
局所到達から採食/身体維持の報酬を作らない。餌の不成果や親維持Hはこの試作では未追加。

候補は従来の草量/距離/向き/直前セルのスコアからセルHを引く。
近傍候補のHが0なら最大スコアを選び、H>0なら温度1+最大H/2のsoftmaxで選ぶ。
共通の残差・H平坦化の考え方を使う軽量版で、BasicLoop本体の利用ではない。
一時的に目標から離れる隣接セルも候補で、特別な脱出/ワープ/餌場禁止はない。
記憶上限ではH最小（同値はセルID順）を忘れる。長期保持保証ではない。

policyオブジェクトが個体別H・見積もり・RNGを所有し、直列化可能。
呼出し側は同じpolicyを毎tick保持し、再開時には世界と一緒に保存する必要がある。
長期統合runner `humans_learned_predators.jl` の第7引数 `true` で接続する（省略時false）。
同じpolicyをpredator_cohort内に保持し、H・固定見積もり・RNGを日次checkpointへ保存。
日次結果のrabbit_approachには個体別H・目標・経過・見積もりを記録する。
通常LW単独runnerへの自動接続はまだしていない。
旧世界構造の変更はなく、試験では旧day-006 checkpointを読み込める。

## 捕食者の任意渡河（2026-11-08）

`predator_crossing.jl` の `PREDATOR_CROSSING`。mind.estimates["crossing_enabled"]=1でON、既定OFF。
同じ維持親MBの候補cross:east/westとして共通のchoose_method!/H平坦化へ渡す。
priorityは食料圧−2.5−見積費用/900。Hや失敗回数による強制選択はしない。
身体備蓄が渡河見積費用の1.2倍以下、予測移動strainで1以上、着地点が岩/水なら候補を出さない。
満腹時は既存の食料需要フィルタを適用。到岸は局所成功のみ、親Hと食料報酬は変更しない。

数値：陸上.22m/tick、水中.12m/tick、水中移動消費は陸上の4倍（基礎代謝は別に1回）。
着地点は同じzの対岸+1m、到着半径.4m。予測時間は陸/水距離と速度から1.5倍余裕。
川式と自己位置を使う暫定的な完全地形知識。獲物の真の分布は参照しない。
水中では休息/期限による再選択を岸まで延期する暫定固定をconfigured_crossing_committedへ隔離。
死亡による終了は延期しない。障害物/世界境界は通り抜けない。
流速/深さ/浮力/溺水/水泳疲労の種差は未実装。兎は従来どおり水へ入らない。
将来は観測地形MB、泳ぎと上陸の身体能力、経験からの費用予測へ置換。

実験配置は `predator_crossing_layout.jl` のCROSSING_LAYOUTで隔離。
west_rabbits=20、seed=20261108、岸から3m以上の草地を選び家族単位で東西20:80へ配置。
出生/授乳情報は保持し初期位置/巣だけ変更。行動側には全体の配分を伝えない。
`crossing_longrun.jl INPUT DONOR OUTPUT DAYS [true/false]` は人なし、捕食者2、草scale3、
兎H/繁殖ON、同じ旧BのMBを継承し、渡河選択時H/確率/食料/費用と成否を記録する。
日次checkpointには世界・全MB・RNG・兎H・集計を保存。全捕食者死亡後も指定日数まで進める。

### 捕食者の基礎消費を半減（2026-11-08）

PREDATOR_ANIMAL_TRIAL.daily_foodを600→300食料相当量/日へ変更。
実カロリー/重量への較正ではなく、捕食間隔と再生のバランスを調べる暫定身体条件。
移動.1/距離、水泳移動4倍、初期備蓄900、需要目安900、容量1800、成体栄養900×実験倍率1.5は維持。
実行と費用見積もりは同じdaily_foodを参照。休息の追加費用は変更しない。
旧600の実験ソースは凍結済み。比較は同じ初期条件からの新規90日で、状態の途中移行ではない。

### 捕食者なし・草半量の比較（2026-11-08）

`crossing_longrun.jl INPUT DONOR OUTPUT DAYS [crossing=true] [predators=2] [grass_scale=3]`。
predatorsは0/2、grass_scaleは有限の正数。世界資源の既存wildlife.grass_scaleを実験引数化。
1.5は旧3.0に対し、各セルの容量・初期量・容量比例の再生量を半分にする。
草の配置、地形、兎の初期状態、繁殖率を直接変更しない。conditions.jsonへ実値を保存する。
期間上限は360日のまま。草半量は途中の状態変更ではなく初日から比較する。

第8引数 `add_predators_from_checkpoint` は捕食者なしの日末状態に2匹を追加する実験専用。
世界時刻・草・兎の身体/繁殖/乱数/Hを保存状態から保持し、草倍率の途中変更は拒否する。
捕食者は既存試験の初期位置・身体条件と指定ドナーMBで新規導入。場所記憶の時刻を導入時へ合わせる。
期間は追加日数、日次dayは追加後の日数、absolute_dayは元世界からの通算日数。

### 母個体の幼体セル採食反発（2026-11-08）

撤去済み：同日の巣穴方式へ置換。以下は実験履歴であり、現行APIではない。

`configured_paths/rabbit_nest_grazing.jl`、`RABBIT_NEST_GRAZING`。
生存する自分の離乳前の子のセルに対して、採食費用=1+4×草容量。
capacity_multiplier=4、cost_floor=1は草量と同じ評価尺度の暫定値。
現在のセル資源上限を上回るので母親はそこで採食せず探索へ移る。
近傍の採食目標評価からも差し引くが、通行禁止・授乳禁止ではない。
逃走/授乳の既存上書きを優先。他個体や離乳後/死亡後の子には適用しない。
`G.advance!(...;nest_grazing_avoidance=false)`でOFF、既定true。
子の位置・血縁・生存状態は世界データの直接参照という暫定固定。
将来は観測・巣記憶・子との関係MBからの採食勾配に置換する。
草の実量/観測値を書き換えず、行動の評価費用として接続。
crossing_longrunのconditionsにONと係数、H目標変更時はrecordsに
grazing_relation_changedを記録。保存状態のrequests/consumedでも作用を検査できる。
新生児数×母数の全組合せ検索をせず、一回の走査で母→セル集合を構築する。

### 幼体の巣穴（2026-11-08）

`configured_paths/rabbit_burrow.jl`のRABBIT_BURROW.enabled=true。
繁殖ONかつ母IDあり・28日齢未満の幼体は出生地点の穴内として扱う暫定世界規則。
掘削・入口・内部地形・自発的な出入りは省略。離乳境界で自動的に地上扱い。
捕食者の視覚と両捕獲方式（従来/確率）で保護し、人へのvisibilityも0。
授乳・餓死・匂いは既存のまま。母を含む全個体の草採食は通常ルール。
enabled=falseを凍結前に設定すると旧草上待機へ戻る。繁殖OFFでは無効。
conditions.rabbit_burrowへ設定、日次dependent/保存個体born,motherで対象を追跡可能。
将来は穴の形状・入口の観測と出入り行動へ置換する。学習による隠れ行動ではない。

捕食者なしの巣穴対照実験：crossing_longrunの第8引数の保存状態をpredators=0でも
継続可能とした。元状態に捕食者がいないこと、草倍率一致、日末境界の検査は維持。
年齢・繁殖/乱数・草・兎Hを引き継ぎ、再配置しない。donor引数は0匹時には未使用。

### 授乳前のまとめ採食と不足による再要求（2026-11-08）

`configured_paths/wildlife_reproduction.jl`のRABBIT_NURSING_PLAN。
request_energy=4（幼体1日消費分）、milk_target=8は既存身体値。
子の不足＋帰巣中の子の消費を効率.75で母体必要量へ換算し、母の留保35と帰巣消費を足す。
move_speed=.2、move_cost_per_tick=.012は既存移動の値、travel_slack=1.5は直線距離への暫定余裕。
departure_cap=85は既存通常満腹値。上限を超えた必要量を待ち続けず85で出発可能。
準備中は満腹休息より採食を優先するがgut_limit=3.8、sleep_limit=1、minimum_grass=.005は
既存の胃/睡眠/採食境界を保つ。採食速度・消化速度・身体容量は増やさない。
enabled=falseは準備/帰巣の設定介入のみ無効化し、従来の日次打切りへは戻さない。
血縁・子のenergy・巣座標・世界草量を直接参照する暫定固定。将来は観測と関係MBへ置換。
母ごとに全幼体の不足を合算。1tickの小さな補充を繰り返さないよう子energy<=4で授乳を開始し、
その場の兄弟の不足を8までまとめて補充する。供給不足なら次tick以降も再試行可能。
nursed_dayは最終授乳日の記録のみ。日次の実施済みを要求/供給の遮断に使わない。
conditions.nursing_plan、既存milk_in/out/nursing_visits/nursed_day、比較用eventsに記録。
遠方・低資源で準備が間に合わない可能性は残る。子の余命からの緊急出発は未実装。


## 2026-11-08 兎の任意渡河（暫定固定）

地域的な草不足から移動できる候補としてRabbitSwimmingPolicyを追加。通常OFF。既存RabbitApproachPolicyを包み、探索中・岸から6以内で64tickごと（個体ずらし）に検討する。空腹と局所Hで確率上昇、近傍の観測草量で低下。対岸の草量は参照しない。
川形状・着岸点の世界実状態参照は暫定固定。陸上速度0.2/水中0.1、消費0.012/0.036（各tick）。費用予測×1.5＋余力5を満たす場合のみ候補化。岸で授乳・逃避上書きがあれば中断、水中は着岸まで継続。障害物・境界は貫通せず、巣穴幼体は泳がない。流速・溺死・体温は未実装。将来は岸の観測・身体MBへ置換。
実装はsrc/lw/configured_paths/rabbit_swimming.jl。crossing_longrun.jl第9引数rabbit_swimming=trueで有効化。conditions.jsonに条件、日別にselected/arrived/swim_ticks/interrupted累計、個体記録に選択・到着を保存。途中の目的地・乱数をチェックポイントで継承。水中に取り残すためON保存状態からOFFへの切替は拒否。


## 兎近傍GPU接続（2026-11-08、実験用）

`crossing_longrun.jl` 第10引数 `cpu`（既定）/`gpu`/`gpu_audit`。通常CPU動作を維持し、GPU利用時のみOpenCL.dllへ接続。H・乱数・草更新・行動選択はCPUのまま。状態確定後、近傍観測が必要なSEARCH個体の候補を一括転送し、静的な岩との線分クリアランスを返す。川・境界条件は元のFloat64処理。
`src/ecology/herbivore/neighbor_batch.jl` の `RABBIT_NEIGHBOR_GPU_BAND=0.001`（地図座標単位）はFloat32境界再判定用の暫定数値許容帯。帯内・非有限値は元のCPU判定へ戻す。対象地図・障害物座標は絶対値1000以内に制限。任意地形に対する数学的な誤差保証ではないため、新地図ではgpu_auditでCPU照合が必要。世界・tick・観測元位置が違えばキャッシュを使わない。静的障害物が変わった場合は再初期化が必要。
実行ハンドル・キャッシュは保存状態に含めず、ロード後にバックエンドを再生成。conditionsと日別neighbor_gpuに機種・バッチ数・候補数・キャッシュ利用・境界再判定数を記録。これは計算方式の切替であり、固定行動の追加ではない。


## 2026-11-08 観測要求・結果の共通バッチ型

RabbitNeighborBatchをCPU/GPU共通に変更。要求はFloat64の始点・終点配列、結果はBool配列。個体×近傍方向の固定配列で要求位置を引き、毎tickの辞書登録・検索を除去。配列は個体数増加時のみ拡張し再利用。GPU用Float32への変換も事前確保領域へ書き込む。CPUは同じ要求に元のFloat64線分判定を適用する。観測時刻・要求生成条件・草/H更新順は変更しない。
ランナー第10引数はcpu（従来逐次、既定）/batch_cpu（共通型CPU）/gpu/gpu_audit。既存enable_rabbit_neighbor_gpu!も互換入口として残す。GPU境界帯0.001と監査は継続。計算方式のみで、新たな固定行動・観測間引きは加えない。


## 候補数によるCPU/GPU自動切替（2026-11-08）
第10引数auto/auto_auditを追加。共通要求バッチの候補数がRABBIT_NEIGHBOR_GPU_MIN_QUERIES=128以上ならGPU、それ未満ならCPU。暫定の実行系パラメータで、最適な境目の確定値ではない。個体の行動・H・観測時刻は変更しない。CPU選択時はFloat32変換・転送・GPU呼出しを行わない。GPUハンドルは初期化時に用意して再利用。cpu_batches/gpu_batchesおよび双方の候補数を日別累計で記録。既定は従来cpuを維持。30日比較ランナーはbatch_cpu→gpu→autoの順次実行、同じ66日目保存状態・泳ぎあり・捕食者なし、全日チェックポイントを三者比較。


## 2026-11-08 暦による兎の繁殖停止を既定OFF
`RABBIT_BREEDING_SEASON.enabled=false`をconfigured_paths/wildlife_reproduction.jlに追加。新規妊娠を止めていたmod(day,365)<240をconfigured_rabbit_breeding_openへ隔離し、通常は通年許可。過去条件の再現にはenabled=true、日次処理の検査・呼出しではrabbit_daily!(...;seasonal_breeding=true)を使用可能。旧year_days/season_daysは再現用に保持。成熟150日、雌雄の遭遇、エネルギー70、妊娠・回復・受容周期など他の条件は維持。暦の直接参照は暫定固定で、将来は環境・身体条件へ置換。スナップショットとcrossing_longrunのconditionsにbreeding_seasonを記録。旧凍結ソース・既存結果は変更しない。変更後の長期実験は未実施。

- 兎繁殖の身体応答: src/ecology/lw_grazing/reproduction.jl / RABBIT_REPRODUCTIVE_CONDITION。reserve_low=35、reserve_full=85（身体エネルギー）、balance_tau_days=3（日次収支EWMA時定数）、balance_scale_per_day=5（エネルギー/日）。全て暫定身体近似、enabled=true。満腹で収支0でも繁殖可能。詳細はwildlife報告の『繁殖と身体収支』。

- 分散初期集団: src/lw/configured_paths/rabbit_diverse_start.jl / RABBIT_DIVERSE_START。新規試験のdiverse指定だけON、既定baseline。100体の年齢/家族/身体状態分布を定義。ゲーム世界の初期条件であり学習規則ではない。詳細はwildlife報告。

- 草の初期残量: src/lw/configured_paths/rabbit_patchy_grass.jl / RABBIT_PATCHY_GRASS。seed20261110、区画幅20世界距離、残量比0.2〜1.0。暫定固定の世界初期条件で既定full、明示patchy時のみ。容量/再生速度は変更しない。

- 出産前巣候補: src/lw/configured_paths/rabbit_nest_preparation.jl / RABBIT_NEST_PREPARATION。lead_days=3、観測半径8、採食評価半径3、距離費0.12、選択温度0.5、移動reserve70/眠気1未満、到着半径0.6。全て暫定固定。既定ON、将来は場所MBへ置換。

- 2026-11-09 草の遮蔽への移動加点: src/lw/configured_paths/rabbit_cover_foraging.jl / RABBIT_COVER_FORAGING。enabled=true、RabbitApproachPolicyのみ適用（泳ぎラッパーを含む）。reserve_low=25、reserve_full=85、cover_target_weight=2。暫定固定の認知評価。観測coverに身体余裕を掛けて移動候補へ加点。空腹時は加点を弱め、reserve25以下で0。採食切り上げの状態上書きは撤去した。enabled=falseで旧候補評価。将来は露出・採食経験MBへ置換。crossing_longrunのconditionsに記録。

- 2026-11-09 分散初期配置: src/lw/configured_paths/rabbit_distributed_layout.jl / RABBIT_DISTRIBUTED_LAYOUT。seed=20261109、tile_width=16世界距離、bank_margin=3。真の通行可能性と草容量を参照する暫定固定の実験初期条件。親子を保持し、区画容量比例の人数割当とグループ間距離を使う。crossing_longrunの第13引数distributed（新規の既定）/legacy（旧西20東80）。継続時は再配置せずinheritedを記録。草初期残量・身体・経験は変えない。将来は準備期間での自律分散へ置換。conditions.layoutに設定・各区画配分を保存。

- 2026-11-09 薄い草からの採食離脱: src/lw/configured_paths/rabbit_sparse_departure.jl / RABBIT_SPARSE_DEPARTURE。enabled=true、density_hungry=0.005、density_comfortable=0.05、reserve_low=25、reserve_full=85。観測density（植生密度×残量比）が身体余裕に応じた線形閾値未満ならGRAZEをSEARCHへ変更。等号は採食継続。睡眠・休息・逃走や授乳overrideは従来どおり。暫定固定で将来は採食成果MBへ置換。無効化はenabled=false。conditionsへ記録。

- 2026-11-09 二層草モデル: src/ecology/herbivore/grass_layers.jl / GRASS_LAYERS。初期short割合0.6、成熟時定数4日、従来同様空容量を2日で補充、短草の遮蔽係数0.2。容量を増やさず再生はshortへ、成熟はlongへ質量移送。crossing_longrun第14引数layered（新規既定）/single。src/lw/configured_paths/rabbit_grass_layers.jl の暫定固定選択: reserve55以下かつshort_density0.02未満ならlong、long一口量は通常の0.5。経験由来ではなく将来は味/採食成果MBへ置換。層別残量・累積採食・成熟量を日次保存。World型を拡張したため旧チェックポイントは旧凍結ソースで読む。

- 2026-11-09 1m格子比較: rabbit_grid_refinement.jl、crossing_longrun第15引数cellsize=2（既定）/1。新規配置後・二層化前に親セルを4分割し容量と残量を1/4へ、植生と地形区分を継承。初期位置は保持。候補中心の軸方向範囲2mを保ち、1mでは24候補（2mは8）。草の評価量は従来4平方単位当たりへ換算。CPU/GPUバッチも候補数へ対応。実際の衝突判定は連続形状を使用。到着のセル進入判定・最低予測10tickは維持するため経路の選び直し頻度は変わり得る。新規のみ分割、継続では格子変更不可。

- 2026-11-09 格子細分化は負荷優先で撤回。通常処理は2m・8候補へ復帰、第15引数による格子選択も撤去。1m試験の凍結ソースと比較記録は保持。二層草と分散配置は維持。

- 2026-11-09 短草再生の校正: GRASS_LAYERS.regrowth_days=0.1日へ変更（指数回復の時定数）。short_capacity_fraction=0.6、長草は残り0.4で総容量維持。長草が満量でも短草再生可能、成熟は長草満量で停止する世界近似。enable_grass_layers!のrenewal=trueが既定、falseとregrowth_days=2で旧式比較。一区画容量9に1/2/4匹を固定する診断で各30日比較し採用。詳細と固定診断の限界はexperiments/lw_wildlife/grass_regrowth_calibration.md。旧保存状態は凍結ソースを使用。

- 2026-11-09 採食小移動: src/lw/configured_paths/rabbit_grazing_motion.jl / RABBIT_GRAZING_MOTION。enabled=true、interval_ticks=60（5分）、step_distance=0.1、turn_amplitude=π/4、turn_phase=2.399963229728653、候補offsets=(0,π/2,-π/2)。暫定固定で将来は採食成果MBへ置換。RabbitApproachPolicyと泳ぎラッパーのみ、採食成功・overrideなし時に実行。近傍3点の草量参照、同点は前向き優先。通常の衝突・座標更新と共通化し、移動距離当たり追加消費0.0365を適用。採食は移動前セル、探索ターゲットは小移動後に無効化。睡眠・休息・幼体待機には不適用。enabled=falseで無効化。crossing_longrun条件と日次grazing_motionに試行/成功/阻害を保存（統計はプロセス単位、継続起動では0開始）。

- 2026-11-09 巣の境界回避: RABBIT_NEST_BOUNDARY.enabled=true。境界距離8.25以上（WILDLIFE_BOUNDARY.width+body_margin）を許可。初期生成・distributed配置・巣候補・出生位置に適用。巣候補は到着半径0.6も余白へ加える。予定日に禁止帯なら出産保留し、妊娠追加コストなしで巣準備を継続。候補未確保時は日次再検討。瞬間移動なし。暫定固定で将来は場所MBへ置換。enabled=falseで解除。旧legacy配置・旧保存状態は自動移設しない。出生保留はdueが現在tick以前として記録、長期ランナーconditionsにも設定保存。今回は長期未検証。

- 2026-11-09 幼体段階採食: RABBIT_JUVENILE_GROWTH(enabled=true,start_days=18,range_at_weaning=8,burrow_radius=0.25)。18日丁度は0、18〜28日で採食口量・胃容量・消化速度を線形増加。通常代謝と幼体代謝4/日を同率混合し二重課金しない。行動半径0〜8、離乳後は制限解除。授乳は28日まで維持。巣から0.25を超えれば捕食・視覚対象、移行期は泳ぎ不可。経験由来でない暫定成長近似。enabled=falseで従来の28日一括切替へ戻す。将来は身体発達と採食経験へ置換。長期ランナーconditionsへ設定保存。生存そのものの抽選なし。

- 2026-11-09 局所ρ実験（通常OFF/未接続）: rabbit_local_rho_experiment.jl。候補なしSEARCHのforecast_ticks=10、H_trigger=1、H_limit=32。半径0.4/0.8/1.2/1.6、32方向、arrival=0.21、visit_resolution=0.4、visit_penalty=0.7、heading_bonus=0.15、distance_cost=0.1、forecast_slack=2、speed=0.2。全て暫定実験係数。親MBへの共通接続は未実装。詳細とON/OFF結果はexperiments/lw_wildlife/local_rho_mother71.md。

- 2026-11-09 局所ρ通常接続: RABBIT_LOCAL_RHO.enabled=true。RabbitApproachPolicy/泳ぎラッパーの全個体SEARCHに適用、逃走/泳ぎには不介入。通常目標あり・局所Hなしなら追加走査なし。幼体移動範囲は細候補にも適用。採食再開で局所圧を解除、他状態では中間目標中断。history_limit=64、visit_limit=256で記録を制限し累計は別保存。個体ごとのlocal_rhoをcheckpoint保存、長期日次local_rhoに発動個体数・照会点数・イベント累計を保存。RabbitApproachMemory型変更のため旧checkpointは旧凍結ソースで読む。局所ρは親MB全体のHと未統合、候補ありの停滞は従来処理のまま。

- 2026-11-09 食料確保の親H局所試験（通常未接続）: RABBIT_FOOD_PRESSURE。forecast_ticks=120、search_cost=0.012、residual_scale=4、H_limit=32、gut_conversion=3。探索開始の体力+消化見込みから固定予算1.44を差し引き、未回復分だけH化。局所到着で解除しない。候補選択時に評価、非選択中は前回値。実験は個体16のみ。既存のHゼロ/正の確率切替の不連続も作用。詳細はexperiments/lw_wildlife/food_pressure_rabbit16.md。将来は学習見積もりへ置換。

- 2026-11-09 親H選択閾値の局所比較: RABBIT_FOOD_PRESSURE_GATE(enabled=true,enter_H=1.0,exit_H=0.5)。個体16の局所ランナーのみ、通常未接続。親/局所Hの最大が1以上で確率選択、0.5以下で解除、中間は状態保持。非活動時は選択圧のみ0、生のHと候補スコアは保持。更新は候補選択時だけ。enabled=falseで旧H>0切替。暫定固定で将来は目的・経験の許容帯へ置換。実験JSONに設定/発動ログ、詳細food_pressure_threshold_rabbit16.md。

- 2026-11-09 親H閾値の通常接続: RABBIT_FOOD_PRESSURE_CONNECTION(enabled=true,history_limit=64)。全RabbitApproachPolicy（泳ぎラッパー含む）の新規目標選択時のみ、局所Hと親Hの最大に1.0/0.5ゲートを適用。falseで親H接続前へ復帰。H計算・観測の毎tick追加なし。最初の選択時の身体予備量を固定基準とする暫定近似を局所試験から維持し、試行別の学習見積もりへの置換は未実装。履歴は64件、累計選択数は別保持。日次food_pressureに集計。メモリ型変更のため旧チェックポイントは旧凍結ソースで読む。

- 2026-11-09 親H閾値の次回比較: RABBIT_FOOD_PRESSURE_GATEの暫定既定値をenter_H=4、exit_H=2へ変更。個体16の局所比較で採食再開時energy64.87を残した条件。最適値の確定ではない。同一初期条件の90日で1/0.5版と比較する。その他の式・接続・有効化条件は維持。

- 2026-11-09 摂取時の親H冷却: RABBIT_FOOD_COOLING.enabled=true。実際の採食量>0の直後に、胃内容込みの既存予備量式を再評価。栄養を別途減算しないので消化時の二重冷却なし。max(親H,保持局所H)<=解除閾値でゲート解除、局所Hそのものは食事で消さない。未初期化予測は作らない。falseで旧選択時のみ更新。暫定固定接続で将来は食料確保MB成果評価へ置換。記録intake_cooling、履歴上限64。初回予備量固定の近似は変更していない。

- 2026-11-09 摂取冷却あり次回比較: 開始H=8、解除H=4へ暫定変更。その他の親H式・初回基準・局所H合成は維持。90日比較で速度と生存を見る。最適値確定ではない。

- 2026-11-09 限界側の比較: 開始H=20、解除H=10へ暫定変更、摂取冷却ONを維持。同一条件90日で開始8版と比較。個体16の局所生存は確認済みだが一般的安全値ではない。身体・親H式・初回基準は変更なし。

- 2026-11-09 食料確保解除: RABBIT_FOOD_PRESSURE_GATE.release_on_intake=trueを既定。開始H20、解除は摂取量>0の成果で判定しH閾値を使わない。exit_H10はrelease_on_intake=falseの旧方式比較のみ。親Hの量的冷却は維持し局所Hは保持。採食中は選択ゲートを呼ばず、再度探索し候補選択した時に残存Hから再発動可能。Hが0になっても摂取前はモード保持、選択関数への圧はeps(Float64)でゼロ分岐と区別。暫定固定で将来は共通の成果/試行終了へ置換。記録food_acquired、設定はconditionsに保存。

- 2026-11-09 指数型候補幅: RABBIT_EXPONENTIAL_CANDIDATES(enabled=true,minimum=1,maximum=8,full_H=20,curvature=3)。新方式では開始/解除ゲートを迂回しmax親/局所Hを使用。正規化Hの指数曲線を整数丸めして粗順位上位Nへ限定。設定はconfigured_pathsへ隔離、将来はMB想起へ置換。falseで旧ゲート復帰。観測は全近傍のまま、限定するのは遮蔽加点/確率選択。conditionsと日次candidate_workに設定/処理件数を保存。長期効果未確認。

- 2026-11-09 授乳成立ゴール: RABBIT_NURSING_GOAL(enabled=true,completion_tolerance=1e-9)。子のenergy<=既存request_energy4で不足する同腹子をpendingへ登録、実際の乳供給でmilk_target8まで達した子だけ完了。局所到着/少量供給/危険中断では消去しない。死亡/離乳/母死亡は終了として除去。接近先は対象子の現在座標、最も低energy→距離→IDの順。既存の血縁/体力/位置への直接アクセスを使う暫定固定で将来MBへ置換。enabled=falseで巣目標に復帰。pending/targetsはRabbitLifeに保存、日次pending件数とconditions設定を記録。旧checkpointは凍結ソースで読む。

- 2026-11-09 警戒と授乳必要性の比較: RABBIT_NURSING_ALERT(enabled=true,near_distance=3,far_distance=10,history_limit=64)。ALERTのみ、必要性clamp((request_energy4-min_child_energy)/4,0,1)と危険clamp((10-最後の観測位置までの距離)/7,0,1)を比較、必要性>危険かつ既存departure_energy以上なら授乳接近を許可。同点警戒維持。FLEEや他の割込みは変更しない。母の体力不足時は警戒を解除しない。子の体力/血縁への直接参照は暫定固定、将来MBへ置換。falseで旧警戒一律優先。日次nursing_alertに検討/許可累計、直近64判断はRABBIT_NURSING_ALERT_RECORDS（プロセス内、checkpoint未保存）。
