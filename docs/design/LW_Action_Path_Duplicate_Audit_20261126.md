# 人間LWの各行動に残る並行経路・旧処理の監査

2026-11-26、基準2cacb3d。調査のみ。行動・学習・実験条件は変更していない。
対象は通常LWの候補生成、選択、実行、結果評価、睡眠整理。
動物側全実装や外部GUI/APIの全分岐まで検査したものではない。
主な根拠は `src/lw/simulation/day.jl`、`integrated.jl` と以下の各関数。
有効条件は直前の `experiments/social_relationships/trade_use30_input.json` に照合した。
入力でONでも、実際の発火件数・処理時間・選択確率への寄与は今回未計測。

## 要点

食品専用取引と同様に整理したい並存処理はある。ただし、同じ行動名でも
親目的・局所手段・身体実行・世界の収支を分けることは必要。
「複数の記録がある」だけで二重報酬と判定せず、同じ証拠をどの状態に何回加えるかで判断する。

優先は (1) 固定の拠点休息報酬、(2) 移動の複数記憶系による選択補正、
(3) 疲労判断の二段構え、(4) 援助提供の複数評価、(5) 残存する慣性観測記録。
近距離の釣り判断と食事判断には、共通分布を使うが共通試行の開始・終了とは別という差もある。

## 行動別の一覧

|行動|並存する経路|判定・現在の条件|
|---|---|---|
|食事・加工・取り出し|`food_desire_plan!`／`configured_food_preparation`／帰還後固定食事／日課の食事|新食欲ONなら旧準備・旧帰還食事・日課の食事は抑止。旧取引のような無条件フォールバックではない|
|採取・釣り|`acquisition_targets!`で方法・場所選択→近距離`fishing_plan!`または`configured_near_food`|上位の目的選択と作業選択の二段。親子分離自体は必要だが近距離判断の見積もり・学習契約が異なる|
|移動・帰還|旧landmark/relation経路、一般目印、MB route/chunk/sleep、探索horizon、採取field、bundle、trail|複数同時有効。各方法名や記憶が異なるので、同じ方向・同じ経験への複数加点があり得る。実際の重複率は未計測|
|継続移動|`gradient_roll`／通常候補／`continuous_descent`／旧movement_inertia記録|rollは成功時に通常候補を飛ばす。descentは実行方向の修正で別役割。旧inertiaは現在観測・履歴が中心|
|疲労休息|`fatigue_navigation_continue!`の継続/休む→通常候補のrest＋`project_body_methods!`|外の同一判断で二段とも到達可能。継続を選んでも下流でrestを選べる。意図を整理したい|
|帰還目的・拠点滞在|身体親、embedded rest、夜間恐怖、日次計画、食料不安、備蓄による滞在|同じreturningを順次更新する多層構造。直近は夜間恐怖OFF、他の複数経路ON。上書き履歴が必要|
|拠点休息の学習|通常帰還の成果評価＋`configured_home_rest_step!`＋`embedded_rest_feedback!`|固定休息報酬がON。単なる同一関数の二重呼び出しではなく、別の追加報酬が残っている|
|睡眠・待機|夜間固定rest／sleep gate／task focus／返答待ち／帰還後認知停止|行動の理由と計算省略の機構が混在。gate等は実行ループのcontinueで排他的。今回post_return_idleはOFF|
|援助提供|要求への`experienced_response`／表情からの`visual_aid_plan!`／混合取引の一方提供|入口が違うだけでなく、自己保持費用・提供利益・学習の問いが異なる。通常LWで並存|
|安全対応|`safety_plan!`／`safety_methods!`|三項演算で片方のみ。今回はhazards=offなので前段の安全選択は作動しない|
|食品交換|食品専用／混合|前変更で通常LWは混合のみ。旧定義は歴史的検査用に隔離済み|

## 1. 固定の拠点休息報酬は残っている

`configured_paths/home_rest_reward.jl` の `configured_home_rest_step!` は、
拠点内で60秒連続restすると一日一度5を加える。
記録した帰還試行があれば、対応するmethod・route・chunkのrewardにも配る。
これは事前の見積もりとの差とは別の固定追加。直近入力の `home_rest_reward=on`。

同時に `embedded_rest_feedback!` は休息できた割合から拠点のplace_valueを更新する。
こちらは休息場所の経験であり、同じrewardへの二重加算ではない。
通常帰還の効率評価、固定報酬、休息場所評価を一つの学習と解釈しない。
固定追加の撤去・OFFを先に検討し、初期の拠点選好まで一緒に削らない。

## 2. 移動には旧記憶とMB記憶が同時に働く

`route_result!` (`learning/landmark_routes.jl`) は採取→持ち帰りで旧経路を形成し、
成功時support増加/H=0、選択経路でblockedならH+1という更新を保持する。
`relation_candidates!` はその記憶から候補を作り、`mb_route_candidates!` /
`mb_chunk_candidates!` / `mb_sleep_candidates!` も別の記憶から候補を作る。

既存の重複抑止:

- relation_field ONなら、landmark側の旧route候補は `include_routes=false`。
- general_landmarks ONなら、landmark側の単純な観測目印候補は `include_observed=false`。
- active MB経路と同じroute IDのfresh候補は除外する。
- MBチャンク候補がある場合、同じ段階の新規mb_simulateは実行しない。

