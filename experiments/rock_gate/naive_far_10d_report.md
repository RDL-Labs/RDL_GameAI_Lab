# 未経験3体・遠方食料10日試験（2026-10-27）

MB持ち越しなし。回転した遠方食料のみの地図、修正済み初期配置、危険OFF、共有備蓄ON、日次持ち帰り目標ON。初日は拠点観察。感度はA=0.5、B=1、C=2。

| 個体 | 最終reserve | 持ち帰り達成日数 | 採取数 | 最終拠点距離 |
|---|---:|---:|---:|---:|
| A | 96.33 | 9 | 28 | 1.00 |
| B | 94.45 | 9 | 24 | 1.19 |
| C | 94.36 | 9 | 28 | 1.12 |

全員2〜10日目の毎日持ち帰り達成、最終時点は拠点内。各10回食事。日次保存点の最低reserveは約70.74（全時刻の最低値ではない）。直接譲渡は行動カウンタ上0。共有備蓄は預入76、引出26、残50。各個体のMBにtransfer情報がないことを確認。

実行約1440.29秒（24分、コンパイル込み）、ピークRSS約1.44 GB、累積割当約1.29 TB。初期配置・地形105項目、生活整合51項目PASS。経路・親MB・帰還見積もりの保存結果監査もすべて終了コード0。

今回の条件では未経験のみでも往復が成立した。混成6体試験とは個体数・配置・資源競争が異なるため、持ち越しの効果を単独で比較する試験ではない。共有備蓄と設定経路による支援も残る。単一seedの結果。

結果: naive_far_10d_summary.json
ローカル実行出力: outputs/naive-far-3actors-10d-20261027

## 新規地図での追試（開始）

出力: outputs/naive-newmap-3actors-10d-20261027
追加引数: --world-seed 20261027

native_landscape_sceneで地形と背景物を新規生成し、同じseedで特徴を付与する。AIの選択seedとconfigは前回から変更しない。食料位置・量、初期位置・reserve・所持品、拠点位置、聴覚設定の一致を入力JSONで確認。川のphaseと木・岩などの配置は異なる。人工道と特徴的な目印の設計は維持するため、完全に別の経路配置を試す条件ではない。高い障害物数は116から118へ変化。

未経験3体、10日。準備実行で地形・到達性105項目PASS。本番結果は実行中のため未評価。

### 新規地図10日結果（完了）

A: 持ち帰り9日、最終reserve95.95、拠点距離1.20、採取28。
B: 持ち帰り8日、最終reserve93.01、拠点距離0.96、採取26。
C: 持ち帰り9日、最終reserve95.15、拠点距離1.16、採取28。

全員最終拠点内、各10回食事。Bだけ9日目に預入なし。ただしその日も採取1・食事1で、日末は拠点内（位置0.929,6.744）、reserve92.32。帰還不能ではない。10日目には採取3・預入1へ復帰。9日目は歩行7247・見回し4405で、行動負担が増えていた。日次集計だけでその原因は確定しない。

共有備蓄は預入77、引出25、残52。直接譲渡カウンタなし。MB持ち越しなしを確認。地形105項目・生活51項目PASS、経路・親MB・帰還見積もり監査すべて終了コード0。

実行1272.16秒（約21.2分、前回24.0分）、ピークRSS1.44 GB、累積割当1.48 TB。単発実行・地図による行動差を含むため一般的な高速化ではない。

前回は3体とも9日達成、今回は9/8/9日。背景地形を変えても生活と往復は概ね維持。ただし食料・人工道・主要目印の配置は同じであり、任意の新規経路配置への一般化は未検証。

集計: naive_newmap_10d_summary.json

## 人工道なし追試（開始）

出力: outputs/naive-newmap-no-roads-10d-20261027
新規地図追試と同じ引数に --no-artificial-roads を追加。配置検査後、実行入力のscene.artificial_roadsを空配列にする。拠点舗装を含む3グループを全削除。自然の踏み跡（ground_wear=on）は維持。

保存入力JSONを比較し、artificial_roads以外の全項目がdeepEqualで一致することを確認。既存105項目は人工道削除前の配置・到達性チェックであり、人工道を使用した実行結果を保証するものではない。未経験3体・10日、実行中につき結果未評価。同じseedの対比較であり、一般化には別seedの確認が必要。

### 人工道なし10日結果（完了）

| 個体 | 持ち帰り達成日数（道あり→なし） | 最終reserve（道あり→なし） | 歩行操作数（道あり→なし） |
|---|---|---|---|
| A | 9→9 | 95.95→95.89 | 5326→5321 |
| B | 8→9 | 93.01→96.45 | 14315→4027 |
| C | 9→9 | 95.15→94.18 | 7424→10080 |

全員2〜10日目に毎日持ち帰り、最後は拠点内。各採取28・食事10。共有備蓄は預入79・引出25・残54。日次保存点の最低reserveは約70.73。直接譲渡カウンタなし。

歩行操作合計27065→19428（約28.2%減）だが、Cは増加。見回し合計55362→50149。実行1272.16→1237.51秒（約21.2→20.6分）、ピークRSS約1.37 GB、累積割当約1.40 TB。生活整合51項目PASS、経路・親MB・帰還見積もり監査すべて終了コード0。

この単一seedでは人工道を除いても往復・生活は崩れず、Bは改善した。人工道が無作用だったとも、常に不利とも判定できない。道の除去で観測・選択・後続の経験が変わるため、道への直接反応とその後の確率的な行動分岐は、この最終集計だけでは分離できない。自然に生じる踏み跡は有効のまま。

集計: naive_no_roads_10d_summary.json

## 岩囲い・人工道なし10日追試（開始）

出力: outputs/enclosed-no-roads-10d-20261027
直前の人工道なし条件へ --enclosed-camp のみ追加。生成・特徴付与・地図回転の後で、半径5の円周に半径0.8・高さ3の岩23個を追加。北向き入口のみ1区画を空ける（元の狭い囲いの180度回転形）。入口の岩表面間の幅は約0.99、身体半径0.2を考慮した中心の通過幅は約0.59。既存の両側光源は維持。

保存入力の全体比較で、末尾の岩23個以外が前回と完全一致することを確認。危険OFF・人工道なし・自然踏み跡ON・未経験3体・10日。囲い追加後の入口通過、側面遮断、初期位置非衝突、隣接岩の接続、ID一意性30項目PASS。事前チェック105項目もPASS。実行中のため行動結果は未評価。

### 岩囲い10日結果（完了）

全員が2日目の開始後66秒（A）、98秒（B）、111秒（C）に北側入口から半径5の外へ出た。各外出1回・再入場0回。10日間の預入・日次持ち帰り達成は全員0。共有備蓄も0。円境界のカウンタは拠点到着そのものの判定ではないが、今回のログでは外出後一度も囲い内部へ戻っていない。

| 個体 | 最終reserve | 最終拠点距離 | 採取/食事 | 歩行操作数 |
|---|---:|---:|---:|---:|
| A | 72.29 | 15.57 | 10/10 | 78822 |
| B | 92.91 | 8.67 | 11/11 | 78233 |
| C | 93.28 | 17.85 | 11/11 | 77990 |

囲いなしでは全員9日持ち帰り達成、歩行計19428。囲いありは0日、歩行計235045（約12.1倍）。各自が採取して消費し生活を維持。初期備蓄・所持品0、譲渡カウンタなし。最終エネルギーだけでは帰還失敗を見逃す結果。

実行2319.22秒（約38.7分、囲いなし20.6分）、ピークRSS約2.02 GB、累積割当約1.89 TB。生活整合51項目PASS、経路・親MB・帰還見積もり監査すべて終了コード0。監査通過は行動目標達成を意味しない。

危険OFFでも狭い囲いへの帰還問題が再現。外出は成立し、問題はその後の帰還過程にある。ただし帰還目的の選択不足、入口への誘導、局所回避のどこが主因かは今回の集計では未分離。入口周辺に張り付いたとまでは断定しない。食料・背景・AI設定は前回と一致し、岩23個のみを追加した単一seed比較。

集計: enclosed_no_roads_10d_summary.json

## 入口接近時の診断再実行（開始）

出力: outputs/enclosed-gate-diagnostic-20261027
前回の岩囲い試験と保存入力JSONが完全一致。追加引数 --gate-diagnostics はコピーしたソースに読み取り専用の観測フックを挿入する。未経験3体、感度0.5/1/2、地図seed20261027、選択seed20261005、初日拠点観察、遠方食料3箇所、初期備蓄なし、危険OFF、人工道なし、自然踏み跡ON。ほかの身体・日次目標・夜間恐怖・認識・MB・睡眠設定も前回通り。

対象は60秒サンプル中で入口へ最接近したCの121680秒（8日目）。17300秒付近の外出と比較するため、17280〜17420秒、121380〜121680秒の各個体について選択されたplan、方向補正前のplan、移動観測、障害物、ρ構造認識、位置・向き・帰還状態を保存する。121681秒で専用例外を捕捉して正常終了。完了時はdiagnostic-stop.jsonと位置履歴を保存し、通常の10日結果や生活監査は生成しない。途中停止を全期間完了と解釈しない。

診断ファイルから同じ地図に対するポテンシャル各成分・方向別評価を復元可能。軌跡の再現性確認と図示は完了後に行う。診断記録は乱数やAI状態を書き換えない。

### 入口診断結果

121681秒で予定通り正常停止。60秒間隔の位置履歴6084件は前回の対応する先頭部分と完全一致。観測追加で軌跡が変わっていないことを確認。

Cの最接近位置（0.331873,12.712135）は121678〜121680秒に維持され、3秒連続scan。121680秒は帰還目的有効、method=cue:arrangement:shape-ochre/shape-orange/1:-5、question=target_observed。正面歩行ref2はclear=true/status=performed（候補予測）で、energy行のcostも5方向中最低。ただしこれは最終選択確率そのものではない。実際にはscanが選ばれ、歩行の局所ポテンシャル補正は実行されない。

