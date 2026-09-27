# Luanti L10 — sensory learning to M_B-informed action Evidence

2026-09-27 / IMPLEMENTED / PASS。
[契約](../experiment-contracts/LUANTI_L10_sensory_learning_action_contract.md)。基準commit `7f7ed83`。

## 実機結果

実Luanti 5.17.0＋HTTP Runtimeで、独立3run・各12Episode、計36Episodeを実行。
各runの1〜6を形成、7〜8を独立検査、9〜10を同条件での行動確認、11〜12を条件反転に使用した。
各Episodeの開始時に同じ位置・姿勢・身体・Food・Base stockへ戻す。学習runではRuntime材料を保持する。
同runで近景・遠景・聴覚を各12frame、計36frame受理。3run合計108frame、拒否0。
聴覚窓の取得は含むが、聴覚による学習や行動起動はこの試験の主張ではない。

| 条件 | E9 赤 | E10 暗灰 | E11 赤・通路変更後 | E12 暗灰・通路変更後 |
| --- | --- | --- | --- | --- |
| M_B更新を反映しない | 試行→失敗 | 試行→取得・帰還 | 試行→取得・帰還 | 試行→失敗 |
| M_B更新を反映する | 保留 | 試行→取得・帰還 | 保留・未試行 | 試行→失敗、比較差-1 |
| 色と結果を逆にして学習・反映 | 試行→取得・帰還 | 保留 | 試行→失敗、比較差-1 | 保留・未試行 |

| run | 総試行数 | 総deposit | canonical cutover |
| --- | ---: | ---: | ---: |
| 反映なし | 12 | 6 | 0 |
| 反映あり | 10 | 5 | 1 |
| 逆対応・反映あり | 10 | 5 | 1 |

反映なしでも同じ固定規則でCandidateを形成・検査し、inactive M_B'を再構成する。
違いは明示activationの有無。独立runなのでrun/event/frame IDと実取得時刻は異なり、
Experienceのバイト同一性は主張しない。通常対応の二群で、形成・検査の色条件と実結果系列は同じ。

保留はWorldへ身体作用を出さず、位置不変、action数0、取得結果null、Experienceなし。
通常の壁あり試行は接近2stepで停止。壁なしでは7stepで取得・帰還し、Food entity除去、
保持状態の変更、Base stock 0→1を確認した。
色名の意味は固定規則に含めず、逆対応runでは予測・保留する色が逆転する。

これは**行動差の成立**であり、成功率の単純な向上ではない。
条件変更後、以前の失敗条件を保留した個体は、新しく成功できたはずの条件を試さず、
反映なし側よりdepositが1件少ない。その未試行を反証・失敗・成功確認として数えない。
成功予測で試した条件が破れた場合は、新たな失敗Experienceと同一M_BでのF/F'差を保持する。
反例から二度目の再編を起動する処理は今回追加していない。

## 経路と権限

受理済み遠景frameの特徴を断面へ取得し、`FrozenGameAIMB.interpret_sensory_food()`で予測する。
採用relationは既存T1-A/B/Cから再構成artifactへ入り、active registryのモデルだけをconsumerが使う。
初期M_Bは未知を返し、固定の有限探索規則で試行する。観測色を成功／失敗へ直結したif規則ではない。

学習を起動する時点、形成・検査の集合、独立canonical reviewと切替はharnessが明示する。
count比較の未吸収判定は実験用の明示reviewであり、取得失敗や候補支持数からHを自動生成していない。
旧count解釈と今回の補助感覚境界の比較は別に保持する。

全12操作で同一決定要求を再送し、Runtime応答の完全一致を確認。
返った二つの応答をLua台帳へ渡し、権限消費は1回、二度目は拒否する。
ネットワーク切断やprocess再起動をまたぐ一回実行保証ではない。

## 再実行

```powershell
& .\integrations\luanti\scripts\test-sensory-learning.ps1
& .\integrations\luanti\scripts\test-sensory-learning.ps1 -Activate $false
& .\integrations\luanti\scripts\test-sensory-learning.ps1 -Reverse $true
$env:PYTHONPATH = 'tests'
python -m unittest test_sensory_food_learning -v
python -m unittest discover -s tests
& .\integrations\luanti\scripts\test-observation-v1.ps1 -Scenario faults
& .\integrations\luanti\scripts\test-l7.ps1
```

最終実機snapshot（ignored output内）:

- `l10-20260927-032003-843.snapshot.json`：反映あり
- `l10-20260927-032015-538.snapshot.json`：反映なし
- `l10-20260927-032028-542.snapshot.json`：逆対応・反映あり

[同梱replay](../../tests/fixtures/luanti_l10_replay.json)は、この3snapshotから受理済みframe、
決定要求、結果事実、Worldの実行記録を抽出したもの。元ファイル名・SHA256を保持する。
試験はframeをstoreへ再受理し、元frameとの全項目一致を確認してから、T1再構成と行動選択を再実行する。
再配送時だけstore追加のrun/epochをenvelopeへ戻す。特徴・取得時刻は変更しない。
canonical reviewの比較窓はreplayで作り直すため、元のT1 bundle IDの完全再現を主張しない。

## テスト結果

- L10専用 **19 PASS**。3実機runの記録再生を含む。
- 全体 **578件実行 = 527 PASS + 51 optional/opt-in skip**。
- 実Luanti OBS-9 faults: **PASS**。108frame、再観測、A/B生活完了。
- 実Luanti L7: **PASS**。旧relation3件、model cutover、REENTERED。

専用試験は、形成／検査分離、逆対応、対照、保留と失敗の分離、親モデル保存、
更新後も古い決定には古いM_Bを使用、未知・取得不完了・鮮度、改変再送、同event/同frameの再利用、
容量と再送、モデル不一致比較拒否を検査する。
経験ledgerが空の新consumerでもactive M_Bから同じ予測・行動を得ることを確認し、
判断が履歴カウンターの参照で代用されていないことを検査する。

今回の実機は単一個体の有限fixture。OBS-9の継続A/B生活＋Probeへ新しい学習を常設統合した試験ではない。
NERV/SOC、自律Sleep・注意・review、一般Goal/Trajectory、長期学習、p5新表示は範囲外。
Godot実機・ブラウザーは今回再実行していない。
