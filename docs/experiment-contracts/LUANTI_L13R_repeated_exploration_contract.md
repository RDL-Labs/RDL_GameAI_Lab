# Luanti L13R — 発見まで最大30日の探索系列と記録保持

状態: IMPLEMENTED / FINITE ACCEPTANCE COMPLETE / l13r-v1 / 2026-09-27。
基準: `ae2a2a1` ＋ 本実装working tree。実行結果は[Evidence](../experiment-evidence/LUANTI_L13R_repeated_exploration_evidence.md)。
[探索計画](../design/RDL_GameAI_Luanti_Exploration_Plan.md#61-発見まで最大30日の探索系列)の
系列実行・日間記録保持を切り出す。[L13A](LUANTI_L13A_finite_exploration_contract.md)の固定規則・身体操作・取得契約は維持する。

## 問いと停止境界

**未発見日は次の日へ進み、本人が実際にFoodを観測したら新しい日を起動せず、最大30日で打ち切れるか。**
日ごとにWorld・身体・Runtimeを初期化し、本人の受理済み観測・実測作用・結果だけを保持できるか。
成功者だけでなく未発見の日と系列全体を保存する。

L13Rは学習前の反復基準実験である。`history()`が返す過去材料は、現行の固定L13A選択器へ接続しない。
開始記録は常に`history_consumed_by_policy=false`を持つ。
保持あり／リセットで行動が同じでも不具合ではなく、記録保持の効果やM_Bの行動差が証明されたことにもならない。
複数目印の経路照合はL13B、帰納・独立検査・T1/M_Bによる探索選択はL13Cとして未接続のまま残す。
保持するのは探索の出典付き記録であり、既存のExperience storeへ新しい学習Experienceを登録する処理でもない。

## 日・系列・発見の区別

- 初版は一系列に一個体npc_a。日数上限は1〜30、主受入は30とする。
- 各日16秒の探索World時間、250ms枠、最大64取得packet・64操作許可。
  最大30日で480秒・1920packet・1920許可。各日の終了後の配送処理は既存の25秒までの有限run内で行う。
  通信／実行器エラーや取得枠逸失は機構不具合として停止し、普通の時間切れに変換しない。
- 「日」は昼間固定の独立Episode。夜間・睡眠・消耗回復は実装しない。
  拠点・初期yaw・地形・Food・山を同一条件へ再設定する。本人の帰還成功とは数えない。
  毎日の初期観測でFoodが見えていないことを検査する。
- `run_id`と`episode_id`は日ごとに新規。日番号・ID文字列・scenarioは探索選択規則へ使わない。
  各日の身体台帳・観測store・HTTP serverを別processで作り直す。
  旧runのcommand／観測／結果は新runのcontext検査で拒否される。

系列の`discovered`は新しい受理済み局所Food観測に検出が存在すること。
発見元observationと取得時刻を残す。実験者のWorld座標、予測、過去の検出から発見を補完しない。
単発L13Aは当日の残り予算で接近・pickupを続けるため、系列終了判断はその日の受付完了後に行う。
「発見した時刻」と「取得した時刻」は別であり、発見の直後に身体を止める契約ではない。
発見したがpickupできなかった日でも系列は`discovered`、`acquired=false`となる。

30日未発見は`undiscovered_at_limit`。発見日・発見までの時間／距離／許可数はnull、
実際に消費した時間／距離／許可数は別に保存する。Food不存在、経路無価値、死亡を意味しない。
機構不具合は`mechanism_error`とし、途中までの記録と未完了日の予約を保存して停止する。
部分実行した日を自動的に別eventへ置換して再試行しない。

## 受理・保持・再送

`runtime.exploration_series.ExplorationSeries`は身体権限を持たない系列台帳。
`start_day`で一日だけ予約し、`close_day`で完了したHTTP往復を受理する。
入力はconfigure／observe／result／finishのrequestとresponseのみ。
L13Aの`FiniteExploration`へ再生し、入力検査・実測結果の束縛・受付応答・正常終了を再検証してから一括保存する。
日ごとの最大往復数は256。署名付き証拠ではなく、身体の真の動作は別のWorld checkerで検査する。

同じ日・同じ完全入力は既存receiptを返す。内容変更、run再利用、並列の別日起動、
別個体・別runの混線、未完了日、response改変を拒否する。失敗時に完了日や履歴を部分更新しない。
満杯・発見後も既受理日の再送は可能だが、新しい日は起動できない。
旧日の再送で現在の日の予約を解除しない。process内RLockで同一日の並行受付を一件へまとめる。

- `memory`: 過去の受理済み観測・command・実測result・Sensory snapshotを出典付きで返す。
  開始時に前日までの参照、digest、取得件数を固定する。
- `reset`: 本人へ公開する履歴は常に空。実験者用監査archiveには全日を保存する。
- World絶対位置、Food配置、山ID／座標、描画readback、scenario、生成手順は台帳入力から除く。
  観測内のFood refは、その日に実際に見えた対象へのrefに限る。
- 原取得時刻・run・時計・poseを保存し、日をまたぐ参照で鮮度を更新しない。
  異なる日のローカル時刻が同じでも、同時観測や同一frameと扱わない。
- 全返値はcopy。保持記録を呼出し側が書き換えても保存済み状態は変わらない。

履歴も台帳も有限な一実験のprocess内状態。圧縮replay archiveは監査・再生用であり、
再起動後に身体操作を継続する永続トランザクションや自律長期記憶ではない。

## 実World受入と指標

主比較は右曲がりの色帯あり／同一Food配置で色帯なし、それぞれmemory／resetの4系列。
帯ありの初日発見で終了する陽性対照と、帯なしで最大30日を消費する未発見対照を比較する。
未発見対照を途中で正解方向へ誘導せず、Food追加・取得済み扱い・日番号による方向切替をしない。

各日は既存Luanti checkerで実位置／yaw readback、距離・回転予算、取得範囲、重複作用防止、
独立したrun、昼間固定、山の実観測、canonical／InteractionHistory非介入を検査する。
系列checkerはWorld初期条件の一致、出典の分離、記録保持／リセット、発見時停止、30日上限、
全日再生と系列receipt一致を検査する。保持条件間の固定規則のaction列も比較する。

全日の観測・作用・未検出／観測不足／blocked・終了理由を残す。
発見日と累積コストは系列単位で比較し、未発見系列を除外しない。
後半の日に残った系列だけの平均を学習改善と読まない。
現行consumerが履歴を参照しない以上、保持による行動差はこの受入の成功条件にしない。
