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
