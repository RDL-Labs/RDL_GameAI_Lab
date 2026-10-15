# 数値CPU版：兎30体＋捕食者1体

既存 `../herbivore-cpu` を残した独立実験。Juliaで同じ地形・初期位置・大量の草を使い、3日（51,840 tick）実行。状態はUInt8、座標・身体状態は数値、対象は整数添字。文字列はログと入出力に使用。MB・深い記憶・繁殖・GPUは未実装。

## 結果

| 条件 | 生存 | 捕食 | エネルギー切れ死亡 | 攻撃回数 |
|---|---:|---:|---:|---:|
| 捕食者なし、seed 20261005 | 30 | 0 | 0 | 0 |
| 捕食者あり、seed 20261005 | 27 | 3 | 0 | 26 |
| 捕食者あり、seed 20261006 | 28 | 2 | 0 | 63 |
| 捕食者あり、seed 20261007 | 24 | 3 | 3 | 28 |

基準ケースの生存数は1日目29、2日目28、3日目27。基準seedの再実行はresult.jsonがバイト単位で一致。対照条件は旧herbivore-cpuの摂食量・日別状態時間・最終位置と一致。

同一Juliaプロセスで対照→捕食→再実行→別seed2本の順。初回対照の計測区間はコンパイル込み2.149秒、捕食試行は0.177〜0.228秒。プロセス最大RSSは約317 MB。Julia起動・モジュール読み込みは計測区間外。旧MBモデルとの速度比較には使えない。

## 今回の仮ルール

- 捕食者：探索→追跡→突進→回復／捕食後の休息。
- 視認は岩で遮られる。草の残量比で捕食者の視認距離が16から約8.9へ短くなる。兎側は従来の距離10・障害物チェック。
- 見失った位置は20 tickのみ保持。見えない獲物の現在位置は追跡判断に使わない。
- 探索速度0.22、追跡0.5、兎の逃走0.6、突進1.0 world unit/tick。
- 追跡上限60 tick。距離2.5以内で方向固定の3 tick突進。失敗／追跡打切り後120 tick停止。
- 突進移動線分と兎半径0.55の接触を判定。1攻撃につき1回だけ結果を解決。逃走状態かつ外向きの方向なら成功率28%、それ以外78%。兎の実移動速度までは成功率に反映しない。
- 捕食成功後8,640 tick（このモデルの半日）停止。捕食者の空腹・代謝・死亡はまだモデル化せず、この時計で狩りの頻度を制限している。
- 兎は障害物で逃げ道が塞がれた場合、通行可能な候補のうち脅威から最も遠い一歩を選ぶ。
- 兎のエネルギーが0になれば死亡。捕食と別イベントに記録。死亡個体は以降の摂食・移動・身体更新を停止。
- 各tickは捕食者の知覚／計画→兎の知覚／移動→捕食者の移動／接触→エネルギー死判定。完全な連続時間・同時物理解決ではない。
- 捕食者の初期位置は固定基準点(-8,6)に近い通行可能セル。獲物の現在位置を使って配置しない。

値はゲーム実験用で、実在動物の生理値ではない。半日休息により捕食数が強く制約されるので、今回の少ない捕食数を自然な個体数均衡とは評価しない。

seed 20261007では3体が南端付近(z≈-57)でエネルギー切れ。移動距離は各約1,600で、単純な完全停止ではない。局所的な採食探索と逃走後の移動の詳細分析が次の課題。繁殖なしのため長期個体数維持も未検証。

## 検証・再実行

`run.jl` は5条件を実行し、各フォルダにresult.json、metrics.json、trajectory.csvを保存する。trajectoryのid=0は捕食者。対照条件のid=0は無効な固定プレースホルダー。

```powershell
$env:JULIA_DEPOT_PATH='C:\Users\ken_m\Documents\Codex\tools\julia-depot'
& 'C:\Users\ken_m\Documents\Codex\tools\julia-1.13.1\bin\julia.exe' --project=outputs/numeric-cpu/source/julia outputs/predator-cpu/run.jl
& 'C:\Users\ken_m\Documents\Codex\tools\julia-1.13.1\bin\julia.exe' --project=outputs/numeric-cpu/source/julia outputs/predator-cpu/checks.jl
& 'C:\Users\ken_m\Documents\Codex\tools\julia-1.13.1\bin\julia.exe' --project=outputs/numeric-cpu/source/julia outputs/predator-cpu/predator_checks.jl
```

21項目の既存草食動物チェック、12項目の捕食者チェック、4項目の対照一致チェックが成功。実行中にも草・摂食の保存則、捕食回数と死亡数、攻撃結果の整合性、地形内の最終位置を検証。

設計参照：[RDL Living Field README](https://github.com/HermannDegner/RDL_Demos/blob/main/demos/relational-ecology-lab/README.md)、[core.mjs](https://github.com/HermannDegner/RDL_Demos/blob/main/demos/relational-ecology-lab/core.mjs)。外部ソースをコピーせず、限定知覚・攻撃と回復の区分をこちらのJulia状態機械で実装。元デモの学習系やCore理論の実装ではない。