ただし、旧relation経路と新MB経路の横断重複まで消す契約ではない。
加えて `learning=full` は `model_field/harvest_sleep` 等をONにし、
候補優先度へ採取経験fieldを適用する。その後bundle/trailも候補を補正する。
直近条件ではrelation_field、MB、経験bundle、selection_trailsがON、bundle_creditはOFF。
`project_trails!` は使用回数等から優先度を加え、`project_bundles!` は経験から反発を加える。
これらは新しい見積もり差評価だけで動く一系統にはなっていない。

次の局所監査では、同じ意思決定に対し「観測/経験ID、到達仮説、行動、各補正前後」を
並べ、同じ証拠・効果が重なった箇所を判定する。方向が同じだけで候補を統合しない。
旧経路の記憶を削る前に、MB側で担う役割と移行方法を確認する。

## 3. 休むか進むかが二段で決まる

拠点外・MB有効時は `fatigue_navigation_continue!` が見積もりによって継続を選ぶ。
継続した場合、body_fieldが通常候補へrestを追加し、`project_body_methods!` が
疲労と空腹からrest/walk/scanを再補正する。直近条件は両方有効。
したがって「継続判断=実際に移動」とは限らない。

身体限界の停止は残す一方、疲労の選好を一回の共通候補比較に寄せる余地がある。
旧固定疲労判定は最初に作られるが、条件を満たすと予測判断で上書きされる。
現状のガードは拠点外に限定されるため、全状況で旧閾値を撤去済みとは言えない。

## 4. 同じ「渡す」に複数の主観評価がある

- `experienced_response` は要求に応じ、身体要求・不安・関係・表情からgive/refuseを比較。
  応答用BasicLoopはその場で作り、応答H=0。関係経験は読むが、永続する同じ試行ではない。
- `visual_aid_plan!` は表情から自発的援助を候補化。持続する独自loopを持ち、届けたかを評価。
- 混合取引では、物の用途差と自己保持、相手の状況、将来の関係投資から一方提供も評価可能。

実行は一人一tick一行動であり三重に食品を渡すという問題ではない。
しかし同じ相手・同じ資源差でも入口により提供判断が変わる。
共通化の候補は「渡した前後の本人の資源・用途・将来予測」。
要求を受けた事実、自発性、交換条件という文脈まで消さない。

## 5. 旧慣性は判断より観測・記録の残り

`movement_inertia.jl` と通常day内の参照を確認した範囲では、
`observe_inertia!` が観測比較用の配列を作って独自Hを更新し、選択後に履歴を保存する。
この独自Hを候補優先度へ適用する通常dayの呼出しは見当たらない。
現在の継続移動はgradient_roll等が担う。直近入力はmovement_inertia=on。

これは撤去・診断専用化の比較的安全な候補。ただし、外部の分析・保存形式への参照は
別途確認が必要。今回、実測コストやOFF時の全内部状態一致までは調べていない。

## 6. 見送り後に旧処理へ落ちない箇所／役割が違う箇所

食事: food_desire ONならconfigured_actionはnothing、旧帰還食事は `!food_desire`、
日課の食事へ渡すhungryも `!food_desire` で抑止される。
food_desireがdeferしても、これらの旧食事選択が再発火する構造ではない。
ただし食事選択はmethod_distributionで抽選し、結果は味記憶・intent記録へ返す。
共通試行のbegin/resolveが全面的につながったという意味ではない。

釣り: acquisitionは食料確保の方法・場所、近距離fishing_planはfish/scanを比較する。
連続キャスト中は継続し、通常の結果はacquisition_resultへ返る。
acquisition_resultは同時刻の重複適用を拒み、親手段Hも局所Hを差し引く構成がある。
「二段だから即二重罰」とは言えない。近距離の固定look_elsewhere優先度等は別途統一候補。

移動: continuous_descentは候補を選び直すのでなく、選択後の具体的方向を修正する。
goalの認識、経路選択、足元の衝突回避は役割が異なり、一括削除しない。

睡眠: mb_sleep ON時は旧sleep_actions/sleep_maintenanceを明示的にOFFにする。
入力JSONで両方ONに見えても同時適用ではない。一方、general記録・採取学習・MB整理・
社会記憶整理は別の対象として残る。sleep gateは外界遮断であり記憶整理そのものではない。

身体: 新マクロ身体の消化経路はmacro_body存在時に分岐してreturnする。
旧フィールドがあるだけで、新旧のカロリーが二重消費されると断定しない。

## 整理の順番

1. 固定home_rest_rewardの役割を終了させるか確認し、短い局所比較。
2. 旧inertiaの診断専用化・無効化で行動と乱数消費が変わらないか確認。
3. 旧relation/採取field/bundle/trailと新MBの寄与を、実際の一判断で比較。
4. 疲労の二段判断、援助の資源差評価、食事・釣りの試行APIを順次揃える。

今回は候補の棚卸しであり、撤去や全機能の統合は行っていない。
長期実験も再開せず、既存の状態・凍結ソースは維持した。
