# 最新LW 30日・帰還調査

2026-10-21。GitHub mainと一致する `b260ff6de50640904ee3e8b8fced35a703d8d329`。
Julia 1.13.1 / Windows。Python、Luanti不使用。

## 結果（2026-10-22完了）

**30日完走。永久停止は観測しなかったが、連続方向移動ONでも帰還が数日長引く現象を再現。**
1日以上継続した帰還はA5件・B7件・C4件、計16件。すべて30日以内に完了した。
30日終了時には別の帰還が各個体に残り、その後の成否は今回の範囲外。

|個体|最長帰還（simulation日）|終了時の拠点距離（World単位）|終了時reserve|終了時の帰還継続日数|
|---|---:|---:|---:|---:|
|A|3.012|44.957|78.495|0.456|
|B|3.565|53.869|74.006|0.500|
|C|3.761|6.876|84.351|0.168|

全個体でreserve=0の日末、終日restの日は0。記録した帰還中のreserve<=0 tickも0。
30日末に全員が拠点外であることだけで永久帰還不能とは判定しない。
1,555,200操作、食料124+198=地面117+共有112+消費93、最終携行0。
安全16・Sleep観測4・統合4・日次/継続150、計174 assertions PASS。
帰還episodeの完了記録数と既存目的カウンターも全個体で一致。

### 具体例：Cの26〜30日目

- 帰還開始445892秒。最初の操作後距離は約1.500、reserve約89.225。
- この最初のサンプルはhome_visible=false、method=walk_-90。これは安全候補の命名経路であり、通常step_*の連続接近補正対象ではない。
- 64993tick（約3.761日）後、510885秒の観測で帰還目的が完了。
- 保存サンプルでは拠点から最大約33.177まで離れ、reserveは約13.526まで低下。その後補給し30日末は84.351。
- この区間の保存1091サンプルのうちhome_visible=trueは5。サンプリング間隔は一様でないため、時間割合として解釈しない。
- 最後のサンプルでも操作前home_visible=falseだが、操作後距離0.941へ到達。次tickで目的完了を確認。

コード上、local_descentは現在観測のtargetを必要とし、通常のstep_*歩行だけに適用する。
危険回避は帰還・食事・夜間方策より先に判断される。今回の長期帰還には
安全移動と、目標不可視時の探索・休息が併存する。角度量子化だけが残原因という証拠ではない。
安全解除、探索、休息それぞれの因果寄与はOFF/ON介入をしていないため未分離。
次の調査対象はこのCの区間における危険回避後の帰還再開と拠点の再捕捉。

### 過去記録との照合・実時間

旧クラウド90日試験の最初の30日と、全90個体日の位置・reserve・home H・10種類の
日別操作数が数値として完全一致。コード整理後も、この観測範囲の既存挙動を再現した。
これは完全な内部状態や全tickの旧新一致を主張するものではない。

日次進捗の12→13日と27→28日の間に実時間の大きな空白があり、
合計経過約33548秒を純粋な計算速度として使わない。中断原因はこの計測だけでは確定しない。
プロセスはexit0で終了し、試験中クラッシュなし。観測したpeak RSSは約1.264GB。

保存先: `outputs/return-30d-20261021/`。コンパクトな監査結果は[evidence](evidence/return_audit.json)、
[日別CSV](evidence/daily_return.csv)、[旧結果との照合](evidence/historical_comparison.json)。

## 固定条件

`experiments/julia_migration/lw_integrated/search_review_spec.json` をそのまま使用。
seed20261005、川沿い地形、3個体、30日、continuous_descent ON、parent_breadth ON。
身体、混合危険物、地形抵抗/履歴、共有在庫、3日周期の資源再生、経路、記憶、Sleep、社会応答を有効化。
1日17,280 simulation seconds、合計1,555,200個体操作。
CLIの最小既定構成とは異なる、過去の30/90日調査と同じ合成設定である。

## 観測方法

srcとnative入口を出力先へコピーし、身体更新直後に読み取り専用の記録を挿入。
係数、角度、身体、判断、時刻、資源配置は変更しない。コピーと変更前後ハッシュを保存。

- 帰還目的ごとに開始時刻、継続tick、最小距離、reserveが0以下のtick数、完了/未完了を記録。
- 60tickごと、または帰還中に拠点から3以内のとき、位置・身体・行動・home H・現在home観測有無を保存。
- 各日末に操作数、身体、帰還目的、共有在庫、経過実時間をflush。
- 完走後、終了時刻、食料保存、有限身体値、日次操作数、日跨ぎ状態一致を検査。

距離は実験者側のWorld座標から計算し、AIには渡さない。
サンプルの位置・距離・身体は操作後、home_visibleは同じtickの操作前観測。
最短距離は全tickで測るが、連続移動中の線分上最小距離ではない。
完了は既存return_purposeが解除したこと。荷下ろし成功便数や新規の独立課題数ではない。
夜間の拠点付近からの離脱/再到着でも短い目的が繰り返されるため、完了回数だけを効率指標にしない。
日末の未完了だけで永久停止とせず、後の再開、継続期間、エネルギー切れを区別する。
記録処理の時間を含む実験で、純粋な性能ベンチマークではない。

## 再実行

```powershell
$env:JULIA_DEPOT_PATH='C:\Users\ken_m\Documents\Codex\tools\julia-depot'
& 'C:\Users\ken_m\Documents\Codex\tools\julia-1.13.1\bin\julia.exe' --startup-file=no --project=. experiments/return_30d/run.jl outputs/return-30d-new
./experiments/return_30d/analyze.ps1 -OutputPath outputs/return-30d-new
```

出力先は未使用パス必須。日次進捗はprogress.jsonl、全結果はrun/result.json、
帰還episodeはreturn_episodes.jsonl、観測標本はreturn_samples.jsonl。
監査後のdaily_return.csv / return_audit.jsonには日別経過と長引いた帰還を保存する。
