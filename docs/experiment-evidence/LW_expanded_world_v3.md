# LW拡張World v3：拠点周辺の障害物

2026-10-07、基準2ce9a14。既存の遠方の木・岩に加え、拠点周辺に8障害を追加。
高い岩4個（高さ2〜2.5m、半径0.6〜0.8m）と低い障害4個（高さ0.4m、半径0.1m）。
通常のsolid物体として既存の観測・遮蔽・衝突・身体能力判定で扱う。
拠点半径1.25mと身体余白を確保し、東へ10mの直線経路は開けている。
遠方のseed配置・食料10地点・食料量・視認距離・身体・行動規則は変更しない。
manifestはexpanded-camp-landscape-v3。旧出力は保存する。

関連38テストPASS。配置再現・食料非視認・出口・衝突判定に加え、
追加した低い障害を既存BodyCampaignがclimbとして選択し、身体が実際に通過する個別試験を確認。
この個別試験は食料を障害の向こうに置いた対照であり、統合Worldの採取成功ではない。

LW統合版3日、seed20261005：採取0、初期所持から食事4、全員最終所持0。
最終reserve A=0、B=73.7796、C=47.8064。
食料保存・身体作用の重複/重なりなし・3日完走の監査PASS。
探索成功や回避効率の改善を主張しない。全体suite/Luanti/長期運転は未実行。

[配置図・拠点拡大図](LW_expanded_world_v3.html) / [集計](LW_expanded_world_v3.json)

実行：`python -m integrations.lightweight.expanded_world_campaign --days 3`
生ログ：`outputs/expanded_world_v3_3d/run.jsonl`