当時のρ地図はcoarse/complete。左側障害物群の距離約1.03〜1.37、右側約1.69、正面光線の障害物は10.63先。地図はこの観測時点で入口全体を一枚の近接壁にはしていない。ただし線上の空きと通路全体の理解は別。

直前121677秒はreposition_-90を選択、補正後-101.25度。引力項-0.49039、反発0.08493、合計-0.40546。この歩行で最接近位置まで進んだ。

外出成功直前17390秒のCはhorizon_0歩行、補正後-11.25度。引力項-0.49039、反発1.16350、合計+0.67310でも前進した。絶対コストが正だから停止する規則ではなく、選択済み方向付近の候補間の比較。

ソース上、rho_potentialの引力は拠点座標への固定引力ではなく、上流で選択された進行方向への項。target_nearerのときのみ観測targetから方向を取る。それ以外は選択済みmethodの方向を中心に±45度を調整する。最接近のscanではこの勾配自体を評価しない。したがって今の証拠は、入口反発だけよりも、進める局面で見回し・目印候補を選択する上流の問題を調査対象にする。ただし3秒のscanだけで10日帰還不能の主因とは断定しない。

集計: gate_diagnostic_summary.json。再実行は指定時刻までであり、その後の離脱行動は診断対象外。コードの挙動変更は行っていない。

## ABCの最接近前後（保存ログ分析）

60秒位置サンプルでの最接近を基準とし、外出直後は除外。真の毎秒最小値ではない。eventsは変更時圧縮されるため、直前イベントを引き継いで前60秒〜後59秒の120操作を再構成した。

| 個体 | 基準秒（全員8日目） | 入口距離 | 60秒後 | 120秒後 | 歩行/見回し/休息 |
|---|---:|---:|---:|---:|---|
| A |129540|1.839|6.154|8.283|84/34/2|
| B |121620|1.808|3.867|7.061|70/49/1|
| C |121680|1.744|6.065|6.929|63/57/0|

全個体で120操作のpurpose_family=home。blockedは0。これは実行した動作の結果であり、候補段階の衝突除外がなかったという意味ではない。

A: 前進・位置調整から接近、基準時に橙色の目印をscan、次にreposition_90。その後も茶・黄土・緑などの目印へ歩行が切り替わり、1分後6.15まで離れる。Aのこの時刻の勾配・yawは既存詳細診断の範囲外なので、各歩行の絶対方向は未確認。

B: 基準前4秒は連続scan。基準時はstep_-45、yaw105.3906度に対し補正前の絶対方向60.3906度（入口へ向く方向ではない）。補正後は37.8906度となり、位置(0.2309,12.7927)から(0.5380,13.1873)へ移動。入口距離1.808から約2.252へ増加。選択済み方向の時点ですでに入口から離れる成分があり、反発補正も加わる。1秒後scan、2秒後reposition_90でさらに(0.8450,13.5819)へ。勾配total=-0.38374、引力=-0.46194、反発0.07820。親homeでもこの引力は入口への引力ではない。

C: 基準3秒前のreposition_-90で最接近位置へ到達。その後4秒連続scan（基準-2〜+1）、+2秒でopening:-2、+4秒でstep_-90。その後も歩行・見回しが切り替わり、1分後6.07まで離れる。openingという方法名は実際の拠点入口の識別成功を意味しない。既存詳細診断は基準時までで、その後の方向補正は不明。

共通所見: 帰還目的は維持されるが、下位の移動・注視対象が頻繁に切り替わり、入口を通る一連の行動にまとまっていない。これをH過大・記憶欠落など特定原因と断定するには、選択候補の重み・親/子Hの時系列が必要。追加シミュレーションやAIコード変更はしていない。

集計: gate_abc_timeline.json

## 出口から見える食料・3日試験（開始）

出力: outputs/enclosed-exit-food-3d-20261027
引数追加: --exit-visible-food --checkpoints、期間3日。未経験3体。岩囲い・松明・背景・AI設定は10日保存付き試験と同じ。input.json比較で、日数と食料3箇所の座標以外は完全一致。

食料を(-2,15.5),(0,15.5),(2,15.5)へ移動。入口中央(0,11)から約4.5〜4.92離れる。各24、再生あり（総量72、従来通り）。近場の食料を追加したのではなく既存3箇所を移動。拠点中心からは9.5〜9.71。

実際のperceive_movementで、入口前後の3地点・外向き±10度の3方向の全9条件で3箇所とも見えることを確認。低い障害物も含む移動経路の身体半径0.2クリアランスと非水域を確認。追加21項目PASS、既存135項目PASS。視認はその位置と向きでの保証であり、個体が常に食料へ注意を向ける保証ではない。

初日は散策、危険OFF、人工道なし、自然踏み跡ON、日末保存。出口から採取につながるか、採取後の再入場・持ち帰りが成立するかを評価する。実行中のため結果は未評価。

### 出口から見える食料・3日結果

3日完了。全員外出1回・再入場0回・持ち帰り0日。各採取4、食事3、所持1。最終reserve A87.1401、B86.8740、C86.9145。共有備蓄0、地上食料60。食料を出口正面へ近づけても、この3日では帰還改善なし。採取できない問題ではなく、採取後も囲い内への再入場が成立していない。

実行500.53秒（約8.3分）、ピークRSS約1.61 GB。生活整合16項目PASS、経路・親MB・帰還見積もり監査終了コード0。日末保存3個を生成。集計: exit_visible_food_3d_summary.json。視認しやすい配置だけで入口通過の行動連鎖が成立したとはいえない。原因特定は別途必要。

## ρと境界反発範囲の連動

fineでは同じ観測点をより細かく分ける既存処理に加え、反発範囲を短くする。基本clearance2.0に対しcoarseは2.0、fineは0.5。荷物・損傷・走行による追加分は維持し、最小範囲は0.35。身体半径0.2の物理衝突判定は変更しない。

式: range = fineならmax(0.35,clearance-1.5)、それ以外clearance。
反発 = weight * clearance * max(0,1-distance/range)^3。
境界上の振幅は維持するため、fineでは近距離へ勾配が集中する。coarseの数式は従来と同じ。障害物と水の観測グループに適用し、道の項と目的方向の項は変更しない。

rho_potentialを共通化したままなので、候補への観測評価と実行方向補正の両方へ適用。実行planにrho_boundary_rangeを記録する。0.5等の値は初期設計値で、学習済みの最適値ではない。

検査: 既存構造・隙間・ρ・候補検査と、新設の12検査がすべてPASS。新設検査は粗い場の式の維持、細かい場で中央が空くこと、境界付近の強い反発、荷物等の余白、候補評価への反映、実障害物の衝突拒否を確認。CIにも接続。

この変更でセンサー密度は増えない。ρの自動切替も未実装なので、今まで通りcoarse固定の実験では新しい狭い反発場は使われない。fineを指定する比較試験が必要。長期シミュレーションや帰還改善はまだ未検証。コードが変わったため、旧版チェックポイントをそのまま再開することはv1の互換性検査で拒否される。

## 直近の拠点距離によるρ切替・3日試験（開始）

出力: outputs/enclosed-home-distance-3d-20261027。前回の出口正面食料3日入力と比較し、rho_profileのみhome-distanceへ変更したことをdeepEqualで確認。未経験3体・感度0.5/1/2・初日散策・岩囲い・危険OFF・人工道なし・自然踏み跡ON・日末保存。

新しいhome_distance状態は、既存の視認可能なhome観測の相対forward/rightを記憶し、既存ground_receiptの自己移動・旋回から自己中心ベクトルを更新する。真の拠点座標・絶対位置はこの推定器へ渡さない。移動量・旋回量・時間経過で不確実さを増し、再観測で補正する。身体運動の情報源は既存の正確な自己移動receiptで、ノイズのある運動感覚は未実装。

距離+不確実さ<=10かつ不確実さ<=3でfineへ。fineは距離+不確実さ<=12まで維持し、振動を抑える。未知・不確実ならcoarse。距離10/12・誤差係数等は暫定値。日末保存はmb_map内の状態と切替カウンタを含む。目標指向の移動方向や逆経路を新規に強制せず、拠点が近い推定時の構造分割・境界反発の解像度だけを切り替える。自動ρは今の版では帰還選択時だけに限定せず、拠点近傍の外出時にも有効。

単体10項目PASS（未知、相対並進/旋回、同じreceiptの二重適用防止、不可視時の保持、ヒステリシス、距離・不確実さによる降格、再観測）。配置・視認156項目PASS。3日実行中、帰還改善はまだ未評価。旧coarse試験に対しfine境界反発の変更も含む。

### 拠点距離によるρ切替・3日結果

3日完了、全員外出1回・再入場0回・持ち帰り0。各採取4・食事3・所持1。最終reserve A87.2521、B86.9439、C86.8719。実行518.07秒（約8.6分）、ピークRSS1.40 GB。生活16項目・親/経路/帰還見積もり監査PASS。日末保存3個。

全期間のfine ticksはA17360/B17358/C17364。1日目チェックポイントを直接読み、fine ticks A17278/B17270/C17270を確認。したがって外出を開始する2日目以降のfineはA82/B88/C94秒のみ（2日間34560秒の約0.24〜0.27%）。最終は全員coarse。不確実さがA858.47/B893.10/C879.61まで増加し、閾値3を超過している。

結論: 帰還改善なし。ただし肝心の外出後はほぼcoarseとなっており、入口付近で高解像度を持続できる方式の有効性を否定する結果ではない。現行の距離推定は見回し等による不確実さの蓄積を再観測以外で縮められず、高解像度への切替条件が維持できない。さらに既存receiptのyaw差は±180度の折返しを含み得るため、誤差加算時の角度正規化も点検対象。今回の確認では修正・再実行はしていない。

