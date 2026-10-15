# LW 別PC再現試験（Linux / WSL2）

## 保存済みのクラウド90日試験

[2026-10-15の結果と再現手順](evidence/cloud_90d_20261015/README.md)：
90日・3個体・4,665,600操作を完走、既存検査473件PASS。
30日上限を実験コピーで90日に延長した試験。Aは途中停止後に活動再開、
Cは63〜90日目に拠点外で終日休息。全員の習慣化成立とは扱わない。
圧縮した全結果、入力、変更差分、進捗、日別H・行動集計を保存している。

## 30日診断の実行方法

30日・3個体・保存World・Julia 1.13.1・1 threadの診断用実行。
ソースは `5b09a58c3009f59044cc08d2a551f939a3fa7790` に固定。
呼出し元の作業ツリーではなく、出力内へgit archiveした独立コピーへ計測を追加する。
行動規則・係数・seed・日数は変更しない。Python3は実行前の計測挿入だけに使用する。

## 別PCのUbuntuで実行

Git、Python3、tar、Linux版Julia 1.13.1が必要。
Windows版julia.exeは使わない。リポジトリと出力はLinux側ホームに置く。

```bash
cd ~
git clone https://github.com/RDL-Labs/RDL_GameAI_Lab.git
cd RDL_GameAI_Lab
# インストールしたLinux版Juliaの絶対パスに合わせる
export JULIA_BIN="$HOME/tools/julia-1.13.1/bin/julia"
export HARDWARE_NOTE='別PC、電源/メモリ設定の変更内容をここに記録'
bash experiments/julia_migration/diagnostics/run_lw_progress.sh
```

既存cloneなら先に `git pull --ff-only`。完全な履歴を取得すること（固定コミットをarchiveする）。
依存関係はsetup.jlから導入。ネット接続が必要。自動再試行はしない。
出力先は `~/lw-bench/diagnostic-日時/`。第1引数で未使用の出力先を指定可能。

## 別ターミナルから確認

```bash
tail -n 8 ~/lw-bench/diagnostic-日時/progress.tsv
cat ~/lw-bench/diagnostic-日時/status.txt
```

- progress.tsv: シミュレーション60秒ごとの開始・観測開始・操作実行開始。
  Unix時刻、ループ開始後秒数、シミュレーション秒、1始まりの日、完了操作数、段階、プロセスpeak RSS bytes。
  毎回flush。操作の直前なので、末尾が故障地点そのものとは限らない。
  最終loop_complete行の日番号だけは終端境界のため31になる。
- memory.tsv: 実時間5秒ごとのLinux `/proc` RSS / 仮想サイズ / peak RSS（kB）。
- run.log: 検査結果とJuliaエラー。setup.log: 導入ログ。
- status.txt: 終了コードと壁時計時間。突然のOS停止ではrunningのまま残り得る。
- environment.txt / hardware-note.txt: 実行環境と申告設定。
- source/: 実際の固定ソース＋計測。instrumentation.patch: 計測差分。
- 完走時: result.json / summary.json、資源収支・日跨ぎ・操作数検査。

wall_secondsはsetupを除き、コンパイル・検査・出力・監視の最大約5秒の待ちを含む。
summaryのcall_secondsはシミュレーション呼出しの計測。両者を混同しない。
記録には少量の負荷があるため、計測なしとの厳密な速度比較用ではない。
失敗時も出力フォルダを保持し、status/run/progress/memoryをセットで比較する。

## 元PCでの事実

- WSL2 3日×2回: 完走、108.7秒 / 93.9秒、resultが一致。
- 30日（計測なし）: 195秒でsignal 11、辞書rehash。
- 最大プロセッサ状態99%申告後: 148秒でsignal 11、エラー表示中の型判定。
- 同設定・本計測付き: 395秒でsignal 11。末尾は189060秒（11日目）、567180操作、execution_begin。
  最終RSS約940MiB、peak約1.04GiB。元エラーは不明。

CPU/RAM/Juliaいずれの原因も未確定。別PCの成否だけで特定部品を断定しない。
