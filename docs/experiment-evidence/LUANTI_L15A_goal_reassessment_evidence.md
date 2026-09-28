# L15A — 目標再評価と内部参照の分離比較

2026-09-28、基準 `b14f834`。[契約](../experiment-contracts/LUANTI_L15A_goal_reassessment_contract.md)。

## 実Luanti

8run、24個体run、1536通常観測。全runで同じ草地・seed・3個体steady・16秒。
slot23にAの頭上へ実障害、除去条件では27に除去。身体側の実blocked・wait・結果受付を維持した。
存続4runに続き除去4runを追加で固定。provenanceへ順序を記録している。

| World | 再評価 | 内部参照 | Aの追加選択 | Bの追加選択 | A実移動距離 | B実移動距離 |
| --- | --- | --- | --- | --- | ---: | ---: |
| 存続 | disabled | disabled | なし | なし | 10.414 | 7.414 |
| 存続 | disabled | enabled | なし | なし | 10.414 | 7.414 |
| 存続 | enabled | disabled | 候補なし | -15度 | 10.414 | 12.414 |
| 存続 | enabled | enabled | 候補なし | -15度 | 10.414 | 12.414 |
| 除去 | disabled | disabled | なし | なし | 10.414 | 7.414 |
| 除去 | disabled | enabled | なし | なし | 10.414 | 7.414 |
| 除去 | enabled | disabled | +45度 | -15度 | 17.414 | 28.071 |
| 除去 | enabled | enabled | +45度 | -15度 | 17.414 | 28.071 |

角度は選択直後の指令。全6件で実身体結果turnedを確認し、その後の移動も記録した。
Cは全条件で再評価起動0、距離9.828。全条件・全個体で採取0。
追加選択6件は独立した成功学習6件ではない。同じ条件の比較であり、到達や採取成功を示さない。

存続Aは元目標と同色の候補と、幅が広すぎる障害特徴しかなく、1回の検討枠を消費して待機。
除去Aは現在観測の別色特徴を候補にでき、slot28のwaitから+45度旋回へ変化した。
Bはslot29で-15度を選択した。個体別の記録・枠は共有しない。
休憩やFoodへの優先処理、後続の再停滞は既存規則に従い、目標の無制限リセットはしない。

## 原因の分離

本条件で確認した行動差は再評価権限の有無によるもの。
enabledの実記録を、内部参照だけdisabledへ変更したRuntimeで完全な同一wire入力として再生し、
全observe指令と学習stateが一致した。内部参照の効果がゼロという一般命題ではなく、この有限記録での結果。
記憶costで候補順位が変わる正例は合成Python試験のみ。

従って、実Worldでの記憶による地形寄与、記憶による候補順位変更、探索効率・採取改善は未成立。
「追加選択して実移動できた」と「正しい目標や経路を学習した」を区別する。

## 検証

全8runのHTTP wire、最終Runtime state、観測・身体・stock・有限休憩を再生検査。
各個体各期間の検討1回、現在観測への出典、旧8目標予算を保持した追加1枠を監査した。
実受理履歴の再評価直前までを再生して、同時再送8回・入力競合・失敗受付での非消費・他個体非介入を検査。
候補なし、同点、pickup優先、固定設定競合、disabledの旧経路同等性も検査する。
新しい条件でのネットワーク応答消失注入は未実施。既存の重複操作・他個体guardは継続。

専用10テストPASS（6.737秒）、関連回帰89テストPASS（33.798秒）、各exit code 0。
回帰は障害比較・再活性化・有限休憩・反復・履歴診断・steering・terrain接続。
リポジトリ全体テストは今回未実施。

成果物: `tests/fixtures/luanti_l15a_goal_reassessment.json.gz`。

```powershell
python -m integrations.luanti.tests.run_goal_reassessment --output tests/fixtures/luanti_l15a_goal_reassessment.json.gz
python -m unittest discover -s tests -p test_goal_reassessment.py
```

次は、再評価後に何が観測され、なぜ次の停止や選択へ至ったかを確認する段階。
係数変更で成果を作る前に、現在の固定候補規則と本人の学習モデルが担う役割を分ける。
