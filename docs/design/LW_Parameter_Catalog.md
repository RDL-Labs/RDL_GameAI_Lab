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