集計: home_distance_3d_summary.json

## 広い入口・距離ρ・3日比較（開始）

出力: outputs/enclosed-wide-home-distance-3d-20261027、追加 --wide-enclosure。直前のenclosed-home-distance-3dと全入力比較し、入口両側の岩2個（world_id145/167）を除く以外の変更なしを確認。岩21個となり、岩の表面間の入口幅0.99→3.4。松明は動かしていないため、その実体は入口付近に残る。

未経験3体、初日散策、感度0.5/1/2、出口正面食料3箇所、危険OFF、人工道なし、自然踏み跡ON、home-distanceによる自動ρ、既存の身体・日次目標・休息・MB・睡眠設定、seedはすべて維持。日末保存、3日目まで。初期配置・視認154項目PASS。結果は実行中で未評価。

### 広い入口・3日結果

3日完了。A/Bは2・3日目の2日持ち帰り達成、Cは3日目の1日達成。最終全員拠点内（距離A1/B1/C1.036）。最終reserve A91.569/B90.812/C90.404。半径5の境界通過はA外2/内2、B外3/内3、C外2/内2。境界通過数は荷下ろし回数と同義ではない。共有備蓄は預入12・引出3・残9。

狭い入口版では全員再入場0・持ち帰り0。変更は岩2個の除去のみで、今回は全員の再入場と持ち帰りが成立。入口の幾何条件がこのseedで大きく作用した。ただしこれで狭い入口の通過設計が解決したわけではない。

fine ticksはA41960/B38691/C34403（全51840tick）。最終不確実さは全員0.25へ補正されているが、fineが帰還成功の原因か、帰還・再観測の結果fine維持が可能になったかは分離できない。

実行282.54秒（約4.7分、狭い版518.07秒）、ピークRSS約1.60 GB。生活16項目・親/経路/帰還見積もり監査PASS、日末保存3個。集計: wide_home_distance_3d_summary.json。

## 入口幅2.0・3日比較（開始）

実行出力: outputs/enclosed-medium-home-distance-3d-20261027-r3。wide条件に --medium-enclosure を追加。入口両端world_id146/166の半径のみ0.8→1.5へ変更し、表面間の幅3.4→2.0。他の入力全体が一致することを確認。松明・食料・個体・seed・home-distance等は維持。日末保存あり、3日間。

最初の岩を内側へ移動する案は隣接岩との連続性チェックに失敗して本実行前に停止。拡大方式への修正時の構文エラーも本実行前に修正。r3は配置・視認155項目PASSで開始。入口幅以外にも両端岩の曲率・見え方が変わる幾何比較である。結果未評価。

### 入口幅2.0・3日結果

3日完了。Aは2・3日目持ち帰り達成、Cは3日目達成、Bは未達。A/Cは最終拠点内、Bは外（拠点距離29.06、所持1）。最終reserve A90.61/B86.17/C88.24。境界再入場A2/B0/C1、共有備蓄預入6・引出1・残5。

幅3.4では全員帰還・持ち帰り、幅2.0では2体、幅0.99では0体（同じhome-distance・出口食料条件）。単一seedの短期結果で、成功確率や限界幅は未確定。両端岩の半径も変わるため入口幅だけの連続パラメータ比較ではない。

実行340.45秒（約5.7分）、ピークRSS1.37 GB。日末保存3個、生活16項目・経路/親MB監査PASS。帰還見積もり監査はFAIL: Bのreturn_outlook.evaluated=0で、全員に評価実績を要求するassertに未達（A80/C45）。クラッシュではなく保存結果の監査不成立であり、全監査PASSとはしない。原因の追加調査は未実施。

集計: medium_home_distance_3d_summary.json

## 入口幅1.5・3日比較（開始）

出力: outputs/enclosed-width15-home-distance-3d-20261027。--entrance-width 1.5 を追加。幅2.0の試験から入口両端world_id146/166の半径だけ1.5→1.75に変更。その他のinput.json全項目の一致を確認。幅・通過可能性・壁の連続性・食料視認等155項目PASS。

未経験3体・初日散策・感度0.5/1/2・出口正面食料・松明・seed・危険OFF・人工道なし・自然踏み跡ON・home-distance自動ρ・身体/MB/睡眠設定は維持。日末保存、3日目まで実行。幅2.0でA/C成功・B未達だった結果と比較する。岩の曲率と見え方も変化する条件。実行中につき結果未評価。

### 入口幅1.5・3日結果

3日完了。B/Cは3日目に持ち帰り達成、最終拠点内。Aは境界再入場1回あるが荷下ろし0、最終拠点外（距離7.61、所持1）。最終reserve A87.01/B88.89/C88.65。半径5境界の外/内はA2/1、B1/1、C2/2。全員少なくとも一度は囲い内部へ通過しており、Aの再入場を拠点到着・持ち帰り成功と混同しない。

共有備蓄は預入4・引出2・残2。幅2.0ではA/C持ち帰り成功・B未達、幅1.5ではB/C成功・A未達。成功人数はともに2で入れ替わった。幅と個体の成功は単調ではなく、単一seed・3日で限界幅を断定できない。

実行355.64秒（約5.9分）、ピークRSS1.63 GB。生活16項目・親/経路/帰還見積もり監査PASS、日末保存3個。集計: width15_home_distance_3d_summary.json。

## 幅1.5・近距離有限3日相当・10日試験（開始）

出力: outputs/enclosed-width15-finite-near-10d-20261027。--finite-near-three-day を追加、10日、日末保存。未経験3体・入口幅1.5・home-distance等は直前と同じ。input.jsonの比較で期間と食料以外の一致を確認。

近距離3箇所は各4個・合計12個・再生なし。直近3日試験の実績「各個体採取4個、3体計12個」を3日相当の基準とした。時間で消す・3日ちょうどで尽きる設定ではない。元の遠方3箇所(8,24),(0,30),(-6,24)を各24・再生ありで追加し、近場が尽きた後の探索先として残す。近場と遠方で合計84個。

初日散策、感度0.5/1/2、危険OFF、人工道なし、自然踏み跡ON、松明・背景・seed・身体/日次目標/休息/MB/睡眠は維持。近場の視認21項目、有限食料が再生しないこと等4項目を含む159項目PASS。再入場・持ち帰り、近場枯渇後の探索と生活を評価する。実行中、結果未評価。

### 幅1.5・有限近場10日結果

10日完了。日末チェックポイントを直接読み、近場は1日末[4,4,4]、2日末[0,0,0]と確認。3日相当とした12個は実際には全員が2日目に各4個採取して枯渇した。遠方は2日末[24,24,24]、3日末[24,24,21]、4日末[24,24,18]。近場枯渇後に遠方へ移行した。

持ち帰り達成日はA[2]、B[3,4,7]、C[4]。半径5の外/内通過はA6/6、B5/5、C5/4。最終A/B拠点内、Cは距離15.26の外。最終reserve A96.32/B83.31/C94.18、日次保存点で全員reserve0なし。共有備蓄は預入11・引出4・残7、遠方食料残[10,24,12]。帰還・採取は継続したが、持ち帰りは毎日安定していない。

実行1833.63秒（30.6分）、ピークRSS約1.75 GB。生活整合51項目・親/経路/帰還見積もり監査PASS。日末保存10個。集計: finite_near_width15_10d_summary.json。

### 有限近場10日: 入口接近後の離脱ログ

入口両端岩の中心線(0,10.330127)を基準に、60秒位置サンプルで入口3以内・囲い半径5の外・帰還有効となり、その後120秒で入口6以上へ離れ、間に半径5への再入場がない場面を抽出した。300秒以内の重複を間引き、A12/B3/C10場面。全接近の網羅的な試行数ではない。

代表: A9日目138600秒、距離1.704→120秒後8.477。B2日目27360秒、2.381→6.735。C8日目132120秒、1.350→6.370。各120操作を変更時圧縮eventsから復元し、全てpurpose_family=home、status=performed。歩行/見回し/休息はA61/51/8、B67/48/5、C55/59/6。実行動作のblockedは0だが、候補段階の衝突除外を否定しない。

Aは入口前で休息→橙色等を見回し→opening:0→斜め歩行・別目印へ。Bは岩・光源の見回しを繰り返してから茶色の目印方向へ歩行。Cは入口前でopening:0歩行の次に緑色や地面の見回しへ切り替わり、休息・横移動等を挟んで離脱。openingは局所的な観測隙間であり、その方法名だけで拠点入口と同一だとは断定しない。

親目的の切替や食料不足を直接の原因とする証拠はこの代表場面にはなく、入口接近後も下位行動を継続できず選択が散る既存の傾向が残る。H値・候補重み・向きの詳細は当該実行のeventsに保存されていないので原因確定は未実施。追加再実行なし。抜粋: finite_near_gate_departures.json。

### 入口への進入位置・角度の比較

有限近場10日ログの半径5内向き通過15件（A6/B5/C4）を比較。通過直前の横ずれは中央から0.291以内、南向き正面に対する実移動角は絶対値最大16.47度で、多くはほぼ正面だった。この境界は最狭部より外側にあり、15件を最狭部通過や荷下ろし成功とは同一視しない。

離脱代表3件の位置はA(-0.081,12.032)、B(-0.229,12.700)、C(-0.070,11.679)。全て中央寄りで、身体半径0.2を加えて高低両障害物との線分距離を検査すると、入口内側(0,9.5)への直線と南向き0.5の次の一歩は衝突しない。内側点への必要角はA1.82/B4.09/C1.84度。ただしこれは仮想直線の角度であり、離脱時の実際の向きではない。

