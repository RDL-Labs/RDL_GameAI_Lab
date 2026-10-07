# 道を新個体へ引き継ぐ30+30日比較

2026-10-07、基準 b777f3e。[契約](../experiment-contracts/LW_cohort_paths.md)。
軽量World、seed20261005。前任3個体30日、未学習の新3個体30日×2条件。
前任者は退場。新個体は同一slot名だが別run identity、記憶/M_B/Sleepは新規。

| 条件 | 採取 | 食事 | 最終の道区画数 |
|---|---:|---:|---:|
| 前半30日 | 95 | 92 | 6 |
| 新個体・道継承 | 91 | 91 | 4 |
| 新個体・初期wearだけ0 | 95 | 93 | 5 |

後半の初期manifestはresetフラグ以外一致。資源・再生時刻・危険物・
新個体の身体/持ち物/位置/parameterは同一。初期学習記録は全員0。
両条件とも全員初日に採取し、初採取時刻も一致。拠点近くに資源がある
social_shared配置なので、遠い食料へ道が導くことを検査した結果ではない。

同じ個体slot/取得時刻の4,608判断中、commandのkind/amountが1,710件異なる。
比較不能な時刻組は0。実行resultのstatusは1,538件異なる。
最初のkind/amount差は後半36.25秒のnpc_c: 継承move 0.5／リセットsocial 0。
socialの内容が違ってもkind/amountが同じなら、この操作差計数には含めない。
差の件数は全て直接のenergy選択差という意味ではなく、後続相互作用も含む。

全員の最終reserveは正。道継承81.02/92.57/78.46、リセット92.94/82.85/88.47。
3runとも食料保存・身体作用重複なし・作用重なりなし・30日完走の監査PASS。
関連21テストPASS。全体suite/Luantiは未実行。

今回成立したのは、個体の記憶を渡さなくてもWorldの地面履歴を通して
後続個体の生活行動が変わること。採取改善・道の意味学習・道を追う能力は未確認。
認識機能は引き続き記録のみ、局所抵抗→身体消耗/候補順位は既存接続。
1seedであり、継承の一般的有利/不利は結論しない。

[比較地図](LW_cohort_paths.html) / [集計・checkpoint・ログhash](LW_cohort_paths.json)。
地図は実験者用で個体には渡さない。各図は自動縮尺。
地面のoperationsは現在cohortのみ、cell距離は前任者を含む累積履歴。
旧所持食料は退場者とともに除外され、共有備蓄があればWorldとして継承する。

実行 `python -m integrations.lightweight.cohort_path_campaign`。
再監査 `python -m integrations.lightweight.audit_cohort_paths`。
生ログ `outputs/cohort_paths/{formation,inherited,reset}.jsonl`。
