# LW sparse layout comparison

基準 efe12dc。`--layout sparse`を追加。既定dense、Runtime、観測上限、遠景rays方式、M_B field enabled、seed 20260928、3個体、30日／3持帰り条件は維持。

疎配置は密配置のobject index 0/1/4/7/10/14だけを残す。塔1、資源付近の目印3、その他の障害物2となる。資源8地点×12、座標、個体初期位置は完全に同じ。対象除去は遮蔽だけでなく衝突条件も変えるため、純粋な視覚密度だけの効果とは呼ばない。目印の色・高さは元のseed配置を保持し、個体へ食料との関連は教えない。

## 結果

疎配置は21.584秒で30日完了、各7,680観測。採取0、持帰り0、採用M_B0。

| 個体 | 密配置の移動距離 | 疎配置の移動距離 | 疎配置で食料visibleの観測数 |
| --- | ---: | ---: | ---: |
| A | 37 | 40 | 0 |
| B | 34 | 0 | 0 |
| C | 0 | 138 | 308 |

密配置でのacquisition_incompleteはA3661/B3678/C3719回。疎配置では全個体0回。主要な待機理由はlandmark_no_candidate_after_scanへ変わり、A3547/B3600/C3282回。Cは食料を観測し、terrainによる接近・旋回へ入ったが採取には至らなかった。したがって観測不完了が消えても、探索・接近の成功は保証されない。食料visible回数は異なる308個の食料や独立経験を意味しない。

今回のdense再実行は終了summaryなしでプロセス終了した（ログに診断文なし、原因未確定）。再実行完了とは扱わず、比較元には前回の完走済み `lightweight_world_30day_enabled.jsonl.gz` を使用。初期manifestからlayout/objects以外の条件一致を検査した。タイミングの公平な性能比較は主張しない。

保存: `tests/fixtures/lightweight_layout_sparse.jsonl.gz`、`lightweight_layout_comparison.json`。既存再生画面でgzipを選択して確認可能。

## 検証と次の観察

lightweight関連13テストPASS。新規試験は配置以外の資源・身体初期条件不変、object subset、再現性、不正layout拒否を確認。全リポジトリテスト・Luantiは未実行。

疎配置は観測の詰まりを外して行動を観察する基準候補になった。次はCが食料を見てから採取できなかった系列を再生して、接近・旋回・有限予算のどこで止まったかを見る。Hや学習規則は未変更。