位置だけで通過不能だった証拠はなく、進行方向の選択・継続を調べる必要がある。当該実行は離脱時の毎tickのyawや操舵後ベクトルを保存していないため、実際の進入角度が原因か否かは未確定。再実行はしていない。数値: gate_entry_angles.json。図: outputs/gate_entry_angles.png（緑は実際の境界通過一歩、赤点は離脱前サンプル、赤点線は通行可能な仮想直線）。

## 幅1.5・中央巨大焚き火・有限近場3日（開始）

出力: outputs/enclosed-width15-bonfire-3d-20261027。有限近場10日条件に --central-bonfire を追加し、期間3日。未経験ABC、初日散策、近場各4個再生なし・遠方再生あり、感度0.5/1/2、危険OFF、人工道なし、自然踏み跡ON、home-distance、身体/MB/睡眠/既存休息報酬は維持。日末保存あり。

焚き火は拠点中心(0,6)、橙色、見た目半径1.2、高さ6、light_source=16（既存松明1）。scene.visual_landmarksとして既存landmark_fan/skylineへ接続し、物理障害物・home_observation遮蔽には追加しない。炎を見える目印として表す実験で、燃料・熱・危険・調理・新しい報酬・強制誘導はない。現在の水平光源モデルでは高さ6による壁越しの視認を新設したわけではなく、既存の遮蔽規則を使用する。

事前配置159項目と追加14項目PASS。入口の前後3地点で昼夜とも光が追加観測され、brightと認識されること、橙色の特徴が見えること、物理障害物数が変わらないことを検査。前回入力との全体比較でvisual_landmarksとconfig.days以外が一致。比較対象は前回10日試験の最初の3日。結果未評価。

### 中央巨大焚き火・3日結果

3日完了。A/Bは2・3日目に持ち帰り、Cは3日目。最終全員拠点内（距離A1.128/B0.990/C1.068）、reserve A91.62/B91.31/C90.37、全員所持0。半径5の外/内通過A2/2・B2/2・C1/1。共有預入13・引出4・残9。

焚き火なし有限近場10日実験の最初の3日との比較: A達成[2]→[2,3]、B[3]→[2,3]、C[]→[3]。3日末の共有在庫3→9、拠点内人数1→3。初日末の身体・位置・所持は同一。焚き火ありでは再入場から荷下ろしまでA10/23秒・B11/22秒・C13秒（境界の定義は半径5）。初回帰還までの探索・外出時間そのものは長く、成功経路の再利用や焚き火への直接誘導を証明した結果ではない。

単一seedの3日では全員帰還まで改善したが、見た目・光による選択系列と個体間相互作用の変化を含み、長期安定性は未確認。中央光源への行動選択の直接寄与は追加解析していない。

計測呼出265.26秒（約4.4分、コンパイル込み）、ピークRSS1.65 GB、累積割当183.15 GB。生活整合16項目、経路・親MB・帰還見積もり監査すべてPASS。日末チェックポイント3個。比較集計: bonfire_3d_comparison.json（storageFullRunとmeasurementは各実験全期間の値、daily/deliveries/crossingsのみ最初の3日へ限定）。

## 最小入口・中央巨大焚き火・有限近場3日（開始）

出力: outputs/enclosed-narrow-bonfire-3d-20261027。直前の幅1.5巨大焚き火3日条件から --wide-enclosure --medium-enclosure --entrance-width 1.5 を外し、以前の最小入口へ戻す。23岩、両端半径0.8、表面間隔0.988190451。幅1.5時の21岩と異なり両肩岩が復帰し、隣の拡大岩は半径0.8へ戻る。単なる幅だけの比較ではない。

中央巨大焚き火、松明、未経験3体、初日散策、近場有限12個・遠方再生食料、感度0.5/1/2、危険OFF、人工道なし、自然踏み跡ON、home-distance、身体/MB/睡眠/休息/日次目標、seedすべて維持。3日・日末保存あり。事前配置・視認174項目PASS、前回inputとの比較でscene.obstacles以外は全項目一致。中央光源はこの狭い入口の前後でも昼夜ともbrightとして観測される。結果未評価。

### 最小入口・巨大焚き火3日結果

3日完了。全員外出1・半径5再入場0、荷下ろし0、最終拠点外。A距離8.30/reserve86.99、B9.20/86.92、C19.09/86.58、全員所持1。近場12個は枯渇、遠方各24のまま。共有預入・引出0。幅1.5巨大焚き火ではA/B2・3日目、C3日目に荷下ろし、全員最終拠点内だったが、最小幅0.988では再現しなかった。

60秒間隔の外側位置サンプルで入口中央(0,10.829629)へ最も近い位置はA(0.041,12.535) sec27000、B(-0.308,12.976) sec45360、C(-0.069,12.949) sec46680。いずれもreturn_active=true。毎tickの最接近ではない。

最終home_distance.profileは全員coarse。不確実性A915.73/B894.32/C907.49、fine_ticksはA17345/B17352/C17391（全51840tick）。近距離の精細化が十分持続しない既知の問題が疑われるが、接近時profileや操舵はこの集計では未特定。光源不足だけでは解決しない結果で、狭い通過時の認識・行動選択を分けて調べる必要がある。単一seed・3日で因果確定はしない。

呼出418.15秒（約7分）、ピークRSS1.64 GB、累積割当199.29 GB。生活整合16項目、経路・親MB・帰還見積もり監査すべてPASS。集計: narrow_bonfire_3d_summary.json。

## 最小入口・巨大焚き火・常時fine・3日（開始）

出力: outputs/enclosed-narrow-bonfire-fine-3d-20261027。直前の最小入口巨大焚き火3日条件の --rho home-distance を --rho fine に変更。input.json全体比較でconfig.rho_profile以外の一致を確認。事前配置・視認174項目PASS。

入口幅0.988、中央視覚光源、松明、未経験ABC、初日散策、近場有限12個・遠方再生食料、感度0.5/1/2、危険OFF、人工道なし、自然踏み跡ON、身体/MB/睡眠/休息/日次目標、seedを維持。3日・日末保存。距離推定の不確実性に依存せず、既存rho_mapと境界ポテンシャルを常時fineにする。観測レイの密度増加ではない。全員帰還未達だったhome-distance条件との比較。結果未評価。

### 最小入口・常時fine・3日結果

3日完了。全員少なくとも一度帰還・荷下ろし達成。A3日目、B2日目、C2・3日目。半径5外/内はA1/1、B3/2、C3/3。最終A/C拠点内（距離1.05/1.01）、Bは距離21.77の外で所持2。reserve A87.87/B90.29/C90.00。共有預入8・引出1・残7。近場0、遠方[21,24,21]。

同じ最小入口巨大焚き火のhome-distance試験は全員再入場・荷下ろし0、共有0。rho_profileのみfineへ変更した今回は3体とも荷下ろしできた。精細な地図・境界ポテンシャルで最小幅を通過できる証拠となったが、固定fineは初日から全期間の認識・選択系列を変える。接近時だけの精細化の効果や、不確実性増大が唯一の原因だと確定する比較ではない。Bの3日目帰還は未達で長期安定性も未確認。

呼出325.78秒（約5.4分）、ピークRSS1.64 GB、累積割当167.14 GB。自動切替の418.15秒から今回は短縮したが単発で行動量も異なるため一般的な高速化とはしない。生活整合16項目・親MB/経路/帰還見積もり監査PASS。日末保存3個。集計: narrow_bonfire_fine_3d_summary.json。

## 不確実性によるρ精細化・確認候補

home-distanceを改修。既知の予測距離10以内でfineへ入り、12を越えたら戻る。不確実性による近距離fineの禁止と距離への不確実性の加算を廃止。未観測または不確実性3超なら、24tickの確認窓を開いてfineとする。未解決で窓が終われば再確認まで120/240/480/960tickと待機を延ばす。近距離なら確認窓外でもfineを維持する。

帰還の通常候補生成にhome_distance_confirm（scan、priority3、target_observed）を追加。強制行動ではなく既存の学習・確率選択・身体/安全優先に従う。確認試行ごとに見回し方向を左右交互にし、通常の天体見回しによる角度上書きはしない。選ばれた回数はscan_selectedに記録。窓が開いても選ばれない場合はある。

実際のhome_observationを得た場合だけ相対距離・向きを再固定し、不確実性を0.25へ戻す。未観測・見回し実行だけでは減らさない。目印を拠点と自動同一視する更新や観測レイ増加はない。既存の見回しが新しい方向を観測することで確認材料を増やす。構造地図は当tickの観測前に生成されるため、確認結果は次tickの地図へ反映される。

向きの差は[-180,180)へ折り返してから不確実性へ加算し、+179→-179の2度回転を358度として数えない。これはρ制御と同時の修正なので、次の実験をρ制御だけの効果とは扱わない。確認状態はmb_maps内に保存される。fine/coarse固定モードには確認候補を追加しない。

単体50項目PASS（未知からの確認、時間制限、待機、未観測での不確実性保持、観測での補正、近距離ヒステリシス、回転折返し）。同検査をJulia checkpoint CIへ追加。3日行動試験はまだ行っていない。
短縮時計120秒×2日による統合検査もPASS。最小入口巨大焚き火・home-distance入力で、通常実行・日末保存実行・再開結果の一致と不適合再開拒否7項目を確認。長期の帰還改善を示す検査ではない。

## 最小入口・巨大焚き火・不確実性確認付き自動ρ・3日（開始）

出力: outputs/enclosed-narrow-bonfire-confirm-3d-20261027。実装9ffbad0のhome-distanceで3日。最小入口幅0.988、巨大焚き火、松明、未経験ABC、初日散策、近場有限12個・遠方再生食料、感度0.5/1/2、危険OFF、人工道なし、自然踏み跡ON、身体/MB/睡眠/休息/日次目標・seed維持。日末保存あり。

