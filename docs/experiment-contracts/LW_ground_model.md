# LW統合版：観測された地面の連続パターンを暫定M_Bとして探索へ接続

基準 cb8bd8a。LW統合版は軽量Worldの探索・採取・帰還・身体・危険・社会・
Sleepを同時運転する本線を指す。基本OPTIONSはintegrated_social_campaign、
実行本体はtimed_harvest。今回の入口はground_model_campaign。

World側の通行によるwear形成、未使用時の回復は既存仕様を維持する。
個体は自身の15点地面観測から得た帯候補を、GameAI-localな暫定M_Bとして
まとめる。canonical M_Bへの採用、恒久的な道ID、道の目的地の推論ではない。

## 観測断片の対応

- 初版の対象はtrampled_grass/bare_groundのsampled_band_candidate。
  草の帯も認識はするが、今回の探索候補にはしない。
- run/agent/epoch/clockを束縛。前の判断に対応した実行resultのsource、
  姿勢・revision・取得時刻を確認し、実測forward/right/yawで相対点を変換する。
- 0.6以内で現観測2点以上が過去点へ対応し、両側の割当が一意な場合だけ継続。
  一致は近似であり物理的な同一道を証明しない。指令値やWorld座標は使用しない。
- 確認できない身体対応は旧モデルを退役。曖昧な対応は候補化しない。
  遮蔽/未観測はnot_currently_supported、既観測付近の草への変化は
  observed_context_changed。単なる見失いを道消滅と断定しない。
- 最大8activeモデル、32相対点/モデル、16観測出典・16対応link、
  未再観測8秒で退役。linkは見失い中を含む身体変換列を保持（最大32）。
  これは有限な短期連続性であり、長い道全体の記憶・地図・分岐網は未実装。

## 既存探索への使用

ground_continuity_enabledは明示opt-in。ground_pattern_enabledとcontinuous選択が必要。
探索phaseのmethod_reselectionで、現観測が支持するモデルについて、最も遠い
実観測点へ向かう候補food/ground_Nを追加する。未観測の先へ外挿しない。
既存の地面評価でsampled/通行可能な5方向だけ。身体・energy・Sleep経験・
経験束・選択経路・社会・食事・危険優先は既存順序のまま。
通常の有効なbaseline、採取、帰還、夜間、危険phaseを道で置換しない。

基礎score2.25から既存のH/θ圧力を引く。θ=2。
旋回後は実測旋回・現地面・現在の帯支持を再確認して一歩進む。
その一歩で新しい点（保存点から0.25超）が得られたら局所の進展支持、
帯は再観測できたが拡張せず/blockedならH+1。対応不能はdefer。
これらは目的地へ近づいた、採取に成功したという評価ではない。
未実行の候補へH評価・成功支持を与えない既存のsupersession処理を維持。
退役したモデルの子nodeも削除し、別モデルへHを引き継がない。

## 比較

前実験の形成30日checkpointを両条件で継承、新3個体30日、seed20261005。
道は両条件とも存在し、接続フラグだけ異なる。観測・身体resultから保存モデルを
全再計算する。候補提示/選択/最終実行を別々に計数。
採取改善を受入条件にせず、既存生活との競合も結果として残す。

## 90日延長比較

`python -m integrations.lightweight.ground_model_campaign --days 90`。
同じ形成30日checkpointから、新個体の運転を90日へ延長する（Worldは通算120日）。
disabled/enabledとも終了条件は90日期限のみ。途中の30日境界で状態をリセットしない。
既存の長期設定に従いSleep保存容量は576、道モデルの保持条件・係数は変更しない。
期間別集計は `python -m integrations.lightweight.summarize_ground_model outputs/ground_model_90d`。
1〜30日/31〜60日/61〜90日の採取・食事・移動距離・道候補実行を分ける。
