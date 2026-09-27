# Luanti L13A — 色タイルと遠景を伴う有限探索 Evidence

**状態: IMPLEMENTED / FINITE ACCEPTANCE COMPLETE。2026-09-27。**
基準: GameAI `df2d23d` ＋ 本実装working tree。
[契約](../experiment-contracts/LUANTI_L13A_finite_exploration_contract.md)／
[後続計画](../design/RDL_GameAI_Luanti_Exploration_Plan.md)。
実機: Luanti 5.17.0 Windows、LuaJIT 2.1.1782726002、headless server。
Worldのnode・entity・yaw・位置・HTTPを実行した。GUI／画面キャプチャによる外観検査は行っていない。

## 成立した一周

```text
Worldの地表9点・局所Food・遠景の表面特徴を取得
→ 取得時刻／姿勢／身体revisionとともにRuntimeへ送信
→ 入力検査と有限保存
→ 固定された局所色追従または見えているFoodへの相対操作
→ World stepで期限と身体状態を再検査し、操作台帳を先に消費
→ 実移動／回転／pickupと実測結果を返す
→ 新しい通常取得枠で継続
```

`runtime.exploration.FiniteExploration`は専用opt-in。既定のNPC行動経路へは挿入しない。
地表は新しい`l13a-ground-nine-v1`の有限取得記録で、旧vision_localの個数payloadは変更していない。
遠景は共有`distant_sensor.lua`と既存SensoryObservationStoreで取得・受理する。
未知のFood位置・全地図・タイルの接続表・正解経路はRuntimeへ送らない。
Foodが本人の半径12へ入った時点で、そのrefと相対位置を観測し、以後の接近に使う。
地表色の続く方向を試す規則は設計者固定。Experience形成・経路記憶・T1・M_B更新は行わない。

## 9つの独立World run

各runでWorld・Runtimeを新しくし、昼時刻0.5を固定したまま経過時計を進めた。
単独npc_a、平坦な地面と幅2nodeの青い帯、歩行区画外の岩山3か所。
直線Foodは開始から26node、曲がりのFoodは(±24,1,12)。全runの最初の配送ではFood未観測。
回転配置は初期yaw・帯・Foodだけを90度回転し、山は固定した。
帯なし対照は右折配置と同じ初期身体・Food・山で、帯を灰色へ置き換えている。

| ケース | 取得記録／許可処理数 | 実移動node | 結果 | 実取得までのWorld秒 |
| --- | ---: | ---: | --- | ---: |
| straight | 26 | 25 | acquired | 6.278 |
| right | 39 | 37 | acquired | 9.527 |
| left | 39 | 37 | acquired | 9.538 |
| rotated | 39 | 37 | acquired | 9.525 |
| no_strip | 64 | 62 | time_limit | null |
| no_food | 64 | 61 | time_limit | null |
| partial | 64 | 0 | time_limit、取得不完了でwait | null |
| blocked | 64 | 2 | time_limit、実移動blocked後にwait | null |
| faults | 42 | 37 | acquired | 10.287 |

合計**441取得packet、地表3969点、受理済み遠景441frame、実pickup5件**。
遠景には合計364個の表面特徴記録がある。独立した364山という意味ではない。
許可処理数にはwait・expired・staleも含み、身体を変えた回数とは区別する。
時間切れ4runは16.000809〜16.013700秒の最初のWorld stepで停止し、終了後は配送だけを処理した。
未取得側の操作数や距離は効率改善の証拠ではなく、未達の経過として記録した。

straightは移動25回とpickup1回。right/left/rotatedは移動37回・回転1回・pickup1回。
no_stripは移動62回・境界blocked1回・回転1回で、Foodは最後まで未観測だった。
no_foodは道の先で引き返す動きも残るが、本人の位置同定や「迷った」という自己判断は実装していない。
これらは固定規則と有限配置での結果であり、一般の探索性能や、全地形での成功／失敗は主張しない。

## 取得と身体の検査

