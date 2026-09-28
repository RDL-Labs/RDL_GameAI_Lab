# L15A — 実接触記録の休憩後適用比較

状態: FINITE WORLD COMPARISON COMPLETE / 行動変更・脱出改善は未成立。
基準: `259a26f`。既存[再活性化契約](LUANTI_L15A_rest_reactivation_contract.md)の適用条件を実Worldで検査する。
Runtime、係数、休憩周期、探索目的の予算、M_B権限は変更しない。

## 問いと固定条件

同じ姿勢で実際に進めなかった記録が、通常の疲労休憩後に適用可能になるか。
適用可能であっても現在のactionが対象外なら介入しない。行動変更や成功を受入の必須条件にしない。

- natural_meadow、seed 20260928、A/B/C steady、1期間16秒、各64通常取得。
- reactivation disabled/enabled × 障害persistent/removed の4run。
- 既存3個体WorldのAに限り、slot23取得前に現在位置から1歩までの頭上セルへ実nodeを置く。
- 既存 `natural.destination` が身体移動の可否を検査する。結果をblockedへ書き換えない。
- removedだけslot27取得前に元nodeへ戻し、readbackする。
- slot28で通常観測・再開判断・身体結果を保存する。実Worldの前方通行可否は実験者専用監査。
- 予定slotは既存保存記録から選択し、persistent/enabledの予備1run後に4比較を固定した。
  自然発生率や未選択seedでの有効性を主張しない。

障害位置の決定に使うWorld姿勢、node座標、存続/除去ラベル、実験者の通行可能判定は個体へ渡さない。
同じseedでも取得時刻・HTTP遅延には揺れがある。入力系列が完全同一という比較ではない。
通常取得、生活priority、既存目的の終了条件を維持する。

## 別々に記録する段階

1. 実移動結果blocked、変化しない身体姿勢。
2. 実waitによる有限休憩、新しい通常取得。
3. 記憶の取得と適用条件、観測変化による失効理由。
4. 潜在的な前方costと、実際に地形へ適用したcost。
5. baseline actionと最終action、その後の身体結果。

完全取得は全空間の把握ではない。低い地形rayが頭上障害を捉えなくても、別の目印fanが変化する場合がある。
除去を知る根拠は現在の本人観測だけ。観測が同じならWorld側で除去した事実だけを使って記録を失効させない。
一方、観測が変われば既存の `observed_context_changed` を維持する。

本比較で `landmark_goal_budget` によりwaitとなる場合、記憶costで目的を再起動しない。
再起動・目標の再選択は別の権限契約が必要。単発記憶を採用済みM_Bや障害の原因推論へ昇格させない。

成果物と結果は[Evidence](../experiment-evidence/LUANTI_L15A_rest_obstacle_evidence.md)。
