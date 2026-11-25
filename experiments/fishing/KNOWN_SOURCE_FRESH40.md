# 既知地点の探索報酬修正版・新規40日（2026-11-25）

コード基準 d360994。初期状態から40日。旧報酬・MB・身体を継承しない。
入力は human-investment10-20261125/input.json、daysのみ40へ変更。
人間A/B/C/D、動物OFF、3栄養素身体、個人備蓄各3、非公開倉庫、日次食料再生。
採取・釣り・加工・取引・援助・取引関係投資ON。
既存の固定研修、交渉制限、拠点待機等の条件は維持。新しい固定行動は追加しない。

runner: experiments/body_macronutrients/lw_run.jl
出力: C:/Users/ken_m/Documents/Codex/human-known-source40-20261125
job prefix: C:/Users/ken_m/Documents/Codex/human-known-source40-20261125-job
scheduler: RDL-Julia-b0e9fcebcbe14fcc8af37ad7200338e1
日本時間20:58開始、Julia1.13.1、1thread、上限24時間。
実行コード・入力は出力先に凍結。チェックポイントは日末保存。

完了時はworker exit.jsonとcompleted.jsonの40日を照合する。
比較対象は旧新規10日＋継続30日の計40日。
探索成功・報酬・H、釣りと採取の選択/成果、糖・脂肪・組織・行動不能、取引、処理時間を確認。
実行開始の記録であり、完了・生存改善は未判定。
