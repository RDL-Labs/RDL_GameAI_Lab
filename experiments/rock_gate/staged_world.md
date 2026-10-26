# 段階的な食料と地域の特徴

普通の拠点で`--staged-food --distinctive-landmarks --food-roads on --world-features on`を使用。--nearby-foodとは併用不可。食料段階と目印群は独立したフラグなので、片方ずつ比較可能。既存マップの既定値は変えない。

- 初級：距離4、3地点各12食、有限。
- 中級：距離約10.8〜12、3地点各24食、有限。既存の分岐道の途中。
- 上級：距離約19〜24、3地点各24食、再生あり。既存の外側地点。

段階は世界側の配置ラベルで、順番に解禁しない。最初から全地点が存在し、AIは通常の観測・探索で選ぶ。実測による難易度保証ではなく距離段階。初日備蓄は--camp-provisionsで別途追加する。

西に黄土色の弧状岩場、東に2列の並木、南に大小の岩を設ける。既存の色・大きさ・連続構造の認識材料を増やす。塔と松明は保持。今回は障害物の配置としての地形特徴であり、標高・川の形・森の生態系は変更しない。世界IDは既存最大値から付番。

実行可能性検査：全9地点への世界側の経路について身体余白0.2付きの障害物衝突と水域を確認。有限6地点が再生しないこと、遠方3地点は再生すること、ID重複なしを確認。段階配置48項目・既存道19項目・普通拠点13項目PASS。AIの行動試験は未実施。

構築確認：outputs/staged-world-prepare-20261026。図の再生成：`node experiments/rock_gate/render_staged_world.cjs outputs/staged-world-prepare-20261026/ordinary/input.json experiments/rock_gate/evidence/staged-world/layout`。
