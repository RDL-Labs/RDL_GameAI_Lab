# 同じ3日目の特徴照合再利用実験

2026-11-26。開始HEAD 97bfe04。元実験はhuman-retired-rest-inertia10-20261126、
凍結ソースe1b9df0。元checkpoint/sourceには変更せず、実験プロセス内で照合関数のみ置換。

## 変更範囲

`recognition_fit_workspace.jl`は同一個体・同一時刻・同一frame・同一有効metric重みで
特徴照合の結果を共有する実験。ノードの差替え・signature変更・特徴辞書の差替えも検出。
返すのはimmutableなconfidenceとanchorだけ。差の配列や候補辞書は共有しない。
未知のnothingも保存できる。

目的別の対象列挙、support、H、順位・打切り、usable、確率、照合統計は毎回処理する。
IdDictの作業領域は実験側にのみ存在し、保存・学習状態に入らず、再実行ごとにclearする。
通常コードへの採用済み実装ではない。

現実装のmb_scene/ノードfeaturesはsignatureから作る読み取り専用の派生特徴。
将来その辞書を直接書き換える処理を追加する場合は、明示的な無効化かrevision管理が必要。
今回の実験は、任意の外部コードによる特徴辞書の破壊的変更まで安全に検出する汎用キャッシュ
ではない。長期実装にする際は作業領域の寿命管理も別途必要。

## 局所検査

`recognition_fit_workspace_checks.jl ROOT`：18項目PASS。
4用途×2種類のHで返却候補が一致し、認識統計を含む状態も一致。
未知、重み更新、時刻更新、anchor変更、ノード差替え、保存対象からの独立も検査。

## 比較条件

`benchmark_recognition_reuse.jl ROOT 3 OUTPUT`。Julia 1.13.1、1スレッド。
前後それぞれ512 tickウォームアップし、2日末保存状態を読み直して変更前→変更後を直列実行。
CPUサンプリング、重複入力のコピー照合、毎tick診断ログは付けない。
tick開始〜日末保存と保存単独の実時間、および呼出し全体の割当・GC・コンパイルを記録。
512 tickでコンパイルが完了する保証はなく、順序効果を含むため単発の差を一般化しない。

日末checkpointのstate全フィールドを再帰的に比較する。保存されたRNGも対象。
オブジェクトの別名共有の構造自体は比較しない。派生作業領域はcheckpoint外。

出力: `C:/Users/ken_m/Documents/Codex/recognition-cache-compare-day3-20261126`。

## 初回（変更前→変更後）

| 指標 | 変更前 | 再利用あり |
| --- | ---: | ---: |
| 呼出し全体 | 405.764秒 | 340.077秒 |
| tick＋保存 | 356.666秒 | 339.318秒 |
| 保存のみ | 3.319秒 | 0.988秒 |
| tick、保存除外 | 353.347秒 | 338.330秒 |
| 累積割当 | 74.450 GB | 69.726 GB |
| GC | 12.739秒 | 11.571秒 |
| コンパイル（呼出し全体） | 59.321秒 | 0秒 |

保存除外で4.25%短縮。ただし初回コンパイルが前条件にだけ含まれ、保存単独にも
初回費用差が見える。高速化率として確定しない。全checkpoint stateの再帰比較PASS、
差分0。MB・行動・身体・資源・保存済みRNGを含む。別名共有構造は未比較。
原本 `recognition_cache_day3_forward.json`。

順序確認として `benchmark_recognition_reuse_reverse.jl` で変更後→変更前を追加実行する。
出力 `C:/Users/ken_m/Documents/Codex/recognition-cache-reverse-day3-20261126`。
