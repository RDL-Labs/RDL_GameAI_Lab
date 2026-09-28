# L15A — 現行探索への有限接続

状態: FINITE CONNECTION ACCEPTANCE COMPLETE。2026-09-28。基準 `7ca3018`。
[Phase 1の純粋計算契約](LUANTI_L15A_subjective_movement_terrain_contract.md)の式は変更しない。
これはPhase 2の最小接続であり、拡張計画の全Phase完了ではない。

## 接続する範囲

`TerrainResourceExploration` は既存L14Bの3個体・共有資源・継続時計・個体別学習を利用するopt-in mode。
schemaは `l15a-terrain-resource-exploration-v1`。既存L14Bのschemaとpacketはそのまま維持する。
新modeは各観測の `movement_surface` を必須とし、旧modeはこの拡張を拒否する。

既存の判断順序のうち `observed_material_heading / observed_material_approach` だけを接続する。
本人が教示された外観を持ち、現在観測され、既存接近予算で除外されていない前方Foodを全件合成する。
最大5Foodの正規化・地表・障害物の式と範囲はPhase 1のまま。

- 取得圏内のpickup、所持品上限、身体対応不足のwaitは従来どおり。
- L14Bのvariation要求、目印へのsubgoal、周辺探索は従来の権限で実行する。
- Foodが見えないときに地形面から探索先を発明しない。
- 従来のFood観測は後方も含む。前方Foodがない場合は既存の観測方向への旋回を使い、再観測する。
- 地形に使うFoodがないことをWorld全体のFood不在とは扱わない。

既存の接近予算24操作とblocked target管理を維持する。
その帳簿のrefは既存制御の接近対象であり、合成地形が単一対象へ向かう保証ではない。
本接続は操作の生成経路を変えるため、以後の実結果・経験・M_Bが旧modeと同じになるとは主張しない。
採取学習の形成/独立検査/T1採用規則そのものは変更せず、同一入力の非接近経路で一致を検査する。

## 観測adapter

`movement_surface.lua` は現在の身体位置・yawから固定rayだけを取得する。
Worldのheight関数、`natural.destination`、非可視障害物一覧、資源残量をセンサー入力に使わない。
rayは最初の非air/未ロードnodeで終了し、その裏側の地表を補完しない。

| 取得 | 有限計画 |
| --- | --- |
| 地表 | −90/−45/0/+45/+90度。現在位置+0.5の眼から、水平1・高さ−3の終点へ各31点まで |
| 障害物 | −90/−60/−30/−10/+10/+30/+60/+90度。身体位置+0.25の高さ、距離6まで各49点 |
| 上限 | 13ray、合計547 node read以内/観測/個体。既存観測slotで1回 |

地表の最初の可視surfaceが既知の支持材(grass/dirt/stone)なら、
観測nodeと身体の相対高さ `node_y + 1 - body_y` を送る。
他の非airならblocked、最後までairならno_surface、未ロードならunavailable/partial。
これはrayの最初の可視surfaceであり、終点への経路が安全だという判定ではない。

障害物は各水平rayの最初の非air点だけを身体相対forward/rightへ変換する。
同じWorld物体へ複数rayが当たれば複数の観測点が残る。refはray標本の参照であり、物体IDではない。
その密度も合成反作用に影響するが、Phase 1のcapで有界にする。
「complete」はこの有限ray計画内での完了。ray間・眼の後方・未観測高さの自由空間を保証しない。
他個体entityとの衝突回避は取得対象に含めない。

Runtimeへ送る拡張は `schema/ground/obstacles` のみ。
各channelのsourceは既存packetのrun/epoch/agent/observation/clock/capture/pose/body revisionと一致し、
frame参照は `<observation_id>:ground / :obstacles` に固定する。
Food項は同じpacketの教示済み外観の観測からRuntimeで射影する。新たなFood真値を足さない。
Food coverageがpartialなら、切り捨て理由を推測せずそのままpartialとする。
実World位置、hit node名、ray始終点は実験者のauditにだけ保存する。

旧groundの色や遠景の粗い特徴を、高さ差・障害物距離へ読み替えない。
movement_surfaceは受理したexploration observationに保存する。既存SensoryObservationStoreには遠景のみを渡す。
この二つを同じSensorFrame storeへ統合したとは主張しない。

## 地形から一操作へ

1. 不完全取得または全方向除外ならwait。数値を0へ補完しない。
2. 最低方向に0度が含まれれば、現在のheadingでmove 1。
3. 最低方向のうち絶対旋回量が最小の方向が一意ならturn −90/−45/+45/+90。
4. 等しい左右旋回が残ればwait。右優先・ID優先・seedによる勝者選択をしない。

旋回と移動を同じ操作にまとめない。旋回後の新しい観測から再計算する。
高さの絶対閾値や履歴依存の慣性、局所極小からの脱出機構は追加しない。
一方へ誘引があっても、最終的な身体作用は既存 `natural.destination` が別途判定する。
地形面はWorld collision truthではなく、実行結果はmoved/blocked等としてそのまま残る。

## 権限・再送・学習

既存World controllerが、個体・観測・取得姿勢・body revision・期限を作用前に検査する。
操作は `op:<observation_id>` 一件。500ms以内かつ当該period内で失効し、実行済みIDの再送は既存結果を返す。
HTTP callbackから直接身体を動かさず、従来のWorldステップの受渡しを利用する。
Runtime再送では凍結したcommandを返し、地形・経験・学習回数を増やさない。
同じ観測IDで地形入力を変えるとconflict。他個体/旧姿勢のsource、不正な入力も部分公開前に拒否する。

各decisionには地形全体・寄与別出典・適用gateを保存する。command/result/次観測は従来のIDで結び付く。
active M_B・社会relation・未知の価値・身体疲労は地形の重みに使わない。
地形の高さや差をCore E/H/θ/M_deltaへ自動変換しない。

## 有限受入

- Python: Foodと障害物配置が既存commandを変える、左右反転/同点、欠測wait、後方/採取/探索優先、
  model採用経路、旧mode非介入、source混線・再送・競合・入力不正の検査。
- Lua: 実Luanti上の代替readによる有限sensor単体検査。これはWorld配置での検証とは分ける。
- 実Luanti: 同じL14B World/センサー/身体controllerで3個体、各2periodの接続run。
  近傍資源対照＋故障注入、自然林、接続offの既存回帰を別runで実行する。
  全受付wireの再生、在庫保存、各個体の一回作用と期限、実際の地形由来move、pickup、学習採用を検査する。

2periodで全個体が発見/学習すること、30periodで探索効率が改善すること、
障害物を必ず回避すること、袋小路・対称停滞・旋回振動の解消は受入条件に含めない。
計画Phase 3/4の独立した配置対照や長期比較は後続である。