配置・視認174項目PASS。input.json全体が旧自動ρ試験enclosed-narrow-bonfire-3d-20261027と一致。変更は自動ρ実装（近距離判定、不確実性確認窓・見回し候補、実観測による補正、角度折返し）。fine固定試験との比較も行うが複数の実装修正を含むため単一要素の効果とは扱わない。帰還・荷下ろし、fine/coarse時間、確認窓・見回し選択・再観測の実績を確認する。実行開始、結果未評価。

### 確認付き自動ρ・3日結果

3日完了。荷下ろしはA2日目の1回（2個）のみ。Bは半径5へ再入場1回あるが荷下ろし0、Cは再入場0。外/内A2/1・B2/1・C1/0。最終全員外、距離A9.95/B9.25/C21.59、reserve A90.67/B86.68/C86.20、所持A2/B1/C1。共有残2、近場0、遠方[24,24,21]。

比較: 旧自動ρは荷下ろし全員0、常時fineはA3日目・B2日目・C2/3日目、新自動ρはA2日目のみ。単一seedで旧版より達成人数は増えたが、常時fineの結果には届かない。最終Bが境界内に留まるわけでもなく、境界再入場と帰還完了を分ける。

全51840tick中fine: A43883(84.7%)、B37651(72.6%)、C26295(50.7%)。確認窓checks A25/B38/C39、確認見回しscan_selected A14/B12/C15。確認候補は実選択されたが毎窓必ず選ばれたわけではない。confirmedは全員1で初期の未知状態からの拠点観測も含むため、外出後の再確認成功1回とは読めない。最終連続未解決unresolved A24/B37/C38、距離不確実性A92.28/B257.01/C568.87。精細化・見回しは作動したが、拠点観測による確認窓の解決が継続している証拠はない。窓以外での観測もanchorsへ数えられ、confirmedとは別。

実行366.38秒（約6.1分）、ピークRSS1.63 GB、累積割当181.55 GB。生活整合16項目・親MB/経路/帰還見積もり監査PASS。集計: narrow_bonfire_confirm_3d_summary.json。追加再実行・修正なし。

### 確認付き自動ρ: 入口接近後の離脱

60秒位置サンプルと変更時圧縮eventsを再構成。B/Cは入口中央(0,10.829629)から3以内・帰還有効・囲い外、その120秒後に6以上へ離れ、その間再入場なしの場面から最接近サンプルを選択。該当サンプルB3/C4（独立試行数ではない）。Aは同抽出0で、3日目帰還有効の最接近46440秒を別途選択した。

A: 46440秒、入口距離1.97→60秒後7.08→120秒後5.02。120操作は歩行68/見回し23/休息29、全てhome/performed。最初は緑のsky見回し→緑・茶のshape方向歩行→休息→reposition_90/-90/0等。確認専用見回しも窓内1回あるが帰還完了せず。

B: 39240秒、距離1.22→9.77→15.89。歩行81/見回し36/休息3、全てhome/performed。橙shape歩行→通常見回し→踏み跡見回し→灰shape歩行→明るい光見回し→黄土shape・横移動・openingへ切替。C: 37380秒、距離2.45→3.39→9.03。歩行79/見回し38/休息3、全てhome/performed。横移動→sky見回し・歩行→食料特徴方向歩行→岩特徴・opening・横移動と切替。食料特徴を選んでも親目的はhomeのまま。実行statusにblockedはないが、候補段階の衝突除外は不明。

補足訂正: Bの唯一のinは17397秒、out17435秒で両方return_active=false。帰還中の再入場ではなく2日目の外出直後の往復だった。Aの帰還in27180秒→荷下ろし27190秒は成功。Aの翌日out34640秒もreturn_active=falseで、成功後の新しい外出と、帰還中の離脱を区別する。

代表例の離脱時に目的切替はなく、下位の目印・移動方法が切り替わり内向き進行を維持しない挙動。橙色や光の方法名だけでは巨大焚き火と松明を識別できない。毎tickのrho/yaw/候補重みは保存されておらず、この場面でcoarse化したかは判定不能。追加再実行なし。抜粋: confirm_gate_departures.json。

## 離脱前後のρ・候補確率診断（完了）

出力: outputs/enclosed-confirm-departure-diagnostic-20261027。--departure-diagnosticsで37320〜37500、39180〜39360、46380〜46560秒を全個体について記録し、46561秒で予定停止。通常の3日完了試験ではない。前回と同じ入力・seed・改修自動ρで、選択前のread-only method_distribution（乱数不使用）、候補のpriority/reward/H/failure_repulsion、home観測、距離推定、実rho、操舵前後plan・位置yawを記録。記録された60秒位置サンプル2328件は前回の同区間と完全一致。候補確率和も検証。

代表離脱120秒で実rhoはA fine90/coarse30、B108/12、C114/6。全員開始時fine。最初のcoarseはA46485秒（45秒後）、B39348秒（108秒後）、C37494秒（114秒後）。最初の離脱をcoarse化で説明できない。A親H2.468〜2.557、候補24〜42、home観測なし。B親H32固定、候補3〜40、home観測39241秒のみ。C親H32固定、候補21〜48、home観測なし。閾値は全員2。

B詳細: 39240秒(-0.139,12.044)、yaw-170.07、fine。橙shape方向への歩行（選択確率3.14%、32候補中11位）を選び、操舵後-7.5度で南向きに前進。反発項0.000245、引力-0.5で、この一歩に大きな反発はない。39241秒(-0.161,11.544)でhome観測あり（距離5.547）。候補は休息45.45%、step_0直進29.39%、survey見回し25.16%。直進priority4.716、学習報酬0.07485、方法H32、失敗反発log値9.514。休息priority0.687、報酬0、方法H0、失敗反発0。親H32/閾値2でtemperature17。実際は見回しを選び+90度回転。次tickからhome観測なし。

続いて+45度、+15度の見回しを選び、39244秒に灰shapeへ歩行。yaw-27.57+操舵45=世界17.43度、つまり北寄りの外向きとなる。この歩行の反発は0。ここでは岩に押し返されたのではなく、見回しで向きを変えた後に選んだ目印方向へ歩いている。色・光だけでは焚き火と松明の同定はしない。

診断結論: 精細地図でも帰還方向の選択継続は保証されず、拠点を観測した瞬間にも過去の方法失敗・高い親H・確率選択が作用して見回しへ移れる。Bで具体的に確認。Aは低いHでも多数候補から別目印を選んでおり、全個体の離脱をH上限だけで説明しない。修正は行っていない。集計: confirm_departure_diagnostics_summary.json、再集計: analyze_confirm_diagnostics.cjs。生ログは出力ディレクトリgate-decisions.jsonlに保存。

### 中央焚き火の実視認確認

保存したselected段階の位置・yaw（行動前）540フレームについて、同じprepare_landmark_objects/light_fanを再実行。現行landmark_routes.jlと実験snapshotの同ファイルのSHA256一致を確認。中央visual_landmarkの発光だけを0にした対照を作り、遮蔽形状を維持したまま出力光源数の差で中央焚き火を識別。橙色shapeのレイ最短交差も追跡。新しい行動シミュレーションは行っていない。

B39240秒: 中央焚き火まで6.046、相対角-11.25度、遮蔽なし、光bright、shapeレイ-15/0度で焚き火に交差。39241秒: 距離5.547、角-4.088度、brightとshapeが引き続き観測可能。この時surveyを選び+90度回転。39242秒には光源中心-94.088度で視野±90外となりlight出力から消えるが、炎の端は-90度shapeレイに残る。39243秒以降はshapeも外れる。39245秒のcue:light:bright:5を選ぶ場面では中央焚き火は視野外なので、この光候補を中央焚き火とは解釈できない。

代表120秒で中央光源が見えるフレームはA1/B2/C6、shapeレイが炎へ当たるフレームはA1/B3/C10。A46440秒は中央焚き火が背後約177度、C37380秒も背後約165度。位置は入口正面でも本人は内側を向いていない。Aは46442秒に視野端で一度bright、Cは途中6フレームでbright。光が見えたことは「中央焚き火／帰還目標として同定した」ことを保証せず、AIへは光源IDではなく方角・明るさが渡る。

結論: Bの離脱は中央焚き火が見えなかったためではない。見えている時に見回しを選び、自ら視野から外した。A/Cも同じタイミングで見えていたとは言えず、姿勢と時刻を区別する。検証コードcheck_bonfire_visibility.jl、結果bonfire_departure_visibility.json。

## 重要ランドマーク確認ショートカット・3日（開始）

出力予定: outputs/enclosed-narrow-camp-landmark-3d-20261027。最小入口0.988・巨大焚き火・改修自動ρ・近場有限12個/遠方再生・未経験ABC・初日散策・危険OFF・人工道なし・同seed/感度/MB設定を維持し、--camp-landmark-shortcutを追加。初日に入口内外を固定行程で確認して、観測した大焚き火とhomeの対応を記録。帰還で再観測した特徴に対してpriority6・対数事前重みlog8の仮設候補を追加。詳細と設定経路の限定はsrc/lw/configured_paths/README.md。

短縮時計600秒×2日の統合試験を実施。可視性・未観測/未学習時不採用・同時home観測による対応・衝突候補除外など11項目、初日チェックリスト6項目PASS。ABC全員が内外の観測を実際に完了し、帰還候補も選択された（短縮試験A22/B31/C41回）。3日結果は未評価。

初日の固定見学そのものが入口通過経験を与えるため、改善しても目印の加点だけの効果とは判定しない。また半径5外/内通過数には初日見学分も含まれるので、2日目以降と分離して評価する。
本試験の事前配置・視認174項目PASS。入力全体比較でscene.configured_camp_landmark以外は直前の確認付き自動ρ試験と一致。

