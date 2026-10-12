# J0–J2 初回結果 — 同等幾何移植、接続前で停止

実施日: 2026-10-12。状態: **J0–J2実施、J3未着手、本線Python維持**。

- Python基準: `52a94225484f7e1771c4b4c3703c3eb9eef39730`
- 成功実験commit: `e4deefb583f0db06b111913c5437181df868079a`
- [成功run 38215198325](https://github.com/RDL-Labs/RDL_GameAI_Lab/actions/runs/38215198325)
- Ubuntu 24.04 / Linux 6.17 Azure / AMD EPYC 9V45、Python 3.12.15、Julia 1.13.1、単一thread。
- Project/Manifestは実環境生成物。BenchmarkTools 1.8.0、JSON3を含む全依存はManifest参照。
- 新しい空depotで復元し、Manifest不変とテスト成功を確認した。
- runtime・既存World・行動規則・H・rho・既存テスト期待値の変更なし。

## J0: 180 World秒の計測

human_scale_v1、観測1秒、movement_inertia、seed 20261005、A/B/C、social_base。
各組を新しいworkerで実行し、events→off / off→events / events→offの順序。
summaryの比較除外は事前登録した最上位elapsed_secondsだけ。

| 系列 | events 本体秒 | off 本体秒 | events 全体秒 | off 全体秒 | 最終状態 |
|---|---:|---:|---:|---:|---|
| 0 | 4.229644 | 4.304925 | 4.389862 | 4.377486 | 一致 |
| 1 | 4.347735 | 4.313213 | 4.449960 | 4.386000 | 一致 |
| 2 | 4.254060 | 4.266431 | 4.352321 | 4.345200 | 一致 |

この短窓でもoffの速度優位は確認できなかった。各events監査は270操作、
食料保存・操作重複/重なりなしPASS。offには操作監査がなく、最終状態一致だけで
中間の全行動列一致は主張しない。夜間・翌日の費用は未計測。

別workerのcProfileは10.747275秒。排他的自己時間の暫定分類:

| 分類 | 秒 | profile全体中 |
|---|---:|---:|
| ray_hit + segment_hit 自己時間 | 2.892868 | 26.92% |
| copy.py 内の自己時間 | 3.037327 | 28.26% |
| 観測関連の命名で分類した自己時間 | 1.185850 | 11.03% |
| その他 | 3.631230 | 33.79% |

ray_hitは9,705,600回、segment_hitは2,284,371回。累積時間はそれぞれ1.774098秒と
1.974045秒。copy.py以外の組込み関数費用はotherに含まれる。
分類は関数名・ファイル名のヒューリスティックであり、観測と幾何の責務を
完全に分割した値ではない。累積時間同士も合算しない。
**プロファイラの呼出し負荷があるため、この比率を無計測時の全体速度比へ直結させない。**

## J2: 正しさと改修

固定Python Git blobから式を読み、UTF-8/LF JSONLとして入力・出力を保存。
最終fixtureは境界46件、固定生成1000件、保存World由来100件、合計1146件。
hit/miss・最近対象の順序は厳密、距離は事前のabs/rel各1e-12条件で検査。
**意味上の不一致0件**。再実行、入力不変、結果バッファ独立、同距離の先着保持も確認。
Juliaは22アサーションPASS（1146件の差分は集合として検査）、Pythonは3テストPASS。
既存portable replayの6テストもローカルPASS。全体suiteの再実行をこの報告の根拠にはしていない。

失敗・修正の履歴を隠さない:

1. `b1862fc` / run 38214561128: WindowsのCRLFをハッシュ化し、GitのLF保存と
   不一致。数値を変えず保存バイトをLFへ固定。既存JSON値は変更なし。
2. `315f864` / run 38214737954: 幾何1040件は一致。wrapperのBool拒否1件が失敗。
   Juliaの配列連結がBoolをFloat64へ昇格していた。変換前のtupleで検査する修正。
   幾何式・許容差・既存期待値は変更なし。
3. 初稿後の改修としてnextafter境界6件、実際にhitする同距離group2件を追加。
   元1040件と旧groupはバイト列prefix不変をPythonテストで検査。
   J0で100物体/castと分かったため、速度を見る前に保存Worldの100件も追加。

この改修は通常の構造体・関数・配列で完了した。型診断でbatchの入力はVector{Query}、
出力はVector{Union{Nothing,Bool,Float64}}。動的なAnyの結果配列ではない。
M_B形成・関係網・多重ディスパッチによるRDL全体の実装適性は、今回の幾何試作では未検証。

## 準備後のカーネル時間

各言語3つの新process、交互順、1系列200標本。入力生成/検証は測定外。
両方とも新しい結果配列を返す。同じ状態を消費する更新はない。
表は**各系列の中央値、単位microseconds**。全標本は生JSONに保存。

| バッチ | Python 0 / 1 / 2 | Julia 0 / 1 / 2 | 系列中央値の中央値比 |
|---|---|---|---:|
| 23 合成 | 6.269 / 6.069 / 6.600 | 0.421 / 0.441 / 0.180 | 14.89倍 |
| 100 保存Worldのcast | 19.920 / 19.309 / 21.427 | 1.172 / 1.202 / 0.441 | 17.00倍 |
| 1024 拡大合成 | 347.305 / 340.731 / 355.563 | 21.828 / 22.444 / 8.082 | 15.91倍 |

Juliaの3系列目は他より速く、系列間ばらつきもある。最良値だけで代表させない。
保存Worldの100件は初期Aの位置・yawからの一回のcastであり、動作中の全観測分布ではない。
JuliaCall接続費用、全観測、World全体の速度は測っていない。

## 起動・整形・メモリ

新processの起動から最初の有効結果まで（秒）:

- Python: 0.090416 / 0.041899 / 0.043865
- Julia: 1.765379 / 1.731515 / 1.749225

これはJSON読込・検証・計測ライブラリのimport込みの**このハーネスの冷間時間**。
依存ダウンロード/インストールは含めない。最小Julia本体の起動時間とは呼ばない。

1146件の初回入力処理（3系列の範囲）:

| 処理 | Python秒 | Julia秒 |
|---|---:|---:|
| JSON parse | 0.004540–0.004691 | 0.187915–0.188487 |
| 型付き/参照入力への検証・整形 | 0.002031–0.002126 | 0.577879–0.619613 |
| 初回batch | 0.000395–0.000419 | 0.027236–0.046935 |

Juliaのこの初回値にはコンパイルが含まれる。常駐状態での整形時間やPythonとの
受け渡し時間は未計測。毎queryに新processを起動する方式には進まない。

同じLinux `/usr/bin/time -v` によるwarmハーネスの最大RSS:

- Python: 16,536 / 16,544 / 16,544 KiB
- Julia: 404,460 / 408,868 / 406,524 KiB

約24.6倍で、計画の暫定「2倍を超えたら無条件採用しない」に該当する。
これは実行系・コンパイラ・計測ツールを含み、kernelの配列だけのメモリではない。
Julia kernelの確保量は23/100/1024件で272/1040/9288 bytes、GC時間は全標本0。
Python tracemallocの別測定peakは296/912/8896 bytes。PythonのGC collectionsは0、
GC時間は未計測null。異なるメモリ測定器の値を性能比へ換算しない。

## 判定と停止位置

**J3の常駐・バッチ受け渡し試験へ進む材料はある。ただし採用は保留。**
局所速度は有望で、独立環境復元と追加改修も通った。一方、メモリ増加は暫定条件を
超えている。次に進むなら起動を償却する常駐方式、整形/往復費用、Worldプロセス全体の
RSSを測り、copy/履歴側も別の候補として検討する。J3はこの作業では実装・実行しない。

一つのkernelが約17倍でもGameAI全体が17倍になったとは言えない。
Juliaへの全面移行、H検索拡張、rho遷移、Sleep移植、1日/30日/90日運転は未実施。

## 生データと再現

ローカル取得先: `outputs/julia_migration/cloud-38215198325/run/`

- manifest.json / baseline_comparison.json / baseline-*/options.json と report.json
- profile/profile.pstats と profile.json
- correctness/correctness.json
- benchmark/*-warm.json（全標本、確保量、GC）、process_timings.json
- benchmark/*.resource.txt、*.warntype.txt、setup.txt、restore.txt

artifact `julia-migration-j0-j2` ZIP SHA-256:
`755054c2cf5333fa9dffb0b7b9be5687ea21547b65631c39e0450f3b7fdd4e05`。
クラウドartifactは14日保持、ダウンロード済み原本はoutputs内に保存。
fixtureとhash、ソース、lockfile、計測コマンドはリポに保存。
実施コマンドはmanifest・profile.json・process_timings.jsonとworkflowに残る。