- 250000usごとの通常取得枠を一回だけ処理し、全runでslot重複なし。最大64記録。
- 地表9点は実node色と有限rayから取得。入力には身体基準の区画IDを使い、World座標を含めない。
- partialは読み取りadapterへnilを返す故障注入。実Worldが空だったことや実chunk unloadの証拠にはしない。
- blockedは第3取得後、前方に本物の不透過nodeを追加。取得済みの青い帯を根拠に発行された前進が、
  実行時の衝突検査でblockedになり、位置を変更しなかった。以後は遮蔽による不足としてwait。
- 相対移動はkinematic。0.25node刻みの通過点と床を検査し、1node移動の前後位置を読み戻す。
  一般歩行物理・移動しながらの一般姿勢変換を実装したとはしない。
- 山はWorld nodeで作り、固定した露出表面を読み戻した。全runで遠景特徴が実際に配送・受理された。
  方向・粗い色の取得までで、稜線認識・山の同定・山を使う行動選択は未接続。
- 全runのcanonical snapshotとInteractionHistoryは開始前後で完全一致。

## 応答消失・遅延・古い操作

faultsでは最初の観測をRuntimeが受理した成功応答を呼出し側へ適用せず破棄し、同じ入力を再送した。
再受付は`new_observations=0 / new_frames=0`、同じ操作IDと元取得時刻を返す。
Luantiはその操作を一度だけ実行する。毎操作の即時再要求、および古い操作の後続再注入でも身体作用は増えない。
これはconsumerへ旧応答のcommandを再注入した検査であり、ネットワーク順序逆転を直接起こしたものではない。

さらに一つの応答受渡しを750000us遅らせ、保留中にも地表・遠景の取得が継続した。
実結果は**expired2件、stale1件**。いずれも実変位・回転・取得は0。
その後は新しい観測から再開し、通常右折条件と同じ移動37回・回転1回・pickup1回で取得した。
pending最大は4件（上限8）。実ネットワーク切断・任意障害・プロセス再起動後の永続一回実行は未検証。

## 検証と再現

- L13A Python: **20テストPASS**。入力allowlist、取得不足、同時再送、容量、原子的受付、期限・姿勢、
  実測結果、HTTP opt-in、未観測対象拒否、完了と時間切れ、非介入、9runの完全再生を含む。
- Lua制御／地表取得: **24アサーションPASS**（各実機run内で実行）。二重消費・実行中再入・異個体・
  期限・身体版・容量・色取得・回転・遮蔽・未取得を含む。身体操作の一部は局所test adapter。
- 全体Python: **675件実行 = 624 PASS + 51 intentional skip**（9.995秒）。
- 今回再実行した既存実Luanti回帰: **L12 positive_active/A（7Episode）、OBS-9 faults（108frame、A/B生活）、OBS-3 PASS**。
  L12全12runやOBS系列全ケースを今回再実行したという意味ではない。

[保存再生記録](../../tests/fixtures/luanti_l13a_replay.json)には、9runの未改変JSON tree、
受理済みHTTP wire、入力と結果、World側だけの正解・実測を分離して保存している。
各元snapshotのSHA256と実装sourceのSHA256を付けた。検査器は全wireを再投入し、応答・最終snapshotを完全比較する。

```powershell
.\integrations\luanti\scripts\test-exploration.ps1 -Matrix
python -m integrations.luanti.tests.capture_exploration_replay <matrix-manifest.json>
python -m unittest discover -s tests -p test_exploration.py
python -m unittest discover -s tests
```

今回のmanifestは`integrations/luanti/output/l13a-matrix-20260927-092804.json`。
生ログは同outputの`l13a-matrix.log`、`l13a-full-python.log`、`l13a-regression-*.log`（Git対象外）。
既定Luanti配置は`D:\luanti`。launcherは専用Worldを作り、起動したserver／Runtimeだけを終了する。

## 次の境界

初版で成立したのは**未知のFoodを実観測で発見し、有限な固定規則で取得／未達まで実行すること**。
「青い道が餌につながる」と帰納したわけではなく、山を使って道を覚えたわけでもない。
その経験の保持・目印の対応・独立検査・M_B採用はL13B/Cで別に実装する。
昼夜・消耗・行き倒れ・複数個体を、この初版の完了条件へ追加しない。
