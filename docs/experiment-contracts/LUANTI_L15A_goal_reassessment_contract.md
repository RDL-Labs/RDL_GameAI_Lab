# L15A — 休憩後の有限な目標再評価

状態: FINITE IMPLEMENTATION / WORLD ACCEPTANCE COMPLETE。
基準 `b14f834`。[直前の障害比較](../experiment-evidence/LUANTI_L15A_rest_obstacle_evidence.md)からの独立opt-in。

## 権限

`l15a-goal-reassessment-v1` / `ReassessingExploration` は既存再活性化Runtimeを拡張する。
configureで `reassessment_mode=disabled/enabled` を固定。既存modeは変更しない。
既存の `landmark_goal_budget` は1目標の予算ではなく、1期間の最大8目標選択の予算だった。
この8件をリセットせず、次の条件で別枠を1回だけ付与する。

- 現在判断が `landmark_goal_budget`、かつ実休憩からの `resumed`。
- 個体・期間ごと最大1回。候補なし・同点・情報不足でも消費し、同期間に再抽選しない。
- 旧 `selected_count=8` は保持。最大8通常目標＋1追加目標と明示し、予算増加を隠さない。
- 旧目標全体、元観測、未達状態を `state.held` とbaseline reasonへ保持する。
- Food、身体対応不足、取得不足、variation、休憩中を上書きしない。
- 再送は既存observe identityで同じ指令を返す。失敗した受付で枠を消費しない。

## 有限な候補規則

現在の本人観測にある最大13特徴のみ。近距離以外、角幅45度以下を候補にする。
元目標の色と同じ特徴は全て除外する。この保守的な外観条件は物体同一性ではない。
同色の別物も除外され得る。過去に試した全目標を識別して永久に除外する機能ではない。
元目標の記述がない場合は保留する。World ID・座標・障害除去ラベルを入力へ追加しない。

基本costは `abs(現在の角域中心)/90`。適用可能なblocked記録がある場合だけ、
正面0度を含む候補へ既存の一時cost0.5を足す。候補ごとに両成分を別々に記録する。
これは初期の固定制御規則で、学習された価値や新M_Bではない。記憶は方向命令を出さない。
唯一の最低costを選択し、最低値が同点なら `ambiguous_minimum` で待機する。

選択直後は既存の目印servoと同じ最大45度の旋回、または1歩の移動。
以降は既存の特徴対応・最大12操作・実身体結果・Food優先の経路へ戻す。
詰まる、見失う、途中でFoodへ向く、再び予算待ちになることを許容する。
通行可能性や到達成功を保証しない。次期間の枠更新は既存の期間境界に従う。

## 比較

障害存続/除去 × 再評価disabled/enabled × 内部参照disabled/enabled = 8run。
同じseed20260928、草地、3個体steady、1期間16秒、通常取得64件/個体。
先に存続4条件を固定。旧目標の色と候補の関係を確認した後、除去4条件を追加で固定した。
Runtime規則は8runを通して同じ。各条件1runで、取得時刻には実機揺れがある。

再評価の機会による差と、記憶costによる差を分離する。
追加選択、実旋回、実移動、再停滞、未達、採取を別に記録し、移動量の増加だけを改善としない。
独立したT1採用・M_B更新・自由連想・自律的な目標生成・生物学的DMNの再現は範囲外。

[Evidence](../experiment-evidence/LUANTI_L15A_goal_reassessment_evidence.md)
