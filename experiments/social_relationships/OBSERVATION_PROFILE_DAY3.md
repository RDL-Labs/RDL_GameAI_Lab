# 同じ3日目の全体CPU調査

2026-11-26。調査開始HEAD 844df15。対象実験は
`C:/Users/ken_m/Documents/Codex/human-retired-rest-inertia10-20261126`、凍結ソースe1b9df0。
人間4体、動物なし。設定・判断・観測頻度・乱数消費の変更なし。
出力は `C:/Users/ken_m/Documents/Codex/observation-profile-day3-20261126`。

## 方法

`profile_observation_day.jl ROOT 3 OUTPUT`。2日末checkpointから512 tickを
ウォームアップし、同じcheckpointを読み直して3日目を実行。
Julia 1.13.1、1スレッド、Profileの5ms間隔CPUサンプリング。
サンプリング範囲は最初のtickから日末checkpoint保存完了まで。
復元と最終返却処理は呼出し全時間・割当には含むが、CPUサンプル範囲からは除外。
512 tickで全経路のコンパイルが済むわけではなく、実測呼出しにもコンパイルが残る。

`summarize_observation_profile.jl OUTPUT`でスタックごとの関数名重複を除去して集計。
62,388スタック。割合は子呼出しを含むサンプル占有率であり、関数の正確な時間や
呼出し回数ではない。親子の行は加算不可。通常の実行との速度比較ではなく単発診断。

## 実時間と割当

| 指標 | 値 |
| --- | ---: |
| run_integrated呼出し全体 | 423.588秒 |
| tick開始〜日末保存終了 | 374.779秒 |
| checkpoint保存 | 3.499秒 |
| tick開始〜保存前（差分） | 371.279秒 |
| 呼出し全体のコンパイル | 59.910秒 |
| 呼出し全体のGC | 13.734秒 |
| 呼出し全体の累積割当 | 73.812 GB |

割当は全体量のみ。関数別割当の内訳は未計測。前回の取引計測475.47秒とは
ウォームアップ・計測範囲・計測処理が異なり、今回の数値を高速化の効果とはしない。

## 重い処理

| 関数 | サンプル割合 | 内容 |
| --- | ---: | --- |
| mb_correspondences | 18.21% | 現在場面と記憶場面の照合 |
| mb_chunk_candidates! | 8.40% | 記憶経路から候補を作る |
| mb_exploration_project! | 7.61% | 外出時の関係を帰還候補へ反映 |
| mb_goal_cue_project! | 7.45% | 目的との関係を目印候補へ反映 |
| mb_similarity | 7.01% | 特徴の共通部分・角度・距離帯の比較 |
| mb_simulate! | 4.21% | 記憶経路の探索・候補生成 |
| mb_search | 3.99% | 上記の経路探索 |
| mb_observe! | 3.33% | 観測から記憶場面を更新 |
| cue_candidates! | 3.11% | 目印候補生成 |
| rho_observed_map! | 2.61% | 地形の構造化 |
| observed_cues | 2.57% | 観測された手がかりの構築 |
| movement_observation | 2.14% | 移動の観測・予測 |
| skyline_fan | 1.52% | 遠景観測 |
| mb_return_outlook! | 0.96% | 帰還見通し |
| landmark_fan | 0.55% | 目印観測 |
| item_attention_view! | 0.44% | 物品への注意判定・必要時の詳細観測 |
| item_visible | 0.12% | 詳細物品観測（上の行に内包） |
| item_social_plan! | 0.07% | 取引候補評価 |

候補構築4関数（chunk/exploration/goal_cue/simulate）のいずれかを含む
スタックは重複を除いて27.68%。mb_correspondencesの18.21%をこれに足さない。
照合を呼ぶ文脈は探索関係6.54%、目的目印5.82%、記憶経路4.81%、simulate0.32%
（いずれも全サンプル比）。

地形・目印の観測7関数（rho_observed_map!/observed_cues/movement_observation/
skyline_fan/landmark_fan/light_fan/ground_appearance）の和集合は10.07%。
これは指定した関数群であり、観測から派生する記憶更新まで含む全観測費用ではない。
物品観測2関数の和集合は0.44%。取引前の観測を含めても、今回の主因ではない。

## 次の候補と制約

優先は照合の内部。mb_similarityは毎回共通キーの集合・整列、距離帯辞書、
差の配列を作る。mb_correspondencesは複数の目的別呼出しから使われ、対象の
列挙・順位付けや対応辞書も作る。プロファイルはここに費用が集まることを示すが、
同じ場面ペアの計算重複率そのものはまだ測っていない。

次は同一判断中の場面ペア・特徴計算の重複を測り、共通材料の再利用を検討する。
目的ごとの対象集合、関係の強さ、H、usable判定、照合統計は異なるため、
照合結果全体を無条件に共有しない。記憶・特徴・学習重みの変更も無効化条件になる。
候補構築の索引作成やmb_searchの辺評価も次点。観測頻度の変更は今回の調査とは分ける。

元3日末checkpointとのdaily全体・物品countsのJSON正規化比較は2項目PASS。
全内部状態・RNGの完全比較は未実施。通常実装の変更なし。
計測値は `observation_profile_day3_metrics.json`、集計は
`observation_profile_day3_samples.json`。生のスタックとflat/treeは上記ローカル出力に保持。
