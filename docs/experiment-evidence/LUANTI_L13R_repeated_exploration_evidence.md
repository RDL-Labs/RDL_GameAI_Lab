# Luanti L13R — 最大30日探索系列のEvidence

状態: FINITE ACCEPTANCE COMPLETE / 2026-09-27。
基準: `ae2a2a1` ＋ 本実装working tree。
[契約](../experiment-contracts/LUANTI_L13R_repeated_exploration_contract.md)。
再生記録: [luanti_l13r_replay.json.gz](../../tests/fixtures/luanti_l13r_replay.json.gz)（1,901,410 bytes）。
62日分の未改変JSON木・HTTP response文字列、元snapshotファイルのSHA-256、実行時の実装10ファイルのSHA-256を保存。
圧縮は監査記録の可逆保存であり、履歴を意味的に要約する学習処理ではない。

## 到達点と限定

同一地形で日ごとに拠点・身体・Runtimeを初期化し、未発見なら次の日を起動する系列制御。
本人の新しい局所観測でFoodを発見した日を最後とし、最大30日で終了する。
単発L13Aは当日の残り予算で接近・pickupを確認するため、発見時刻と実取得時刻は別に残る。

**保持した記録を現行の固定探索器へは渡していない。** `memory`は過去材料を公開でき、
`reset`は空を返すが、どちらも行動はL13Aの固定規則のまま。
これは30日系列と記録保持の受入・学習前の基準結果であって、学習による探索改善の実証ではない。
経路照合、帰納、独立検査、Experience登録、T1/M_B更新は実装していない。

## 実Luanti系列

Luanti 5.17.0 / LuaJITで、4系列・計62独立runを実行した。

| 地形 | 履歴条件 | 日数 | 初回発見 | 実取得 | 受理packet／遠景frame | 総移動node |
| --- | --- | ---: | --- | --- | ---: | ---: |
| 右曲がり色帯あり | memory | 1 | 1日目・6,770,974µs | 9,533,619µs | 39 | 37 |
| 右曲がり色帯あり | reset | 1 | 1日目・6,780,239µs | 9,556,576µs | 39 | 37 |
| 同一Food配置・色帯なし | memory | 30 | null | なし | 1,920 | 1,860 |
| 同一Food配置・色帯なし | reset | 30 | null | なし | 1,920 | 1,860 |

合計3,918取得packet、地表35,262サンプル、受理済み遠景3,918frame、遠景特徴2,898記録、実pickup2件。
遠景特徴の件数は固有の山の数ではない。全runの最大pendingは1。

帯ありは両条件とも37move＋1turn＋1pickup。発見まで26node・27許可消費、取得まで37node・39許可消費。
日間の経験保持効果を試す前に初日で終了しており、この陽性対照から学習改善を主張しない。
帯なしは両条件とも毎日62move＋1blocked＋1turnの64許可。毎日64取得枠を使い、16秒で時間切れ。
30日で系列あたり480秒の探索時間を消費した。実際の終了step時刻の微小な超過は原記録に残し、
集計する探索予算は各日16秒を上限とする。開始・配送の実時間を480秒へ含めていない。
各系列の発見時点で次の日を起動せず、30日未発見側は`undiscovered_at_limit`で停止。
主比較62runに機構エラーはなかった。

各日は別Luanti process・別Runtime process・新規Worldを使用する。日番号を行動入力にしない。
地形、Food配置、三つの山、開始位置／yaw、昼間照明を同一条件へ再設定していることを
World側Evidenceで比較し、その真値を保持材料へ入れない。
拠点への復帰はharnessのリセットであり、本人が帰還できた証拠ではない。

道なしでもFoodはWorldに存在する。固定規則は前進し、区画端でblockedとなって右回転し、
残り時間で前進する。この配置ではFoodの局所観測範囲へ入らず、翌日も同じ経路を繰り返す。
30回の実行を、30種類の経路探索や30件の独立した負の学習支持へ置き換えない。

## 保持・再送・未達

