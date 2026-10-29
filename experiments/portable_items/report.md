# 汎用的な落ち物の配置・携行・譲渡・交換

2026-10-30。Julia / 世界側の操作と接続検査。基準コミット`4c40007`。

地面にある独立物を、品目の専用コードを増やさずに扱えるようにした。光る石・貝殻・羽は初期属性の3種類。新しい正整数kindを`loose_items`へ配置し、`item_kinds`または物体側に属性を記載すれば、同じ拾得・保管・譲渡・交換操作が使える。旧入力名`portable_items`も維持する。

取得の可否は距離・遮蔽・所在・身体状態・大きさ・合計携行質量で決まる。初期枠は非食料の合計mass=5、単品size=1で、傷害は質量枠を下げる。食料側の既存運搬計算は別。交換は双方の最終携行状態と資源を検査してから一括移転する。

「価値をまだ実装していない」と「価値がないと学習した」は異なる。今回は好み・収集動機・交換の主体的評価を追加していない。地形の岩や立木を独立した落ち物へ変える採取工程も対象外。設計と制約は[仕様](../../docs/design/LW_Portable_Items.md)を参照。

## 世界操作とLW接続

| 検査 | 結果 | 確認内容 |
|---|---:|---|
| `checks.jl` | 251 PASS | 所有・有限資源・観測範囲・再送・期限・身体状態・一般kind・携行容量・原子的交換・シリアライズ |
| `integration_checks.jl` | 29 PASS | 実際のLW tickで操作、食料成功への誤加算防止、品目のデータ追加、日末からの同一再開 |

取得済み出力を[evidence/checks.txt](evidence/checks.txt)と[evidence/integration.txt](evidence/integration.txt)へ保存した。既存の層依存597、食料世界操作232、食料交換方策74、LW方策5の検査もPASSした。

操作検査は`configured_item_actions`という明示的な設定経路。10秒の短い日×2日で全操作と日末保存を検査しており、通常の2日行動実験ではない。拾う・保管・取り出す・譲る・置く・品物と食料の交換・品物同士の交換・拒否を通した。提案が未決の状態で日末保存し、翌日の受諾後の全結果が連続実行と一致した。

新しい木片kind=4242も、コードの種類分岐なしに拾得→譲渡→保管→果実との交換を通した。容量検査は単体の過大なサイズ／質量、荷の合計、傷害、譲渡先の満載、満載同士の等質量交換、片側だけ容量不足の交換、過大物の倉庫間交換を含む。物の総数・所有権・食料量に部分移転や二重適用がないことを検査した。

物体操作の結果には`item_`を付け、食料取得として目的達成・報酬へ混入させない。操作中は既存の親MBと経路を休止・保持する。身体維持などの既存候補が優先されると設定操作は実行されず、勝手に後の時刻へ延期しない。

## 通常時間の配置接続試験

実行条件は既存の`outputs/social-unified-30d-20261029/input.json`を基に、日数と9個の落ち物だけを変更した。入力・ソース・日末チェックポイントを`outputs/loose-items-1d-20261030/`に保存した。再実行用の入力は[evidence/placement-input.json](evidence/placement-input.json)、集計と実行ソースのハッシュは[evidence/placement-summary.json](evidence/placement-summary.json)に保存した。

- 日数1、世界seed=20261007、3個体、感度A=0.5／B=1／C=1。
- 兎30体、既存の食料配置・個人保管・加工・食料交換・関係学習を維持。
- 全体の食料モードはrenewableだが、全17地点がrenewable=falseのため、人用食料は有限・補充なし。危険off、夜間恐怖on。
- 拠点周囲の障害・水域・食料位置を避け、光る石・貝殻・羽を各3個配置。
- 設定拾得0、収集報酬未設定、自律拾得候補未接続。通常の物体操作件数は0の想定。
- 標準時計は1日17,280 tick、各tickはモデル内1秒。短縮した操作検査の時計とは異なる。

この試験は接続と資源保存を確認するもの。嗜好・交換の自律発生・長期効果・性能差の評価には使用しない。光る物は通常の目印観測にも入るため、「収集しない」ことは「既存の移動に全く影響しない」ことを意味しない。

**完了：1日、配置検査7項目PASS。** 物体9個（各3個）を維持し、物体操作は全種類0件。食料は初期1,275、消費3、地上1,272、補充0で収支一致。呼出し時間はコンパイル込み92.89秒。時間計測は単発で、性能差の比較ではない。[実行出力](evidence/placement.txt)

## 再実行

```powershell
julia --project=. experiments/portable_items/checks.jl
julia --project=. experiments/portable_items/integration_checks.jl
node experiments/portable_items/prepare.cjs BASE_INPUT.json NEW_INPUT.json 1
julia --project=. experiments/portable_items/run.jl NEW_INPUT.json NEW_OUTPUT
# 今回と同じ配置条件を再実行
julia --project=. experiments/portable_items/run.jl experiments/portable_items/evidence/placement-input.json NEW_OUTPUT
```

`prepare.cjs`は元入力を変更しない。`run.jl`は入力とソースを固定して実行する。物体・提案・受領記録を含む再開は日末チェックポイントを使う。旧JSON world_historyへ物体状態を落として引き継ぐ操作は明示的に拒否する。