### 重要ランドマーク固定補助・3日結果

3日完了。ABC全員が2・3日目に荷下ろし達成、終了時全員拠点内・所持0。reserve A92.19/B90.59/C92.18、拠点距離A0.959/B0.804/C1.178。共有預入17・引出5・残12。近場0、遠方[21,24,18]。初日見学分を除く外/内通過A2/2・B3/3・C3/3。

初日チェックリストは全員完了（A51秒/B42秒/C46秒）。観測した焚き火とhomeの対応を全員記録。帰還時の設定候補は提示/選択A68/63、B104/57、C51/45。改修自動ρのみではA2日目のみ成功だったところから、今回は全員2日連続成功へ改善。ただし初日固定見学と特徴認識と候補への固定加点を合わせた結果であり、各効果は分離していない。ユーザーの理想とする「拠点全体の関係をひとまとまりのMBとして想起する」機構は未実装で、今回結果もその証拠ではない。

呼出221.16秒（約3.7分）、ピークRSS1.41 GB、累積割当129.68 GB。生活整合16項目・親MB/経路/帰還見積もり監査PASS。集計camp_landmark_3d_summary.json。追加変更なし。

## 拠点一巡経験MB・完了報酬・3日（開始）

出力: outputs/enclosed-camp-experience-3d-20261027。--camp-experience-mbを追加。最小入口0.988・巨大焚き火・改修自動ρ・近場有限12個/遠方再生・未経験ABC・初日散策・危険OFF・人工道なし・感度/seed/MB設定維持。入力比較でscene.configured_camp_experience以外は前回固定補助試験と全一致。

初日に入口内外→拠点左右→中央近傍を固定見学、実観測場面・遷移をplace_mbへ集約。中央帰着後60操作連続rest成立で初期報酬20をmb_place:campのMethodNodeへ一回だけ付与。旧fixed priority6/log8候補は無効。以後は通常の方法選択・成功失敗評価を使用し、観測した特徴から拠点MBを想起。視野外でも自己移動receiptで相対方向を更新、不確実ならscan。まとまりの全関係を汎用推論する完成版ではなく、観測した場面群と特徴対応を核とした初期版。

短縮時計600秒×2日で全員形成・初期報酬一度・旧加点候補未使用18項目、報酬再取得防止/未観測起動防止/視野外方向更新10項目、不確実時の非ゼロscan1項目PASS。A14場面19遷移/B14場面17遷移/C15場面17遷移を保存し、短縮試験では記憶による選択A7/B5/C2回。検査コードのBasicLoop生成引数不足は修正後に再検査PASS。事前配置・視認174項目PASS。

日末保存あり、初日固定見学の外/内通過を実生活の帰還と分離して評価する。強い初期報酬・見学拡張・記憶保持を合わせた比較で、単一要素の効果とは判定しない。3日本試験は実行開始、結果未評価。

### 拠点一巡経験MB・3日結果

3日完了。A2/3日目、C3日目に荷下ろし、B未達。最終A/C拠点内（距離1.00/1.04）、B距離10.60の外・所持1。reserve A91.79/B86.90/C87.62。共有預入6・引出1・残5。初日を除く外/内通過A5/5・B4/3・C2/2。固定加点版の全員2/3日成功より後退した。

全員が初日一巡を完了し、60連続rest後に報酬20を一度だけ受領。A169秒/B159秒/C163秒。保存した場面/遷移A14/19、B14/17、C15/17。旧固定加点候補の提示・選択は全員0。

場所MB候補選択A129/B648/C464。うち視野外の記憶による選択A81/B620/C440。ただしこれを記憶による歩行成功と解釈しない。圧縮eventsから全tickを復元すると場所MBの歩行/scanはA80/49、B56/592、C41/423。特にB/Cは不確実な推定から確認用scanを多く選び、帰還へ結びついていない。Bの最終場所推定不確実性235.28。

監査注意: place_mb.recallsは、拠点内で毎tick「可視→active→at_homeで解除」を数えるため、A23962/C5026など過大になる。独立した想起回数や帰還試行数として利用不可。これは統計上の問題で、今回コード修正・再実行はしていない。

呼出423.11秒（約7.1分）、ピークRSS1.33 GB、累積割当394.54 GB。生活整合16項目、親MB/経路/帰還見積もり監査PASS、日末保存3個。集計camp_experience_3d_summary.json。記憶形成・報酬と安定した帰還を区別する。

## 暫定ゴールへの到達モード

scene.goal_arrival=true（rock_gate runner --goal-arrival）で有効、既定off。帰還と食料取得それぞれにsearch/approach状態をmb_map.goal_arrivalとして保持。直接のhome/食料観測、または学習済み場所MBの特徴観測と場面一致confidence>=0.75を根拠に暫定到達へ入る。場所MB一致は既存mb_similarityで保存場面との一致を評価し、観測した焚き火の特徴との対応も要求する。世界座標や正解IDで照合しないため誤認を許す。

一時的に見失っても対象refと相対位置推定を保持し、自己移動receiptで更新。食料は活動中の対象refを再照合し、別の可視食料へ無条件に切り替えない。身体優先や安全の上位処理を維持する。homeへの実帰着・食料の実pickup/recoverで終了する。approach開始は達成報酬や成功として数えない。

到達中の候補は、同じ目標への距離減少と見回しによる目標方向の確認を評価。全候補を削除する方式ではなく、観測に基づく対数重みで局所到達へ寄せる。到達候補には親Hによる温度上昇を適用せず、方法報酬・過去失敗は保持。専用の直進/確認候補を追加するが、既存衝突/地形・局所操舵に従う。見回しの角度が別の定時方位確認で上書きされないようにする。

到達モード自身のHを分離。観測位置と自己移動予測との差は許容帯max(1,推定不確実性)を超えた分だけ蓄積。開始時の固定操作見積もりmax(60,4*距離/0.5+30)を超過した場合も残差を蓄積し、H>=8で仮説を棄却、60tickの再採用待機。見積もりはこの初期版では固定式であり未学習。反復観測で期限を後ろへずらさない。Hに応じて方向への選択重みを緩め、局所的な迂回余地を増やす。棄却証拠は有限recordsに保存するが、誤認記録を類似度学習へ追加する処理はまだない。

これは全目的に対する汎用的な問い形成の完成版ではなく、food/homeで共通の到達仮説・候補評価を接続した初期版。モードは日末保存対象。ρ自体は既存設定を継続し、モード切替による強制fineは追加しない。

到達モード検証: 基本12項目（低一致拒否、高一致採用、視野外保持、自己移動更新、位置矛盾による棄却、再採用待機、方向評価、親H温度からの独立、期限超過棄却、実達成解除）、短縮時計600秒×2日のhome/food接続9項目、日末保存からの再開結果一致1項目、計22項目PASS。A food42/home14、B14/18、C19/16操作で到達モード候補を選択。初回検査でentry統計の加算漏れを検出し修正。検査中のソース変更によるcheckpoint hash不一致は最終ソース固定後に再実行してPASS。3日本試験は未実施。検査: goal_arrival_checks.jl。

## 2026-10-27: parent MB arrival question and reversible location H

`--goal-arrival` now connects the provisional goal hypothesis to the parent MB itself. The food/home purpose remains unchanged; its question changes from search to approach. The existing search episode is suspended, and a fresh approach forecast is frozen on the first action. Re-observation does not restart that forecast. Unknown target observations can use the retained egocentric goal estimate; no hidden world coordinates are supplied.

Only search pressure attributable to delay/stagnation beyond energy and child-route debt is eligible for relief. Relief is bounded by current parent H and multiplied by recognition confidence. Other parent pressure and method failure records remain. Rejection or overdue approach restores the suspended search episode and the exact relieved amount (subject to the existing H cap of 32); new pressure is retained. Actual arrival discards suspended location debt and retains the existing actual-success handling. This does not yet decompose all historical parent H into independently persistent causal components. Search is never learned as a successful full journey merely because a candidate location was found.

Parent state `parent_mb.modes[goal]` records the mode, suspended episode, relief and bounded transition events with before/after H. It is included in existing daily checkpoints. Tests cover partial relief, idempotence, unseen-goal approach estimation, restoration with intervening pressure, and actual-confirmation disposal, plus shortened simulation/resume equivalence.

Three-day experiment conditions: inexperienced A/B/C; seed 20261005, world seed 20261027; minimum rock entrance about 0.988; central visual bonfire; first-day configured camp tour and rewarded place MB; finite near food 4 x 3 and renewable distant food; hazards off; no artificial roads; automatic home-distance rho and opening candidates; fixed sensitivities 0.5/1/2; body purpose, daily delivery, camp safe zone, MB simulation/chunks/sleep and similarity learning enabled. Daily checkpoints enabled. Output: `outputs/enclosed-parent-arrival-3d-20261027`.

Result (implementation `9a2719e`): three days completed, 376.06 s measured call time (including compilation), peak RSS 1.457 GB. A deposited 3 on day 2 and finished 11.41 from home, reserve 90.71; B deposited 1 on day 2 and finished 25.59 away, reserve 90.42; C deposited 2 on day 3 and finished 1.17 away, reserve 88.99. Initial configured-tour returns are not counted as delivery success. Daily checkpoints 1–3 saved. Life invariants 16 PASS; route, parent MB and return-outlook audits all PASS. Shortened checks: 12 arrival + 8 parent transition + 9 integration + 1 resume equivalence = 30 PASS.

All three agents used the mode; home entries A/B/C = 3/4/10, and no hypotheses were rejected in this trial. **No positive H relief occurred in the full run.** All home entry H values were zero except C at 41,743 s, whose parent H remained 32 because no search-only attributable pressure was eligible; C reached home and deposited at 41,757 s. The reversible-H mechanism is covered by targeted tests, but its natural-run effect/restoration is not demonstrated here. The stored transition lists have fewer than 64 entries in each goal, so no transition truncation affects this finding.

