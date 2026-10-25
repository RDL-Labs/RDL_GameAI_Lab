# 確率的なMB対応付け・鮮度撤廃：3日動作試験

2026-10-25。[設計](../../docs/design/LW_Probabilistic_MB_Recognition.md)。初日見回し＋備蓄12食、続く2日通常行動。地形・seed・設定は直前の備蓄あり10日試験と同じで、入力差は日数だけ。今回は認識方式、1特徴観測の保持、鮮度制限、容量整理を同時に変更しており、各変更の効果を個別に識別する比較ではない。

## 動作結果

3日正常完走、190.37秒（約3分10秒、コンパイル込み）、ピークRSS約1.37GB。短い検査を並行実行しており厳密な性能比較ではない。全員全日末エネルギー>0。

| 個体 | MB経路選択（睡眠 / 成功まとまり / 詳細探索） | まとまり形成 | 不一致 / unknown | 最終reserve | 外からの再入場 |
| --- | ---: | ---: | ---: | ---: | ---: |
| A | 8（2 / 6 / 0） | 1 | 2 / 6 | 91.85 | 1 |
| B | 105（5 / 99 / 1） | 2 | 1 / 104 | 90.63 | 1 |
| C | 21（4 / 16 / 1） | 2 | 0 / 21 | 90.55 | 0 |

合計134回選択。以前0だった睡眠経路の実選択が11回、成功したまとまりからの選択が121回発生した。成功まとまりは5件（food3・home2）、実際の目的H解消から総報酬22を付与した。すべて初回成功の仮まとまりで、反復成功による定着はこの試験では未確認。

homeの2件は2日目、最初の外出より前に拠点内で形成されたもの。外から戻る長距離の帰還経路を学習した証拠とはしない。帰還目的カウンタはA3/B2/C2だが、入口を外→内に通った回数はA1/B1/C0であり区別する。

**選択した経路が正しかったと確認できた回数は0。** 共通特徴2個以上による次観測との照合では不一致3、unknown131。一つの特徴だけの観測は候補化には使うが、認識正解の強い証拠にはしない。実環境で不一致の学習記録は得られた一方、認識精度や安定帰還の改善は未証明。実行失敗の分離は単体検査で確認し、この実配置での対象選択では0件だった。

初日末の接続は、旧方式の各1辺からA26/B24/C18辺へ増えた。ノードは旧A4/B6/C5からA7/B9/C8。有効観測はA2215→14961、B3294→13395、C909→14853。同じ初日の見回し行動から、以前捨てていた1特徴の観測を保持できた。

食料は初期88＝消費12＋地上64＋共有倉庫8＋携行4。倉庫搬入11・取り出し3。初日備蓄は終端で全地点0。初日入口通過0、翌日以降の通常歩行を監査済み。

## 失敗理由と限界

候補化阻害の集計を追加した。今回も目的不一致、目標ラベルが現状で支持されない、現在観測なし、最初の動作が実行不能などで除外されている。これらのカウンタは仮説×対応付けの組を調べた回数を含み、tick数や独立した失敗経験数とは異なる。

認識・経路の不一致は原因を確定せず対応付けと辺の評価へ反映し、実行失敗とは別に保存する。間違いを許すことは、仮に対応したノードへ実観測を接ぎ替えることではない。0特徴区間の追跡、拠点全体の構造、多階層ρ、目標ラベル上書きは残る課題。

容量整理はこの試験では上限に達していないため削除不要。睡眠時だけの整理、上限での覚醒中新規登録抑制は別の検査で確認した。

## 検証

新規対応付け27、既存MB・睡眠46、まとまり24、実配置69、計166項目PASS。新規検査は非一致キーからの候補生成、間違いによる重み・選択確率低下、一致による回復、blockedと認識誤りの分離、1特徴のunknown、実観測ノードの非混同、100日経過後の利用、睡眠でのみ容量整理することを含む。追加監査で食料・地図・初日観察・結果照合の整合を確認。

```powershell
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_recognition_checks.jl
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_sleep_checks.jl
julia --startup-file=no --project=. experiments/julia_migration/lw_integrated/mb_chunk_checks.jl
julia --startup-file=no --project=. experiments/rock_gate/run.jl outputs/probabilistic-mb-3d-20261025 --narrow-only --days 3 --rho coarse --rho-openings on --food-roads on --general-landmarks on --body-purpose on --mb-simulation on --mb-chunks on --mb-sleep on --home-observation on --camp-provisions 4
```

証拠：[認識と初日の比較](evidence/probabilistic-mb-three-day/recognition-audit.json)、[対応付け・候補・結果記録](evidence/probabilistic-mb-three-day/map-audit.json)、[日別集計](evidence/probabilistic-mb-three-day/summary.json)、[manifest](evidence/probabilistic-mb-three-day/manifest.json)、[provenance](evidence/probabilistic-mb-three-day/provenance.json)。開始時コミットは親を示し、変更済み実行ソースはmanifestで識別する。実行後はmb_sleep.jlのコメントだけを整えた。
