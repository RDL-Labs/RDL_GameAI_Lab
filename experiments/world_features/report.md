# 世界特徴の導入と有限確認

2026-10-26。[設計・実装範囲](../../docs/design/World_Color_Size_Patches.md)。

木・岩の固定した色/寸法差、木に関連する既存食料サイトの初期量差、草群落の色/高さ/密度を導入。草の採食と回復が同じ状態から食料・遮蔽を変える。

専用31項目、既存草食21項目、捕食者16項目PASS。生成の再現性、異seed差、半径/色の個体差、実サイト関連、光源属性保持、群落の保持数、草の採食と回復・保存則、体格と遮蔽、実際の捕食者可視判定、観測からの世界ID除外を検査した。

- 兎30体・捕食者なし3日: 飢餓0、最終最低エネルギー83.11、平均84.51。食料/消化/操作数の保存則を実行時assertで確認。計測2.64秒（コンパイル込み）、ピークRSS約320MB。既存版との性能比較ではない。
- 方向視覚・動態視覚・捕食者あり3日: 生存27、捕食3、飢餓0、攻撃15回。動作確認であり、遮蔽による生存改善の比較結果ではない。
- LW rich-riparian 1日: 正常完走、初期食料145、消費5、地面124。所要35.96秒。草食生態系とは別の実行系。

実行（Julia --startup-file=no --project=.）:

    experiments/world_features/checks.jl
    experiments/world_features/run.jl outputs/new-rich-herbivores
    experiments/world_features/predator_run.jl outputs/new-rich-predators.json
    experiments/julia_migration/lw_integrated/native.jl outputs/new-rich-lw --layout rich-riparian --days 1 --seed 20261005 --ground patches --low-obstacles on --skyline subrays

[兎結果](evidence/herbivores.json)、[捕食結果](evidence/predators.json)、[LW manifest](evidence/lw-manifest.json)、[専用検査](evidence/checks.txt)。初回実行後に光源などの追加属性保持・未知色コードの扱いを補強し、専用検査を再実行。manifestは当該LW実行時点のソースを示す。