Previous goal-arrival-OFF comparison: A deliveries days 2/3, B none, C day 3; current ON: A day 2, B day 2, C day 3. B improved but A did not return on day 3, so this single shared-world run does not establish general return improvement. Input JSONs match after removing scene.goal_arrival; this comparison includes both arrival candidate projection and parent-mode integration, not a parent-H-only ablation. Full compact evidence is in `parent_arrival_3d_summary.json`, generated by `summarize_parent_arrival.cjs`.

## 2026-10-27: superseding partial relief with outcome-only question switching

The partial location-H relief design above is superseded. On entering arrival mode, the parent MB saves its entire H and active forecast. The currently evaluated arrival question starts at H=0 and has its own forecast; zero here is a new question's initial state, not a claim that return is complete. Local action evaluation continues normally. The saved parent H is not updated by local H increments.

When arrival ends, only success/failure is applied to the saved parent pressure through the same `goal_result_H` rule as ordinary goal evidence: actual success resolves it; failure restores saved H plus one failure (existing cap 32). No local H amount, confidence-scaled discount or residual debt is transferred. A repeated synchronization cannot apply the same failure twice. Failed arrival restores the suspended parent forecast; confirmed success disposes of it without fabricating a completed old search-duration observation. Local method evidence and censored approach observations still belong to their existing learners.

Transition events now contain saved_parent_H, success (on outcome), local_H (diagnostic only), and H_after. Both food and home use the same switching function. Daily checkpoints retain the saved state. Historical three-day results above are for the prior implementation and must not be read as evidence for this revision. Validation uses the existing shortened 600-second/day, two-day integration scenario, plus save/resume equivalence and explicit tests that different local H values yield the same parent failure outcome.

Validation completed: goal-arrival/outcome tests 49 PASS (including shortened simulation and checkpoint resume equality); existing mb_parent_checks.jl dependency suite 147 PASS. No new full three-day run was performed for this revision.

## 2026-10-27: fine rho for the active arrival question

With goal arrival enabled and rho enabled, the currently selected home/food purpose uses fine rho while its arrival hypothesis is active. The same tick's recognition chooses the structure map before candidates and steering consume it. Other purposes' retained hypotheses do not force refinement. Search restores the ordinary configured/distance-derived baseline on the next perception decision; explicit rho-off remains off. Fixed coarse is a baseline overridden during arrival; fixed fine remains fine. Expiry during candidate projection takes effect at the next perception decision.

Ground observations are sampled once; body odometry updates the baseline before the current home observation anchors it. Structure tracking is updated once per tick using the final chosen resolution. This refines grouping/boundary potentials over existing rays, not visual sampling density or new world knowledge. Per-purpose rho_baseline, rho_effective and rho_fine_decisions expose the selection and persist with the goal state.

Validation conditions: the existing camp-experience input, goal-arrival ON, shortened two days of 600 seconds/day, including daily checkpoint resume equivalence. Dedicated tests cover both food/home entry, failed hypothesis, actual success, coarse/fine baselines and explicit off.

Final validation: 67 goal-arrival/rho/integration assertions PASS including checkpoint resume equality; 50 home-distance regression assertions PASS. Initial run was invalidated by a source edit during checkpoint verification (source mismatch); the final frozen-source rerun passed. No full three-day trial for this revision.

## 2026-10-27: three-day outcome-only arrival with fine rho

Source: `118d858`. Output: `outputs/enclosed-arrival-rho-3d-20261027`. Same input JSON as the previous `enclosed-parent-arrival-3d-20261027` trial (deep equality checked). Three days, inexperienced ABC, sensitivities 0.5/1/2, world seed 20261027 and choice seed 20261005, minimum rock entrance ~0.988, central visual bonfire, first-day configured camp/place experience, finite near food 12 total plus renewable distant food. Hazards off, artificial roads off, automatic home-distance rho with arrival refinement; daily checkpoints on. Compared with the previous full trial this includes both outcome-only parent-H switching and arrival fine-rho, so the comparison does not isolate rho alone.

Completed: 462.23 s call time including compilation (~7 min 42 s), peak RSS 1.479 GB, cumulative allocation 326.74 GB. A deposited 3 on day 2 and 2 on day 3, final distance 1.16, reserve 91.22. B deposited 1 on day 2 and 3 on day 3, final distance 1.00, reserve 92.24. C had no deposits, final distance 33.99, reserve 87.44. Thus A/B returned on both active days, while C failed to bring food home; not a universal improvement over the prior A day-2/B day-2/C day-3 pattern.

A's home question entered arrival at 46,347 s with saved parent H=27.390625 and local H=0, then confirmed arrival/deposited at 46,356 s (9 s later). The saved parent question was resolved on success. No arrival rejections were observed, so natural-run failure restoration remains unexercised. Home-mode entries A/B/C=4/5/9 include initial observation excursions and are not delivery counts. Fine-rho perception decisions for home A/B/C=231/80/91 and food=25,409/24,947/25,168; these counters include perception ticks without navigation and are not counts of walking actions.

All three daily checkpoints saved. Life invariants 16 PASS; route, parent MB and return-outlook audits PASS. The earlier full trial took 376.06 s; this run took about 23% longer, but behavior also changed and timing is single-run/compilation-inclusive. Evidence: `arrival_rho_3d_summary.json`; input JSON equality with prior trial was checked before evaluation. No new implementation changes were made during this simulation.

### C trajectory follow-up, day 2 onward

Read-only analysis of the same `118d858` trial; no simulation rerun. Change-only action events were expanded by their next-event timestamps; positions are 60-second samples (not exact paths). C picked up/eat at 17,299/17,300 s near camp, left the enclosure at 17,525 s, then picked up on 17,574–17,576 s (three successive actions collapsed into one event). It had 3 units before later eating, 2 at day-2 end, and 1 at day-3 end; there was no deposit.

At (5.695, 9.874), an uninterrupted rest event spans 18,218–24,403 s (6,185 s). The existing exploration rule allows resting outside when inventory >=3 and reserve >=80. Home-purpose walking appears at 24,403 s; the persistent return-purpose state/body parent switches at 25,920 s. These are different telemetry layers, so return_active alone does not label every home-purpose action. The plot uses action-event purpose. C circles the outside south/east; day 2 ends at (9.337,8.320). On day 3 it reaches the north side again, then drifts west to (-30.636,20.716), and rests from 48,960 s through the end. It eats carried food at 26,573 and 41,916 s.

No home arrival-mode entry occurs after the final initial-area confirmation at 17,511 s. The nearest gate sample during day 3 is at 45,960 s, (-1.085,13.776), about 3.14 from the entrance center (0,10.83); sampling cannot establish the exact closest approach or visibility. The evidence supports successful near-food acquisition followed by failed return localization/navigation, not failure to obtain food or rejection inside arrival mode. Exact visibility/candidate weights at those approaches need a separate diagnostic replay.

Reproducible rendering/summary: `trace_c_arrival.cjs RUN OUTPUT`; retained summary `c_arrival_day2_trace.json`. Local image: `outputs/c-arrival-trace/c-path.png`. Lines interpolate 60-second positions; obstacle crossings in these lines are not evidence of actual collision traversal.

## 2026-10-27: C sensitivity 2 -> 1, matched three-day comparison

Run `outputs/enclosed-arrival-c1-3d-20261027`, implementation unchanged from `118d858` (current HEAD `aeebd52` adds documentation/analysis only). Fresh inexperienced actors and identical seeds/map/food/tour, minimum entrance ~0.988, central bonfire, hazards off, artificial roads off, parent outcome-only switching, arrival fine rho and checkpoints. A stays 0.5, B stays 1; only C's delay/stagnation/energy/contradiction sensitivities change from 2 to 1 via `sensitivity_c1.json`. Input JSON deep comparison confirms these four values are the only changed simulation inputs. This is one matched-seed shared-world comparison, not a multi-seed estimate of a general causal effect.

Completed C=1 trial: all A/B/C deposited on both days 2 and 3 and ended inside home. C deposits: day 2 at 26,473 s, 3 units; day 3 at 46,442 s, 2 units. Final home distance 1.13 and reserve 91.28 (C=2: no deposits, distance 33.99, reserve 87.44). C entered arrival at 26,464/46,426 s with saved parent H=32, then confirmed arrival 9/16 s later. No arrival rejections. Home fine-rho perception ticks 116 vs 91. C daily-ending home H is now 0/0/0 vs prior 0/32/32; this reflects actual success reset and does not mean H never grew.

A deposits 3/3 and B 1/2 on days 2/3; both end home. Their differing results despite unchanged sensitivities demonstrate shared-world interaction, so do not interpret this as an isolated C-only trajectory intervention. The result supports sensitivity affecting behavior for this seed; it does not establish that lower sensitivity always improves navigation. No implementation/default sensitivity changes were made.

Call time 286.18 s (~4 min 46 s), peak RSS 1.412 GB, cumulative allocation 169.50 GB. Prior call 462.23 s; behavior/amount of searching changed, so this is not a pure per-step performance comparison. Life invariants 16 PASS; route, parent MB and return-outlook audits PASS; three daily checkpoints saved. Evidence: `arrival_c1_3d_summary.json`. Generic daily maps: `outputs/arrival-c1-daily-paths/day-02.png` and `day-03.png` (60-second samples). The baseline-specific annotated C tracer was not used for interpretation of this different run.

## 2026-10-27: C=2 alternate choice seed, three days