保持系列は日開始時に0、64、128…と前日までの記録を公開できる。
リセット系列は日開始時の公開履歴が常に0。実験者の監査archiveには両条件とも全日を保存する。
retentionの有無を学習の有無と呼ばず、全開始記録に`history_consumed_by_policy=false`を残す。

runtime向けrequest／receiptだけを抽出し、新しい`FiniteExploration`へ正確に再生してから
日全体を保存する。World座標・地形・山ID・描画readbackは別の実機検査用記録に残す。
再生の一致はソフトウェア契約の検証であり、World作用は実位置／yaw／Food除去のreadbackで検査する。

同じ日の同じ受付の再送は完了日を増やさない。変更payload、別runの使い回し、未完了日、
応答改変は拒否し、現在の日の予約と既存記録を変更しない。
旧日の受付再送が新しい日の予約を消さないことはPython検査。
旧runの身体command拒否は各実Luantiで実行する既存24 Lua assertions内のcontext検査を利用する。
遅延callbackが生存したまま別processへ実際に届く通信実験や永続的な一回実行保証ではない。

未発見で上限に達した系列は`undiscovered_at_limit`。発見日・発見までのコストはnull、
消費した総時間・移動・操作は別の値として残す。World全体のFood不存在や死亡を意味しない。
通信／実行器の例外は`mechanism_error`で停止し、30日未発見完了へ含めない。

## 検証

- L13R Python: **21 PASS**。全62日再生、系列receipt一致、保持条件間の全action列一致を含む。
- 各実Luanti run: 既存L13A制御／観測の**24 Lua assertions PASS**。
- 全体: **696件実行＝645 PASS＋51 intentional skip**（23.686秒）。
- 追加の実Luanti回帰: L13A `faults` **PASS**。42取得、37node移動、実取得10,286,490µs。
  応答消失後の同一観測受付`new_frames=0`、遅延中の取得、失効操作、旧応答の二重作用防止を再検査した。
- 既存L13Aの9runやL12／OBS等の保存記録は全体Pythonで再生した。今回はL12／OBSの実Worldを新たに再実行していない。

ログは `integrations/luanti/output/l13r-matrix.log`、`l13r-full-python.log`、
`l13r-l13a-faults-regression.log`。追加回帰snapshotは `l13a-20260927-101639-954.snapshot.json`。
主比較の圧縮series archiveは同ディレクトリの次の4件。保存replayにも同じseries IDと全内容を含む。

- `l13r-5f4b048817244e13.series.json.gz`（帯あり／memory）
- `l13r-4a9397e22ae04120.series.json.gz`（帯あり／reset）
- `l13r-927e2e9242a14010.series.json.gz`（帯なし／memory）
- `l13r-7996fc069ed5403c.series.json.gz`（帯なし／reset）


再送・日数30／31・取得1920件・copy独立性・並行受付・不正入力時の部分更新なし・
発見と取得の分離・観測不足・初期Food既知拒否・旧run排除・canonical/History非介入を検査する。
「発見したが取得できない」「途中の日に初めて発見する」「機構エラー」は合成Python条件であり、
今回の実World主比較の結果へ混ぜない。

## 再現

```powershell
# 4系列。道ありは各1日で発見、道なしは各30日を実行する既存固定規則の基準比較。
python -u -m integrations.luanti.tests.run_exploration_series --matrix --output tests/fixtures/luanti_l13r_replay.json.gz

# 一系列だけ。常に1〜30日の有限上限。
python -u -m integrations.luanti.tests.run_exploration_series --scenario no_strip --mode memory --max-days 30

# 保存した全日の実World測定・HTTP往復・系列台帳を再検証。
python -m integrations.luanti.tests.check_exploration_series tests/fixtures/luanti_l13r_replay.json.gz
python -m unittest tests.test_exploration_series -v
python -m unittest discover -s tests
```

mainの既定実行へ自動挿入していない。headless Luantiで実行し、GUI／ブラウザーの目視は受入に含めない。
圧縮artifactはJSON木とHTTP response文字列を保持する監査資料であり、長期記憶・再起動後の行動再開機能ではない。
