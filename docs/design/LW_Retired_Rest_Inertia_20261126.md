# 固定休息報酬と旧慣性の通常LWからの撤去

2026-11-26。基準2f2c1c8。[行動経路監査](LW_Action_Path_Duplicate_Audit_20261126.md)からの変更。

## 変更

- `configured_home_rest_arrival!` と `configured_home_rest_step!` の通常day呼出しを撤去。
  拠点で60秒休むことによる一日一度の固定+5を、method/route/chunkへ追加しない。
- 旧movement_inertiaの状態生成、観測比較、独自H更新、選択記録、receipt更新を撤去。
  旧慣性のためだけにhazard観測を起動する条件も外した。
- 休息による身体回復、embedded_restの場所経験、見積もり差の帰還評価、
  gradient_roll、continuous_descent、睡眠遮断は維持する。

旧関数定義は歴史的な局所検査・再現用に残す。通常LWの選択経路には接続しない。
新しい閾値・報酬・代替の強制行動は追加していない。

## 入力と保存

古い入力の `home_rest_reward=on` / `movement_inertia=on` は受け付けるが、再有効化しない。
結果と統合集計の `retired_action_paths` にrequestedとeffective=falseを明示する。
元入力のconfigはそのまま記録されるため、実効状態はこの欄で判定する。

新規チェックポイントのinertia枠はnothing、結果のmovement_inertiaもnothing。
保存形式の枠は残し、従来のソースハッシュ検証も維持。
既存の学習済みrewardから過去の固定報酬を推定して差し引くことはしない。
旧チェックポイントの自動移行は今回行わず、過去の凍結ソースは変更しない。

## 局所検査

`experiments/rock_gate/retired_rest_inertia_checks.jl`:

- 歴史的関数を直接使った対照で60秒後+5を確認し、身体のrestで疲労が減ることを別に検査。
- 旧関数を「呼ばれたらエラー」に差し替え、旧フラグONでも通常LWを実行。
- 128秒/日×2日の拠点内fixtureで60回以上休息しても固定報酬状態が生成されないこと、
  embedded_restが引き続き動くことを確認。
- 撤去後の旧フラグON/OFFでevents・counts・final_agents・daily・mb_map・home_activityを比較。
  保存した各個体/目的loopのRNGコピーから8個のUInt64を取り出して比較。
- 日末保存からの再開で同じ出力項目を比較。

これは撤去後の互換フラグの無作用と再開検査。変更前後の長期行動一致を示すものではない。
固定報酬をなくすため、長期の経路選好は変わり得る。速度改善率は計測していない。
新検査は機能別CI navigationへ登録。既存gradient_rollとembedded_restの局所検査も実施する。

実行結果（Windows、Julia 1.13.1、1スレッド）:

- 歴史的報酬対照・身体回復3項目PASS。
- 通常LWの無作用・保存再開・RNG等31項目PASS。
- gradient_roll39項目PASS、embedded_rest17項目PASS。合計90項目PASS。

比較対象の出力はJSONへ正規化後に内容で比較し、辞書の列挙順は比較しない。
RNG比較はhome/food等の保存loopの次の8値であり、世界全体の全乱数状態の完全証明ではない。