Run `outputs/enclosed-c2-seed20261006-3d`. Sensitivities A=0.5/B=1/C=2 restored. Choice seed 20261005 -> 20261006; world seed remains 20261027. Input JSON deep comparison against `enclosed-arrival-rho-3d-20261027` confirms config.seed is the only difference. All actors use the new seed; this is not a C-only RNG intervention. Fresh actors, same narrow enclosure/food/initial tour, hazards off, no artificial roads, outcome-only parent switching, fine arrival rho, daily checkpoints, three days. Runner now accepts --choice-seed (default unchanged); simulation implementation unchanged.

Result: C=2 with seed 20261006 deposits 1 on day 2 (17,359 s), but none on day 3; final distance 9.04, reserve 90.82, inventory 2. Day-2 crossing confirms an actual short outing: out 17,289 s -> in 17,351 s -> deposit 17,359 s. Thus the day-2 delivery is not merely an initial in-camp action. C departs again at 34,634 s and never re-enters by the end. A deposits 2/3 and B 3/2 on days 2/3, both finish home.

Natural failure-path evidence: C enters home arrival at 34,817 s, saved parent H=0; the hypothesis expires as arrival_overdue at 43,028 s (hypothesis H=8.015567). Local arrival-loop H=32 at sync, but the restored parent H is exactly 1, with success=false. No local pressure magnitude is transferred. This is one retained failure event, not repeated per tick. The elapsed wall simulation time spans other purposes/rest; arrival budget counts eligible navigation decisions, not every second. Home fine-rho perception decisions=407. This run demonstrates a failure restoration that the prior runs did not exercise.

Matched results for C: seed 20261005 sensitivity 2 -> no deliveries, end distance 33.99; same seed sensitivity 1 -> deliveries days 2/3, distance 1.13; seed 20261006 sensitivity 2 -> delivery day 2 only, distance 9.04. These three runs show variation with both sensitivity and stochastic trajectory; they do not establish a generally optimal sensitivity. Shared-world coupling and all-actor seed change remain part of this comparison.

Call time 359.37 s (~5 min 59 s), peak RSS 1.480 GB, cumulative allocation 364.77 GB. Life invariants 16 PASS; route, parent MB and return-outlook audits PASS; all three daily checkpoints saved. Evidence: `arrival_c2_seed20261006_summary.json`. Input-equality check verified only config.seed differs from the prior sensitivity-2 baseline.

## 2026-10-27: seed 20261006, C sensitivity 1 matched trial

Run `outputs/enclosed-c1-seed20261006-3d`, source `50cdaaa`, simulation code unchanged. Same three-day conditions and seeds as the immediately preceding C=2 run; only C delay/stagnation/energy/contradiction change 2 -> 1. A=.5/B=1. Input JSON deep equality after restoring C profile confirms no other input difference.

C again deposits one on day 2 at 17,359 s. On day 3 it picks up at 43,253 s and eats at 43,254 s, then returns empty-handed: arrival-mode entry at 47,234 s with saved parent H=32, confirmed home at 47,244 s (10 s later). Final home distance .967, reserve 89.67, inventory zero. No arrival rejection. Thus navigation improved relative to C=2/seed20261006 (failed arrival, final distance9.04), but day-3 food delivery did not improve: neither delivered on day3. Do not conflate actual return with delivery.

A deposits on both days and finishes home (distance1.18); B deposits only day2 and finishes outside (distance9.06). B's sensitivity is unchanged, emphasizing shared-world interaction. Across the two tested seeds, C=1 finishes home in both, whereas C=2 finishes outside in both; these are only two shared-world trajectories, not a reliable success-rate or optimal-sensitivity estimate.

Call time397.98 s (~6 min38 s), peak RSS1.718 GB, cumulative allocation389.87 GB. Life invariants16 PASS; route/parent MB/return-outlook audits PASS; all daily checkpoints saved. Evidence: `arrival_c1_seed20261006_summary.json`. No defaults or simulation implementation changed.

## 2026-10-27: far-only ten-day trial started

Output `outputs/enclosed-far-c1-seed20261006-10d`; source `f7eed7f`. Fresh inexperienced actors, A=.5/B=1/C=1, choice seed20261006, world seed20261027. Ten days; retain the minimum rock entrance, central bonfire, configured first-day camp observation/place learning, parent outcome switching and arrival fine rho. Hazards off, artificial roads off, daily checkpoints on. Initial reserve90/inventory0 and camp provisions0. Food ONLY (8,24),(0,30),(-6,24), each stock24 and renewable; remove all three finite near patches. Input JSON comparison confirms only config.days (3->10) and removal of near food differ from `enclosed-c1-seed20261006-3d`. Geometry checks passed. This entry records launch/conditions, not completed results. Log: `outputs/enclosed-far-c1-seed20261006-10d.log`.

### Far-only ten-day result

Completed all ten days and daily checkpoints. Call time1732.96 s (~28m53s), peak RSS1.490 GB, cumulative allocation1.626 TB (not resident memory). Life invariants51 PASS; route/parent MB/return-outlook audits PASS.

A: deposits days2,3,4,7,8,10 (11 units); final home distance1.067/reserve91.43. C: deposits days2,3,4,5,6,8,10 (19 units); final distance1.221/reserve93.99. B: deposits days2,3 (5 units); no later delivery, but day9 final position is at home (distance~1.11), so this is not an uninterrupted failure to return; day10 final distance6.532/reserve85.25. All actors remain alive. Home-arrival hypothesis rejections A2/B0/C0; entries include initial tour and local returns and are not delivery totals.

Storage deposited35, retrieved10, finalshared25. Food initial72+regrown23=ground40+consumed30+shared25 (final inventories all0). The result demonstrates repeated distant-food delivery for A/C under this one seed; B's later instability remains. Near-food removal changes stochastic trajectories and shared-food interaction, so this is not evidence that more distant food is intrinsically easier. Compact evidence: `far_c1_10d_summary.json`.

### B trajectory diagnosis, days4-10

Read existing result/events/60-second position samples; no simulation replay or code changes. Rendering: `trace_b_far.cjs RUN OUTPUT` after `render_daily_paths.cjs RUN ordinary outputs/far-10d-daily-paths`; figure `outputs/b-far-trace/b-days4-10.png`. Evidence `b_far_day4_trace.json`.

B obtains three units at 51,937–51,939 s on day4 (collapsed pickup event expanded until next action). It then spends 8,437 seconds of day4 in food-purpose rest; the existing inventory>=3/reserve>=80 exploration rest rule is relevant, rather than immediate mandatory delivery. Persistent return starts at60,480 s. It eats the three carried units at61,900/77,641/93,698 s, i.e. days4/5/6, leaving daily inventories2/1/0. No later deposit occurs. Thus initial food acquisition succeeded; the load was consumed while return remained unresolved.

Days4-8 end with parent home H=32. No home-arrival entry occurs between day3's46,316 s and day9's142,311 s. B repeatedly passes near the north opening in the position samples: day5 at81,360 s is(0.253,12.636), about1.82 from the entrance center(0,10.83), but selected action is mb_recheck scan, not arrival. Days5-8 contain27,869 home scan seconds vs27,898 home walk seconds, indicating prolonged search/rechecking. H saturation and candidate diffusion are plausible contributors; exact view direction, visibility and candidate probabilities at those passes are not stored in these logs and cannot be diagnosed conclusively without replay. Do not equate proximity or sampled lines through obstacles with seeing a traversable entrance.

After depletion, B obtains one at109,752 s/day7 and eats immediately. Day8 C gives one at126,016 s after requests/refusals; B eats at126,017 s. Day9 B picks up/eats at141,814/141,815 s, then enters home arrival at142,311 s and reaches home142,322 s (11s), empty-handed. Day10 again picks up/eats159,644/159,645 s, with no surplus to deposit; it spends16,686 seconds resting that day and ends just outside, distance6.53. Shared stock is known, but this investigation does not establish which particular home-rest rule dominates each interval.

Operational diagnosis: food collection on day4 succeeds -> delayed/non-converging return before arrival recognition -> carried stock used for survival -> later food interruptions are single-unit replenishment, so even day9 successful return brings no cargo. Arrival execution itself has no recorded rejection for B in this trial. The upstream perception/candidate-selection cause of missed arrivals remains a diagnostic replay question, not proven by the trace alone.

## 2026-10-27: open camp, complex rocky map authoring

Added opt-in `--complex-rocks` world authoring for ordinary open camp with far-transfer food; mutually exclusive with --enclosed-camp. Central bonfire now supports ordinary open camps. The existing 23-stone enclosure is omitted; 100 new rocks form four staggered partial ridges north of camp and five flank/rear clusters. Added rocks stay outside radius8 plus their radius, keep food clearance, and avoid existing objects. Total high obstacles218. New IDs remain unique. The world is intentionally authored with regular ridges, not a claim of natural geology.

Prepared output `outputs/open-camp-complex-rocks-20261027/ordinary/input.json`: sensitivities .5/1/1, choice seed20261006/world seed20261027, far food(8,24),(0,30),(-6,24), 24 each renewable; artificial roads0; hazards off; initial tour/place MB, central bonfire, outcome-only switching/fine-arrival rho retained. Configured duration10 but prepare-only was used: no behavioral trial has run.

Geometry verification includes 10 complex-map assertions: camp/spawn clearance, added-object exclusion radius, unique IDs, and reachability of all three food centers. A .5-grid dry-ground BFS with obstacle margin.3 and checked edges found routes of32/42/43 units. These are feasible grid witnesses, not optimal continuous paths or guarantees the AI can find them. Witnesses are saved separately in complex-rocks-access.json, never passed to the agent. Existing layout/bonfire checks also passed. Authoring evidence `complex_rocks_access.json`; renderer `render_complex_map.cjs CASE_DIR`; local preview `outputs/open-camp-complex-rocks-20261027/ordinary/complex-map.png`.
